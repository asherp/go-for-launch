extends Node2D

## Ghost Manager - Spawns multiple ghost players based on available recordings
## This script automatically discovers all recording files and creates a ghost for each one

# Ghost player scene template (we'll duplicate the existing ghost)
@export var ghost_scene_path: String = "res://scenes/launch_blocks.tscn"
@export var recordings_directory: String = "res://recordings"
@export var ghost_spacing: float = 32.0  # Horizontal spacing between ghosts
@export var ghost_colors: Array[Color] = [
	Color(0.5, 0.5, 1.0, 0.6),  # Blue
	Color(0.5, 1.0, 0.5, 0.6),  # Green
	Color(1.0, 0.5, 0.5, 0.6),  # Red
	Color(1.0, 1.0, 0.5, 0.6),  # Yellow
	Color(1.0, 0.5, 1.0, 0.6),  # Magenta
	Color(0.5, 1.0, 1.0, 0.6),  # Cyan
	Color(1.0, 0.8, 0.5, 0.6),  # Orange
	Color(0.8, 0.5, 1.0, 0.6),  # Purple
]

var spawned_ghosts: Array[Node] = []
var recording_files: Array[String] = []

func _ready() -> void:
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	spawn_all_ghosts()

func spawn_all_ghosts() -> void:
	"""Discover all recordings and spawn a ghost for each one"""
	# Clear any existing ghosts
	clear_all_ghosts()
	
	# Find all recording files
	recording_files = get_all_recording_files()
	
	if recording_files.is_empty():
		print("[GhostManager] No recordings found in %s" % recordings_directory)
		return
	
	print("[GhostManager] Found %d recordings, spawning ghosts..." % recording_files.size())
	
	# Spawn a ghost for each recording (await each one to ensure proper setup)
	for i in range(recording_files.size()):
		var recording_path = recording_files[i]
		var ghost = await spawn_ghost_for_recording(recording_path, i)
		if ghost:
			spawned_ghosts.append(ghost)
			print("[GhostManager] Spawned ghost %d for recording: %s" % [i + 1, recording_path.get_file()])

func get_all_recording_files() -> Array[String]:
	"""Get all recording files sorted by modification time (newest first)"""
	var recordings: Array[String] = []
	var dir = DirAccess.open(recordings_directory)
	
	if not dir:
		push_error("[GhostManager] Cannot open recordings directory: %s" % recordings_directory)
		return recordings
	
	# Collect all recording files with their timestamps
	var file_data: Array[Dictionary] = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("player_recording_"):
			var full_path = recordings_directory + "/" + file_name
			var modified_time = FileAccess.get_modified_time(full_path)
			file_data.append({
				"path": full_path,
				"time": modified_time,
				"name": file_name
			})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by modification time (newest first)
	file_data.sort_custom(func(a, b): return a.time > b.time)
	
	# Extract just the paths
	for data in file_data:
		recordings.append(data.path)
	
	return recordings

func get_start_position_from_recording(recording_path: String) -> Dictionary:
	"""Read the first position from a recording to get starting floor and position"""
	var file = FileAccess.open(recording_path, FileAccess.READ)
	if not file:
		push_error("[GhostManager] Could not open recording file: %s" % recording_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GhostManager] Could not parse recording JSON: %s" % recording_path)
		return {}
	
	var recording_data = json.data
	if not recording_data.has("events") or recording_data.events.is_empty():
		push_error("[GhostManager] Recording has no events: %s" % recording_path)
		return {}
	
	# Find the first position event
	var first_event = null
	for event in recording_data.events:
		if event.has("player_position") and event.has("floor"):
			first_event = event
			break
	
	if not first_event:
		push_error("[GhostManager] No position data found in recording: %s" % recording_path)
		return {}
	
	var floor_name = first_event.floor
	var pos = first_event.player_position
	var start_position = Vector2(pos.x, pos.y)
	
	# Find the floor node
	var floor_node = get_node_or_null("../" + floor_name)
	if not floor_node:
		push_warning("[GhostManager] Floor '%s' not found, falling back to GroundFloor" % floor_name)
		floor_node = get_node_or_null("../GroundFloor")
	
	return {
		"floor": floor_node,
		"position": start_position,
		"floor_name": floor_name
	}

