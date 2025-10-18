# Recordings Directory

This directory stores player input recordings that can be replayed as NPCs with pre-recorded behaviors in the game.

## How It Works

The recording system captures player inputs and positions during gameplay, then replays them as autonomous NPCs that follow the exact same path the player took.

### Recording Process
1. **Auto-Record**: Game automatically starts recording when you begin playing
2. **Input Capture**: Records all keyboard inputs (movement, jump) and mouse clicks
3. **Position Tracking**: Records player position every second as "checkpoints"
4. **Auto-Save**: Recording is automatically saved when you stop or restart

### Playback Process
1. **NPC Spawning**: Game automatically spawns NPCs for each recording
2. **Path Following**: NPCs follow the exact recorded path using simulated inputs
3. **Visual Preview**: Shows next 3 positions as colored dots (black=next, white=3rd)
4. **Looping**: NPCs repeat their path indefinitely

## File Format

Recordings are saved as JSON files with timestamped filenames:
```
player_recording_20250114_153045.json
```

## What's Inside

Each recording contains:
- Player name and recording metadata
- Duration and event count
- Timestamped input events (movement, jumps, clicks)
- Position checkpoints for accuracy
- Floor/level information for multi-story gameplay

Example:
```json
{
  "version": 1,
  "player_name": "Player",
  "duration": 15.891,
  "event_count": 21,
  "events": [
    {
      "timestamp": 0.0,
      "action": "position_checkpoint",
      "floor": "GroundFloor",
      "player_position": {"x": 272.0, "y": 216.0},
      "tile_position": {"x": 21, "y": 5}
    },
    {
      "timestamp": 0.707,
      "action": "left",
      "pressed": true,
      "player_position": {"x": 271.9, "y": 215.95}
    },
    {
      "timestamp": 2.134,
      "action": "jump",
      "pressed": true
    }
  ]
}
```

## File Size

These files are very small:
- ~5-10 KB per minute of gameplay
- 60-second recording ≈ 6 KB
- 5-minute recording ≈ 30 KB

## Controls

### Recording Controls
- **R** - Start/stop recording
- **Ctrl+S** - Save current recording to file
- **P** - Print recording statistics

### Playback Controls
- **Ctrl+L** - Load and play most recent recording
- **Ctrl+Space** - Start/stop playback (without position correction)
- **0** - Restart game (respawns all NPCs)

### NPC Management
- **G** - Refresh/respawn all NPCs
- **H** - Print NPC and recording info

## Usage

### Automatic NPC Spawning
When you start the game, it automatically:
1. Scans the recordings directory
2. Spawns an NPC for each recording file
3. Each NPC follows its recorded path independently
4. NPCs are color-coded for easy identification

### Manual Playback
You can manually replay any recording:
```gdscript
# Load and play a specific recording
player.load_recording_from_file("res://recordings/player_recording_20250114_153045.json")
player.start_playback(1.0, true)  # 1x speed, with position correction

# Get recording statistics
player.print_recording_stats()
```

### View Recordings
Simply open the JSON files in any text editor or JSON viewer to see the raw data.

### Export to CSV
See `scripts/recording_demo.gd` for examples of exporting to CSV format for analysis in Excel or Python.

## NPC Behavior

### Visual Features
- **Color-coded** (blue, green, red, etc.) for easy identification
- **Path preview** shows next 3 positions as colored dots
- **No collision** with each other or the player (NPCs pass through each other)
- **Independent playback** - each NPC follows its own timeline

### Movement System
- Uses **simulated inputs** to replay exact player actions
- **Position correction** ensures accurate path following
- **Floor transitions** handled automatically for multi-story gameplay
- **Looping** - NPCs repeat their path indefinitely

### Performance
- **Efficient** - only processes input events, not full physics
- **Scalable** - can handle many simultaneous NPCs
- **Smooth** - 60fps playback with minimal overhead

## Git Management

By default, recording files are **not ignored** by git, so they'll be committed to your repository.

To ignore them, uncomment this line in `.gitignore`:
```
# recordings/*.json
```

Keep them committed if you want to:
- Share gameplay data with team members
- Track player behavior over time
- Use as test cases or regression tests
- Include example recordings with your project
- **Create persistent NPCs** that survive across game sessions

## Location

Recordings are saved to:
```
/Users/asherp/git/godot_games/go-for-launch/recordings/
```

This is your project's `res://recordings/` directory.

**Note**: In exported games, `res://` is read-only. For production use, consider saving to `user://` instead.

