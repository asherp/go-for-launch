extends CharacterBody2D

const CharacterNames = preload("res://scripts/character_names.gd")

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
@export var npc_color := Color(0.5, 0.5, 1.0, 1.0)  # Color for NPC players
@export var loop_playback := true  # Whether NPC should loop playback
@export var can_follow_others := false  # Whether this NPC can follow other NPCs

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
var auto_record_duration := 30.0  # Duration to record in seconds (0 = infinite)
var recording_elapsed_time := 0.0  # Time elapsed since recording started
var manually_stopped_recording := false  # Flag to prevent auto-save after manual stop

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

# NPC following system
var is_following_npc := false  # Flag to indicate we're following an NPC
var followed_npc: Node = null  # Reference to the NPC being followed
var follow_update_timer := 0.0  # Timer for updating follow target
var follow_update_interval := 1.0  # Update target position every second
var follow_distance := 20.0  # Distance to maintain from the followed NPC
var is_playing_as_character := false  # True when playing as a selected character until interrupted
var skip_next_mouse_click := false  # Flag to skip recording the next mouse click
var skip_mouse_release := false  # Flag to skip recording the next mouse release

# Character names are now loaded from character_names.txt via CharacterNames utility class

# Playback visualization
var recorded_position_markers: Array[Node2D] = []  # Visual markers for all recorded positions

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sprite_alt: Sprite2D = get_node_or_null("Player")
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var tile_highlight: Polygon2D = get_node_or_null("highlight")
@onready var recorder = get_node_or_null("PlayerRecorder")  # PlayerRecorder node

func _ready() -> void:
	# Try to find the sprite node with either name
	if sprite == null:
		sprite = sprite_alt
	if sprite == null:
		push_warning("No Sprite2D child found! Jump visual won't work.")
	
	# Set proper player name for main player (not NPCs)
	if not is_npc:
		# Check if we should spawn as a specific character
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data and global_data.has_meta("spawn_as_character"):
			var character_data = global_data.get_meta("spawn_as_character")
			# Set flag BEFORE calling _spawn_as_character to prevent random spawn
			is_playing_as_character = true
			# Disable auto-recording when playing as existing character
			auto_record_on_start = false
			_spawn_as_character(character_data)
		else:
			var character_name = get_next_character_name()
			name = character_name
			print("[Player] Set player name to: %s" % name)
	
	# NPC mode setup
	if is_npc:
		if sprite:
			sprite.modulate = npc_color
		# Disable auto-recording for NPCs
		auto_record_on_start = false
		# NPCs don't use random spawn
		random_spawn = false
	
	# Random spawn for non-NPC players (but not when playing as existing character)
	if random_spawn and not is_npc and not is_playing_as_character:
		_spawn_on_random_tile()
	
	# Setup navigation agent
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
		# Connect to velocity_computed signal for modern navigation
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
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
		
		# Auto-start recording if enabled (not for ghosts)
		# But wait for NPCs to start their playback first for synchronization
		if auto_record_on_start and not is_npc:
			print("\n[Player] Waiting for NPCs to start, then will begin recording...")
			_connect_to_npc_synchronization()
		
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
	
	# Connect to countdown timer if it exists
	var countdown_timer = get_node_or_null("../CanvasLayer/MarginContainer/CountdownTimer")
	if countdown_timer and countdown_timer.has_signal("timer_finished"):
		countdown_timer.timer_finished.connect(_on_timer_finished)
		print("[Player] Connected to countdown timer")
	else:
		print("[Player] WARNING: Could not find or connect to countdown timer")