func get_floor_from_recording(recording_path: String) -> Node:
	"""Read the first position from a recording to determine which floor the ghost should spawn on"""
	var file = FileAccess.open(recording_path, FileAccess.READ)
	if not file:
		push_error("[GhostManager] Could not open recording file: %s" % recording_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GhostManager] Could not parse recording JSON: %s" % recording_path)
		return null
	
	var recording_data = json.data
	if not recording_data.has("events") or recording_data.events.is_empty():
		push_error("[GhostManager] Recording has no events: %s" % recording_path)
		return null
	
	# Find the first position event
	var first_event = null
	for event in recording_data.events:
		if event.has("player_position"):
			first_event = event
			break
	
	if not first_event:
		push_error("[GhostManager] No position data found in recording: %s" % recording_path)
		return null
	
	var first_position = first_event.player_position
	
	# Determine floor based on floor name or Z position
	var floor_name = "GroundFloor"  # Default fallback
	
	# Check if the first event has floor information
	if first_event.has("floor") and not first_event.floor.is_empty():
		# Use explicit floor name from the event
		floor_name = first_event.floor
		print("[GhostManager] Using floor from event: %s" % floor_name)
	elif first_position.has("z_height"):
		# Determine floor based on Z height
		var z_height = first_position.z_height
		if z_height <= 0:
			floor_name = "GroundFloor"
		elif z_height <= 16:
			floor_name = "FirstFloor"
		elif z_height <= 32:
			floor_name = "SecondFloor"
		else:
			floor_name = "GroundFloor"  # Fallback
	
	# Find the floor node
	var floor_node = get_node_or_null("../" + floor_name)
	if not floor_node:
		push_warning("[GhostManager] Floor '%s' not found, falling back to GroundFloor" % floor_name)
		floor_node = get_node_or_null("../GroundFloor")
	
	return floor_node

func spawn_ghost_for_recording(recording_path: String, ghost_index: int) -> Node:
	"""Spawn a single ghost player for a specific recording"""
	print("[GhostManager] Attempting to spawn ghost %d for recording: %s" % [ghost_index + 1, recording_path.get_file()])
	
	# Get starting position from recording BEFORE creating ghost
	var start_data = get_start_position_from_recording(recording_path)
	if start_data.is_empty():
		push_error("[GhostManager] Could not read start position from recording: %s" % recording_path.get_file())
		return null
	
	var target_floor = start_data.floor
	var start_position = start_data.position
	
	if not target_floor:
		push_error("[GhostManager] Could not determine floor for recording: %s" % recording_path.get_file())
		return null
	
	print("[GhostManager] Found target floor: %s, start position: %s" % [target_floor.name, start_position])
	
	# Create a new ghost player with the starting position
	var ghost = create_ghost_player(ghost_index, start_position)
	if not ghost:
		push_error("[GhostManager] Failed to create ghost player %d" % (ghost_index + 1))
		return null
	
	print("[GhostManager] Created ghost player %d successfully" % (ghost_index + 1))
	
	# Set initial position before adding to scene (uses local coordinates)
	ghost.position = start_position
	print("[GhostManager] Set ghost %d initial position to: %s" % [ghost_index + 1, start_position])
	
	# Add to the scene
	target_floor.add_child(ghost)
	print("[GhostManager] Added ghost %d to %s at position %s (global: %s)" % [
		ghost_index + 1, target_floor.name, ghost.position, ghost.global_position
	])
	
	# Verify the ghost is visible
	if ghost.get_child_count() > 0:
		var sprite = ghost.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			print("[GhostManager] Ghost %d sprite texture loaded: %s" % [ghost_index + 1, sprite.texture.get_path()])
		else:
			print("[GhostManager] WARNING: Ghost %d sprite has no texture!" % (ghost_index + 1))
	
	# Set up the ghost with the specific recording (await it!)
	await setup_ghost_for_recording(ghost, recording_path, ghost_index)
	
	return ghost

func create_ghost_player(ghost_index: int, start_position: Vector2) -> Node:
	"""Create a new ghost player node with all required components"""
	print("[GhostManager] Creating ghost player %d (start_position will be: %s)..." % [ghost_index + 1, start_position])
	
	# Create the main CharacterBody2D
	var ghost = CharacterBody2D.new()
	ghost.name = "GhostPlayer_%d" % (ghost_index + 1)
	ghost.z_index = 2  # Higher z_index to ensure visibility
	ghost.add_to_group("ghost")
	
	# Don't set position here - let _position_player_at_start() handle it
	# This avoids confusion between local and global position
	
	print("[GhostManager] Created CharacterBody2D for ghost %d (position will be set by recorder)" % (ghost_index + 1))
	
	# Add CollisionShape2D
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.visible = false
	collision_shape.position = Vector2(0, 1)
	
	# Create circle shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 3.0
	collision_shape.shape = circle_shape
	ghost.add_child(collision_shape)
	
	# Add Sprite2D
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, 1)
	sprite.z_index = 2  # Ensure sprite is visible
	
	# Load the player texture
	var player_texture = load("res://player/player.png")
	if player_texture:
		sprite.texture = player_texture
	else:
		push_warning("[GhostManager] Could not load player texture")
	
	ghost.add_child(sprite)
	
	# Add NavigationAgent2D
	var nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	nav_agent.path_desired_distance = 5.0
	nav_agent.target_desired_distance = 5.0
	nav_agent.path_postprocessing = 1
	nav_agent.debug_enabled = true
	nav_agent.debug_use_custom = true
	ghost.add_child(nav_agent)
	
	# Add PlayerRecorder
	var recorder = Node.new()
	recorder.name = "PlayerRecorder"
	var recorder_script = load("res://scripts/player_recorder.gd")
	if recorder_script:
		recorder.set_script(recorder_script)
	ghost.add_child(recorder)
	
	# Add the player script
	print("[GhostManager] Loading player_1.gd script for ghost %d..." % (ghost_index + 1))
	var player_script = load("res://scripts/player_1.gd")
	if player_script:
		print("[GhostManager] Successfully loaded player_1.gd script")
		ghost.set_script(player_script)
		
		# CRITICAL: Set ghost properties BEFORE adding to scene tree
		# This ensures _ready() sees the correct values
		ghost.set("is_ghost", true)
		ghost.set("random_spawn", false)
		ghost.set("loop_playback", true)
		ghost.set("auto_record_on_start", false)
		
		# Override the ghost's auto-load behavior by setting a flag
		ghost.set_meta("skip_auto_load", true)
		
		# Disable position correction for ghosts to prevent navigation issues
		ghost.set("max_deviation_threshold", 999999.0)
		
		# Set ghost color (cycle through available colors)
		if ghost_index < ghost_colors.size():
			ghost.set("ghost_color", ghost_colors[ghost_index])
		else:
			# Generate a random color for additional ghosts
			ghost.set("ghost_color", Color(randf(), randf(), randf(), 0.6))
		
		# Verify is_ghost is set correctly
		var is_ghost_value = ghost.get("is_ghost")
		print("[GhostManager] Ghost %d properties set - is_ghost verified: %s" % [ghost_index + 1, is_ghost_value])
	else:
		push_error("[GhostManager] Could not load player_1.gd script")
		ghost.queue_free()
		return null
	
	print("[GhostManager] Successfully created complete ghost player %d" % (ghost_index + 1))
	return ghost

