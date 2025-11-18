# Multi-Ghost System

The Multi-Ghost System automatically spawns multiple ghost players, each replaying a different recording from your `res://recordings/` directory.

## How It Works

1. **Automatic Discovery**: The system scans the `res://recordings/` directory for all `*.json` recording files (named by character names like `bill.json`, `billy_pilgrim.json`, etc.)
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
- **NPCManager Node**: Manages spawning of multiple NPC players
- **Dynamic NPC Creation**: NPCs are created at runtime based on available recordings

## Controls

- **G Key**: Refresh the ghost list (useful for testing)
- **H Key**: Print ghost information to console

## Configuration

You can modify the NPC manager behavior by editing `scripts/npc_manager.gd`:

```gdscript
@export var npc_spacing: float = 32.0  # Horizontal spacing between NPCs
@export var npc_colors: Array[Color] = [...]  # Customize NPC colors
@export var recordings_directory: String = "res://recordings"  # Change directory
```

## Example Output

When you run the scene, you'll see console output like:
```
[NPCManager] Found 3 recordings, spawning NPCs...
[NPCManager] Spawned NPC 1 for recording: bill.json
[NPCManager] Spawned NPC 2 for recording: billy_pilgrim.json
[NPCManager] Spawned NPC 3 for recording: doc_brown.json
[NPCManager] NPC 1 loaded recording: bill.json
[NPCManager] NPC 1 started playback
[NPCManager] NPC 2 loaded recording: billy_pilgrim.json
[NPCManager] NPC 2 started playback
[NPCManager] NPC 3 loaded recording: doc_brown.json
[NPCManager] NPC 3 started playback
```

## Use Cases

1. **Speedrun Comparison**: See multiple attempts side by side
2. **Strategy Analysis**: Compare different approaches to the same level
3. **Multiplayer Preview**: Test how the level feels with multiple players
4. **Tutorial Demonstration**: Show optimal vs suboptimal runs
5. **Ghost Racing**: Race against your previous attempts

## Technical Details

- Each NPC uses the same `player_1.gd` script with `is_npc = true`
- NPCs are positioned on the appropriate floor with horizontal spacing
- Recordings are sorted by modification time (newest first)
- Position correction is enabled for NPCs to ensure accurate replay
- Each NPC gets a unique color from the predefined palette
- NPCs use character names from the recording filenames
