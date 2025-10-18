extends CharacterBody2D

const max_speed := 40.0
const min_speed := 8.0
const time_to_max_speed := 0.1
const time_to_stop := 0.05
const time_to_turn := 0.05

const acceleration := max_speed / time_to_max_speed
const friction := max_speed / time_to_stop
const turn_speed := max_speed / time_to_turn

# Jump and height constants
const jump_height := 30.0  # Maximum height of jump arc
const jump_duration := 0.6  # Time to complete full jump (up and down)
const ground_height := 0.0  # Default ground level
const floor_height := 16.0  # Height of one floor (tile height)

# NPC mode settings
@export var is_npc := false  # If true, disables user input and auto-loads recordings
@export var npc_color := Color(0.5, 0.5, 1.0, 0.6)  # Color for NPC players
@export var loop_playback := true  # Whether NPC should loop playback

# Spawn settings
@export var random_spawn := true  # If true, spawn on random tile on GroundFloor
@export var spawn_floor_name := "GroundFloor"  # Name of floor to spawn on

var dir_input := Vector2.ZERO
var z_height := 0.0  # Simulated Z-axis height
var is_jumping := false  # Whether player is in a jump
var jump_time := 0.0  # Time elapsed in current jump
var ground_z := ground_height  # Height of current tile
var current_direction := Vector2.ZERO  # Current movement direction (locked)
var is_navigating := false  # Whether we're following a navigation path
var navigation_target_tile := Vector2i.ZERO  # Target tile for navigation
var last_logged_current_tile := Vector2i(-999, -999)  # Track last logged tile for debug
var last_logged_next_tile := Vector2i(-999, -999)  # Track last logged next tile for debug

# Recording settings
var auto_record_on_start := true  # Automatically start recording when game starts
var auto_record_duration := 60.0  # Duration to record in seconds (0 = infinite)
var recording_elapsed_time := 0.0  # Time elapsed since recording started

# Playback state
var simulated_inputs: Dictionary = {}  # Store simulated input states during playback
var is_in_playback_mode := false  # Flag to indicate we're in playback mode
var playback_cancelled := false  # Flag to indicate playback was cancelled due to deviation
var max_deviation_threshold := 30.0  # Maximum allowed deviation in pixels

# Position correction system
var is_correcting_position := false  # Flag to indicate we're in position correction mode
var correction_target_position := Vector2.ZERO  # Target position for correction
var correction_start_time := 0.0  # When correction started
var correction_duration := 0.0  # How long to wait before checking position
var correction_waypoint_index := 0  # Index of the waypoint we're navigating to

# Playback visualization
var recorded_position_markers: Array[Node2D] = []  # Visual markers for all recorded positions

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sprite_alt: Sprite2D = get_node_or_null("Player")
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var tile_highlight: Polygon2D = get_node_or_null("highlight")
@onready var recorder = get_node_or_null("PlayerRecorder")  # PlayerRecorder node

func _ready() -> void:
	print("[Player %s] _ready() called - is_npc: %s" % [name, is_npc])
	
	# Try to find the sprite node with either name
	if sprite == null:
		sprite = sprite_alt
	if sprite == null:
		push_warning("No Sprite2D child found! Jump visual won't work.")
	
	# NPC mode setup
	if is_npc:
		print("[NPC %s] NPC mode enabled, setting up..." % name)
		if sprite:
			sprite.modulate = npc_color
			print("[NPC %s] Sprite color set to: %s" % [name, npc_color])
		# Disable auto-recording for NPCs
		auto_record_on_start = false
		# NPCs don't use random spawn
		random_spawn = false
		print("[NPC %s] NPC player initialized (auto_record=%s, random_spawn=%s)" % [name, auto_record_on_start, random_spawn])
	
	# Random spawn for non-NPC players
	if random_spawn and not is_npc:
		_spawn_on_random_tile()
	
	# Setup navigation agent
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
	
	# Setup tile highlight
	if tile_highlight:
		tile_highlight.visible = false
		tile_highlight.z_index = 100  # Always on top
	
	# Setup recorder if available
	if recorder:
		recorder.player = self
		recorder.recording_stopped.connect(_on_recording_stopped)
		recorder.playback_started.connect(_on_playback_started)
		recorder.playback_finished.connect(_on_playback_finished)
		recorder.playback_input.connect(_on_playback_input)
		recorder.position_deviation.connect(_on_position_deviation)
		
		# Auto-start recording if enabled (not for NPCs)
		if auto_record_on_start and not is_npc:
			print("\n[Player] Auto-starting INPUT_ONLY recording for %.1f seconds..." % auto_record_duration)
			start_recording()
			recording_elapsed_time = 0.0
		
		# Auto-load and play recording for NPCs (unless skip flag is set)
		if is_npc and not has_meta("skip_auto_load"):
			await get_tree().create_timer(0.5).timeout  # Wait for scene to fully load
			_npc_load_and_play_most_recent()
	
	# Initialize simulated inputs
	simulated_inputs = {
		"ui_right": false,
		"ui_left": false,
		"ui_up": false,
		"ui_down": false,
		"jump": false,
		"mouse_click": false,
		"mouse_pos": Vector2.ZERO
	}
	
	# Set initial z_index based on current floor
	update_z_index()

