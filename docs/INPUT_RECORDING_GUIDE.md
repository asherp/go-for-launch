# Input Recording Guide

## Overview

The player recording system records user inputs (key presses, mouse clicks) with timestamps, along with position checkpoints for position tracking. This creates efficient, small recording files perfect for speedruns and long sessions.

## Why Input Recording?

### Efficiency

For a **60-second recording**:

| Recording Type | Data Points | File Size | Use Case |
|----------------|-------------|-----------|----------|
| **Input Events** | 50-200 | 5-10 KB | Input sequences, speedruns |
| **Position Checkpoints** | ~60 | Additional ~2 KB | Position tracking |

**Input recording produces tiny files perfect for speedruns and long sessions!**

## Data Structure

Input recording captures events like:

```json
{
  "version": 1,
  "player_name": "bill",
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

### Automatic Recording

Recording starts automatically when the game launches. No configuration needed!

### Manual Control

```gdscript
# Start recording
player.start_recording()

# Stop and save
player.stop_recording()
player.save_recording_to_file()  # Saves to res://recordings/[character_name].json
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

### What Input Recording Provides
- ✅ Complete input sequence with timestamps
- ✅ Position checkpoints every second
- ✅ Navigation targets (mouse clicks)
- ✅ Floor and tile information
- ✅ Small file sizes (5-10 KB per minute)
- ✅ Perfect for speedruns and long sessions

## Advanced: Position Checkpoints

Position checkpoints are automatically recorded every second. You can adjust the interval:

```gdscript
# In player_recorder.gd, modify:
position_checkpoint_interval = 0.5  # Record position every 0.5 seconds
```

## File Size Examples

Real-world examples:

| Duration | Inputs | File Size |
|----------|--------|-----------|
| 30 sec | 71 | ~3 KB |
| 1 min | 142 | ~6 KB |
| 5 min | 710 | ~30 KB |
| 30 min | 4,260 | ~180 KB |

## Tips

1. **For speedruns**: Input recording provides exact timestamps
2. **For analysis**: Position checkpoints provide location data
3. **For long sessions**: Input recording keeps files small
4. **For debugging**: Check console output for detailed event logging

## File Locations

Recordings are saved to `res://recordings/` directory:
- Files are named using character names (e.g., `bill.json`, `billy_pilgrim.json`)
- Character names are automatically assigned from `assets/character_names.txt`
- The exact filename is printed when you save a recording

## Keyboard Shortcuts

- **R** - Start/Stop recording manually
- **P** - Print statistics
- **Ctrl+S** - Save recording (saves to `res://recordings/` with character name)
- **Ctrl+L** - Load recording (requires file path)

Recordings are automatically saved when auto-record duration is reached.