func _input(event: InputEvent) -> void:
	# Skip all user input for NPC players - only main player should respond to clicks
	if is_npc:
		return
	
	# Check if we're in character takeover mode and user is providing input
	if is_playing_as_character and _is_user_input(event):
		print("[Player] User input detected - switching from playback to live recording")
		# Stop playback and switch to live recording
		if recorder and recorder.is_playing_back():
			recorder.stop_playback()
		
		# Start recording new inputs (continuing from where playback left off)
		if recorder:
			recorder.start_recording(false)  # false = don't clear existing events
			print("[Player] Started live recording - will append to original recording")
			# Set flag for auto-save when recording stops
			set_meta("was_character_takeover", true)
		
		is_playing_as_character = false
		# Disable position correction for live control
		if recorder:
			recorder.position_correction_enabled = false
		print("[Player] Position correction disabled for live control")
		# Continue processing the input normally
	
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
			print("[Player] Ctrl+S pressed - manually_stopped_recording: %s, is_recording: %s" % [manually_stopped_recording, recorder.is_recording])
			save_recording_to_file()
		
		# L key - load and play recording
		if event.keycode == KEY_L and event.ctrl_pressed and recorder:
			load_and_play_recording("", false)  # Disable position correction
		
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
			var click_position = get_global_mouse_position()
			
			# First check if clicking on an NPC
			var clicked_npc = get_npc_at_position(click_position)
			print("[Click] Clicked at position: %s" % click_position)
			print("[Click] Found NPC: %s" % (clicked_npc.name if clicked_npc else "None"))
			if clicked_npc and clicked_npc != self:  # Don't follow yourself
				# Clicked on an NPC - start following it
				print("[Click] Starting to follow NPC: %s" % clicked_npc.name)
				# Set flag to skip recording this mouse click (both press and release)
				skip_next_mouse_click = true
				skip_mouse_release = true  # Also skip the mouse release event
				follow_npc(clicked_npc)
				return
			else:
				print("[Click] No NPC found or clicked self, proceeding with normal navigation")
				
				# If we were trying to click on an NPC but didn't find one, 
				# check if there are any NPCs nearby and log debug info
				var npcs = get_tree().get_nodes_in_group("npc")
				if npcs.size() > 0:
					print("[Click] Debug: %d NPCs exist but none detected at click position" % npcs.size())
					for npc in npcs:
						if npc and is_instance_valid(npc):
							var distance = npc.global_position.distance_to(click_position)
							print("[Click] Debug: NPC %s at %s, distance: %.1f" % [npc.name, npc.global_position, distance])
			
			# Not clicking on NPC - normal navigation
			if navigation_agent:
				var target_position = click_position
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
				
				# Stop following NPC if we click elsewhere
				if is_following_npc:
					_remove_follow_indicator()  # Remove indicator first
					stop_following_npc()
				
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
	
	# Reset manual stop flag after a frame to prevent race conditions
	if manually_stopped_recording and not recorder.is_recording:
		manually_stopped_recording = false
	
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
	if is_in_playback_mode or is_npc or is_playing_as_character:
		# NPCs, playback, and character takeover use simulated inputs only
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
	
	# Update path markers during playback to show only next 3 seconds
	if is_in_playback_mode and recorder:
		_update_path_markers()
	
	# Handle horizontal movement (4-directional diagonal only, Pac-Man style)
	# Define the 4 isometric diagonal directions (32x16 tiles = 2:1 ratio)
	var northeast := Vector2(2, -1).normalized()  # Up-right on screen
	var southeast := Vector2(2, 1).normalized()   # Down-right on screen
	var southwest := Vector2(-2, 1).normalized()  # Down-left on screen
	var northwest := Vector2(-2, -1).normalized() # Up-left on screen
	
	# Update position correction system
	_update_position_correction()
	
	# Update NPC following system
	_update_npc_following(delta)
	
	# Check for manual input (keyboard) or simulated input during playback
	# NPC players can always use simulated inputs, even during position correction
	var is_playback: bool = is_in_playback_mode and not playback_cancelled and (not is_correcting_position or is_npc)
	
	# NPCs should always use playback inputs, but following takes priority for navigation
	# Also use playback inputs when in character takeover mode
	var should_use_playback_inputs = is_playback or is_npc or is_playing_as_character
	
	# Debug logging for character takeover mode
	if is_playing_as_character and not is_npc:
		if not has_meta("debug_logged_takeover"):
			print("[Player] Character takeover mode active - using simulated inputs")
			print("[Player] is_playback: %s, is_npc: %s, is_playing_as_character: %s" % [is_playback, is_npc, is_playing_as_character])
			print("[Player] should_use_playback_inputs: %s" % should_use_playback_inputs)
			print("[Player] is_in_playback_mode: %s, is_playing_as_character: %s" % [is_in_playback_mode, is_playing_as_character])
			set_meta("debug_logged_takeover", true)
	
	# During playback OR for NPCs, use ONLY simulated inputs (ignore real keyboard)
	var right_just_pressed: bool
	var left_just_pressed: bool
	var up_just_pressed: bool
	var down_just_pressed: bool
	var right_pressed: bool
	var left_pressed: bool
	var up_pressed: bool
	var down_pressed: bool
	
	if should_use_playback_inputs:
		# NPCs and playback use simulated inputs only
		right_just_pressed = simulated_inputs.get("ui_right_just_pressed", false)
		left_just_pressed = simulated_inputs.get("ui_left_just_pressed", false)
		up_just_pressed = simulated_inputs.get("ui_up_just_pressed", false)
		down_just_pressed = simulated_inputs.get("ui_down_just_pressed", false)
		right_pressed = simulated_inputs.get("ui_right", false)
		left_pressed = simulated_inputs.get("ui_left", false)
		up_pressed = simulated_inputs.get("ui_up", false)
		down_pressed = simulated_inputs.get("ui_down", false)
		
		# Debug logging for character takeover mode
		if is_playing_as_character and not is_npc:
			var any_simulated_input = right_pressed or left_pressed or up_pressed or down_pressed
			if any_simulated_input and not has_meta("debug_logged_input"):
				print("[Player] Character takeover received simulated input: right=%s, left=%s, up=%s, down=%s" % [right_pressed, left_pressed, up_pressed, down_pressed])
				set_meta("debug_logged_input", true)
	else:
		# Only non-ghost players use real keyboard input
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
	# For NPCs following others, keyboard input temporarily pauses following but doesn't cancel it
	if any_key_pressed and not (is_npc and is_correcting_position):
		if not (is_npc and is_following_npc):
			is_navigating = false
		else:
			# NPC is following - temporarily pause following during keyboard input
			# The following will resume when keyboard input stops
			pass
	
	# Handle navigation (free movement, not restricted to diagonals)
	# Modern NavigationAgent2D approach
	if is_navigating and navigation_agent:
		var should_navigate = true
		
		# If NPC is following and using keyboard input, pause navigation
		if is_npc and is_following_npc and any_key_pressed:
			should_navigate = false
		
		if should_navigate:
			if navigation_agent.is_navigation_finished():
				# Navigation finished - check if we're close enough to target
				var target_pos = navigation_agent.target_position
				var distance_to_target = global_position.distance_to(target_pos)
				if distance_to_target < 5.0:  # Within 5 pixels of target
					is_navigating = false
					velocity = Vector2.ZERO
					print("[Player] Navigation completed - reached target at distance %.1fpx" % distance_to_target)
				else:
					# Still navigating but pathfinding is done - use direct movement
					var direction_to_target = (target_pos - global_position).normalized()
					velocity = direction_to_target * max_speed
			else:
				# Still navigating - let NavigationAgent2D handle the velocity
				var next_position = navigation_agent.get_next_path_position()
				var desired_velocity = (next_position - global_position).normalized() * max_speed
				navigation_agent.set_velocity(desired_velocity)
		else:
			# Navigation paused - stop moving
			velocity = Vector2.ZERO
	
	# Update direction based on manual input (most recently pressed key wins)
	if right_just_pressed:
		current_direction = southeast  # East = down-right
	elif left_just_pressed:
		current_direction = northwest  # West = up-left
	elif up_just_pressed:
		current_direction = northeast  # North = up-right
	elif down_just_pressed:
		current_direction = southwest  # South = down-left
	
	# Handle manual movement (keyboard input only)
	if any_key_pressed and not is_navigating:
		# Move in the current direction
		if !current_direction.is_equal_approx(velocity.normalized()) and velocity.length() > 0.1:
			velocity += current_direction * turn_speed * delta
		else:
			velocity += current_direction * acceleration * delta
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		
		# Apply grid snapping for manual keyboard input
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
		
		move_and_slide()
	elif not is_navigating:
		# No keys pressed and not navigating - apply friction
		current_direction = Vector2.ZERO
		if velocity != Vector2.ZERO:
			velocity -= velocity.normalized() * friction * delta 
			if velocity.length() < min_speed:
				velocity = Vector2.ZERO
		move_and_slide()
	# Note: Navigation movement is handled by _on_velocity_computed callback