func _input(event: InputEvent) -> void:
	# Skip all user input for NPC players
	if is_npc:
		# Debug: Verify NPC is ignoring input (disabled for cleaner output)
		# if event is InputEventKey and event.pressed:
		#	print("[NPC %s] Ignoring keyboard input (is_npc=%s)" % [name, is_npc])
		return
	
	# Handle recording controls
	if event is InputEventKey and event.pressed:
		# R key - start/stop recording
		if event.keycode == KEY_R and recorder:
			if recorder.is_recording:
				stop_recording()
			else:
				start_recording()
		
		# S key - save recording to file
		if event.keycode == KEY_S and event.ctrl_pressed and recorder:
			save_recording_to_file()
		
		# L key - load and play recording
		if event.keycode == KEY_L and event.ctrl_pressed and recorder:
			load_and_play_recording()
		
		# P key - print recording statistics
		if event.keycode == KEY_P and recorder:
			print_recording_stats()
		
		# SPACE key - start/stop playback (without position correction)
		if event.keycode == KEY_SPACE and event.ctrl_pressed and recorder:
			if recorder.is_playing_back():
				stop_playback()
			else:
				start_playback(1.0, false)  # Disable position correction
	
	# Handle mouse click for navigation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if navigation_agent:
				var target_position = get_global_mouse_position()
				var current_floor = get_parent()
				
				# Convert to tile coordinates using tilemap's coordinate system
				if current_floor is TileMapLayer:
					navigation_target_tile = current_floor.local_to_map(current_floor.to_local(target_position))
					# Convert back to world position at tile center
					target_position = current_floor.to_global(current_floor.map_to_local(navigation_target_tile))
				else:
					# Fallback
					target_position = snap_to_tile_center(target_position)
					var iso_x = (target_position.x / 32.0) + (target_position.y / 16.0)
					var iso_y = (target_position.y / 16.0) - (target_position.x / 32.0)
					navigation_target_tile = Vector2i(round(iso_x), round(iso_y))
				
				navigation_agent.target_position = target_position
				is_navigating = true
				
				# Debug: print tiles in all four directions with floor transitions
				print("\n[Click] Target tile: ", navigation_target_tile)
				if current_floor is TileMapLayer:
					var grandparent = current_floor.get_parent()
					print("  Northeast (+0, -1): ", check_next_tile_with_floors(current_floor, grandparent, navigation_target_tile + Vector2i(0, -1), true))
					print("  Southeast (+1, +0): ", check_next_tile_with_floors(current_floor, grandparent, navigation_target_tile + Vector2i(1, 0), false))
					print("  Southwest (+0, +1): ", check_next_tile_with_floors(current_floor, grandparent, navigation_target_tile + Vector2i(0, 1), false))
					print("  Northwest (-1, +0): ", check_next_tile_with_floors(current_floor, grandparent, navigation_target_tile + Vector2i(-1, 0), true))

