# Multi-Ghost System

The Multi-Ghost System automatically spawns multiple ghost players, each replaying a different recording from your `res://recordings/` directory.

## How It Works

1. **Automatic Discovery**: The system scans the `res://recordings/` directory for all `player_recording_*.json` files
2. **Smart Floor Detection**: Each recording is analyzed to determine which floor it originally started on
3. **Ghost Creation**: For each recording found, a new ghost player is created on the appropriate floor
4. **Individual Playback**: Each ghost loads and replays its assigned recording
5. **Simultaneous Start**: All ghosts start playback at the same time for synchronized replay

## Features

- **Automatic Spawning**: No manual setup required - just run the scene
- **Color Coding**: Each ghost gets a unique color (blue, green, red, yellow, etc.)
- **Spacing**: Ghosts are positioned with horizontal spacing to avoid overlap
- **Smart Floor Detection**: Ghosts spawn on the same floor where their recording originally started
- **Error Handling**: Gracefully handles missing recordings or failed loads
- **Debug Info**: Console output shows which recordings are loaded and which ghosts are spawned

## Scene Changes

The `launch_blocks.tscn` scene now includes:
- **GhostManager Node**: Replaces the single hardcoded ghost player
- **Dynamic Ghost Creation**: Ghosts are created at runtime based on available recordings

## Controls

- **G Key**: Refresh the ghost list (useful for testing)
- **H Key**: Print ghost information to console

## Configuration

You can modify the ghost manager behavior by editing `scripts/ghost_manager.gd`:

```gdscript
@export var ghost_spacing: float = 32.0  # Horizontal spacing between ghosts
@export var ghost_colors: Array[Color] = [...]  # Customize ghost colors
@export var recordings_directory: String = "res://recordings"  # Change directory
```

## Example Output

When you run the scene, you'll see console output like:
```
[GhostManager] Found 3 recordings, spawning ghosts...
[GhostManager] Spawned ghost 1 for recording: player_recording_20250113_143022.json
[GhostManager] Spawned ghost 2 for recording: player_recording_20250113_142156.json
[GhostManager] Spawned ghost 3 for recording: player_recording_20250113_141834.json
[GhostManager] Ghost 1 loaded recording: player_recording_20250113_143022.json
[GhostManager] Ghost 1 started playback
[GhostManager] Ghost 2 loaded recording: player_recording_20250113_142156.json
[GhostManager] Ghost 2 started playback
[GhostManager] Ghost 3 loaded recording: player_recording_20250113_141834.json
[GhostManager] Ghost 3 started playback
```

## Use Cases

1. **Speedrun Comparison**: See multiple attempts side by side
2. **Strategy Analysis**: Compare different approaches to the same level
3. **Multiplayer Preview**: Test how the level feels with multiple players
4. **Tutorial Demonstration**: Show optimal vs suboptimal runs
5. **Ghost Racing**: Race against your previous attempts

## Technical Details

- Each ghost uses the same `player_1.gd` script with `is_ghost = true`
- Ghosts are positioned on the FirstFloor with horizontal spacing
- Recordings are sorted by modification time (newest first)
- Position correction is disabled for multiple ghosts to prevent conflicts
- Each ghost gets a unique color from the predefined palette