func get_next_floor_up(current_floor: Node, root: Node) -> Node:
	# Define floor hierarchy (order matters - bottom to top)
	var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor"]
	
	# Handle different parent structures
	var floor_node = current_floor
	if current_floor is TileMapLayer and current_floor.get_parent().name in floor_order:
		# We're in a TileMapLayer child of a floor Node2D
		floor_node = current_floor.get_parent()
	
	var current_index = floor_order.find(floor_node.name)
	if current_index == -1 or current_index >= floor_order.size() - 1:
		return null  # No next floor
	
	# Get next floor name and find it in the scene
	var next_floor_name = floor_order[current_index + 1]
	var next_floor = root.get_node_or_null(next_floor_name)
	
	# If the next floor is a Node2D with TileMapLayer children, return the TileMapLayer
	if next_floor and not next_floor is TileMapLayer:
		for child in next_floor.get_children():
			if child is TileMapLayer:
				return child
	
	return next_floor

func get_next_floor_down(current_floor: Node, root: Node) -> Node:
	# Define floor hierarchy (order matters - bottom to top)
	var floor_order = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor"]
	
	# Handle different parent structures
	var floor_node = current_floor
	if current_floor is TileMapLayer and current_floor.get_parent().name in floor_order:
		# We're in a TileMapLayer child of a floor Node2D
		floor_node = current_floor.get_parent()
	
	var current_index = floor_order.find(floor_node.name)
	if current_index == -1 or current_index <= 0:
		return null  # No floor below
	
	# Get floor below name and find it in the scene
	var floor_below_name = floor_order[current_index - 1]
	var floor_below = root.get_node_or_null(floor_below_name)
	
	# If the floor below is a Node2D with TileMapLayer children, return the TileMapLayer
	if floor_below and not floor_below is TileMapLayer:
		for child in floor_below.get_children():
			if child is TileMapLayer:
				return child
	
	return floor_below

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
	
	# Handle different parent structures
	var map_root = root
	if root.name == "GroundFloor":
		# We're in the GroundFloor TileMapLayer, need to go up to Map
		map_root = root.get_parent()
	elif root is NavigationRegion2D:
		# We're in a TileMapLayer child of NavigationRegion2D
		map_root = root.get_parent().get_parent()
	
	var floor_names = ["GroundFloor", "FirstFloor", "SecondFloor", "ThirdFloor", "EmptyFloor"]
	
	for floor_name in floor_names:
		var floor_node = map_root.get_node_or_null(floor_name)
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
				# Check for TileMapLayer children (new structure)
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
		manually_stopped_recording = false  # Reset flag when starting new recording
		print("[Player] Recording started (press R to stop)")
	else:
		push_warning("[Player] No PlayerRecorder node found!")

func stop_recording() -> int:
	"""Stop recording and return event count"""
	if recorder:
		var event_count = recorder.stop_recording()
		print("[Player] Recording stopped - ", event_count, " events recorded")
		# Reset the auto-record timer when manually stopping
		recording_elapsed_time = 0.0
		# Set flag to prevent auto-save
		manually_stopped_recording = true
		return event_count
	return 0

func save_recording_to_file(file_path: String = "") -> void:
	"""Save the current recording to a JSON file"""
	if not recorder:
		push_warning("[Player] No PlayerRecorder node found!")
		return
	
	print("[Player] save_recording_to_file called - manually_stopped_recording: %s, is_recording: %s, event_count: %d" % [
		manually_stopped_recording, recorder.is_recording, recorder.get_recording().size()
	])
	
	if file_path.is_empty():
		# Ensure recordings directory exists
		var recordings_dir = "res://recordings"
		if not DirAccess.dir_exists_absolute(recordings_dir):
			DirAccess.make_dir_absolute(recordings_dir)
		
		# Check if we're playing as an existing character
		var global_data = get_node_or_null("/root/GlobalData")
		var is_playing_as_existing_character = global_data and global_data.has_meta("spawn_as_character")
		
		if is_playing_as_existing_character:
			# Use the original recording path to overwrite the existing file
			var character_data = global_data.get_meta("spawn_as_character")
			file_path = character_data.get("recording_path", "")
			print("[Player] Overwriting existing character recording: %s" % file_path)
		else:
			# Generate new filename for new players using character name
			var character_name = get_next_character_name()
			# Character name is already in lowercase_underscore format
			file_path = "res://recordings/%s.json" % character_name
			name = character_name
			print("[Player] Creating new character recording: %s" % file_path)
	
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
	# Auto-save if this was a hybrid recording (character takeover)
	if is_playing_as_character or has_meta("was_character_takeover"):
		print("[Player] Auto-saving hybrid recording...")
		save_recording_to_file()
		remove_meta("was_character_takeover")