func _physics_process(delta: float) -> void:
	# Check auto-recording duration
	if recorder and recorder.is_recording and auto_record_duration > 0:
		recording_elapsed_time += delta
		if recording_elapsed_time >= auto_record_duration:
			print("\n[Player] Auto-record time limit reached (%.1f seconds)" % auto_record_duration)
			stop_recording()
			# Auto-save the recording
			save_recording_to_file()
	
	# Get tilemap to check ground height and if player should fall
	var tilemap = get_parent()
	var is_over_tile = false
	
	if tilemap is TileMapLayer:
		var tile_pos = tilemap.local_to_map(position)
		var tile_id = tilemap.get_cell_source_id(tile_pos)
		if tile_id != -1:
			# Player is over a valid tile
			ground_z = ground_height
			is_over_tile = true
	
	# Check if player should fall to floor below
	if not is_over_tile and z_height <= ground_z:
		var current_parent = get_parent()
		var grandparent = current_parent.get_parent()
		var floor_below = get_next_floor_down(current_parent, grandparent)
		
		if floor_below and floor_below is TileMapLayer:
			# Check if there's a tile at this position on the floor below
			# Note: Add (1,1) offset because isometric tiles on lower floors are offset
			var current_tile_on_current_floor = current_parent.local_to_map(position)
			var tile_pos_on_floor_below = current_tile_on_current_floor + Vector2i(1, 1)
			var tile_id = floor_below.get_cell_source_id(tile_pos_on_floor_below)
			
			if tile_id != -1:
				# There's a tile below - fall down to it at the adjusted coordinates
				# Calculate target global position BEFORE reparenting
				var target_local_pos = floor_below.map_to_local(tile_pos_on_floor_below)
				var target_global_pos = floor_below.to_global(target_local_pos)
				
				# Reparent and preserve global position
				current_parent.remove_child(self)
				floor_below.add_child(self)
				global_position = target_global_pos
				
				# Reset jump state when falling to floor below
				is_jumping = false
				z_height = ground_height
				ground_z = ground_height
				
				# Update z_index for new floor
				update_z_index()
	
	# Handle jump input (spacebar or simulated)
	var jump_pressed: bool
	if is_in_playback_mode or is_npc:
		# NPCs and playback use simulated inputs only
		jump_pressed = simulated_inputs.get("jump_just_pressed", false)
		simulated_inputs["jump_just_pressed"] = false
	else:
		# Only real player uses keyboard
		jump_pressed = Input.is_action_just_pressed("jump")
	
	if jump_pressed and not is_jumping and z_height <= ground_z + 1.0:
		is_jumping = true
		jump_time = 0.0
	
	# Update jump using parabolic arc
	if is_jumping:
		jump_time += delta
		var t = jump_time / jump_duration
		
		if t >= 1.0:
			# Jump complete
			is_jumping = false
			z_height = ground_z
		else:
			# Parabolic arc: y = -4h(t - 0.5)^2 + h
			# This creates a symmetric arc that peaks at t=0.5
			var arc_progress = t - 0.5
			z_height = ground_z + jump_height * (1.0 - 4.0 * arc_progress * arc_progress)
	
	# Check if player should move to next floor up
	if z_height > floor_height:
		var current_parent = get_parent()
		var grandparent = current_parent.get_parent()
		
		# Try to find the next floor layer
		var next_floor = get_next_floor_up(current_parent, grandparent)
		if next_floor and next_floor is TileMapLayer:
			# Check if there's a tile at this position on the floor above
			# Note: Subtract (1,1) offset because we're checking the floor above
			var current_tile_on_current_floor = current_parent.local_to_map(position)
			var tile_pos_on_next_floor = current_tile_on_current_floor - Vector2i(1, 1)
			var tile_id = next_floor.get_cell_source_id(tile_pos_on_next_floor)
			
			if tile_id != -1:
				# There's a tile above - move up to it at the adjusted coordinates
				# Calculate target global position BEFORE reparenting
				var target_local_pos = next_floor.map_to_local(tile_pos_on_next_floor)
				var target_global_pos = next_floor.to_global(target_local_pos)
				
				# Reparent and preserve global position
				current_parent.remove_child(self)
				next_floor.add_child(self)
				global_position = target_global_pos
				
				# Continue jump on new floor - adjust height relative to new floor
				z_height -= floor_height
				ground_z = ground_height
				
				# Update z_index for new floor
				update_z_index()
	
	# Toggle collision based on jump state
	if z_height > ground_z:
		# In the air - disable collision with layer 1 (tilemaps)
		collision_mask = 0
	else:
		# On ground - enable collision with layer 1
		collision_mask = 1
	
	# Clamp to ground (safety check)
	if not is_jumping and z_height < ground_z:
		z_height = ground_z
	
	# Update sprite position to show height
	if sprite:
		sprite.position.y = -6 - z_height
	
	# Update tile highlight
	update_tile_highlight()
	
	# Handle horizontal movement (4-directional diagonal only, Pac-Man style)
	# Define the 4 isometric diagonal directions (32x16 tiles = 2:1 ratio)
	var northeast := Vector2(2, -1).normalized()  # Up-right on screen
	var southeast := Vector2(2, 1).normalized()   # Down-right on screen
	var southwest := Vector2(-2, 1).normalized()  # Down-left on screen
	var northwest := Vector2(-2, -1).normalized() # Up-left on screen
	
	# Update position correction system
	_update_position_correction()
	
	# Check for manual input (keyboard) or simulated input during playback
	# NPC players can always use simulated inputs, even during position correction
	var is_playback: bool = is_in_playback_mode and not playback_cancelled and (not is_correcting_position or is_npc)
	
	# During playback OR for NPCs, use ONLY simulated inputs (ignore real keyboard)
	var right_just_pressed: bool
	var left_just_pressed: bool
	var up_just_pressed: bool
	var down_just_pressed: bool
	var right_pressed: bool
	var left_pressed: bool
	var up_pressed: bool
	var down_pressed: bool
	
	if is_playback or is_npc:
		# NPCs and playback use simulated inputs only
		right_just_pressed = simulated_inputs.get("ui_right_just_pressed", false)
		left_just_pressed = simulated_inputs.get("ui_left_just_pressed", false)
		up_just_pressed = simulated_inputs.get("ui_up_just_pressed", false)
		down_just_pressed = simulated_inputs.get("ui_down_just_pressed", false)
		right_pressed = simulated_inputs.get("ui_right", false)
		left_pressed = simulated_inputs.get("ui_left", false)
		up_pressed = simulated_inputs.get("ui_up", false)
		down_pressed = simulated_inputs.get("ui_down", false)
	else:
		# Only non-NPC players use real keyboard input
		right_just_pressed = Input.is_action_just_pressed("ui_right")
		left_just_pressed = Input.is_action_just_pressed("ui_left")
		up_just_pressed = Input.is_action_just_pressed("ui_up")
		down_just_pressed = Input.is_action_just_pressed("ui_down")
		right_pressed = Input.is_action_pressed("ui_right")
		left_pressed = Input.is_action_pressed("ui_left")
		up_pressed = Input.is_action_pressed("ui_up")
		down_pressed = Input.is_action_pressed("ui_down")
	
	var any_key_pressed: bool = right_pressed or left_pressed or up_pressed or down_pressed
	
	# Clear "just pressed" flags at the start of each frame
	if is_playback or is_npc:
		simulated_inputs["ui_right_just_pressed"] = false
		simulated_inputs["ui_left_just_pressed"] = false
		simulated_inputs["ui_up_just_pressed"] = false
		simulated_inputs["ui_down_just_pressed"] = false
	
	# Manual input cancels navigation (but not for NPC players during correction)
	if any_key_pressed and not (is_npc and is_correcting_position):
		is_navigating = false
	
	# Handle navigation (free movement, not restricted to diagonals)
	if is_navigating and navigation_agent and not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction_to_target = (next_position - global_position).normalized()
		
		# Move freely toward target (no diagonal restriction during navigation)
		current_direction = direction_to_target
	elif is_navigating:
		# Navigation finished naturally
		is_navigating = false
		current_direction = Vector2.ZERO
	
	# Update direction based on manual input (most recently pressed key wins)
	if right_just_pressed:
		current_direction = southeast  # East = down-right
	elif left_just_pressed:
		current_direction = northwest  # West = up-left
	elif up_just_pressed:
		current_direction = northeast  # North = up-right
	elif down_just_pressed:
		current_direction = southwest  # South = down-left
	
	if any_key_pressed or is_navigating:
		
		# Move in the current direction
		if !current_direction.is_equal_approx(velocity.normalized()) and velocity.length() > 0.1:
			velocity += current_direction * turn_speed * delta
		else:
			velocity += current_direction * acceleration * delta
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		
		# Only apply grid snapping for manual keyboard input, not during navigation
		if any_key_pressed and not is_navigating:
			# Snap to isometric grid based on movement direction
			# Convert screen position to isometric coordinates
			# iso_x and iso_y represent position in isometric grid space
			var iso_x = (position.x / 32.0) + (position.y / 16.0)
			var iso_y = (position.y / 16.0) - (position.x / 32.0)
			
			if current_direction == southeast or current_direction == northwest:
				# Moving along iso_x axis (east/west) - lock iso_y to integer
				iso_y = round(iso_y)
			elif current_direction == northeast or current_direction == southwest:
				# Moving along iso_y axis (north/south) - lock iso_x to integer
				iso_x = round(iso_x)
			
			# Convert back to screen coordinates
			position.x = (iso_x - iso_y) * 16.0
			position.y = (iso_x + iso_y) * 8.0
	else:
		# No keys pressed - reset direction lock and apply friction
		current_direction = Vector2.ZERO
		if velocity != Vector2.ZERO:
			velocity -= velocity.normalized() * friction * delta 
			if velocity.length() < min_speed:
				velocity = Vector2.ZERO
	
	move_and_slide()

func get_next_floor_up(current_floor: Node, root: Node) -> Node:
	# Define floor hierarchy (order matters - bottom to top)
	var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor"]
	
	var current_index = floor_order.find(current_floor.name)
	if current_index == -1 or current_index >= floor_order.size() - 1:
		return null  # No next floor
	
	# Get next floor name and find it in the scene
	var next_floor_name = floor_order[current_index + 1]
	return root.get_node_or_null(next_floor_name)

func get_next_floor_down(current_floor: Node, root: Node) -> Node:
	# Define floor hierarchy (order matters - bottom to top)
	var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor"]
	
	var current_index = floor_order.find(current_floor.name)
	if current_index == -1 or current_index <= 0:
		return null  # No floor below
	
	# Get floor below name and find it in the scene
	var floor_below_name = floor_order[current_index - 1]
	return root.get_node_or_null(floor_below_name)

