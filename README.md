# Go For Launch

An isometric game with multi-floor navigation and player recording capabilities.

## Features

- Isometric tile-based movement with 4-directional diagonal movement
- Multi-floor navigation with jumping mechanics
- Mouse-click pathfinding
- **Player Recording System** - Record and analyze player actions over time

## Player Recording System

The game includes a comprehensive recording system that records player input events:

- **Input Recording**: Records only user inputs (key presses, mouse clicks) with timestamps
- **Position Checkpoints**: Records player position every second for position tracking
- **Efficient Storage**: Small file sizes (typically 5-10 KB per minute) perfect for speedruns and long sessions

### Quick Start

1. The game automatically starts recording when you launch it
2. Recording runs for 30 seconds by default (configurable)
3. When finished, the recording is automatically saved to `res://recordings/` directory
4. Files are named using character names (e.g., `bill.json`, `billy_pilgrim.json`)
5. The save location is printed to the console

**Input-only recording** produces tiny files perfect for speedruns and long sessions!

### Keyboard Controls

- **R** - Start/Stop recording manually
- **P** - Print recording statistics
- **Ctrl+S** - Save current recording
- **Ctrl+L** - Load a recording

### Documentation

- `INPUT_RECORDING_GUIDE.md` - **Start here!** Input-only recording guide
- `RECORDING_SYSTEM.md` - Complete API documentation
- `SETUP_RECORDING.md` - Step-by-step setup instructions
- `scripts/recording_demo.gd` - Code examples

## Notes

In order to make this as scalable as possible, I'm using the following optimizations

### Navigation processing

Since we will be replaying player input, navigation needs to be as efficient as possible. Therefore, avoidance processing should be turned off when there are many agents, which returns a safe velocity.