func _on_playback_started() -> void:
	"""Called when playback starts"""
	print("[Player] _on_playback_started() called - setting is_in_playback_mode = true")
	is_in_playback_mode = true
	playback_cancelled = false  # Reset cancellation flag
	is_correcting_position = false  # Reset correction flag
	
	# Clear any ongoing navigation
	if is_navigating:
		is_navigating = false
	
	# Visual feedback - could change player color, add overlay, etc.
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 1.0)  # Slight blue tint during playback
	
	# Create visual markers for recorded positions (next 3 seconds)
	_create_recorded_positions_markers()

func _on_playback_finished() -> void:
	"""Called when playback finishes"""
	is_in_playback_mode = false
	
	# NPC mode: loop playback
	if is_npc and loop_playback:
		print("[NPC] Looping playback...")
		await get_tree().create_timer(0.5).timeout
		await recorder.start_playback(1.0, true)  # Position correction enabled for NPCs
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
					print("[%s] Starting navigation to (%.1f, %.1f)" % [name, click_position.x, click_position.y])
				
				# Handle object interaction during playback
				_handle_playback_object_interaction(click_position)
		"npc_follow_start":
			_handle_playback_npc_follow_start()
		"npc_follow_stop":
			_handle_playback_npc_follow_stop()

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
		print("[Player] Waiting for _on_playback_started() callback...")
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
		if file_name.ends_with(".json") and file_name.begins_with("player_"):
			var full_path = recordings_dir + "/" + file_name
			var modified_time = FileAccess.get_modified_time(full_path)
			
			if modified_time > latest_time:
				latest_time = modified_time
				latest_file = full_path
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return latest_file

func get_next_player_number() -> int:
	"""Get the next available player number for naming"""
	var recordings_dir = "res://recordings"
	var dir = DirAccess.open(recordings_dir)
	
	if not dir:
		return 1
	
	var max_number = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("player_"):
			# Extract number from filename like "player_1.json"
			var base_name = file_name.get_basename()
			var number_part = base_name.substr(7)  # Remove "player_" prefix
			if number_part.is_valid_int():
				var number = number_part.to_int()
				if number > max_number:
					max_number = number
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return max_number + 1