func get_closest_diagonal(direction: Vector2, ne: Vector2, se: Vector2, sw: Vector2, nw: Vector2) -> Vector2:
	# Find which of the 4 diagonal directions is closest to the target direction
	var best_direction = ne
	var best_dot = direction.dot(ne)
	
	var dot_se = direction.dot(se)
	if dot_se > best_dot:
		best_dot = dot_se
		best_direction = se
	
	var dot_sw = direction.dot(sw)
	if dot_sw > best_dot:
		best_dot = dot_sw
		best_direction = sw
	
	var dot_nw = direction.dot(nw)
	if dot_nw > best_dot:
		best_dot = dot_nw
		best_direction = nw
	
	return best_direction

func snap_to_tile_center(pos: Vector2) -> Vector2:
	# For isometric tiles (32x16), convert to isometric grid coordinates
	var iso_x = (pos.x / 32.0) + (pos.y / 16.0)
	var iso_y = (pos.y / 16.0) - (pos.x / 32.0)
	
	# Round to nearest integer tile
	iso_x = round(iso_x)
	iso_y = round(iso_y)
	
	# Convert back to screen coordinates (tile center)
	var snapped_pos = Vector2()
	snapped_pos.x = (iso_x - iso_y) * 16.0
	snapped_pos.y = (iso_x + iso_y) * 8.0
	
	return snapped_pos

func update_z_index() -> void:
	# Set z_index to be one more than the current floor level
	var current_floor = get_parent()
	if current_floor:
		var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor"]
		var floor_index = floor_order.find(current_floor.name)
		
		if floor_index != -1:
			var new_z_index = floor_index + 1
			z_index = new_z_index
			if sprite:
				sprite.z_index = new_z_index
			
			# Enable collision only on current floor
			update_floor_collisions(current_floor)

func check_tile_info(floor_layer: TileMapLayer, tile_pos: Vector2i) -> String:
	var tile_id = floor_layer.get_cell_source_id(tile_pos)
	if tile_id == -1:
		return "empty"
	var atlas = floor_layer.get_cell_atlas_coords(tile_pos)
	if atlas == Vector2i(0, 1):
		return "barrier"
	return "tile at " + str(atlas)

func check_next_tile_with_floors(current_floor: TileMapLayer, grandparent: Node, target_tile: Vector2i, check_upper_first: bool) -> String:
	# Check what's on the current floor
	var current_info = check_tile_info(current_floor, target_tile)
	
	print("    [Debug] Checking tile ", target_tile, " on ", current_floor.name, " - has: ", current_info)
	
	# Get floors above and below
	var floor_above = get_next_floor_up(current_floor, grandparent)
	var floor_below = get_next_floor_down(current_floor, grandparent)
	
	print("    [Debug] floor_above: ", floor_above.name if floor_above else "null", " | floor_below: ", floor_below.name if floor_below else "null")
	
	# Check floors in priority order based on direction
	if check_upper_first:
		# North direction - check upper floor first
		if floor_above and floor_above is TileMapLayer:
			var tile_above = target_tile - Vector2i(1, 1)
			var tile_id = floor_above.get_cell_source_id(tile_above)
			var atlas = floor_above.get_cell_atlas_coords(tile_above)
			print("    [Debug] Checking ", floor_above.name, " at ", tile_above, " - tile_id: ", tile_id, " atlas: ", atlas)
			if tile_id != -1 and atlas != Vector2i(0, 1):
				print("    [Debug] Found tile above! Returning.")
				return floor_above.name + " " + str(tile_above) + " (atlas " + str(atlas) + ")"
		
		# No tile above, check below
		if floor_below and floor_below is TileMapLayer:
			var tile_below = target_tile + Vector2i(1, 1)
			var tile_id = floor_below.get_cell_source_id(tile_below)
			var atlas = floor_below.get_cell_atlas_coords(tile_below)
			print("    [Debug] Checking ", floor_below.name, " at ", tile_below, " - tile_id: ", tile_id, " atlas: ", atlas)
			if tile_id != -1 and atlas != Vector2i(0, 1):
				print("    [Debug] Found tile below! Returning.")
				return floor_below.name + " " + str(tile_below) + " (atlas " + str(atlas) + ")"
	else:
		# South direction - check lower floor first
		if floor_below and floor_below is TileMapLayer:
			var tile_below = target_tile + Vector2i(1, 1)
			var tile_id = floor_below.get_cell_source_id(tile_below)
			var atlas = floor_below.get_cell_atlas_coords(tile_below)
			print("    [Debug] Checking ", floor_below.name, " at ", tile_below, " - tile_id: ", tile_id, " atlas: ", atlas)
			if tile_id != -1 and atlas != Vector2i(0, 1):
				print("    [Debug] Found tile below! Returning.")
				return floor_below.name + " " + str(tile_below) + " (atlas " + str(atlas) + ")"
		
		# No tile below, check above
		if floor_above and floor_above is TileMapLayer:
			var tile_above = target_tile - Vector2i(1, 1)
			var tile_id = floor_above.get_cell_source_id(tile_above)
			var atlas = floor_above.get_cell_atlas_coords(tile_above)
			print("    [Debug] Checking ", floor_above.name, " at ", tile_above, " - tile_id: ", tile_id, " atlas: ", atlas)
			if tile_id != -1 and atlas != Vector2i(0, 1):
				print("    [Debug] Found tile above! Returning.")
				return floor_above.name + " " + str(tile_above) + " (atlas " + str(atlas) + ")"
	
	# No tile on other floors, return current floor info
	print("    [Debug] No tiles on other floors. Returning current floor info.")
	return current_floor.name + " " + str(target_tile) + " (" + current_info + ")"

func get_current_tile() -> Vector2i:
	# Use TileMapLayer's built-in conversion which handles all offsets correctly
	var tilemap = get_parent()
	if tilemap is TileMapLayer:
		return tilemap.local_to_map(position)
	
	# Fallback to manual calculation if not on a tilemap
	var iso_x = (position.x / 32.0) + (position.y / 16.0)
	var iso_y = (position.y / 16.0) - (position.x / 32.0)
	return Vector2i(round(iso_x), round(iso_y))

