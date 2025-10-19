extends RefCounted
class_name CharacterNames

## Utility class for managing character names
## Loads character names from a text file for consistency across all scripts

const CHARACTER_NAMES_FILE = "res://assets/character_names.txt"

static var _character_names: Array[String] = []
static var _loaded: bool = false

## Get the list of character names
static func get_character_names() -> Array[String]:
	if not _loaded:
		_load_character_names()
	return _character_names

## Load character names from the text file
static func _load_character_names() -> void:
	_character_names.clear()
	
	var file = FileAccess.open(CHARACTER_NAMES_FILE, FileAccess.READ)
	if not file:
		push_error("CharacterNames: Could not open character names file: %s" % CHARACTER_NAMES_FILE)
		# Fallback to hardcoded list
		_character_names = [
			"bill", "billy_pilgrim", "doc_brown", "donnie_darko", "evan_treborn",
			"henry_detamble", "hermione_granger", "jacob_epping", "james_cole", "kyle_reece",
			"marty_mcfly", "sarah_connor", "ted", "the_terminator", "the_time_traveller", "wolverine"
		]
		_loaded = true
		return
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.length() > 0:
			_character_names.append(line)
	
	file.close()
	_loaded = true
	print("CharacterNames: Loaded %d character names from file" % _character_names.size())

## Get the next available character name (first unused one)
static func get_next_character_name(used_names: Array[String] = []) -> String:
	var names = get_character_names()
	
	for character_name in names:
		if not used_names.has(character_name):
			return character_name
	
	# If all names are used, fall back to numbered system
	return "player_%d" % (used_names.size() + 1)

## Convert internal name to display name
static func to_display_name(internal_name: String) -> String:
	if internal_name == "unknown_character":
		return "Unknown Character"
	
	# Convert underscores to spaces and capitalize each word
	var words = internal_name.split("_")
	for i in range(words.size()):
		if words[i].length() > 0:
			words[i] = words[i][0].to_upper() + words[i].substr(1).to_lower()
	return " ".join(words)

## Get character name from filename
static func from_filename(filename: String) -> String:
	var base_name = filename.get_basename()
	
	# Check if it's a character name file (contains underscores but not player_)
	if "_" in base_name and not base_name.begins_with("player_"):
		# Use the filename directly as character name (already lowercase with underscores)
		return base_name
	
	# Fallback to old player_ format - use the filename as-is for backward compatibility
	if base_name.begins_with("player_"):
		return base_name
	
	# Default fallback
	return "unknown_character"