func get_next_character_name() -> String:
	"""Get the next available character name for recording"""
	var recordings_dir = "res://recordings"
	var dir = DirAccess.open(recordings_dir)
	var used_names: Array[String] = []
	
	if not dir:
		return CharacterNames.get_character_names()[0]  # Return first name if no recordings directory
	
	# Collect all used character names from existing recordings
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = recordings_dir + "/" + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()
				
				var json = JSON.new()
				if json.parse(json_string) == OK:
					var data = json.data
					if data.has("player_name"):
						used_names.append(data.player_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Use CharacterNames utility to get next available name
	return CharacterNames.get_next_character_name(used_names)

## Called when position deviation is detected during playback
func _on_position_deviation(actual: Vector2, expected: Vector2, deviation: float) -> void:
	"""Check if deviation exceeds threshold and start position correction if needed"""
	if playback_cancelled or is_correcting_position:
		return
	
	# Skip position correction while following an NPC
	# When following an NPC, movement is controlled by the following system, not recorded inputs
	if is_following_npc:
		print("[%s] Skipping position correction - currently following NPC (deviation: %.1fpx)" % [name, deviation])
		return
	
	if deviation > max_deviation_threshold:
		print("[%s] Position deviation %.1fpx exceeds threshold %.1fpx - starting position correction" % [name, deviation, max_deviation_threshold])
		_start_position_correction(expected)

## Create visual markers for the next 3 recorded positions
func _create_recorded_positions_markers() -> void:
	if not recorder:
		return
	
	var recorded_inputs = recorder.get_recorded_inputs()
	var current_parent = get_parent()
	
	# Clear any existing markers
	_remove_recorded_positions_markers()
	
	# Get current playback time and find current position index
	var current_time = recorder.get_playback_time()
	var current_index = recorder.current_playback_index
	
	# Find the next 3 position events after current index
	var position_events: Array[Dictionary] = []
	for i in range(current_index, recorded_inputs.size()):
		var event = recorded_inputs[i]
		if event.has("player_position"):
			position_events.append(event)
			if position_events.size() >= 3:  # Only take next 3 positions
				break
	
	# Create markers for the next 3 positions
	for i in range(position_events.size()):
		var event = position_events[i]
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
		for j in range(segments):
			var angle = (j / float(segments)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		circle.polygon = points
		
		# Calculate color based on position order (darker = closer, lighter = further)
		var color_ratio = float(i) / max(1, position_events.size() - 1)
		var color_value = color_ratio  # 0.0 = black (next), 1.0 = white (3rd position)
		circle.color = Color(color_value, color_value, color_value, 0.6)  # Grayscale with alpha
		circle.z_index = 99
		
		marker.add_child(circle)
		marker.global_position = position
		
		# Add to scene
		current_parent.add_child(marker)
		recorded_position_markers.append(marker)
	

## Update path markers to show next 3 positions during playback
func _update_path_markers() -> void:
	"""Update path markers to show only the next 3 recorded positions"""
	if not recorder:
		return
	
	# Check if we need to update markers (only update every 0.2 seconds to avoid performance issues)
	if not has_meta("last_marker_update_time"):
		set_meta("last_marker_update_time", 0.0)
	
	var current_time = recorder.get_playback_time()
	var last_update = get_meta("last_marker_update_time")
	if current_time - last_update < 0.2:  # Update every 0.2 seconds
		return
	
	set_meta("last_marker_update_time", current_time)
	
	# Remove old markers and create new ones
	_remove_recorded_positions_markers()
	_create_recorded_positions_markers()

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
		print("[%s] No next position found - navigating to last position" % name)
		_navigate_to_last_position()
		return
	
	# Find the next non-position-checkpoint action to determine correction duration
	var next_action = _find_next_non_position_action(recorded_inputs, current_time)
	var correction_time_target = current_time
	
	if not next_action.is_empty():
		# Use the timestamp of the next non-position-checkpoint action
		correction_time_target = next_action.timestamp
		print("[%s] Using next action '%s' at %.2fs for correction duration" % [name, next_action.action, next_action.timestamp])
	else:
		# Fallback: use the next position timestamp if no other actions found
		correction_time_target = next_position.timestamp
		print("[%s] No non-position actions found, using next position timestamp" % name)
	
	# Calculate dT (time difference to next action or position)
	var dT = correction_time_target - current_time
	correction_duration = dT
	correction_start_time = Time.get_ticks_msec() / 1000.0
	correction_target_position = next_position.position
	correction_waypoint_index = next_position.index
	is_correcting_position = true
	
	# Start navigation to the target position
	if navigation_agent:
		navigation_agent.target_position = next_position.position
		is_navigating = true
		print("[%s] Navigating to correction target at (%.1f, %.1f) - dT: %.2fs" % [
			name, next_position.position.x, next_position.position.y, dT
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

## Find the next non-position-checkpoint action after the given time
func _find_next_non_position_action(recorded_inputs: Array, current_time: float) -> Dictionary:
	"""Find the next action that is NOT a position_checkpoint after current time"""
	var best_action = {}
	var best_time = INF
	
	for i in range(recorded_inputs.size()):
		var event = recorded_inputs[i]
		if event.timestamp > current_time:
			# Skip position_checkpoint events
			if event.has("action") and event.action == "position_checkpoint":
				continue
			
			# Find the earliest non-position-checkpoint action
			if event.timestamp < best_time:
				best_time = event.timestamp
				best_action = {
					"action": event.get("action", ""),
					"timestamp": event.timestamp,
					"index": i,
					"event": event
				}
	
	return best_action

## Update position correction system
func _update_position_correction() -> void:
	"""Update position correction system - check if correction time has elapsed"""
	if not is_correcting_position:
		return
	
	# Skip position correction while following an NPC
	# When following an NPC, movement is controlled by the following system, not recorded inputs
	if is_following_npc:
		print("[%s] Skipping position correction - currently following NPC" % name)
		return
	
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - correction_start_time
	
	if elapsed_time >= correction_duration:
		# Check if player is within deviation of expected position
		var current_pos = global_position
		var deviation = current_pos.distance_to(correction_target_position)
		
		if deviation <= max_deviation_threshold:
			# Success! Resume normal playback
			print("[%s] Position correction successful - resuming playback" % name)
			_resume_normal_playback()
		else:
			# Still too far - double the time window and find next waypoint
			print("[%s] Still too far (%.1fpx) - doubling time window" % [name, deviation])
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
	
	# Find the next non-position-checkpoint action within the doubled time window
	var next_action = _find_next_non_position_action(recorded_inputs, current_time)
	var correction_time_target = target_time
	
	if not next_action.is_empty() and next_action.timestamp <= target_time:
		# Use the timestamp of the next non-position-checkpoint action within the window
		correction_time_target = next_action.timestamp
		print("[Playback] Using next action '%s' at %.2fs for doubled correction duration" % [next_action.action, next_action.timestamp])
	else:
		# Fallback: use the doubled time window
		correction_time_target = target_time
		print("[Playback] No non-position actions found within doubled window, using doubled time")
	
	# Update correction parameters with the new target time
	var final_dT = correction_time_target - current_time
	correction_duration = final_dT
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

## Handle object interaction during playback
func _handle_playback_object_interaction(_click_position: Vector2) -> void:
	"""Handle clicking on objects during playback to replicate object interactions"""
	if not recorder:
		return
	
	# Get the current playback event to check for object interaction data
	var current_playback_index = recorder.current_playback_index
	var recorded_inputs = recorder.get_recorded_inputs()
	
	if current_playback_index >= 0 and current_playback_index < recorded_inputs.size():
		var current_event = recorded_inputs[current_playback_index]
		
		# Check if this click was on a moveable object
		if current_event.has("clicked_object_id"):
			var object_id = current_event["clicked_object_id"]
			var was_attached = current_event.get("object_attachment_state", false)
			
			# Find the object by ID
			var target_object = _find_object_by_id(object_id)
			if target_object:
				print("[Playback] Interacting with object: %s (was attached: %s)" % [object_id, was_attached])
				
				# Simulate the object interaction
				if was_attached:
					# Object was attached, so detach it
					if target_object.has_method("detach_from_player"):
						target_object.detach_from_player()
				else:
					# Object was not attached, so attach it
					if target_object.has_method("attach_to_player"):
						target_object.attach_to_player()

## Find an object by its unique ID
func _find_object_by_id(object_id: String) -> Node:
	"""Find a moveable object by its unique ID"""
	var moveable_objects = get_tree().get_nodes_in_group("moveable")
	
	for obj in moveable_objects:
		if obj.has_method("get_object_id") and obj.get_object_id() == object_id:
			return obj
	
	return null

## NPC-specific: Load and play most recent recording with looping
func _npc_load_and_play_most_recent() -> void:
	"""Load the most recent recording and start playing it (NPC mode only)"""
	if not is_npc:
		return
	
	var recording_path = get_most_recent_recording()
	
	if recording_path.is_empty():
		push_warning("[Ghost] No recordings found in res://recordings/")
		return
	
		print("[NPC] Loading most recent recording: ", recording_path)
	
	if recorder.load_from_file(recording_path):
		print("[NPC] Recording loaded successfully")
		await recorder.start_playback(1.0, true)  # Position correction enabled for NPCs
	else:
		push_error("[NPC] Failed to load recording")

func _spawn_as_character(character_data: Dictionary) -> void:
	"""Spawn the player as a specific character from recording data"""
	var character_info = character_data.get("character_info", {})
	var recording_name = character_data.get("recording_name", "Unknown")
	var player_number = character_data.get("player_number", 0)
	
	# Set player name to match the character
	name = character_info.get("player_name", "player_%d" % player_number)
	print("[Player] Spawning as character: %s" % name)
	
	# Set position to the character's start position
	var start_position = character_info.get("start_position", Vector2.ZERO)
	if start_position != Vector2.ZERO:
		position = start_position
		print("[Player] Set position to character's start position: %s" % start_position)
	
	# Load the character's recording for playback
	var recording_path = character_data.get("recording_path", "")
	if recording_path != "" and recorder:
		print("[Player] Loading character's recording: %s" % recording_path)
		# Load the recording but don't start playback yet
		recorder.load_from_file(recording_path)
		
		# Start playback after a short delay to ensure everything is set up
		await get_tree().create_timer(0.5).timeout
		
		# Flag already set in _ready() to prevent random spawn
		print("[Player] Started character takeover mode - recording will play until you provide input")
		
		# Stop any current recording before starting playback
		if recorder and recorder.is_recording:
			print("[Player] Stopping current recording before starting playback")
			recorder.stop_recording()
		
		# Start playback with position correction enabled
		print("[Player] About to call recorder.start_playback(1.0, true)")
		print("[Player] Recorder exists: %s" % (recorder != null))
		if recorder:
			print("[Player] Recorder has playback_started signal: %s" % recorder.has_signal("playback_started"))
			print("[Player] Recorder is_recording: %s" % recorder.is_recording)
		var playback_result = await recorder.start_playback(1.0, true)
		print("[Player] recorder.start_playback() returned: %s" % playback_result)
		print("[Player] Character takeover playback started")

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

# ============================================================================
# NPC Following System Methods
# ============================================================================

func get_npc_at_position(click_position: Vector2) -> Node:
	"""Check if there's an NPC at the clicked position"""
	var npcs = get_tree().get_nodes_in_group("npc")
	var click_radius = 40.0  # Increased radius to check for NPCs
	
	print("[NPC Detection] Checking for NPCs at click position: %s" % click_position)
	print("[NPC Detection] Found %d NPCs in group" % npcs.size())
	
	# Debug: List all NPCs found
	for i in range(npcs.size()):
		var npc = npcs[i]
		if npc and is_instance_valid(npc):
			print("[NPC Detection] NPC %d: %s at %s (valid: %s)" % [i, npc.name, npc.global_position, is_instance_valid(npc)])
		else:
			print("[NPC Detection] NPC %d: INVALID or NULL" % i)
	
	for npc in npcs:
		if npc and is_instance_valid(npc):
			var distance = npc.global_position.distance_to(click_position)
			print("[NPC Detection] NPC %s at %s, distance: %.1f (radius: %.1f)" % [npc.name, npc.global_position, distance, click_radius])
			if distance <= click_radius:
				print("[NPC Detection] Found NPC within radius: %s" % npc.name)
				return npc
	
	print("[NPC Detection] No NPC found within %.1f radius" % click_radius)
	return null

func follow_npc(npc: Node) -> void:
	"""Start following a specific NPC"""
	if not npc or not is_instance_valid(npc):
		push_warning("[Player] Invalid NPC provided for following")
		return
	
	# Stop following any current NPC and remove its indicator
	if is_following_npc:
		_remove_follow_indicator()  # Remove indicator from old NPC
		stop_following_npc()
	
	# Set up following
	followed_npc = npc
	is_following_npc = true
	follow_update_timer = 0.0
	
	# Record the NPC following event
	_record_npc_follow_event(npc)
	
	# Start navigation to the NPC (maintaining follow distance)
	if navigation_agent:
		var current_distance = global_position.distance_to(npc.global_position)
		if current_distance > follow_distance:
			var direction_to_npc = (npc.global_position - global_position).normalized()
			var target_position = npc.global_position - direction_to_npc * follow_distance
			navigation_agent.target_position = target_position
			is_navigating = true
		else:
			# Already close enough
			is_navigating = false
	
	print("[%s] Started following NPC: %s" % [name, npc.name])
	
	# Add visual feedback
	_add_follow_indicator(npc)

func stop_following_npc() -> void:
	"""Stop following the current NPC"""
	if not is_following_npc:
		return
	
	print("[Player] Stopped following NPC: %s" % followed_npc.name if followed_npc else "unknown")
	
	# Record the stop following event
	_record_npc_stop_follow_event()
	
	# Clear following state
	is_following_npc = false
	followed_npc = null
	follow_update_timer = 0.0
	
	# Stop navigation
	is_navigating = false
	
	# Remove visual feedback
	_remove_follow_indicator()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	"""Called when NavigationAgent2D computes a safe velocity"""
	velocity = safe_velocity
	move_and_slide()

func _update_npc_following(delta: float) -> void:
	"""Update NPC following system - called every physics frame"""
	if not is_following_npc or not followed_npc or not is_instance_valid(followed_npc):
		# Clean up if NPC is no longer valid
		if is_following_npc:
			stop_following_npc()
		return
	
	# Check if we're currently using keyboard input
	var any_key_pressed = false
	if is_npc:
		any_key_pressed = (simulated_inputs.get("ui_right", false) or 
						  simulated_inputs.get("ui_left", false) or 
						  simulated_inputs.get("ui_up", false) or 
						  simulated_inputs.get("ui_down", false))
	
	# Check current distance to NPC
	var current_distance = global_position.distance_to(followed_npc.global_position)
	
	# Only update navigation if we're too far away and not using keyboard input
	if current_distance > follow_distance and not any_key_pressed:
		# Update timer
		follow_update_timer += delta
		
		# Update target position every second or if we're getting too far
		if follow_update_timer >= follow_update_interval or current_distance > follow_distance * 2.0:
			follow_update_timer = 0.0
			
			# Calculate target position that maintains the desired distance
			var direction_to_npc = (followed_npc.global_position - global_position).normalized()
			var target_position = followed_npc.global_position - direction_to_npc * follow_distance
			
			# Update navigation target
			if navigation_agent:
				navigation_agent.target_position = target_position
				is_navigating = true
	elif current_distance <= follow_distance:
		# We're close enough - stop navigating
		if is_navigating:
			is_navigating = false
			print("[Player] Close enough to NPC, stopping navigation")
	elif any_key_pressed:
		# We're using keyboard input - pause following but keep it active
		pass
	
	# Update indicator position to follow the target NPC
	var indicator_name = "PlayerFollowIndicator" if not is_npc else "NPCFollowIndicator"
	var indicator = get_node_or_null(indicator_name)
	if indicator and followed_npc and is_instance_valid(followed_npc):
		# Position the indicator above the target NPC
		indicator.global_position = followed_npc.global_position + Vector2(0, -20)

func _add_follow_indicator(npc: Node) -> void:
	"""Add visual indicator to show which NPC is being followed"""
	# Remove any existing indicator from this player
	_remove_follow_indicator()
	
	# Create a simple circle indicator that follows the target NPC
	var indicator = Node2D.new()
	
	# Different indicator names and colors for player vs NPC following
	if is_npc:
		indicator.name = "NPCFollowIndicator"
		var circle = Polygon2D.new()
		circle.name = "Circle"
		var points = PackedVector2Array()
		var segments = 12
		var radius = 6.0
		for i in range(segments):
			var angle = (i / float(segments)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		circle.polygon = points
		circle.color = Color(0.0, 1.0, 0.0, 0.8)  # Green for NPC following
		circle.z_index = 99  # Slightly below player indicator
		
		indicator.add_child(circle)
		indicator.position = Vector2(0, -15)  # Slightly lower than player indicator
	else:
		indicator.name = "PlayerFollowIndicator"
		var circle = Polygon2D.new()
		circle.name = "Circle"
		var points = PackedVector2Array()
		var segments = 12
		var radius = 8.0
		for i in range(segments):
			var angle = (i / float(segments)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		circle.polygon = points
		circle.color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow for player following
		circle.z_index = 100  # Always on top
		
		indicator.add_child(circle)
		indicator.position = Vector2(0, -20)  # Above the NPC
	
	# Add indicator to this player (not the NPC) so only this player can see it
	add_child(indicator)
	
	# Set initial position above the target NPC
	if npc and is_instance_valid(npc):
		indicator.global_position = npc.global_position + Vector2(0, -20)

func _remove_follow_indicator() -> void:
	"""Remove the follow indicator from this player"""
	var indicator_name = "PlayerFollowIndicator" if not is_npc else "NPCFollowIndicator"
	var indicator = get_node_or_null(indicator_name)
	if indicator:
		indicator.queue_free()
		print("[Player] Removed follow indicator")

func _remove_all_follow_indicators() -> void:
	"""Remove follow indicators from all NPCs (legacy function - now each player manages their own)"""
	# This function is now deprecated since each player manages their own indicator
	# But we'll keep it for compatibility and just remove this player's indicator
	_remove_follow_indicator()

func _record_npc_follow_event(npc: Node) -> void:
	"""Record when the player starts following an NPC"""
	if not recorder:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var recording_start_time = recorder.recording_start_time if recorder else current_time
	var timestamp = current_time - recording_start_time
	
	# Create a special event for NPC following
	var event = {
		"timestamp": timestamp,
		"action": "npc_follow_start",
		"pressed": true,
		"npc_id": npc.name,
		"npc_position": {
			"x": npc.global_position.x,
			"y": npc.global_position.y
		},
		"follow_distance": follow_distance
	}
	
	print("[%s] Recording NPC follow start - NPC ID: %s" % [name, npc.name])
	
	# Record player position and state
	event["player_position"] = {
		"x": global_position.x,
		"y": global_position.y
	}
	
	# Record current floor
	var current_floor = get_parent()
	if current_floor:
		event["floor"] = current_floor.name
		
		# Record tile position if available
		if has_method("get_current_tile"):
			var tile_pos = get_current_tile()
			event["tile_position"] = {
				"x": tile_pos.x,
				"y": tile_pos.y
			}
	
	# Record z-height if available
	if "z_height" in self:
		event["z_height"] = z_height
	
	# Add to recorder's recorded inputs
	if recorder.has_method("get_recorded_inputs"):
		var recorded_inputs = recorder.get_recorded_inputs()
		recorded_inputs.append(event)
	
	print("[%s] Recorded NPC follow start: %s at %s" % [name, npc.name, npc.global_position])

func _record_npc_stop_follow_event() -> void:
	"""Record when the player stops following an NPC"""
	if not recorder:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var recording_start_time = recorder.recording_start_time if recorder else current_time
	var timestamp = current_time - recording_start_time
	
	# Create a special event for stopping NPC following
	var event = {
		"timestamp": timestamp,
		"action": "npc_follow_stop",
		"pressed": false
	}
	
	# Record player position and state
	event["player_position"] = {
		"x": global_position.x,
		"y": global_position.y
	}
	
	# Record current floor
	var current_floor = get_parent()
	if current_floor:
		event["floor"] = current_floor.name
		
		# Record tile position if available
		if has_method("get_current_tile"):
			var tile_pos = get_current_tile()
			event["tile_position"] = {
				"x": tile_pos.x,
				"y": tile_pos.y
			}
	
	# Record z-height if available
	if "z_height" in self:
		event["z_height"] = z_height
	
	# Add to recorder's recorded inputs
	if recorder.has_method("get_recorded_inputs"):
		var recorded_inputs = recorder.get_recorded_inputs()
		recorded_inputs.append(event)
	
	print("[Player] Recorded NPC follow stop")

func _handle_playback_npc_follow_start() -> void:
	"""Handle NPC follow start during playback"""
	if not recorder:
		return
	
	# Get the current playback event to extract NPC information
	var current_playback_index = recorder.current_playback_index
	var recorded_inputs = recorder.get_recorded_inputs()
	
	if current_playback_index >= 0 and current_playback_index < recorded_inputs.size():
		var current_event = recorded_inputs[current_playback_index]
		
		# Extract NPC information from the recorded event
		if current_event.has("npc_id") and current_event.has("npc_position"):
			var npc_id = current_event["npc_id"]
			var npc_position = Vector2(current_event["npc_position"]["x"], current_event["npc_position"]["y"])
			var recorded_follow_distance = current_event.get("follow_distance", follow_distance)
			
			# Find the NPC by ID
			var target_npc = _find_npc_by_id(npc_id)
			if target_npc:
				# Use the recorded follow distance
				var original_distance = follow_distance
				follow_distance = recorded_follow_distance
				
				# Start following the NPC (this will set up dynamic following)
				follow_npc(target_npc)
				
				# Restore original follow distance
				follow_distance = original_distance
				
				print("[%s] Started following NPC: %s (recorded distance: %.1f)" % [name, npc_id, recorded_follow_distance])
			else:
				print("[%s] Could not find NPC with ID: %s" % [name, npc_id])
		else:
			print("[Playback] NPC follow event missing required data")

func _handle_playback_npc_follow_stop() -> void:
	"""Handle NPC follow stop during playback"""
	if is_following_npc:
		stop_following_npc()
		print("[%s] Stopped following NPC" % name)

func _find_npc_by_id(npc_id: String) -> Node:
	"""Find an NPC or player by its unique ID (name)"""
	var npcs = get_tree().get_nodes_in_group("npc")
	
	print("[%s] Looking for character with ID: %s" % [name, npc_id])
	print("[Playback] Available NPCs:")
	for npc in npcs:
		if npc and is_instance_valid(npc):
			print("  - %s" % npc.name)
			if npc.name == npc_id:
				print("[%s] Found matching NPC: %s" % [name, npc.name])
				return npc
	
	# Also search for human players by name directly
	print("[Playback] Searching for human players:")
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if node.name == npc_id and node != self:  # Don't follow yourself
			print("  - Found node with matching name: %s (type: %s)" % [node.name, node.get_class()])
			# Check if it's a player-like node (has the methods we need)
			if node.has_method("follow_npc") and node.has_method("stop_following_npc"):
				print("  - %s (human player)" % node.name)
				print("[%s] Found matching Player: %s" % [name, node.name])
				return node
			else:
				print("    Node %s doesn't have required player methods" % node.name)
	
	print("[%s] No matching character found for ID: %s" % [name, npc_id])
	return null

func _connect_to_npc_synchronization() -> void:
	"""Connect to NPC manager signal to start recording when NPCs start"""
	# Find the NPC manager
	var npc_manager = get_tree().get_first_node_in_group("npc_manager")
	if not npc_manager:
		# Try to find it by name
		npc_manager = get_node_or_null("../GhostManager")
	
	if npc_manager and npc_manager.has_signal("all_npcs_started_playback"):
		npc_manager.all_npcs_started_playback.connect(_on_npcs_started_playback)
		print("[Player] Connected to NPC synchronization signal")
	else:
		# Fallback: start recording immediately if no NPC manager found
		print("[Player] No NPC manager found, starting recording immediately...")
		_start_recording_synchronized()

func _on_npcs_started_playback() -> void:
	"""Called when all NPCs have started their playback"""
	print("[Player] NPCs have started playback - beginning recording now!")
	_start_recording_synchronized()

func _start_recording_synchronized() -> void:
	"""Start recording synchronized with NPCs"""
	print("\n[Player] Auto-starting INPUT_ONLY recording for %.1f seconds..." % auto_record_duration)
	start_recording()
	recording_elapsed_time = 0.0

func _is_user_input(event: InputEvent) -> bool:
	"""Check if the event represents meaningful user input that should interrupt playback"""
	if event is InputEventKey and event.pressed:
		# Any key press except recording controls
		return event.keycode != KEY_R and not (event.keycode == KEY_S and event.ctrl_pressed) and not (event.keycode == KEY_L and event.ctrl_pressed) and not (event.keycode == KEY_P) and not (event.keycode == KEY_SPACE and event.ctrl_pressed)
	elif event is InputEventMouseButton and event.pressed:
		# Any mouse click
		return true
	elif event is InputEventMouseMotion:
		# Mouse movement (optional - you might want to exclude this)
		return false
	return false

func _on_timer_finished() -> void:
	"""Called when the countdown timer reaches zero"""
	print("[Player] Timer finished - returning to main menu")
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func should_skip_mouse_click_recording() -> bool:
	"""Check if the next mouse click should be skipped from recording"""
	if skip_next_mouse_click:
		skip_next_mouse_click = false  # Reset the flag
		return true
	if skip_mouse_release:
		skip_mouse_release = false  # Reset the flag
		return true
	return false
