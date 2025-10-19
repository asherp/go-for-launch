# Go For Launch

An isometric game with multi-floor navigation and player recording capabilities.

## Features

- Isometric tile-based movement with 4-directional diagonal movement
- Multi-floor navigation with jumping mechanics
- Mouse-click pathfinding
- **Player Recording System** - Record and analyze player actions over time

## Player Recording System

The game includes a comprehensive recording system with two modes:

- **FULL Mode**: Records complete player state every frame (~90,000 data points/min)
- **INPUT_ONLY Mode**: Records only inputs (~50-200 events/min) - **50-100x more efficient!**

### Quick Start

1. Choose your recording mode in `scripts/player_1.gd`:
   ```gdscript
   var recording_mode := 1  # 0 = FULL, 1 = INPUT_ONLY (recommended)
   ```

2. The game automatically starts recording when you launch it
3. Recording runs for 60 seconds by default
4. When finished, the recording is automatically saved to a JSON file
5. The save location is printed to the console

**INPUT_ONLY mode** produces tiny files (5-10 KB) perfect for speedruns and long sessions!

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