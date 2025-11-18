# Player Recording System

A comprehensive system for recording and replaying player input events with timestamps, along with position checkpoints for accurate playback in your Godot game.

## Overview

The recording system consists of two main components:

1. **PlayerRecorder** (`scripts/player_recorder.gd`) - The core recording engine
2. **Player Integration** (`scripts/player_1.gd`) - Integration with the player controller

## Features

- ✅ Record player input events (key presses, mouse clicks) with timestamps
- ✅ Record position checkpoints every second for position tracking
- ✅ Track which floor/tile the player is on
- ✅ Save/load recordings as JSON files
- ✅ Get statistics (event counts, duration, action breakdown)
- ✅ Automatic recording on game start with configurable duration (default: 30 seconds)
- ✅ Manual recording control via keyboard shortcuts
- ✅ Character name-based file naming system

## Quick Start

### 1. Add PlayerRecorder to Your Player

In the Godot editor:
1. Open your player scene (e.g., `player.tscn`)
2. Add a child node of type `Node` and name it `PlayerRecorder`
3. Attach the script `scripts/player_recorder.gd` to this node
4. Save the scene

### 2. Configure Auto-Recording (Optional)

In `scripts/player_1.gd`, you can adjust these variables:

```gdscript
var auto_record_on_start := true   # Start recording when game starts
var auto_record_duration := 30.0   # Record for 30 seconds (0 = infinite)
```

### 3. Play Your Game

When you run the game:
- Recording will start automatically
- After 30 seconds (default), it will stop and save to `res://recordings/[character_name].json`
- The file location will be printed to the console
- Character names are automatically assigned from `assets/character_names.txt`

## Keyboard Controls

While playing:

- **R** - Start/Stop recording manually
- **P** - Print recording statistics
- **Ctrl+S** - Save current recording
- **Ctrl+L** - Load a recording (requires file path in code)

## Recorded Data

The system records input events and position checkpoints:

### Input Events
Each input change is recorded as an event:

```json
{
    "timestamp": 5.432,
    "action": "right",
    "pressed": true
}
```

### Position Checkpoints
Position is recorded every second (configurable):

```json
{
    "timestamp": 5.0,
    "action": "position_checkpoint",
    "player_position": {"x": 256, "y": 128},
    "floor": "GroundFloor",
    "tile_position": {"x": 4, "y": 2},
    "z_height": 0.0
}
```

### Navigation Events
Mouse clicks for navigation are also recorded:

```json
{
    "timestamp": 3.245,
    "action": "mouse_click",
    "pressed": true,
    "position": {"x": 320, "y": 240}
}
```

## Usage Examples

### Example 1: Basic Recording

```gdscript
# Get player reference
var player = get_node("Player")

# Start recording
player.start_recording()

# Do stuff...
await get_tree().create_timer(30.0).timeout

# Stop and save
player.stop_recording()
player.save_recording_to_file()  # Saves to res://recordings/ with character name
```

### Example 2: Get Statistics

```gdscript
# Print detailed statistics
player.print_recording_stats()

# Or get as dictionary
var stats = player.recorder.get_statistics()
print("Events recorded: ", stats.event_count)
print("Duration: ", stats.duration, " seconds")
print("Events per second: ", stats.events_per_second)
```

### Example 3: Get Expected Position at Time

```gdscript
# Get expected position at 10 seconds into the recording
var expected = player.recorder.get_expected_position_at_time(10.0)
if not expected.is_empty():
    print("Position at 10s: ", expected.position)
    print("Floor: ", expected.floor)
```

### Example 4: Load and Analyze

```gdscript
# Load a saved recording
player.load_recording_from_file("res://recordings/bill.json")

# Get all recorded inputs
var events = player.recorder.get_recorded_inputs()

# Analyze behavior
for event in events:
    if event.action == "jump" and event.pressed:
        print("Jump at time %.2f" % event.timestamp)
```

### Example 5: Export to CSV

See `scripts/recording_demo.gd` for a complete example of exporting recording data to CSV format for analysis in Excel, Python, or other tools.

## File Locations

Recordings are saved to `res://recordings/` directory:

- Files are named using character names from `assets/character_names.txt`
- Examples: `bill.json`, `billy_pilgrim.json`, `doc_brown.json`
- The exact filename is printed when you save a recording
- Character names are automatically assigned to new players

## Advanced Features

### Position Checkpoint Interval

Adjust how often position checkpoints are recorded:

```gdscript
# In player_recorder.gd, modify:
position_checkpoint_interval = 0.5  # Record position every 0.5 seconds
```

### Character Name System

The system uses character names from `assets/character_names.txt`:
- Automatically assigns names to new players
- Prevents duplicate names
- Uses lowercase with underscores (e.g., `billy_pilgrim`)

### Compare Recordings

```gdscript
# Load two recordings and compare them
var recorder1 = PlayerRecorder.new()
var recorder2 = PlayerRecorder.new()

recorder1.load_from_file("res://recordings/bill.json")
recorder2.load_from_file("res://recordings/billy_pilgrim.json")

var stats1 = recorder1.get_statistics()
var stats2 = recorder2.get_statistics()

if stats1.duration < stats2.duration:
    print("First recording was faster!")
```

## Use Cases

1. **Playtesting Analysis** - Understand how players navigate your level
2. **Speedrun Validation** - Verify legitimate speedruns
3. **AI Training Data** - Collect data for machine learning
4. **Bug Reproduction** - Record and replay bug scenarios
5. **Tutorial Creation** - Capture gameplay for tutorials
6. **A/B Testing** - Compare different player strategies
7. **Heatmaps** - Generate position heatmaps of player movement
8. **Replay System** - Foundation for implementing replays (not yet implemented)

## Performance Notes

- Recording input events adds minimal overhead (~0.01ms per event)
- One minute of gameplay = ~50-200 input events
- JSON file size: approximately 5-10 KB per minute of gameplay
- Position checkpoints add ~1 event per second
- Perfect for long recording sessions and speedruns

## Future Enhancements

Potential features to add:

- [x] Playback system (replay recordings) - ✅ Implemented
- [x] Visual replay with NPC/ghost players - ✅ Implemented
- [ ] Recording compression
- [ ] Binary format for smaller files
- [ ] Network synchronization for multiplayer
- [ ] In-game recording UI
- [ ] Recording manager for multiple players

## Troubleshooting

**"No PlayerRecorder node found!"**
- Make sure you added the PlayerRecorder node as a child of your player
- Check that the node is named exactly "PlayerRecorder"

**Recording file not found:**
- Check the console for the actual save path
- Use `ProjectSettings.globalize_path("user://")` to find the user directory

**Large file sizes:**
- Input-only recording already produces very small files (5-10 KB/min)
- Delete old recordings periodically if needed
- Consider implementing compression for very long sessions

## API Reference

See inline documentation in:
- `scripts/player_recorder.gd` - Core recording API
- `scripts/player_1.gd` - Player integration methods
- `scripts/recording_demo.gd` - Usage examples

## Credits

Created for the "Go For Launch" isometric game project.

