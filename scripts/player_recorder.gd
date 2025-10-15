extends Node
class_name PlayerRecorder

## Records player input events with timestamps
## Lightweight recording system that only captures user inputs
## Can be attached to any player node to track their actions

# Legacy data structure - no longer used, kept for compatibility
class PlayerFrame:
	var timestamp: float  # Time in seconds
	var global_position: Vector2  # World position
	var velocity: Vector2  # Current velocity
	var z_height: float  # Height in isometric space
	var current_direction: Vector2  # Movement direction
	var is_jumping: bool  # Jump state
	var jump_time: float  # Time in current jump
	var floor_name: String  # Current floor the player is on
	var tile_position: Vector2i  # Tile coordinates
	
	# Input states
	var input_right: bool
	var input_left: bool
	var input_up: bool
	var input_down: bool
	var input_jump: bool
	var input_mouse_click: bool
	var mouse_position: Vector2
	
	func _init(
		p_timestamp: float = 0.0,
		p_position: Vector2 = Vector2.ZERO,
		p_velocity: Vector2 = Vector2.ZERO,
		p_z_height: float = 0.0,
		p_direction: Vector2 = Vector2.ZERO,
		p_jumping: bool = false,
		p_jump_time: float = 0.0,
		p_floor: String = "",
		p_tile: Vector2i = Vector2i.ZERO
	):
		timestamp = p_timestamp
		global_position = p_position
		velocity = p_velocity
		z_height = p_z_height
		current_direction = p_direction
		is_jumping = p_jumping
		jump_time = p_jump_time
		floor_name = p_floor
		tile_position = p_tile
		input_right = false
		input_left = false
		input_up = false
		input_down = false
		input_jump = false
		input_mouse_click = false
		mouse_position = Vector2.ZERO
	
	func to_dict() -> Dictionary:
		return {
			"timestamp": timestamp,
			"position": {"x": global_position.x, "y": global_position.y},
			"velocity": {"x": velocity.x, "y": velocity.y},
			"z_height": z_height,
			"direction": {"x": current_direction.x, "y": current_direction.y},
			"is_jumping": is_jumping,
			"jump_time": jump_time,
			"floor_name": floor_name,
			"tile_position": {"x": tile_position.x, "y": tile_position.y},
			"inputs": {
				"right": input_right,
				"left": input_left,
				"up": input_up,
				"down": input_down,
				"jump": input_jump,
				"mouse_click": input_mouse_click,
				"mouse_pos": {"x": mouse_position.x, "y": mouse_position.y}
			}
		}
	
	static func from_dict(data: Dictionary) -> PlayerFrame:
		var frame = PlayerFrame.new()
		frame.timestamp = data.get("timestamp", 0.0)
		
		var pos = data.get("position", {})
		frame.global_position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		
		var vel = data.get("velocity", {})
		frame.velocity = Vector2(vel.get("x", 0.0), vel.get("y", 0.0))
		
		frame.z_height = data.get("z_height", 0.0)
		
		var dir = data.get("direction", {})
		frame.current_direction = Vector2(dir.get("x", 0.0), dir.get("y", 0.0))
		
		frame.is_jumping = data.get("is_jumping", false)
		frame.jump_time = data.get("jump_time", 0.0)
		frame.floor_name = data.get("floor_name", "")
		
		var tile = data.get("tile_position", {})
		frame.tile_position = Vector2i(tile.get("x", 0), tile.get("y", 0))
		
		var inputs = data.get("inputs", {})
		frame.input_right = inputs.get("right", false)
		frame.input_left = inputs.get("left", false)
		frame.input_up = inputs.get("up", false)
		frame.input_down = inputs.get("down", false)
		frame.input_jump = inputs.get("jump", false)
		frame.input_mouse_click = inputs.get("mouse_click", false)
		
		var mouse_pos = inputs.get("mouse_pos", {})
		frame.mouse_position = Vector2(mouse_pos.get("x", 0.0), mouse_pos.get("y", 0.0))
		
		return frame

