extends Node
## Example script demonstrating how to use the PlayerRecorder system
## Attach this to any node in your scene to control recording

# Get reference to the player
@onready var player = get_node_or_null("/root/YourSceneName/Player")

func _ready() -> void:
	print("\n=== Recording Demo Script ===")
	print("This script demonstrates the PlayerRecorder system")
	print("================================\n")
	
	if not player:
		push_warning("Player node not found! Update the path in recording_demo.gd")
		return
	
	# Example 1: Manual recording control
	# Uncomment to use manual recording instead of auto-recording
	# manual_recording_example()
	
	# Example 2: Query recording info
	# This will work after the auto-recording finishes
	call_deferred("delayed_query_example")

## Example 1: Manual recording control
func manual_recording_example() -> void:
	print("\n--- Manual Recording Example ---")
	
	# Disable auto-recording
	player.auto_record_on_start = false
	
	# Start recording with interval (0 = every frame, 0.1 = 10 times per second)
	player.start_recording(0.1)
	
	# After some time, stop and save
	await get_tree().create_timer(30.0).timeout
	player.stop_recording()
	player.save_recording_to_file("user://my_custom_recording.json")

## Example 2: Query recording information
func delayed_query_example() -> void:
	await get_tree().create_timer(5.0).timeout
	
	if not player or not player.recorder:
		return
	
	print("\n--- Recording Query Example ---")
	
	# Get current recording duration
	var duration = player.recorder.get_recording_duration()
	print("Current recording duration: %.2f seconds" % duration)
	
	# Get frame count
	var frames = player.recorder.get_recording()
	print("Total frames recorded: ", frames.size())
	
	# Get a specific frame at time
	if duration > 10.0:
		var frame_at_10s = player.recorder.get_frame_at_time(10.0)
		if frame_at_10s:
			print("Position at 10 seconds: ", frame_at_10s.global_position)
			print("Was jumping: ", frame_at_10s.is_jumping)
			print("On floor: ", frame_at_10s.floor_name)

## Example 3: Load and analyze a saved recording
func load_and_analyze_example() -> void:
	if not player:
		return
	
	print("\n--- Load Recording Example ---")
	
	# Load a previously saved recording
	var file_path = "user://player_recording_20250101_120000.json"
	if player.load_recording_from_file(file_path):
		# Print statistics
		player.print_recording_stats()
		
		# Analyze the recording
		var stats = player.recorder.get_statistics()
		print("\nAnalysis:")
		print("- Player moved %.2f pixels total" % stats.total_distance)
		print("- Average speed: %.2f px/s" % stats.avg_speed)
		print("- Jumped %d times" % stats.jump_count)
		
		# Get all frames and analyze specific behaviors
		var frames = player.recorder.get_recording()
		var time_on_ground_floor = 0.0
		var time_jumping = 0.0
		
		for i in range(frames.size()):
			var frame = frames[i]
			if frame.floor_name == "GroundFloor":
				if i > 0:
					time_on_ground_floor += frame.timestamp - frames[i-1].timestamp
			if frame.is_jumping:
				if i > 0:
					time_jumping += frame.timestamp - frames[i-1].timestamp
		
		print("- Time on ground floor: %.2f seconds" % time_on_ground_floor)
		print("- Time jumping: %.2f seconds" % time_jumping)

## Example 4: Compare two recordings
func compare_recordings_example() -> void:
	print("\n--- Compare Recordings Example ---")
	
	# This would compare two different playthroughs
	# Useful for analyzing player improvement, A/B testing, etc.
	
	var recording1_path = "user://player_recording_attempt1.json"
	var recording2_path = "user://player_recording_attempt2.json"
	
	# Load first recording
	var recorder1 = preload("res://scripts/player_recorder.gd").new()
	if recorder1.load_from_file(recording1_path):
		var stats1 = recorder1.get_statistics()
		
		# Load second recording
		var recorder2 = preload("res://scripts/player_recorder.gd").new()
		if recorder2.load_from_file(recording2_path):
			var stats2 = recorder2.get_statistics()
			
			# Compare
			print("Attempt 1 vs Attempt 2:")
			print("Duration: %.2fs vs %.2fs" % [stats1.duration, stats2.duration])
			print("Distance: %.2f vs %.2f" % [stats1.total_distance, stats2.total_distance])
			print("Jumps: %d vs %d" % [stats1.jump_count, stats2.jump_count])
			
			if stats1.duration < stats2.duration:
				print("✓ Attempt 1 was faster!")
			elif stats2.duration < stats1.duration:
				print("✓ Attempt 2 was faster!")

## Example 5: Export recording data for analysis
func export_to_csv_example() -> void:
	if not player or not player.recorder:
		return
	
	print("\n--- Export to CSV Example ---")
	
	var frames = player.recorder.get_recording()
	if frames.is_empty():
		print("No recording data available")
		return
	
	# Create CSV file
	var csv_path = "user://recording_data.csv"
	var file = FileAccess.open(csv_path, FileAccess.WRITE)
	
	if file:
		# Write header
		file.store_line("timestamp,pos_x,pos_y,vel_x,vel_y,z_height,is_jumping,floor_name,tile_x,tile_y")
		
		# Write each frame
		for frame in frames:
			var line = "%f,%f,%f,%f,%f,%f,%s,%s,%d,%d" % [
				frame.timestamp,
				frame.global_position.x,
				frame.global_position.y,
				frame.velocity.x,
				frame.velocity.y,
				frame.z_height,
				"1" if frame.is_jumping else "0",
				frame.floor_name,
				frame.tile_position.x,
				frame.tile_position.y
			]
			file.store_line(line)
		
		file.close()
		print("Exported recording to: ", ProjectSettings.globalize_path(csv_path))
	else:
		push_error("Failed to create CSV file")

## Keyboard shortcuts for this demo
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				# Print help
				print_help()
			KEY_F2:
				# Export to CSV
				export_to_csv_example()
			KEY_F3:
				# Load and analyze latest recording
				load_and_analyze_example()

func print_help() -> void:
	print("\n=== Recording System Help ===")
	print("Keyboard Controls:")
	print("  R - Start/Stop recording")
	print("  P - Print recording statistics")
	print("  Ctrl+S - Save recording to file")
	print("  Ctrl+L - Load recording from file")
	print("")
	print("Demo Script Controls:")
	print("  F1 - Show this help")
	print("  F2 - Export recording to CSV")
	print("  F3 - Load and analyze recording")
	print("============================\n")

