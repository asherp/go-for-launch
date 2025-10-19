# Player Recording System

A comprehensive system for recording and analyzing player positions and actions over time in your Godot game.

## Overview

The recording system consists of two main components:

1. **PlayerRecorder** (`scripts/player_recorder.gd`) - The core recording engine
2. **Player Integration** (`scripts/player_1.gd`) - Integration with the player controller

## Features

- ✅ Record player position, velocity, and state every frame
- ✅ Track jump states and z-height (isometric)
- ✅ Record input states (keyboard and mouse)
- ✅ Track which floor/tile the player is on
- ✅ Save/load recordings as JSON files
- ✅ Get statistics (distance, speed, jumps, etc.)
- ✅ Query specific timepoints with interpolation
- ✅ Automatic recording on game start with configurable duration
- ✅ Manual recording control via keyboard shortcuts

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
var auto_record_duration := 60.0   # Record for 60 seconds (0 = infinite)
```

### 3. Play Your Game

When you run the game:
- Recording will start automatically
- After 60 seconds, it will stop and save to `user://player_recording_YYYYMMDD_HHMMSS.json`
- The file location will be printed to the console

## Keyboard Controls

While playing:

- **R** - Start/Stop recording manually
- **P** - Print recording statistics
- **Ctrl+S** - Save current recording
- **Ctrl+L** - Load a recording (requires file path in code)

## Recorded Data

Each frame captures:

```gdscript
{
    "timestamp": 5.432,              # Time in seconds
    "position": {"x": 256, "y": 128},
    "velocity": {"x": 40.5, "y": 0.0},
    "z_height": 0.0,
    "direction": {"x": 0.89, "y": 0.45},
    "is_jumping": false,
    "jump_time": 0.0,
    "floor_name": "GroundFloor",
    "tile_position": {"x": 4, "y": 2},
    "inputs": {
        "right": false,
        "left": false,
        "up": true,
        "down": false,
        "jump": false,
        "mouse_click": false,
        "mouse_pos": {"x": 320, "y": 240}
    }
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
player.save_recording_to_file("user://my_recording.json")
```

### Example 2: Get Statistics

```gdscript
# Print detailed statistics
player.print_recording_stats()

# Or get as dictionary
var stats = player.recorder.get_statistics()
print("Player traveled: ", stats.total_distance, " pixels")
print("Average speed: ", stats.avg_speed, " px/s")
print("Jumps: ", stats.jump_count)
```

### Example 3: Query Specific Time

```gdscript
# Get player state at 10 seconds into the recording
var frame = player.recorder.get_frame_at_time(10.0)
if frame:
    print("Position at 10s: ", frame.global_position)
    print("Was jumping: ", frame.is_jumping)
    print("Floor: ", frame.floor_name)
```

### Example 4: Load and Analyze

```gdscript
# Load a saved recording
player.load_recording_from_file("user://player_recording_20250114_153000.json")

# Get all frames
var frames = player.recorder.get_recording()

# Analyze behavior
for frame in frames:
    if frame.is_jumping:
        print("Jump at time %.2f on floor %s" % [frame.timestamp, frame.floor_name])
```

### Example 5: Export to CSV

See `scripts/recording_demo.gd` for a complete example of exporting recording data to CSV format for analysis in Excel, Python, or other tools.

## File Locations

Recordings are saved to Godot's user directory:

- **Windows**: `%APPDATA%\Godot\app_userdata\[project_name]/`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/[project_name]/`
- **Linux**: `~/.local/share/godot/app_userdata/[project_name]/`

The exact path is printed when you save a recording.

## Advanced Features

### Variable Recording Rate

Record at a lower framerate to save memory:

```gdscript
# Record 10 times per second instead of every frame
player.start_recording(0.1)
```

### Frame Interpolation

Get smooth data between recorded frames:

```gdscript
var frame = player.recorder.get_frame_at_time(5.5)
# Returns interpolated data between frames at 5.4s and 5.6s
```

### Compare Recordings

```gdscript
# Load two recordings and compare them
var recorder1 = PlayerRecorder.new()
var recorder2 = PlayerRecorder.new()

recorder1.load_from_file("user://attempt1.json")
recorder2.load_from_file("user://attempt2.json")

var stats1 = recorder1.get_statistics()
var stats2 = recorder2.get_statistics()

if stats1.duration < stats2.duration:
    print("First attempt was faster!")
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

- Recording every frame adds minimal overhead (~0.1ms per frame)
- One minute at 60 FPS = ~3,600 frames
- JSON file size: approximately 500-700 KB per minute of gameplay
- Consider using recording intervals for longer sessions

## Future Enhancements

Potential features to add:

- [ ] Playback system (replay recordings)
- [ ] Visual replay with ghost player
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
- Use recording intervals: `start_recording(0.1)` for 10 FPS
- Delete old recordings periodically
- Consider implementing compression

## API Reference

See inline documentation in:
- `scripts/player_recorder.gd` - Core recording API
- `scripts/player_1.gd` - Player integration methods
- `scripts/recording_demo.gd` - Usage examples

## Credits

Created for the "Go For Launch" isometric game project.