# Recording state
var is_recording: bool = false
var recording_start_time: float = 0.0
var recorded_inputs: Array[Dictionary] = []
var last_input_state: Dictionary = {}  # Track previous input state to detect changes

# Position checkpoint recording (every N seconds)
var position_checkpoint_interval: float = 1.0  # Record position every second
var time_since_last_checkpoint: float = 0.0


# Playback state
var is_playing: bool = false
var playback_start_time: float = 0.0
var current_playback_index: int = 0
var playback_speed: float = 1.0  # 1.0 = normal speed, 2.0 = 2x speed, etc.

# Position tracking for replay accuracy
var position_deviations: Array = []  # Track position errors during playback
var max_deviation: float = 0.0
var average_deviation: float = 0.0
var position_correction_enabled: bool = false  # If true, force player to recorded positions
var position_correction_threshold: float = 10.0  # Correct if deviation exceeds this (pixels)



# Reference to the player node
var player: CharacterBody2D = null

# Signals
signal recording_started()
signal recording_stopped()
signal input_recorded(event: Dictionary)
signal playback_started()
signal playback_finished()
signal playback_input(action: String, pressed: bool, position: Vector2)
signal position_deviation(actual: Vector2, expected: Vector2, deviation: float)

func _ready() -> void:
	# Try to get player from parent
	if get_parent() is CharacterBody2D:
		player = get_parent()
	else:
		push_warning("PlayerRecorder: Parent is not a CharacterBody2D. Please set player reference manually.")
	
	# Initialize input state tracking
	_reset_input_state()

func _physics_process(delta: float) -> void:
	if is_recording and player:
		# Check for input changes and record them
		_check_and_record_inputs()
		
		# Record position checkpoints at regular intervals
		time_since_last_checkpoint += delta
		if time_since_last_checkpoint >= position_checkpoint_interval:
			_record_position_checkpoint()
			time_since_last_checkpoint = 0.0
	
	if is_playing:
		# Play back recorded inputs
		_update_playback(delta)
		
		# Compare actual vs expected position
		_check_playback_position_accuracy()

## Start recording player input events
func start_recording() -> void:
	if not player:
		push_error("PlayerRecorder: No player reference set!")
		return
	
	is_recording = true
	recording_start_time = Time.get_ticks_msec() / 1000.0
	recorded_inputs.clear()
	time_since_last_checkpoint = 0.0
	_reset_input_state()
	
	# Record initial position checkpoint
	_record_position_checkpoint()
	
	print("PlayerRecorder: Started recording input events (with position checkpoints every %.1fs)" % position_checkpoint_interval)
	recording_started.emit()

## Stop recording and return the number of events recorded
func stop_recording() -> int:
	is_recording = false
	var event_count = recorded_inputs.size()
	print("PlayerRecorder: Stopped recording. Recorded ", event_count, " input events")
	recording_stopped.emit()
	return event_count


## Get recorded inputs
func get_recording() -> Array[Dictionary]:
	return recorded_inputs

## Get recording duration in seconds
func get_recording_duration() -> float:
	if recorded_inputs.is_empty():
		return 0.0
	return recorded_inputs[-1].timestamp