func update_tile_highlight() -> void:
	if not tile_highlight:
		return
	
	var target_tile: Vector2i
	var should_show = false
	
	# Show highlight for navigation target
	if is_navigating:
		should_show = true
		target_tile = navigation_target_tile
	# Show highlight for next tile when moving manually
	elif current_direction != Vector2.ZERO:
		should_show = true
		
		# Get current tile position
		var current_tile = get_current_tile()
		
		# Calculate next tile based on direction
		var northeast := Vector2(2, -1).normalized()
		var southeast := Vector2(2, 1).normalized()
		var southwest := Vector2(-2, 1).normalized()
		var northwest := Vector2(-2, -1).normalized()
		
		if current_direction.is_equal_approx(northeast):
			target_tile = current_tile + Vector2i(0, -1)  # North = -Y in iso space
		elif current_direction.is_equal_approx(southeast):
			target_tile = current_tile + Vector2i(1, 0)   # East = +X in iso space
		elif current_direction.is_equal_approx(southwest):
			target_tile = current_tile + Vector2i(0, 1)   # South = +Y in iso space
		elif current_direction.is_equal_approx(northwest):
			target_tile = current_tile + Vector2i(-1, 0)  # West = -X in iso space
		
		# Check for tiles on floors above or below
		var current_parent = get_parent()
		var grandparent = current_parent.get_parent()
		
		var current_floor_name = current_parent.name if current_parent else "Unknown"
		var next_floor_name = current_floor_name
		
		# Only log if current or next tile changed
		var should_log = (current_tile != last_logged_current_tile or target_tile != last_logged_next_tile)
		
		# Determine check order based on direction:
		# Moving north (negative Y) = check upper floor first
		# Moving south (positive Y) = check lower floor first
		var check_upper_first = current_direction.y < 0
		
		var floor_above = get_next_floor_up(current_parent, grandparent)
		var floor_below = get_next_floor_down(current_parent, grandparent)
		
		# Check floors in priority order
		if check_upper_first:
			# North direction - check upper floor first
			if floor_above and floor_above is TileMapLayer:
				var tile_above = target_tile - Vector2i(1, 1)
				var tile_id = floor_above.get_cell_source_id(tile_above)
				var atlas_coords = floor_above.get_cell_atlas_coords(tile_above)
				
				if tile_id != -1 and atlas_coords != Vector2i(0, 1):
					target_tile = tile_above
					next_floor_name = floor_above.name
			
			# If no tile above, check below
			if next_floor_name == current_floor_name and floor_below and floor_below is TileMapLayer:
				var tile_below = target_tile + Vector2i(1, 1)
				var tile_id_below = floor_below.get_cell_source_id(tile_below)
				var atlas_coords_below = floor_below.get_cell_atlas_coords(tile_below)
				
				if tile_id_below != -1 and atlas_coords_below != Vector2i(0, 1):
					target_tile = tile_below
					next_floor_name = floor_below.name
		else:
			# South direction - check lower floor first
			if floor_below and floor_below is TileMapLayer:
				var tile_below = target_tile + Vector2i(1, 1)
				var tile_id_below = floor_below.get_cell_source_id(tile_below)
				var atlas_coords_below = floor_below.get_cell_atlas_coords(tile_below)
				
				if tile_id_below != -1 and atlas_coords_below != Vector2i(0, 1):
					target_tile = tile_below
					next_floor_name = floor_below.name
			
			# If no tile below, check above
			if next_floor_name == current_floor_name and floor_above and floor_above is TileMapLayer:
				var tile_above = target_tile - Vector2i(1, 1)
				var tile_id = floor_above.get_cell_source_id(tile_above)
				var atlas_coords = floor_above.get_cell_atlas_coords(tile_above)
				
				if tile_id != -1 and atlas_coords != Vector2i(0, 1):
					target_tile = tile_above
					next_floor_name = floor_above.name
		
		if should_log:
			last_logged_current_tile = current_tile
			last_logged_next_tile = target_tile
	
	if should_show:
		tile_highlight.visible = true
		
		# Convert target tile to screen coordinates using tilemap's coordinate system
		var current_parent = get_parent()
		if current_parent is TileMapLayer:
			var highlight_pos = current_parent.map_to_local(target_tile)
			tile_highlight.global_position = current_parent.to_global(highlight_pos)
		else:
			# Fallback to manual calculation
			var highlight_pos = Vector2()
			highlight_pos.x = (target_tile.x - target_tile.y) * 16.0
			highlight_pos.y = (target_tile.x + target_tile.y) * 8.0
			tile_highlight.global_position = highlight_pos
	else:
		tile_highlight.visible = false

func update_floor_collisions(active_floor: Node) -> void:
	# Enable collision AND navigation only on the current floor, disable on all others
	var root = active_floor.get_parent()
	if not root:
		return
	
	var floor_names = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor", "EmptyFloor"]
	
	for floor_name in floor_names:
		var floor_node = root.get_node_or_null(floor_name)
		if floor_node:
			# Floor nodes may contain TileMapLayer children or be TileMapLayer themselves
			if floor_node is TileMapLayer:
				if floor_node == active_floor:
					floor_node.collision_enabled = true
					floor_node.navigation_enabled = true
				else:
					floor_node.collision_enabled = false
					floor_node.navigation_enabled = false
			else:
				# Check for TileMapLayer children
				for child in floor_node.get_children():
					if child is TileMapLayer:
						if child == active_floor:
							child.collision_enabled = true
							child.navigation_enabled = true
						else:
							child.collision_enabled = false
							child.navigation_enabled = false

# ============================================================================
# Recording System Methods
# ============================================================================

func start_recording() -> void:
	"""Start recording player input events"""
	if recorder:
		recorder.start_recording()
		recording_elapsed_time = 0.0
		print("[Player] Recording started (press R to stop)")
	else:
		push_warning("[Player] No PlayerRecorder node found!")

func stop_recording() -> int:
	"""Stop recording and return event count"""
	if recorder:
		var event_count = recorder.stop_recording()
		print("[Player] Recording stopped - ", event_count, " events recorded")
		return event_count
	return 0

