extends Node
## Helper script to analyze player recordings
## Can extract position data, create heatmaps, analyze paths, etc.

## Analyze a recording file and print detailed information
static func analyze_recording(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("Recording file not found: ", file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: ", file_path)
		return {}
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("Failed to parse JSON: ", json.get_error_message())
		return {}
	
	var data = json.data
	var events = data.get("events", [])
	
	# Analyze the recording
	var analysis = {
		"duration": data.get("duration", 0.0),
		"event_count": events.size(),
		"player_name": data.get("player_name", "Unknown"),
		"positions": [],
		"floors_visited": {},
		"floor_transitions": [],
		"path_length": 0.0,
		"time_per_floor": {},
		"actions_per_floor": {}
	}
	
	var last_position = null
	var current_floor = ""
	var floor_start_time = 0.0
	
	for event in events:
		# Track positions
		if event.has("player_position"):
			var pos = event.player_position
			var position_data = {
				"timestamp": event.timestamp,
				"x": pos.x,
				"y": pos.y,
				"z": event.get("z_height", 0.0),
				"floor": event.get("floor", ""),
				"action": event.action
			}
			analysis.positions.append(position_data)
			
			# Calculate path length
			if last_position != null:
				var dx = pos.x - last_position.x
				var dy = pos.y - last_position.y
				analysis.path_length += sqrt(dx * dx + dy * dy)
			
			last_position = pos
		
		# Track floor visits
		var floor = event.get("floor", "")
		if not floor.is_empty():
			if not analysis.floors_visited.has(floor):
				analysis.floors_visited[floor] = 0
			analysis.floors_visited[floor] += 1
			
			# Track time per floor
			if floor != current_floor:
				if not current_floor.is_empty():
					var time_on_floor = event.timestamp - floor_start_time
					if not analysis.time_per_floor.has(current_floor):
						analysis.time_per_floor[current_floor] = 0.0
					analysis.time_per_floor[current_floor] += time_on_floor
				
				current_floor = floor
				floor_start_time = event.timestamp
		
		# Track floor changes
		if event.action == "floor_change":
			analysis.floor_transitions.append({
				"timestamp": event.timestamp,
				"from": event.get("from_floor", ""),
				"to": event.get("to_floor", "")
			})
		
		# Track actions per floor
		if not floor.is_empty():
			if not analysis.actions_per_floor.has(floor):
				analysis.actions_per_floor[floor] = {}
			
			var action = event.action
			if not analysis.actions_per_floor[floor].has(action):
				analysis.actions_per_floor[floor][action] = 0
			analysis.actions_per_floor[floor][action] += 1
	
	return analysis

## Print detailed analysis of a recording
static func print_analysis(file_path: String) -> void:
	var analysis = analyze_recording(file_path)
	
	if analysis.is_empty():
		return
	
	print("\n╔════════════════════════════════════════╗")
	print("║     RECORDING ANALYSIS REPORT          ║")
	print("╚════════════════════════════════════════╝")
	print("\nPlayer: ", analysis.player_name)
	print("Duration: %.2f seconds" % analysis.duration)
	print("Total Events: ", analysis.event_count)
	print("Positions Recorded: ", analysis.positions.size())
	print("Path Length: %.2f pixels" % analysis.path_length)
	
	print("\n--- Floor Visits ---")
	for floor in analysis.floors_visited:
		print("  %s: %d events" % [floor, analysis.floors_visited[floor]])
	
	if not analysis.floor_transitions.is_empty():
		print("\n--- Floor Transitions ---")
		for transition in analysis.floor_transitions:
			print("  %.2fs: %s → %s" % [
				transition.timestamp,
				transition.from,
				transition.to
			])
	
	print("\n--- Time Per Floor ---")
	for floor in analysis.time_per_floor:
		print("  %s: %.2f seconds" % [floor, analysis.time_per_floor[floor]])
	
	print("\n--- Actions Per Floor ---")
	for floor in analysis.actions_per_floor:
		print("\n  %s:" % floor)
		for action in analysis.actions_per_floor[floor]:
			print("    %s: %d" % [action, analysis.actions_per_floor[floor][action]])
	
	print("\n════════════════════════════════════════\n")

## Export recording positions to CSV
static func export_to_csv(file_path: String, output_path: String = "") -> bool:
	var analysis = analyze_recording(file_path)
	
	if analysis.is_empty():
		return false
	
	if output_path.is_empty():
		output_path = file_path.replace(".json", "_analysis.csv")
	
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create CSV file: ", output_path)
		return false
	
	# Write header
	file.store_line("timestamp,x,y,z,floor,action")
	
	# Write data
	for pos in analysis.positions:
		file.store_line("%f,%f,%f,%f,%s,%s" % [
			pos.timestamp,
			pos.x,
			pos.y,
			pos.z,
			pos.floor,
			pos.action
		])
	
	file.close()
	print("Exported position data to: ", ProjectSettings.globalize_path(output_path))
	return true

## Get all positions where a specific action occurred
static func get_positions_for_action(file_path: String, action_name: String) -> Array:
	var analysis = analyze_recording(file_path)
	var positions = []
	
	for pos in analysis.positions:
		if pos.action == action_name:
			positions.append(pos)
	
	return positions

## Create a simple heatmap data structure (grid-based)
static func create_heatmap(file_path: String, grid_size: float = 32.0) -> Dictionary:
	var analysis = analyze_recording(file_path)
	var heatmap = {}
	
	for pos in analysis.positions:
		var grid_x = int(pos.x / grid_size)
		var grid_y = int(pos.y / grid_size)
		var key = "%d,%d" % [grid_x, grid_y]
		
		if not heatmap.has(key):
			heatmap[key] = 0
		heatmap[key] += 1
	
	return heatmap