func setup_ghost_for_recording(ghost: Node, recording_path: String, ghost_index: int) -> void:
	"""Set up a ghost to play a specific recording"""
	print("[GhostManager] Setting up ghost %d with recording..." % (ghost_index + 1))
	
	# Ghost is already in the scene tree and _ready() has been called
	# Just wait one frame to ensure everything is initialized
	await get_tree().process_frame
	print("[GhostManager] Ghost %d initialization frame complete" % (ghost_index + 1))
	
	# Verify is_ghost flag
	var is_ghost_check = ghost.get("is_ghost")
	print("[GhostManager] Ghost %d is_ghost flag: %s" % [ghost_index + 1, is_ghost_check])
	
	# Wait a bit longer to ensure the ghost's auto-load doesn't interfere
	await get_tree().create_timer(0.1).timeout
	
	# Stop any existing playback first
	if ghost.has_method("stop_playback"):
		ghost.stop_playback()
	
	# Load the specific recording
	if ghost.has_method("load_recording_from_file"):
		print("[GhostManager] Loading recording for ghost %d: %s" % [ghost_index + 1, recording_path.get_file()])
		if ghost.load_recording_from_file(recording_path):
			print("[GhostManager] Ghost %d successfully loaded recording" % (ghost_index + 1))
			
			# Verify recording was loaded
			var recorder = ghost.get_node_or_null("PlayerRecorder")
			if recorder:
				var event_count = recorder.get_recorded_inputs().size()
				print("[GhostManager] Ghost %d recorder has %d events loaded" % [ghost_index + 1, event_count])
			
			# Start playback immediately - no delay
			if ghost.has_method("start_playback"):
				print("[GhostManager] Starting playback for ghost %d..." % (ghost_index + 1))
				var playback_started = await ghost.start_playback(1.0, false)  # Position correction disabled for multiple ghosts
				if playback_started:
					print("[GhostManager] Ghost %d playback started successfully!" % (ghost_index + 1))
				else:
					push_error("[GhostManager] Ghost %d playback failed to start!" % (ghost_index + 1))
		else:
			push_error("[GhostManager] Failed to load recording for ghost %d: %s" % [ghost_index + 1, recording_path])
	else:
		push_error("[GhostManager] Ghost %d does not have load_recording_from_file method" % (ghost_index + 1))

func clear_all_ghosts() -> void:
	"""Remove all spawned ghosts"""
	for ghost in spawned_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	spawned_ghosts.clear()

func refresh_ghosts() -> void:
	"""Refresh the ghost list (useful for testing)"""
	print("[GhostManager] Refreshing ghosts...")
	spawn_all_ghosts()

func get_ghost_count() -> int:
	"""Get the current number of spawned ghosts"""
	return spawned_ghosts.size()

func get_recording_count() -> int:
	"""Get the number of available recordings"""
	return recording_files.size()

# Input handling for testing
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 0 key - restart the game
		if event.keycode == KEY_0:
			print("[GhostManager] Restarting game...")
			get_tree().reload_current_scene()
		# G key - refresh ghosts
		elif event.keycode == KEY_G:
			refresh_ghosts()
		# H key - print ghost info
		elif event.keycode == KEY_H:
			print_ghost_info()

func print_ghost_info() -> void:
	"""Print information about spawned ghosts and recordings"""
	print("\n=== Ghost Manager Info ===")
	print("Recordings found: %d" % get_recording_count())
	print("Ghosts spawned: %d" % get_ghost_count())
	
	if not recording_files.is_empty():
		print("\nRecordings:")
		for i in range(recording_files.size()):
			var file_name = recording_files[i].get_file()
			var ghost_status = "✓" if i < spawned_ghosts.size() else "✗"
			print("  %s %d. %s" % [ghost_status, i + 1, file_name])
	
	print("========================\n")
