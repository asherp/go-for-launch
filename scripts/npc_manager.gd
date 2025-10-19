extends Node2D

## NPC Manager - Spawns multiple npc players based on available recordings
## This script automatically discovers all recording files and creates a npc for each one

const CharacterNames = preload("res://scripts/character_names.gd")

signal all_npcs_started_playback

# Character names are now loaded from character_names.txt via CharacterNames utility class

func get_player_number_from_filename(filename: String) -> int:
	"""Extract player number from filename like 'player_1.json'"""
	var base_name = filename.get_basename()
	if base_name.begins_with("player_"):
		var number_part = base_name.substr(7)  # Remove "player_" prefix
		if number_part.is_valid_int():
			return number_part.to_int()
	# Invalid format, return 0 to sort first
	return 0

func get_character_name_from_filename(filename: String) -> String:
	"""Extract character name from filename like 'marty_mcfly.json' or 'player_1.json'"""
	var result = CharacterNames.from_filename(filename)
	print("[NPCManager] Processing filename: %s -> character name: %s" % [filename, result])
	return result

# NPC player scene template (we'll duplicate the existing npc)
@export var npc_scene_path: String = "res://scenes/launch_blocks.tscn"
@export var recordings_directory: String = "res://recordings"
@export var npc_spacing: float = 32.0  # Horizontal spacing between npcs
@export var npc_colors: Array[Color] = [
	Color(0.5, 0.5, 1.0, 0.6),  # Blue
	Color(0.5, 1.0, 0.5, 0.6),  # Green
	Color(1.0, 0.5, 0.5, 0.6),  # Red
	Color(1.0, 1.0, 0.5, 0.6),  # Yellow
	Color(1.0, 0.5, 1.0, 0.6),  # Magenta
	Color(0.5, 1.0, 1.0, 0.6),  # Cyan
	Color(1.0, 0.8, 0.5, 0.6),  # Orange
	Color(0.8, 0.5, 1.0, 0.6),  # Purple
]

var spawned_npcs: Array[Node] = []
var recording_files: Array[String] = []

func _ready() -> void:
	# Add to group for easy finding
	add_to_group("npc_manager")
	
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	spawn_all_npcs()

func spawn_all_npcs() -> void:
	"""Discover all recordings and spawn a npc for each one"""
	# Clear any existing npcs
	clear_all_npcs()
	
	# Find all recording files
	recording_files = get_all_recording_files()
	
	if recording_files.is_empty():
		print("[NPCManager] No recordings found in %s" % recordings_directory)
		return
	
	# Check if player is spawning as a specific character
	var global_data = get_node_or_null("/root/GlobalData")
	var player_character_name = ""
	if global_data and global_data.has_meta("spawn_as_character"):
		var character_data = global_data.get_meta("spawn_as_character")
		player_character_name = character_data.get("recording_name", "")
		print("[NPCManager] Player is playing as: %s - will skip spawning this NPC" % player_character_name)
	
	print("[NPCManager] Found %d recordings, spawning npcs..." % recording_files.size())
	
	# First, spawn all NPCs without starting playback (except the one player is playing as)
	for i in range(recording_files.size()):
		var recording_path = recording_files[i]
		var recording_name = recording_path.get_file().get_basename()
		
		# Skip spawning the NPC that the player is playing as
		if player_character_name != "" and recording_name == player_character_name:
			print("[NPCManager] Skipping spawn for %s (player is playing as this character)" % recording_name)
			continue
		
		var npc = await spawn_npc_for_recording(recording_path, i)
		if npc:
			spawned_npcs.append(npc)
			print("[NPCManager] Spawned npc %d for recording: %s" % [i + 1, recording_path.get_file()])
	
	# Wait a moment for all NPCs to be fully initialized
	await get_tree().create_timer(0.2).timeout
	
	# Now start all recordings simultaneously
	print("[NPCManager] Starting all recordings simultaneously...")
	start_all_recordings()

