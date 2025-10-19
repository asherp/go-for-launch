# Input-Only Recording Guide

## Overview

The player recording system now supports two modes:
- **FULL Mode**: Records complete player state every frame (position, velocity, etc.)
- **INPUT_ONLY Mode**: Records only user inputs (key presses, mouse clicks)

## Why Use Input-Only Recording?

### Efficiency Comparison

For a **60-second recording**:

| Mode | Data Points | File Size | Use Case |
|------|-------------|-----------|----------|
| **FULL** @ 60 FPS | ~90,000 | 500-700 KB | Replay analysis, heatmaps |
| **INPUT_ONLY** | 50-200 | 2-10 KB | Input sequences, speedruns |

**INPUT_ONLY is 50-100x more efficient!**

## Data Structure

Input-only recording captures events like:

```json
{
  "version": 1,
  "mode": "INPUT_ONLY",
  "player_name": "Player",
  "duration": 60.0,
  "event_count": 142,
  "events": [
    {
      "timestamp": 0.523,
      "action": "right",
      "pressed": true
    },
    {
      "timestamp": 1.245,
      "action": "jump",
      "pressed": true
    },
    {
      "timestamp": 2.012,
      "action": "right",
      "pressed": false
    },
    {
      "timestamp": 5.834,
      "action": "mouse_click",
      "pressed": true,
      "position": {"x": 320, "y": 240}
    }
  ]
}
```

## Quick Start

### Enable Input-Only Recording

In `scripts/player_1.gd`, set:

```gdscript
var recording_mode := 1  # 1 = INPUT_ONLY, 0 = FULL
```

That's it! The game will now record only inputs.

### Manual Control

```gdscript
# Start input-only recording
player.start_recording(0.0, 1)  # Second parameter: 1 = INPUT_ONLY

# Stop and save
player.stop_recording()
player.save_recording_to_file()
```

## What Gets Recorded

### Keyboard Inputs
- Arrow keys (up, down, left, right)
- Jump (spacebar)
- Press AND release events

### Mouse Inputs
- Mouse clicks (button press/release)
- Click position (x, y coordinates)

### What's NOT Recorded
- Player position/velocity
- Game state
- Physics calculations

**Note**: To replay these inputs, you'd feed them back into the game at the recorded timestamps.

## Statistics

Get detailed statistics about recorded inputs:

```gdscript
player.print_recording_stats()
```

Output example:
```
=== Input Recording Statistics ===
Events: 142
Duration: 60.00 seconds
Events/Second: 2.37

Action Breakdown:
  right: 15 presses, 15 releases
  left: 12 presses, 12 releases
  up: 18 presses, 18 releases
  down: 14 presses, 14 releases
  jump: 23 presses, 0 releases
  mouse_click: 10 presses, 10 releases
===================================
```

## Use Cases

### 1. Speedrun Validation
```gdscript
# Record a speedrun attempt
var recording_mode := 1
var auto_record_duration := 300.0  # 5 minutes

# The file will be tiny (< 50 KB) even for 5 minutes
# Can be shared and verified easily
```

### 2. Input Replay System
```gdscript
# Load recorded inputs
player.load_recording_from_file("user://speedrun.json")

# Get all events
var events = player.recorder.get_recorded_inputs()

# Replay them (you'd implement this)
for event in events:
    await get_tree().create_timer(event.timestamp).timeout
    simulate_input(event.action, event.pressed)
```

### 3. Input Analysis
```gdscript
# Analyze player behavior
var events = player.recorder.get_recorded_inputs()

var jump_times = []
for event in events:
    if event.action == "jump" and event.pressed:
        jump_times.append(event.timestamp)

print("Player jumped at: ", jump_times)
print("Average time between jumps: ", calculate_average_interval(jump_times))
```

### 4. Bot Training
```gdscript
# Collect input sequences for training an AI
var training_data = []

for i in range(100):  # 100 gameplay sessions
    player.start_recording(0.0, 1)
    await player_completes_level()
    player.stop_recording()
    
    var inputs = player.recorder.get_recorded_inputs()
    training_data.append(inputs)

save_training_data(training_data)
```

## Comparison

### When to Use FULL Mode
- ✅ Need position/velocity data
- ✅ Creating heatmaps
- ✅ Analyzing movement patterns
- ✅ Visual replay with ghost player
- ❌ Large file sizes

### When to Use INPUT_ONLY Mode
- ✅ Recording input sequences
- ✅ Speedrun validation
- ✅ Long recording sessions
- ✅ Minimal file size
- ✅ Sharing recordings
- ❌ No position data

## Advanced: Hybrid Approach

You can record both for ultimate flexibility:

```gdscript
# Record full state at intervals + all inputs
player.start_recording(1.0, 0)  # Full state once per second
# Manually also track inputs in a separate recorder
```

## File Size Examples

Real-world examples:

| Duration | Inputs | File Size (INPUT_ONLY) | File Size (FULL @ 60 FPS) |
|----------|--------|------------------------|---------------------------|
| 30 sec | 71 | 3 KB | 350 KB |
| 1 min | 142 | 6 KB | 700 KB |
| 5 min | 710 | 30 KB | 3.5 MB |
| 30 min | 4,260 | 180 KB | 21 MB |

## Tips

1. **For speedruns**: Use INPUT_ONLY with exact timestamps
2. **For analysis**: Use FULL mode with 0.1s intervals
3. **For long sessions**: Use INPUT_ONLY to stay under 1 MB
4. **For debugging**: Use FULL mode at 0.5s intervals

## Converting Between Modes

You can't convert INPUT_ONLY → FULL (no position data), but you can extract inputs from FULL recordings:

```gdscript
# Load full recording
player.load_recording_from_file("user://full_recording.json")
var frames = player.recorder.get_recording()

# Extract inputs
var inputs = []
for frame in frames:
    if frame.input_jump:
        inputs.append({"timestamp": frame.timestamp, "action": "jump", "pressed": true})
    # ... extract other inputs
```

## Keyboard Shortcuts

Same as before:
- **R** - Start/Stop recording (uses mode set in `recording_mode` variable)
- **P** - Print statistics (automatically detects mode)
- **Ctrl+S** - Save recording
- **Ctrl+L** - Load recording

The system automatically detects the mode when loading files!