## Save recording to a JSON file
func save_to_file(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("PlayerRecorder: Failed to open file for writing: ", file_path)
		return false
	
	var data = get_input_recording_as_dict()
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("PlayerRecorder: Saved input recording to %s" % file_path)
	return true

## Load recording from a JSON file
func load_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("PlayerRecorder: File does not exist: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("PlayerRecorder: Failed to open file for reading: ", file_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("PlayerRecorder: Failed to parse JSON: ", json.get_error_message())
		return false
	
	load_input_recording_from_dict(json.data)
	return true

## Get statistics about the recording (uses input statistics)
func get_statistics() -> Dictionary:
	return get_input_statistics()

## Clear all recorded data
func clear() -> void:
	recorded_inputs.clear()
	is_recording = false
	is_playing = false
	current_playback_index = 0
	_reset_input_state()
	print("PlayerRecorder: Cleared all recorded data")

# ============================================================================
# Playback Methods
# ============================================================================

## Start playing back a recording
## @param speed: Playback speed multiplier (1.0 = normal)
## @param enable_position_correction: If true, force player to recorded positions when drift exceeds threshold
func start_playback(speed: float = 1.0, enable_position_correction: bool = false) -> bool:
	if recorded_inputs.is_empty():
		push_error("PlayerRecorder: No recording loaded to play back!")
		return false
	
	if is_recording:
		push_error("PlayerRecorder: Cannot play back while recording!")
		return false
	
	# Position player at the starting location from the recording
	if not await _position_player_at_start():
		push_error("PlayerRecorder: Failed to position player at starting location")
		return false
	
	is_playing = true
	playback_start_time = Time.get_ticks_msec() / 1000.0
	current_playback_index = 0
	playback_speed = speed
	position_correction_enabled = enable_position_correction
	
	# Reset position tracking
	position_deviations.clear()
	max_deviation = 0.0
	average_deviation = 0.0
	
	var correction_status = " (position correction: %s)" % ("ON" if enable_position_correction else "OFF")
	print("PlayerRecorder: Started playback at %sx speed (%d events)%s" % [speed, recorded_inputs.size(), correction_status])
	playback_started.emit()
	return true

## Position player at the starting location from recording
func _position_player_at_start() -> bool:
	if not player:
		return false
	
	# Find first event with position data
	var start_event = null
	for event in recorded_inputs:
		if event.has("player_position") and event.has("floor"):
			start_event = event
			break
	
	if not start_event:
		push_warning("PlayerRecorder: No position data found in recording")
		return false
	
	var start_floor_name = start_event.floor
	var start_pos = start_event.player_position
	var start_position = Vector2(start_pos.x, start_pos.y)
	
	# Find the target floor in the scene
	var current_parent = player.get_parent()
	var grandparent = current_parent.get_parent() if current_parent else null
	
	if not grandparent:
		push_error("PlayerRecorder: Could not find scene root")
		return false
	
	var target_floor = grandparent.get_node_or_null(start_floor_name)
	
	if not target_floor:
		push_error("PlayerRecorder: Could not find floor '%s' in scene" % start_floor_name)
		return false
	
	# Move player to the correct floor if needed
	if current_parent != target_floor:
		current_parent.remove_child(player)
		target_floor.add_child(player)
	
	# Set player position (use global position for accuracy)
	player.global_position = start_position
	
	# Force position update by waiting a frame
	await player.get_tree().process_frame
	player.global_position = start_position
	
	# Set z-height if available
	if start_event.has("z_height") and "z_height" in player:
		player.z_height = start_event.z_height
	
	# Reset player state completely
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	if "is_jumping" in player:
		player.is_jumping = false
	if "current_direction" in player:
		player.current_direction = Vector2.ZERO
	if "is_navigating" in player:
		player.is_navigating = false
	if "ground_z" in player:
		player.ground_z = 0.0
	if "jump_time" in player:
		player.jump_time = 0.0
	
	# Update z-index
	if player.has_method("update_z_index"):
		player.update_z_index()
	
	print("PlayerRecorder: Positioned player at (%.1f, %.1f) on %s" % [
		start_position.x, start_position.y, start_floor_name
	])
	
	# Verify position was set correctly
	await player.get_tree().process_frame
	var actual_pos = player.global_position
	var pos_error = actual_pos.distance_to(start_position)
	if pos_error > 1.0:
		push_warning("PlayerRecorder: Position drift detected at start (%.2f px)" % pos_error)
	
	return true

## Stop playback
func stop_playback() -> void:
	if not is_playing:
		return
	
	is_playing = false
	current_playback_index = 0
	
	# Calculate final statistics
	_calculate_deviation_stats()
	
	print("PlayerRecorder: Stopped playback")
	if not position_deviations.is_empty():
		print("  Position accuracy - Avg: %.2f px, Max: %.2f px, Samples: %d" % [
			average_deviation, max_deviation, position_deviations.size()
		])
	
	playback_finished.emit()

## Update playback during physics process
func _update_playback(_delta: float) -> void:
	if current_playback_index >= recorded_inputs.size():
		# Playback finished
		stop_playback()
		return
	
	var current_time = (Time.get_ticks_msec() / 1000.0 - playback_start_time) * playback_speed
	
	# Process all events that should have happened by now
	while current_playback_index < recorded_inputs.size():
		var event = recorded_inputs[current_playback_index]
		
		if event.timestamp > current_time:
			break  # Wait for this event's time
		
		# Simulate this input event
		_simulate_input_event(event)
		current_playback_index += 1

## Simulate an input event
func _simulate_input_event(event: Dictionary) -> void:
	var action = event.action
	var pressed = event.pressed
	
	# Handle floor changes
	if action == "floor_change":
		_handle_floor_change(event)
		return
	
	# Handle position checkpoints
	if action == "position_checkpoint":
		_apply_position_checkpoint(event)
		return
	
	# Handle mouse clicks - position player before navigation starts
	var mouse_pos = Vector2.ZERO
	if action == "mouse_click" and pressed and event.has("click_position"):
		var pos = event.click_position
		mouse_pos = Vector2(pos.x, pos.y)
		
		# Position player at the recorded position when the click occurred
		# This ensures navigation path starts from the same location
		if player and position_correction_enabled and event.has("player_position"):
			var click_player_pos = event.player_position
			var start_position = Vector2(click_player_pos.x, click_player_pos.y)
			player.global_position = start_position
			print("[Playback] Positioned player at (%.1f, %.1f) for navigation click" % [
				start_position.x, start_position.y
			])
	
	# Emit signal so the player can respond
	playback_input.emit(action, pressed, mouse_pos)
	
	# For debugging
	# print("[Playback] %.3fs: %s %s" % [event.timestamp, action, "pressed" if pressed else "released"])

## Handle floor change during playback
func _handle_floor_change(event: Dictionary) -> void:
	if not player:
		return
	
	var to_floor_name = event.get("to_floor", "")
	if to_floor_name.is_empty():
		return
	
	# Find the target floor
	var current_parent = player.get_parent()
	var grandparent = current_parent.get_parent() if current_parent else null
	
	if not grandparent:
		return
	
	var target_floor = grandparent.get_node_or_null(to_floor_name)
	
	if not target_floor or target_floor == current_parent:
		return
	
	# Move player to new floor
	var target_global_pos = player.global_position
	current_parent.remove_child(player)
	target_floor.add_child(player)
	player.global_position = target_global_pos
	
	# Update z-height if available
	if event.has("z_height") and "z_height" in player:
		player.z_height = event.z_height
	
	# Update z_index
	if player.has_method("update_z_index"):
		player.update_z_index()
	
	print("[Playback] Floor transition: %s → %s" % [
		event.get("from_floor", "?"),
		to_floor_name
	])

## Apply position checkpoint during playback
func _apply_position_checkpoint(event: Dictionary) -> void:
	if not player or not position_correction_enabled:
		return
	
	if not event.has("player_position"):
		return
	
	var checkpoint_pos = event.player_position
	var target_position = Vector2(checkpoint_pos.x, checkpoint_pos.y)
	var current_position = player.global_position
	var deviation = current_position.distance_to(target_position)
	
	# Always apply checkpoint corrections (they're ground truth)
	if deviation > 0.5:  # Only correct if meaningfully different
		player.global_position = target_position
		
		# Keep velocity intact to maintain momentum during correction
		
		# Set z-height if available
		if event.has("z_height") and "z_height" in player:
			player.z_height = event.z_height
		
		print("[Playback] Position checkpoint applied - corrected %.1fpx deviation" % deviation)

## Apply navigation target during playback

## Check if playback is active
func is_playing_back() -> bool:
	return is_playing

## Get playback progress (0.0 to 1.0)
func get_playback_progress() -> float:
	if recorded_inputs.is_empty():
		return 0.0
	
	if not is_playing:
		return 0.0
	
	var current_time = (Time.get_ticks_msec() / 1000.0 - playback_start_time) * playback_speed
	var total_duration = get_recording_duration()
	
	if total_duration <= 0:
		return 0.0
	
	return clamp(current_time / total_duration, 0.0, 1.0)

## Get current playback time
func get_playback_time() -> float:
	if not is_playing:
		return 0.0
	
	return (Time.get_ticks_msec() / 1000.0 - playback_start_time) * playback_speed


## Get expected position at current playback time using linear interpolation
func get_expected_position_at_time(time: float) -> Dictionary:
	if recorded_inputs.is_empty():
		return {}
	
	# Find the two events that bracket this timestamp
	var event_before = null
	var event_after = null
	
	for i in range(recorded_inputs.size()):
		var event = recorded_inputs[i]
		
		# Only consider events with position data
		if not event.has("player_position"):
			continue
		
		if event.timestamp <= time:
			event_before = event
		
		if event.timestamp >= time:
			event_after = event
			break
	
	# Handle edge cases
	if event_before == null and event_after != null:
		# Before first event - use first position
		return {
			"position": Vector2(event_after.player_position.x, event_after.player_position.y),
			"floor": event_after.get("floor", ""),
			"z_height": event_after.get("z_height", 0.0)
		}
	
	if event_after == null and event_before != null:
		# After last event - use last position
		return {
			"position": Vector2(event_before.player_position.x, event_before.player_position.y),
			"floor": event_before.get("floor", ""),
			"z_height": event_before.get("z_height", 0.0)
		}
	
	if event_before == null or event_after == null:
		return {}
	
	# If same event or no time between them
	if event_before == event_after or event_after.timestamp == event_before.timestamp:
		return {
			"position": Vector2(event_before.player_position.x, event_before.player_position.y),
			"floor": event_before.get("floor", ""),
			"z_height": event_before.get("z_height", 0.0)
		}
	
	# Linear interpolation between the two positions
	var t = (time - event_before.timestamp) / (event_after.timestamp - event_before.timestamp)
	t = clamp(t, 0.0, 1.0)
	
	var pos_before = Vector2(event_before.player_position.x, event_before.player_position.y)
	var pos_after = Vector2(event_after.player_position.x, event_after.player_position.y)
	var interpolated_pos = pos_before.lerp(pos_after, t)
	
	var z_before = event_before.get("z_height", 0.0)
	var z_after = event_after.get("z_height", 0.0)
	var interpolated_z = lerp(z_before, z_after, t)
	
	return {
		"position": interpolated_pos,
		"floor": event_before.get("floor", ""),  # Use floor from earlier event
		"z_height": interpolated_z
	}

## Check position accuracy during playback
func _check_playback_position_accuracy() -> void:
	if not player or not is_playing:
		return
	
	var current_time = get_playback_time()
	
	# Get actual and expected positions
	var actual_pos = player.global_position
	var expected = get_expected_position_at_time(current_time)
	
	if expected.is_empty():
		return
	
	var expected_pos = expected.position
	var deviation = actual_pos.distance_to(expected_pos)
	
	# Apply position correction if enabled and deviation is too large
	if position_correction_enabled and deviation > position_correction_threshold:
		player.global_position = expected_pos
		# Keep velocity intact to maintain momentum
		print("[Playback] Position corrected - was %.1fpx off" % deviation)
	
	# Track for statistics
	position_deviations.append(deviation)
	max_deviation = max(max_deviation, deviation)
	
	# Emit signal for visualization or debugging
	position_deviation.emit(actual_pos, expected_pos, deviation)

## Calculate deviation statistics
func _calculate_deviation_stats() -> void:
	if position_deviations.is_empty():
		average_deviation = 0.0
		return
	
	var total = 0.0
	for dev in position_deviations:
		total += dev
	
	average_deviation = total / position_deviations.size()

## Get playback accuracy statistics
func get_playback_accuracy() -> Dictionary:
	return {
		"average_deviation": average_deviation,
		"max_deviation": max_deviation,
		"sample_count": position_deviations.size(),
		"deviations": position_deviations.duplicate()
	}

# ============================================================================
# Input Recording Methods
# ============================================================================

## Reset input state tracking
func _reset_input_state() -> void:
	last_input_state = {
		"right": false,
		"left": false,
		"up": false,
		"down": false,
		"jump": false,
		"mouse_click": false,
		"mouse_pos": Vector2.ZERO,
		"floor": ""
	}

## Check for input changes and record them
func _check_and_record_inputs() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var timestamp = current_time - recording_start_time
	
	# Check keyboard inputs
	var right = Input.is_action_pressed("ui_right")
	var left = Input.is_action_pressed("ui_left")
	var up = Input.is_action_pressed("ui_up")
	var down = Input.is_action_pressed("ui_down")
	var jump = Input.is_action_just_pressed("jump")
	
	# Check mouse
	var mouse_click = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_pos = player.get_global_mouse_position() if player else Vector2.ZERO
	
	# Track floor changes
	var current_floor = player.get_parent() if player else null
	var current_floor_name = current_floor.name if current_floor else ""
	var last_floor_name = last_input_state.get("floor", "")
	
	# Record floor change as a special event
	if current_floor_name != last_floor_name and not last_floor_name.is_empty():
		var floor_event = {
			"timestamp": timestamp,
			"action": "floor_change",
			"pressed": true,
			"from_floor": last_floor_name,
			"to_floor": current_floor_name
		}
		
		if player:
			floor_event["player_position"] = {
				"x": player.global_position.x,
				"y": player.global_position.y
			}
			if "z_height" in player:
				floor_event["z_height"] = player.z_height
		
		recorded_inputs.append(floor_event)
		last_input_state["floor"] = current_floor_name
	
	# Update floor state on first frame
	if last_floor_name.is_empty():
		last_input_state["floor"] = current_floor_name
	
	# Record changes
	if right != last_input_state.right:
		_record_input_event(timestamp, "right", right)
		last_input_state.right = right
	
	if left != last_input_state.left:
		_record_input_event(timestamp, "left", left)
		last_input_state.left = left
	
	if up != last_input_state.up:
		_record_input_event(timestamp, "up", up)
		last_input_state.up = up
	
	if down != last_input_state.down:
		_record_input_event(timestamp, "down", down)
		last_input_state.down = down
	
	if jump:
		_record_input_event(timestamp, "jump", true)
	
	if mouse_click != last_input_state.mouse_click:
		_record_input_event(timestamp, "mouse_click", mouse_click, mouse_pos)
		last_input_state.mouse_click = mouse_click
		last_input_state.mouse_pos = mouse_pos

## Record a single input event
func _record_input_event(timestamp: float, action: String, pressed: bool, click_pos: Vector2 = Vector2.ZERO) -> void:
	var event = {
		"timestamp": timestamp,
		"action": action,
		"pressed": pressed
	}
	
	# Record player position and state at time of input
	if player:
		event["player_position"] = {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
		
		# Record z-height if available
		if "z_height" in player:
			event["z_height"] = player.z_height
		
		# Record current floor/level
		var current_floor = player.get_parent()
		if current_floor:
			event["floor"] = current_floor.name
			
			# Record tile position if available
			if player.has_method("get_current_tile"):
				var tile_pos = player.get_current_tile()
				event["tile_position"] = {
					"x": tile_pos.x,
					"y": tile_pos.y
				}
	
	# Record mouse click position
	if action == "mouse_click" and pressed:
		event["click_position"] = {"x": click_pos.x, "y": click_pos.y}
	
	recorded_inputs.append(event)
	input_recorded.emit(event)

## Record a position checkpoint (ground truth position at regular intervals)
func _record_position_checkpoint() -> void:
	if not player:
		return
	
	# Skip position checkpoints only while actively moving between waypoints
	# (not when just having a navigation target set)
	if "is_navigating" in player and player.is_navigating and "velocity" in player and player.velocity.length() > 1.0:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var timestamp = current_time - recording_start_time
	
	var checkpoint = {
		"timestamp": timestamp,
		"action": "position_checkpoint",
		"pressed": true,
		"player_position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
	}
	
	# Record z-height if available
	if "z_height" in player:
		checkpoint["z_height"] = player.z_height
	
	# Record current floor
	var current_floor = player.get_parent()
	if current_floor:
		checkpoint["floor"] = current_floor.name
		
		# Record tile position if available
		if player.has_method("get_current_tile"):
			var tile_pos = player.get_current_tile()
			checkpoint["tile_position"] = {
				"x": tile_pos.x,
				"y": tile_pos.y
			}
	
	# Record velocity for reference
	if "velocity" in player:
		checkpoint["velocity"] = {
			"x": player.velocity.x,
			"y": player.velocity.y
		}
	
	recorded_inputs.append(checkpoint)


## Get recorded inputs
func get_recorded_inputs() -> Array[Dictionary]:
	return recorded_inputs

## Get input recording as dictionary for serialization
func get_input_recording_as_dict() -> Dictionary:
	var player_name = "Unknown"
	if player:
		player_name = str(player.name)
	
	var duration = 0.0
	if not recorded_inputs.is_empty():
		duration = recorded_inputs[-1].timestamp
	
	return {
		"version": 1,
		"player_name": player_name,
		"duration": duration,
		"event_count": recorded_inputs.size(),
		"events": recorded_inputs
	}

## Load input recording from dictionary
func load_input_recording_from_dict(data: Dictionary) -> void:
	recorded_inputs.clear()
	
	var events = data.get("events", [])
	for event in events:
		recorded_inputs.append(event)
	
	print("PlayerRecorder: Loaded ", recorded_inputs.size(), " input events")

## Get statistics for input recording
func get_input_statistics() -> Dictionary:
	if recorded_inputs.is_empty():
		return {
			"event_count": 0,
			"duration": 0.0,
			"events_per_second": 0.0,
			"actions": {},
			"floors_visited": [],
			"floor_changes": 0,
			"position_checkpoints": 0,
			"navigation_targets": 0,
			"navigation_waypoints": 0
		}
	
	var duration = recorded_inputs[-1].timestamp
	var action_counts = {}
	var floors_visited = []
	var floor_changes = 0
	var checkpoint_count = 0
	var nav_target_count = 0
	var nav_waypoint_count = 0
	
	for event in recorded_inputs:
		var action = event.action
		
		# Track floor changes
		if action == "floor_change":
			floor_changes += 1
			var to_floor = event.get("to_floor", "")
			if not floors_visited.has(to_floor) and not to_floor.is_empty():
				floors_visited.append(to_floor)
		
		# Track position checkpoints
		if action == "position_checkpoint":
			checkpoint_count += 1
		
		# Track navigation
		if action == "navigation_target":
			nav_target_count += 1
		if action == "navigation_waypoint":
			nav_waypoint_count += 1
		
		if not action_counts.has(action):
			action_counts[action] = {"presses": 0, "releases": 0}
		
		if event.pressed:
			action_counts[action].presses += 1
		else:
			action_counts[action].releases += 1
	
	return {
		"event_count": recorded_inputs.size(),
		"duration": duration,
		"events_per_second": recorded_inputs.size() / duration if duration > 0 else 0.0,
		"actions": action_counts,
		"floors_visited": floors_visited,
		"floor_changes": floor_changes,
		"position_checkpoints": checkpoint_count,
		"navigation_targets": nav_target_count,
		"navigation_waypoints": nav_waypoint_count
	}