func get_all_recording_files() -> Array[String]:
	"""Get all recording files sorted by modification time (newest first)"""
	var recordings: Array[String] = []
	var dir = DirAccess.open(recordings_directory)
	
	if not dir:
		push_error("[NPCManager] Cannot open recordings directory: %s" % recordings_directory)
		return recordings
	
	# Collect all recording files with their timestamps
	var file_data: Array[Dictionary] = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = recordings_directory + "/" + file_name
			var modified_time = FileAccess.get_modified_time(full_path)
			file_data.append({
				"path": full_path,
				"time": modified_time,
				"name": file_name
			})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by character name for consistent ordering across sessions
	file_data.sort_custom(func(a, b): return get_character_name_from_filename(a.name) < get_character_name_from_filename(b.name))
	
	# Extract just the paths
	for data in file_data:
		recordings.append(data.path)
	
	return recordings

func get_start_position_from_recording(recording_path: String) -> Dictionary:
	"""Read the first position from a recording to get starting floor and position"""
	var file = FileAccess.open(recording_path, FileAccess.READ)
	if not file:
		push_error("[NPCManager] Could not open recording file: %s" % recording_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[NPCManager] Could not parse recording JSON: %s" % recording_path)
		return {}
	
	var recording_data = json.data
	if not recording_data.has("events") or recording_data.events.is_empty():
		push_error("[NPCManager] Recording has no events: %s" % recording_path)
		return {}
	
	# Find the first position event
	var first_event = null
	for event in recording_data.events:
		if event.has("player_position") and event.has("floor"):
			first_event = event
			break
	
	if not first_event:
		push_error("[NPCManager] No position data found in recording: %s" % recording_path)
		return {}
	
	var floor_name = first_event.floor
	var pos = first_event.player_position
	var start_position = Vector2(pos.x, pos.y)
	
	# Find the floor node
	var floor_node = get_node_or_null("../" + floor_name)
	if not floor_node:
		push_warning("[NPCManager] Floor '%s' not found, falling back to GroundFloor" % floor_name)
		floor_node = get_node_or_null("../GroundFloor")
	
	return {
		"floor": floor_node,
		"position": start_position,
		"floor_name": floor_name
	}

func get_floor_from_recording(recording_path: String) -> Node:
	"""Read the first position from a recording to determine which floor the npc should spawn on"""
	var file = FileAccess.open(recording_path, FileAccess.READ)
	if not file:
		push_error("[NPCManager] Could not open recording file: %s" % recording_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[NPCManager] Could not parse recording JSON: %s" % recording_path)
		return null
	
	var recording_data = json.data
	if not recording_data.has("events") or recording_data.events.is_empty():
		push_error("[NPCManager] Recording has no events: %s" % recording_path)
		return null
	
	# Find the first position event
	var first_event = null
	for event in recording_data.events:
		if event.has("player_position"):
			first_event = event
			break
	
	if not first_event:
		push_error("[NPCManager] No position data found in recording: %s" % recording_path)
		return null
	
	var first_position = first_event.player_position
	
	# Determine floor based on floor name or Z position
	var floor_name = "GroundFloor"  # Default fallback
	
	# Check if the first event has floor information
	if first_event.has("floor") and not first_event.floor.is_empty():
		# Use explicit floor name from the event
		floor_name = first_event.floor
		print("[NPCManager] Using floor from event: %s" % floor_name)
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
		push_warning("[NPCManager] Floor '%s' not found, falling back to GroundFloor" % floor_name)
		floor_node = get_node_or_null("../GroundFloor")
	
	return floor_node

func spawn_npc_for_recording(recording_path: String, npc_index: int) -> Node:
	"""Spawn a single npc player for a specific recording"""
	print("[NPCManager] Attempting to spawn npc %d for recording: %s" % [npc_index + 1, recording_path.get_file()])
	
	# Get starting position from recording BEFORE creating npc
	var start_data = get_start_position_from_recording(recording_path)
	if start_data.is_empty():
		push_error("[NPCManager] Could not read start position from recording: %s" % recording_path.get_file())
		return null
	
	var target_floor = start_data.floor
	var start_position = start_data.position
	
	if not target_floor:
		push_error("[NPCManager] Could not determine floor for recording: %s" % recording_path.get_file())
		return null
	
	print("[NPCManager] Found target floor: %s, start position: %s" % [target_floor.name, start_position])
	
	# Create a new npc player with the starting position
	var npc = create_npc_player(npc_index, start_position, recording_path)
	if not npc:
		push_error("[NPCManager] Failed to create npc player %d" % (npc_index + 1))
		return null
	
	print("[NPCManager] Created npc player %d successfully" % (npc_index + 1))
	
	# Set initial position before adding to scene (uses local coordinates)
	npc.position = start_position
	print("[NPCManager] Set npc %d initial position to: %s" % [npc_index + 1, start_position])
	
	# Add to the scene
	target_floor.add_child(npc)
	print("[NPCManager] Added npc %d to %s at position %s (global: %s)" % [
		npc_index + 1, target_floor.name, npc.position, npc.global_position
	])
	
	# Verify the npc is visible
	if npc.get_child_count() > 0:
		var sprite = npc.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			print("[NPCManager] NPC %d sprite texture loaded: %s" % [npc_index + 1, sprite.texture.get_path()])
		else:
			print("[NPCManager] WARNING: NPC %d sprite has no texture!" % (npc_index + 1))
	
	# Set up the npc with the specific recording (but don't start playback yet)
	await setup_npc_for_recording(npc, recording_path, npc_index, false)
	
	return npc

func create_npc_player(npc_index: int, start_position: Vector2, recording_path: String) -> Node:
	"""Create a new npc player node with all required components"""
	print("[NPCManager] Creating npc player %d (start_position will be: %s)..." % [npc_index + 1, start_position])
	
	# Create the main CharacterBody2D
	var npc = CharacterBody2D.new()
	# Use character name for consistent naming across sessions
	var character_name = get_character_name_from_filename(recording_path.get_file())
	npc.name = character_name
	print("[NPCManager] Created NPC with name: %s" % character_name)
	npc.z_index = 2  # Higher z_index to ensure visibility
	npc.add_to_group("npc")
	
	# Don't set position here - let _position_player_at_start() handle it
	# This avoids confusion between local and global position
	
	print("[NPCManager] Created CharacterBody2D for npc %d (position will be set by recorder)" % (npc_index + 1))
	
	# Add CollisionShape2D
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.visible = false
	collision_shape.position = Vector2(0, 1)
	
	# Create circle shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 3.0
	collision_shape.shape = circle_shape
	npc.add_child(collision_shape)
	
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
		push_warning("[NPCManager] Could not load player texture")
	
	npc.add_child(sprite)
	
	# Add NavigationAgent2D
	var nav_agent = NavigationAgent2D.new()
	nav_agent.name = "NavigationAgent2D"
	nav_agent.path_desired_distance = 5.0
	nav_agent.target_desired_distance = 5.0
	nav_agent.path_postprocessing = 1
	nav_agent.debug_enabled = false  # Disable debug trails for NPCs
	nav_agent.debug_use_custom = true
	npc.add_child(nav_agent)
	
	# Add PlayerRecorder
	var recorder = Node.new()
	recorder.name = "PlayerRecorder"
	var recorder_script = load("res://scripts/player_recorder.gd")
	if recorder_script:
		recorder.set_script(recorder_script)
	npc.add_child(recorder)
	
	# Add the player script
	print("[NPCManager] Loading player_1.gd script for npc %d..." % (npc_index + 1))
	var player_script = load("res://scripts/player_1.gd")
	if player_script:
		print("[NPCManager] Successfully loaded player_1.gd script")
		npc.set_script(player_script)
		
		# CRITICAL: Set npc properties BEFORE adding to scene tree
		# This ensures _ready() sees the correct values
		npc.set("is_npc", true)
		npc.set("random_spawn", false)
		npc.set("loop_playback", true)
		npc.set("auto_record_on_start", false)
		
		# Override the npc's auto-load behavior by setting a flag
		npc.set_meta("skip_auto_load", true)
		
		# Disable position correction for npcs to prevent navigation issues
		npc.set("max_deviation_threshold", 999999.0)
		
		# Enable NPC-to-NPC following
		npc.set("can_follow_others", true)
		
		# Set npc color (cycle through available colors)
		if npc_index < npc_colors.size():
			npc.set("npc_color", npc_colors[npc_index])
		else:
			# Generate a random color for additional npcs
			npc.set("npc_color", Color(randf(), randf(), randf(), 0.6))
		
		# Verify is_npc is set correctly
		var is_npc_value = npc.get("is_npc")
		print("[NPCManager] NPC %d properties set - is_npc verified: %s" % [npc_index + 1, is_npc_value])
	else:
		push_error("[NPCManager] Could not load player_1.gd script")
		npc.queue_free()
		return null
	
	print("[NPCManager] Successfully created complete npc player %d" % (npc_index + 1))
	return npc

func setup_npc_for_recording(npc: Node, recording_path: String, npc_index: int, start_playback_immediately: bool = true) -> void:
	"""Set up a npc to play a specific recording"""
	print("[NPCManager] Setting up npc %d with recording..." % (npc_index + 1))
	
	# NPC is already in the scene tree and _ready() has been called
	# Just wait one frame to ensure everything is initialized
	await get_tree().process_frame
	print("[NPCManager] NPC %d initialization frame complete" % (npc_index + 1))
	
	# Verify is_npc flag
	var is_npc_check = npc.get("is_npc")
	print("[NPCManager] NPC %d is_npc flag: %s" % [npc_index + 1, is_npc_check])
	
	# Wait a bit longer to ensure the npc's auto-load doesn't interfere
	await get_tree().create_timer(0.1).timeout
	
	# Stop any existing playback first
	if npc.has_method("stop_playback"):
		npc.stop_playback()
	
	# Load the specific recording
	if npc.has_method("load_recording_from_file"):
		print("[NPCManager] Loading recording for npc %d: %s" % [npc_index + 1, recording_path.get_file()])
		if npc.load_recording_from_file(recording_path):
			print("[NPCManager] NPC %d successfully loaded recording" % (npc_index + 1))
			
			# Verify recording was loaded
			var recorder = npc.get_node_or_null("PlayerRecorder")
			if recorder:
				var event_count = recorder.get_recorded_inputs().size()
				print("[NPCManager] NPC %d recorder has %d events loaded" % [npc_index + 1, event_count])
			
			# Start playback only if requested
			if start_playback_immediately and npc.has_method("start_playback"):
				print("[NPCManager] Starting playback for npc %d..." % (npc_index + 1))
				var playback_started = await npc.start_playback(1.0, true)  # Position correction enabled for NPCs
				if playback_started:
					print("[NPCManager] NPC %d playback started successfully!" % (npc_index + 1))
				else:
					push_error("[NPCManager] NPC %d playback failed to start!" % (npc_index + 1))
		else:
			push_error("[NPCManager] Failed to load recording for npc %d: %s" % [npc_index + 1, recording_path])
	else:
		push_error("[NPCManager] NPC %d does not have load_recording_from_file method" % (npc_index + 1))

func start_all_recordings() -> void:
	"""Start playback for all spawned NPCs simultaneously"""
	print("[NPCManager] Starting simultaneous playback for %d NPCs..." % spawned_npcs.size())
	
	# Start all recordings at the same time
	for i in range(spawned_npcs.size()):
		var npc = spawned_npcs[i]
		if npc and is_instance_valid(npc) and npc.has_method("start_playback"):
			print("[NPCManager] Starting playback for NPC %d..." % (i + 1))
			# Don't await - start all simultaneously
			npc.start_playback(1.0, true)  # Position correction enabled for NPCs
	
	print("[NPCManager] All recordings started simultaneously!")
	
	# Emit signal to notify that all NPCs have started
	all_npcs_started_playback.emit()

func clear_all_npcs() -> void:
	"""Remove all spawned npcs"""
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	spawned_npcs.clear()

func refresh_npcs() -> void:
	"""Refresh the npc list (useful for testing)"""
	print("[NPCManager] Refreshing npcs...")
	spawn_all_npcs()

func get_npc_count() -> int:
	"""Get the current number of spawned npcs"""
	return spawned_npcs.size()

func get_recording_count() -> int:
	"""Get the number of available recordings"""
	return recording_files.size()

# Input handling for testing
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 0 key - restart the game
		if event.keycode == KEY_0:
			print("[NPCManager] Restarting game...")
			get_tree().reload_current_scene()
		# G key - refresh npcs
		elif event.keycode == KEY_G:
			refresh_npcs()
		# H key - print npc info
		elif event.keycode == KEY_H:
			print_npc_info()

func print_npc_info() -> void:
	"""Print information about spawned npcs and recordings"""
	print("\n=== NPC Manager Info ===")
	print("Recordings found: %d" % get_recording_count())
	print("NPCs spawned: %d" % get_npc_count())
	
	if not recording_files.is_empty():
		print("\nRecordings:")
		for i in range(recording_files.size()):
			var file_name = recording_files[i].get_file()
			var npc_status = "✓" if i < spawned_npcs.size() else "✗"
			print("  %s %d. %s" % [npc_status, i + 1, file_name])
	
	print("========================\n")
