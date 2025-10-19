extends Control

## Main Menu - Allows player to choose starting position
## Either create a new player or spawn at an existing NPC's position

const CharacterNames = preload("res://scripts/character_names.gd")

@onready var npc_list: VBoxContainer = $VBoxContainer/NPCList
@onready var new_player_button: Button = $VBoxContainer/NewPlayerButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton

var recordings_directory: String = "res://recordings"
var selected_npc_data: Dictionary = {}

# Character names are now loaded from assets/character_names.txt via CharacterNames utility class

func _ready() -> void:
	# Connect button signals
	new_player_button.pressed.connect(_on_new_player_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	
	# Load available recordings and create NPC selection buttons
	_load_available_recordings()

func _load_available_recordings() -> void:
	"""Load all available recordings and create selection buttons"""
	var recordings = _get_all_recording_files()
	
	if recordings.is_empty():
		# No recordings available
		var no_recordings_label = Label.new()
		no_recordings_label.text = "No recordings found"
		no_recordings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		npc_list.add_child(no_recordings_label)
		return
	
	# Create buttons for each recording
	for i in range(recordings.size()):
		var recording_path = recordings[i]
		var recording_name = recording_path.get_file().get_basename()
		var player_number = _get_player_number_from_filename(recording_name)
		
		# Load recording data to get character info
		var character_info = _load_character_info(recording_path)
		
		# Create button for this character
		var character_button = Button.new()
		character_button.text = "Play as %s" % character_info.display_name
		character_button.custom_minimum_size = Vector2(400, 60)
		character_button.add_theme_font_size_override("font_size", 18)
		
		# Add character details as tooltip
		character_button.tooltip_text = "Duration: %.1fs | Events: %d | Position: (%.0f, %.0f)" % [
			character_info.duration,
			character_info.event_count,
			character_info.start_position.x,
			character_info.start_position.y
		]
		
		# Store recording data in the button
		character_button.set_meta("recording_path", recording_path)
		character_button.set_meta("player_number", player_number)
		character_button.set_meta("recording_name", recording_name)
		character_button.set_meta("character_info", character_info)
		
		# Connect button signal
		character_button.pressed.connect(_on_character_selected.bind(character_button))
		
		npc_list.add_child(character_button)

func _get_all_recording_files() -> Array[String]:
	"""Get all recording files sorted by player number"""
	var recordings: Array[String] = []
	var dir = DirAccess.open(recordings_directory)
	
	if not dir:
		push_error("[MainMenu] Cannot open recordings directory: %s" % recordings_directory)
		return recordings
	
	var file_data: Array[Dictionary] = []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = recordings_directory + "/" + file_name
			var character_name = _get_character_name_from_filename(file_name)
			file_data.append({
				"path": full_path,
				"name": file_name,
				"character_name": character_name
			})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by character name
	file_data.sort_custom(func(a, b): return a.character_name < b.character_name)
	
	# Extract just the paths
	for data in file_data:
		recordings.append(data.path)
	
	return recordings

func _get_player_number_from_filename(filename: String) -> int:
	"""Extract player number from filename like 'player_1.json'"""
	var base_name = filename.get_basename()
	if base_name.begins_with("player_"):
		var number_part = base_name.substr(7)  # Remove "player_" prefix
		if number_part.is_valid_int():
			return number_part.to_int()
	return 0

func _get_character_name_from_filename(filename: String) -> String:
	"""Extract character name from filename like 'marty_mcfly.json' or 'player_1.json'"""
	return CharacterNames.from_filename(filename)

func _convert_to_display_name(internal_name: String) -> String:
	"""Convert internal name (lowercase_underscore) to display name (Proper Case)"""
	return CharacterNames.to_display_name(internal_name)

func _load_character_info(recording_path: String) -> Dictionary:
	"""Load character information from a recording file"""
	var character_info = {
		"display_name": "Unknown Character",
		"duration": 0.0,
		"event_count": 0,
		"start_position": Vector2.ZERO,
		"player_name": "Unknown"
	}
	
	var file = FileAccess.open(recording_path, FileAccess.READ)
	if not file:
		push_warning("[MainMenu] Could not open recording file: %s" % recording_path)
		return character_info
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_warning("[MainMenu] Could not parse recording file: %s" % recording_path)
		return character_info
	
	var data = json.data
	if data is Dictionary:
		# Extract character information
		character_info.player_name = data.get("player_name", "Unknown")
		character_info.duration = data.get("duration", 0.0)
		character_info.event_count = data.get("event_count", 0)
		
		# Get start position from first event
		var events = data.get("events", [])
		if events.size() > 0:
			var first_event = events[0]
			if first_event.has("player_position"):
				var pos = first_event["player_position"]
				character_info.start_position = Vector2(pos.get("x", 0), pos.get("y", 0))
		
		# Create display name - convert internal name to display name
		var internal_name = character_info.player_name
		if internal_name == "Unknown" or internal_name.begins_with("player_"):
			# Fallback to character name from filename
			internal_name = _get_character_name_from_filename(recording_path.get_file())
		
		# Convert internal name (lowercase_underscore) to display name (Proper Case)
		character_info.display_name = _convert_to_display_name(internal_name)
	
	return character_info

func _on_new_player_pressed() -> void:
	"""Create a new player and start the game"""
	print("[MainMenu] Creating new player...")
	_start_game_with_new_player()

func _on_character_selected(button: Button) -> void:
	"""Spawn player as selected character"""
	var recording_path = button.get_meta("recording_path")
	var player_number = button.get_meta("player_number")
	var recording_name = button.get_meta("recording_name")
	var character_info = button.get_meta("character_info")
	
	print("[MainMenu] Selected character: %s (player_%d)" % [character_info.display_name, player_number])
	
	# Store selection data
	selected_npc_data = {
		"recording_path": recording_path,
		"player_number": player_number,
		"recording_name": recording_name,
		"character_info": character_info
	}
	
	_start_game_with_character_spawn()

func _on_load_game_pressed() -> void:
	"""Load the game with all NPCs (original behavior)"""
	print("[MainMenu] Loading game with all NPCs...")
	_start_game_with_all_npcs()

func _start_game_with_new_player() -> void:
	"""Start the game with a new player"""
	# Change to the main game scene
	get_tree().change_scene_to_file("res://scenes/launch_blocks.tscn")

func _start_game_with_character_spawn() -> void:
	"""Start the game and spawn player as selected character"""
	# Store the selection data globally so the main scene can access it
	var global_data = get_node("/root/GlobalData")
	if not global_data:
		# Create a global data node if it doesn't exist
		global_data = Node.new()
		global_data.name = "GlobalData"
		get_tree().root.add_child(global_data)
	
	# Store the character selection data
	global_data.set_meta("spawn_as_character", selected_npc_data)
	
	# Change to the main game scene
	get_tree().change_scene_to_file("res://scenes/launch_blocks.tscn")

func _start_game_with_all_npcs() -> void:
	"""Start the game with all NPCs (original behavior)"""
	# Clear any character selection data
	var global_data = get_node("/root/GlobalData")
	if global_data:
		global_data.remove_meta("spawn_as_character")
	
	# Change to the main game scene
	get_tree().change_scene_to_file("res://scenes/launch_blocks.tscn")