func save_recording_to_file(file_path: String = "") -> void:
	"""Save the current recording to a JSON file"""
	if not recorder:
		push_warning("[Player] No PlayerRecorder node found!")
		return
	
	if file_path.is_empty():
		# Ensure recordings directory exists
		var recordings_dir = "res://recordings"
		if not DirAccess.dir_exists_absolute(recordings_dir):
			DirAccess.make_dir_absolute(recordings_dir)
		
		# Generate default filename with timestamp
		var time = Time.get_datetime_dict_from_system()
		file_path = "res://recordings/player_recording_%04d%02d%02d_%02d%02d%02d.json" % [
			time.year, time.month, time.day, time.hour, time.minute, time.second
		]
	
	if recorder.save_to_file(file_path):
		print("[Player] Recording saved to: ", file_path)
		print("[Player] Actual path: ", ProjectSettings.globalize_path(file_path))
	else:
		push_error("[Player] Failed to save recording")

func load_recording_from_file(file_path: String = "") -> bool:
	"""Load a recording from a JSON file"""
	if not recorder:
		push_warning("[Player] No PlayerRecorder node found!")
		return false
	
	if file_path.is_empty():
		push_warning("[Player] No file path provided for loading")
		return false
	
	if recorder.load_from_file(file_path):
		print("[Player] Recording loaded from: ", file_path)
		return true
	else:
		push_error("[Player] Failed to load recording")
		return false

func print_recording_stats() -> void:
	"""Print statistics about the current recording"""
	if not recorder:
		push_warning("[Player] No PlayerRecorder node found!")
		return
	
	var stats = recorder.get_statistics()
	print("\n=== Input Recording Statistics ===")
	print("Events: ", stats.event_count)
	print("Duration: %.2f seconds" % stats.duration)
	print("Events/Second: %.2f" % stats.events_per_second)
	print("Position Checkpoints: ", stats.position_checkpoints)
	
	# Navigation tracking
	if stats.navigation_targets > 0:
		print("\nNavigation:")
		print("  Targets (clicks): ", stats.navigation_targets)
		print("  Waypoints recorded: ", stats.navigation_waypoints)
	
	# Floor tracking
	if stats.floor_changes > 0:
		print("\nFloor Changes: ", stats.floor_changes)
		print("Floors Visited: ", stats.floors_visited)
	
	print("\nAction Breakdown:")
	for action in stats.actions:
		var counts = stats.actions[action]
		# Don't clutter output with internal events
		if action not in ["position_checkpoint", "navigation_target", "navigation_waypoint"]:
			print("  %s: %d presses, %d releases" % [action, counts.presses, counts.releases])
	print("===================================\n")

func _on_recording_stopped() -> void:
	"""Called when recording stops"""
	print("[Player] Recording stopped callback")
	# You can add custom logic here, like auto-saving
	# save_recording_to_file()

func _on_playback_started() -> void:
	"""Called when playback starts"""
	is_in_playback_mode = true
	playback_cancelled = false  # Reset cancellation flag
	is_correcting_position = false  # Reset correction flag
	print("[Player %s] Playback started (is_npc=%s, is_in_playback_mode=%s)" % [name, is_npc, is_in_playback_mode])
	
	# Clear any ongoing navigation
	if is_navigating:
		is_navigating = false
	
	# Visual feedback - could change player color, add overlay, etc.
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 1.0)  # Slight blue tint during playback
	
	# Create visual markers for all recorded positions
	_create_recorded_positions_markers()

func _on_playback_finished() -> void:
	"""Called when playback finishes"""
	is_in_playback_mode = false
	
	# NPC mode: loop playback
	if is_npc and loop_playback:
		print("[NPC] Looping playback...")
		await get_tree().create_timer(0.5).timeout
		await recorder.start_playback(1.0, false)
		return
	
	# Print accuracy statistics
	if recorder:
		var accuracy = recorder.get_playback_accuracy()
		print("\n[Player] Playback finished")
		print("  Position Accuracy:")
		print("    Average deviation: %.2f pixels" % accuracy.average_deviation)
		print("    Max deviation: %.2f pixels" % accuracy.max_deviation)
		print("    Samples: %d" % accuracy.sample_count)
	else:
		print("[Player] Playback finished")
	
	# Reset visual feedback (not for NPCs - keep their color)
	if sprite and not is_npc:
		sprite.modulate = Color(1.0, 1.0, 1.0)  # Normal color
	
	# Remove recorded position markers
	_remove_recorded_positions_markers()
	
	# Clear simulated inputs
	for key in simulated_inputs.keys():
		simulated_inputs[key] = false

func _on_playback_input(action: String, pressed: bool, click_position: Vector2) -> void:
	"""Called for each input event during playback"""
	# Map action names to input states
	match action:
		"right":
			simulated_inputs["ui_right"] = pressed
			if pressed:
				simulated_inputs["ui_right_just_pressed"] = true
		"left":
			simulated_inputs["ui_left"] = pressed
			if pressed:
				simulated_inputs["ui_left_just_pressed"] = true
		"up":
			simulated_inputs["ui_up"] = pressed
			if pressed:
				simulated_inputs["ui_up_just_pressed"] = true
		"down":
			simulated_inputs["ui_down"] = pressed
			if pressed:
				simulated_inputs["ui_down_just_pressed"] = true
		"jump":
			if pressed:
				simulated_inputs["jump_just_pressed"] = true
		"mouse_click":
			simulated_inputs["mouse_click"] = pressed
			if pressed:
				simulated_inputs["mouse_pos"] = click_position
				# Trigger navigation during playback
				if navigation_agent:
					navigation_agent.target_position = click_position
					is_navigating = true
					print("[Playback] Starting navigation to (%.1f, %.1f)" % [click_position.x, click_position.y])

## Start playback of loaded recording
func start_playback(speed: float = 1.0, enable_position_correction: bool = false) -> void:
	"""Start playing back a loaded recording
	@param speed: Playback speed (1.0 = normal, 2.0 = double speed, etc.)
	@param enable_position_correction: If true, force player to match recorded positions
	"""
	if not recorder:
		push_warning("[Player] No PlayerRecorder node found!")
		return
	
	if await recorder.start_playback(speed, enable_position_correction):
		print("[Player] Started playback at %.1fx speed" % speed)
	else:
		push_error("[Player] Failed to start playback")

