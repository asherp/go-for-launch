# Ghost Player - NPC Replay System

The Ghost Player is an NPC that automatically loads and replays the most recent player recording, creating a "ghost" that follows your previous run.

## Features

- ✅ Automatically loads the most recent recording from `res://recordings/`
- ✅ Plays back recorded player movements in real-time
- ✅ Semi-transparent blue appearance to distinguish from main player
- ✅ Loops playback automatically when finished
- ✅ **Reuses the same `player_1.gd` script** - no code duplication!
- ✅ Guaranteed identical physics and behavior to the main player
- ✅ Position correction ensures accurate replay

## How It Works

The Ghost Player uses the **exact same script** (`player_1.gd`) as the main player, but with the `is_ghost` flag set to `true`. This ensures:
- Identical physics and movement behavior
- No code duplication or maintenance overhead
- User input is disabled (ghost only responds to playback)

When the scene starts:
1. The Ghost Player searches for the most recent recording file
2. It loads the recording data (player inputs and positions)
3. Automatically starts playback with position correction enabled
4. Follows the exact movement pattern from the recording
5. When playback finishes, it loops back to the beginning

## Configuration

The Ghost Player uses the same `player_1.gd` script with these special exported variables:

- **is_ghost**: Set to `true` to enable ghost mode (disables user input)
- **ghost_color**: The color/transparency of the ghost (default: semi-transparent blue)
- **loop_playback**: Whether to loop when playback finishes (default: true)

## Scene Structure

The Ghost Player node structure:
```
GhostPlayer (CharacterBody2D)
├── CollisionShape2D
├── Sprite2D
├── NavigationAgent2D
└── PlayerRecorder (Node)
```

The `NavigationAgent2D` is essential for replaying click-to-move navigation that was recorded.

## Usage Example

### Creating a Ghost Player

Simply add a `CharacterBody2D` with the `player_1.gd` script and set `is_ghost = true`:

1. Duplicate your main player node in the scene
2. Rename it to "GhostPlayer"
3. In the Inspector, check the `is_ghost` property
4. Optionally adjust `ghost_color` to change appearance

### In Code

```gdscript
# Get ghost player reference
var ghost = get_node("FirstFloor/GhostPlayer")

# Stop looping
ghost.loop_playback = false

# Change ghost color
ghost.ghost_color = Color(1.0, 0.5, 0.5, 0.5)  # Semi-transparent red

# Manually load a specific recording
if ghost.recorder.load_from_file("res://recordings/player_recording_20251013_225901.json"):
    await ghost.recorder.start_playback(1.0, true)
```

### In Editor

1. Select the `GhostPlayer` node in the scene tree
2. Adjust the exported properties in the Inspector
3. Change `ghost_color` to customize appearance
4. Disable `loop_playback` if you want playback to stop after one run

## Use Cases

1. **Racing against yourself** - Try to beat your previous time
2. **Comparing strategies** - See how different approaches compare
3. **Tutorial demonstration** - Show new players optimal movement
4. **Multiplayer preview** - Test multiplayer feel with AI
5. **Speedrun validation** - Visually verify recorded runs

## Technical Details

The Ghost Player **reuses the exact same `player_1.gd` script** with the `is_ghost` flag enabled:

### How Ghost Mode Works

1. **Input Blocking**: When `is_ghost = true`, the `_input()` function returns early, blocking all keyboard/mouse input
2. **Auto-load on Start**: Ghost automatically loads the most recent recording from `res://recordings/`
3. **Playback Mode**: Uses the existing playback system that all players have
4. **Visual Distinction**: Sprite is tinted with `ghost_color` (semi-transparent blue by default)
5. **Loop on Finish**: When playback ends, it automatically restarts if `loop_playback = true`

### Benefits of Code Reuse

- **Zero Duplication**: Same movement code, jump physics, floor detection, navigation
- **Automatic Updates**: Any improvements to player physics automatically apply to ghosts
- **Maintenance**: Only one script to maintain for both player and ghost behavior
- **Consistency**: Guaranteed identical behavior between recordings and playback

## Tips

- The ghost will only appear if there are recordings in `res://recordings/`
- Make sure to record at least one run before expecting the ghost to appear
- The ghost starts 0.5 seconds after the scene loads to ensure proper initialization
- Ghost color can be changed to any RGBA color value
- Disable collision if you don't want the ghost to interact with the player

## Troubleshooting

**Ghost doesn't appear:**
- Check that recordings exist in `res://recordings/`
- Verify `auto_load_recording` is enabled
- Check console for error messages

**Ghost movements don't match:**
- Ensure recordings are from the same game version
- Verify the recording file isn't corrupted
- Check that physics settings haven't changed

**Ghost is hard to see:**
- Adjust the `ghost_color` property
- Increase alpha channel for more opacity
- Add a glow effect in the shader

## Future Enhancements

Potential improvements:
- [ ] Multiple ghosts (best runs, friends' runs)
- [ ] Ghost selection UI
- [ ] Per-level best ghost
- [ ] Ghost comparison metrics
- [ ] Different visual styles per ghost
- [ ] Ghost pacing system (show if ahead/behind)