## Stop playback
func stop_playback() -> void:
	"""Stop current playback"""
	if not recorder:
		return
	
	recorder.stop_playback()
	is_in_playback_mode = false
	
	# Reset visual feedback
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Remove recorded position markers
	_remove_recorded_positions_markers()
	
	print("[Player] Stopped playback")

## Load and immediately play a recording
func load_and_play_recording(file_path: String = "", enable_position_correction: bool = true) -> void:
	"""Load a recording file and start playing it back
	@param file_path: Path to recording file (empty = use most recent)
	@param enable_position_correction: Force player to match recorded positions (default: true)
	"""
	if file_path.is_empty():
		# Use most recent recording
		file_path = get_most_recent_recording()
		if file_path.is_empty():
			push_error("[Player] No recordings found to play")
			return
	
	if load_recording_from_file(file_path):
		await start_playback(1.0, enable_position_correction)

## Get the most recent recording file
func get_most_recent_recording() -> String:
	"""Find the most recent recording file in the recordings directory"""
	var recordings_dir = "res://recordings"
	var dir = DirAccess.open(recordings_dir)
	
	if not dir:
		return ""
	
	var latest_file = ""
	var latest_time = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("player_recording_"):
			var full_path = recordings_dir + "/" + file_name
			var modified_time = FileAccess.get_modified_time(full_path)
			
			if modified_time > latest_time:
				latest_time = modified_time
				latest_file = full_path
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return latest_file

## Called when position deviation is detected during playback
func _on_position_deviation(actual: Vector2, expected: Vector2, deviation: float) -> void:
	"""Check if deviation exceeds threshold and start position correction if needed"""
	if playback_cancelled or is_correcting_position:
		return
	
	if deviation > max_deviation_threshold:
		print("[Playback] Position deviation %.1fpx exceeds threshold %.1fpx - starting position correction" % [deviation, max_deviation_threshold])
		_start_position_correction(expected)

## Create visual markers for all recorded positions
func _create_recorded_positions_markers() -> void:
	if not recorder:
		return
	
	var recorded_inputs = recorder.get_recorded_inputs()
	var current_parent = get_parent()
	
	# Clear any existing markers
	_remove_recorded_positions_markers()
	
	# Get total recording duration for color calculation
	var total_duration = recorder.get_recording_duration()
	if total_duration <= 0:
		total_duration = 1.0  # Avoid division by zero
	
	# Create markers for each recorded position
	for event in recorded_inputs:
		if event.has("player_position"):
			var pos = event.player_position
			var position = Vector2(pos.x, pos.y)
			
			# Create marker node
			var marker = Node2D.new()
			marker.name = "RecordedPositionMarker"
			
			# Create a small circle marker
			var circle = Polygon2D.new()
			circle.name = "Circle"
			var points = PackedVector2Array()
			var segments = 8
			var radius = 2.0
			for i in range(segments):
				var angle = (i / float(segments)) * TAU
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			circle.polygon = points
			
			# Calculate color based on timestamp (black to white)
			var timestamp = event.get("timestamp", 0.0)
			var time_ratio = clamp(timestamp / total_duration, 0.0, 1.0)
			var color_value = time_ratio  # 0.0 = black, 1.0 = white
			circle.color = Color(color_value, color_value, color_value, 0.6)  # Grayscale with alpha
			circle.z_index = 99
			
			marker.add_child(circle)
			marker.global_position = position
			
			# Add to scene
			current_parent.add_child(marker)
			recorded_position_markers.append(marker)
	
	print("[Playback] Created %d position markers (black=start, white=end)" % recorded_position_markers.size())

## Remove all recorded position markers
func _remove_recorded_positions_markers() -> void:
	for marker in recorded_position_markers:
		if marker and is_instance_valid(marker):
			marker.queue_free()
	recorded_position_markers.clear()

## Start position correction by navigating to next recorded position
func _start_position_correction(expected_position: Vector2) -> void:
	"""Start position correction by finding next recorded position and navigating to it"""
	if not recorder:
		return
	
	var recorded_inputs = recorder.get_recorded_inputs()
	var current_time = recorder.get_playback_time()
	
	# Find the next recorded position after current time
	var next_position = _find_next_recorded_position(recorded_inputs, current_time)
	if next_position.is_empty():
		print("[Playback] No next position found - navigating to last position")
		_navigate_to_last_position()
		return
	
	# Calculate dT (time difference to next position)
	var dT = next_position.timestamp - current_time
	correction_duration = dT
	correction_start_time = Time.get_ticks_msec() / 1000.0
	correction_target_position = next_position.position
	correction_waypoint_index = next_position.index
	is_correcting_position = true
	
	# Start navigation to the target position
	if navigation_agent:
		navigation_agent.target_position = next_position.position
		is_navigating = true
		print("[Playback] Navigating to correction target at (%.1f, %.1f) - dT: %.2fs" % [
			next_position.position.x, next_position.position.y, dT
		])

## Find the next recorded position after the given time
func _find_next_recorded_position(recorded_inputs: Array, current_time: float) -> Dictionary:
	"""Find the next recorded position after current time"""
	var best_position = {}
	var best_time = INF
	
	for i in range(recorded_inputs.size()):
		var event = recorded_inputs[i]
		if event.has("player_position") and event.timestamp > current_time:
			if event.timestamp < best_time:
				best_time = event.timestamp
				best_position = {
					"position": Vector2(event.player_position.x, event.player_position.y),
					"timestamp": event.timestamp,
					"index": i
				}
	
	return best_position

## Update position correction system
func _update_position_correction() -> void:
	"""Update position correction system - check if correction time has elapsed"""
	if not is_correcting_position:
		return
	
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - correction_start_time
	
	if elapsed_time >= correction_duration:
		# Check if player is within deviation of expected position
		var current_pos = global_position
		var deviation = current_pos.distance_to(correction_target_position)
		
		if deviation <= max_deviation_threshold:
			# Success! Resume normal playback
			print("[Playback] Position correction successful - resuming playback")
			_resume_normal_playback()
		else:
			# Still too far - double the time window and find next waypoint
			print("[Playback] Still too far (%.1fpx) - doubling time window" % deviation)
			_double_time_window_and_find_next_waypoint()

## Resume normal playback after successful correction
func _resume_normal_playback() -> void:
	"""Resume normal playback after successful position correction"""
	is_correcting_position = false
	is_navigating = false
	# Normal playback will continue through the recorder

## Double time window and find next waypoint
func _double_time_window_and_find_next_waypoint() -> void:
	"""Double the time window and find the next waypoint within that window"""
	if not recorder:
		return
	
	var recorded_inputs = recorder.get_recorded_inputs()
	var current_time = recorder.get_playback_time()
	var new_dT = correction_duration * 2.0
	var target_time = current_time + new_dT
	
	# Find waypoint closest to but no later than target_time
	var best_position = {}
	var best_time = 0.0
	
	for i in range(correction_waypoint_index, recorded_inputs.size()):
		var event = recorded_inputs[i]
		if event.has("player_position") and event.timestamp <= target_time:
			if event.timestamp > best_time:
				best_time = event.timestamp
				best_position = {
					"position": Vector2(event.player_position.x, event.player_position.y),
					"timestamp": event.timestamp,
					"index": i
				}
	
	if best_position.is_empty():
		print("[Playback] No waypoint found within doubled time window - navigating to last position")
		_navigate_to_last_position()
		return
	
	# Update correction parameters
	correction_duration = new_dT
	correction_start_time = Time.get_ticks_msec() / 1000.0
	correction_target_position = best_position.position
	correction_waypoint_index = best_position.index
	
	# Navigate to new target
	if navigation_agent:
		navigation_agent.target_position = best_position.position
		is_navigating = true
		print("[Playback] Navigating to new waypoint at (%.1f, %.1f) - new dT: %.2fs" % [
			best_position.position.x, best_position.position.y, new_dT
		])

## Cancel playback due to position deviation (fallback)
func _cancel_playback_due_to_deviation() -> void:
	"""Cancel playback when position correction fails"""
	playback_cancelled = true
	is_in_playback_mode = false
	is_correcting_position = false
	
	# Stop the recorder playback
	if recorder:
		recorder.stop_playback()
	
	# Clear all simulated inputs
	for key in simulated_inputs.keys():
		simulated_inputs[key] = false
	
	# Reset visual feedback
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0)
	
	# Remove position markers
	_remove_recorded_positions_markers()
	
	print("[Playback] Playback cancelled due to position deviation")

## Navigate to the last position in the recording as final fallback
func _navigate_to_last_position() -> void:
	"""Navigate to the last recorded position as final fallback"""
	if not recorder:
		_cancel_playback_due_to_deviation()
		return
	
	var recorded_inputs = recorder.get_recorded_inputs()
	var last_position = {}
	
	# Find the last recorded position
	for i in range(recorded_inputs.size() - 1, -1, -1):
		var event = recorded_inputs[i]
		if event.has("player_position"):
			last_position = {
				"position": Vector2(event.player_position.x, event.player_position.y),
				"timestamp": event.timestamp,
				"index": i
			}
			break
	
	if last_position.is_empty():
		print("[Playback] No recorded positions found - cancelling playback")
		_cancel_playback_due_to_deviation()
		return
	
	# Set up navigation to last position
	correction_target_position = last_position.position
	correction_waypoint_index = last_position.index
	is_correcting_position = true
	
	# Set a generous time window for reaching the last position
	correction_duration = 10.0  # 10 seconds to reach last position
	correction_start_time = Time.get_ticks_msec() / 1000.0
	
	# Start navigation to the last position
	if navigation_agent:
		navigation_agent.target_position = last_position.position
		is_navigating = true
		print("[Playback] Navigating to final position at (%.1f, %.1f) - final fallback" % [
			last_position.position.x, last_position.position.y
		])

## NPC-specific: Load and play most recent recording with looping
func _npc_load_and_play_most_recent() -> void:
	"""Load the most recent recording and start playing it (NPC mode only)"""
	if not is_npc:
		return
	
	var recording_path = get_most_recent_recording()
	
	if recording_path.is_empty():
		push_warning("[NPC] No recordings found in res://recordings/")
		return
	
	print("[NPC] Loading most recent recording: ", recording_path)
	
	if recorder.load_from_file(recording_path):
		print("[NPC] Recording loaded successfully")
		await recorder.start_playback(1.0, false)  # Position correction disabled
	else:
		push_error("[NPC] Failed to load recording")

## Spawn player on a random tile on the specified floor
func _spawn_on_random_tile() -> void:
	"""Move player to a random valid tile on the spawn floor"""
	# Find the scene root (parent of all floors)
	var current_parent = get_parent()
	if not current_parent:
		push_error("[Player] No parent found for spawn")
		return
	
	var scene_root = current_parent.get_parent()
	if not scene_root:
		push_error("[Player] No scene root found for spawn")
		return
	
	# Find the spawn floor by name
	var spawn_floor = scene_root.get_node_or_null(spawn_floor_name)
	if not spawn_floor or not spawn_floor is TileMapLayer:
		push_error("[Player] Spawn floor '%s' not found or is not a TileMapLayer" % spawn_floor_name)
		return
	
	# Get all valid tiles on the spawn floor (excluding barriers)
	var valid_tiles: Array[Vector2i] = []
	var used_cells = spawn_floor.get_used_cells()
	
	for tile_pos in used_cells:
		var tile_id = spawn_floor.get_cell_source_id(tile_pos)
		if tile_id != -1:  # Valid tile
			var atlas_coords = spawn_floor.get_cell_atlas_coords(tile_pos)
			# Skip barrier tiles (atlas coords 0,1)
			if atlas_coords != Vector2i(0, 1):
				valid_tiles.append(tile_pos)
	
	if valid_tiles.is_empty():
		push_error("[Player] No valid tiles found on '%s' for spawn" % spawn_floor_name)
		return
	
	# Pick a random tile
	var random_tile = valid_tiles[randi() % valid_tiles.size()]
	
	# Convert tile position to world position
	var spawn_position = spawn_floor.map_to_local(random_tile)
	
	# Reparent if needed
	if current_parent != spawn_floor:
		current_parent.remove_child(self)
		spawn_floor.add_child(self)
	
	# Set position (local to the spawn floor)
	position = spawn_position
	
	print("[Player] Spawned on random tile %s at position %s on floor '%s'" % [random_tile, spawn_position, spawn_floor_name])
