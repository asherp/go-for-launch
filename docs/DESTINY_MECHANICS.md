# Destiny Mechanics - Recording as Character Fate

## What “Destiny” Means Here

- A recording is the canonical itinerary for one character. It is authoritative until a player overwrites it.
- Every NPC replays its latest file in lockstep. Temporal overlap is intentional; spatial collisions are prevented by physics + navigation.
- Deviations are resolved by the adaptive catch-up system (`ADAPTIVE_PATHFINDING.md`), not by teleporting.

## Lifecycle of a Recording

1. **Creation** – `player_recorder.gd` logs inputs, navigation targets, item interactions, and checkpoints (see `RECORDING_SYSTEM.md`).
2. **Playback** – NPCs consume the file verbatim until the player intervenes.
3. **Takeover** – Providing input splices the original file at the takeover timestamp. Everything before remains; everything after becomes new canon.
4. **Persistence** – Resulting JSON replaces the prior file for that character. Future timelines inherit it automatically.

> This “hybrid overwrite” keeps recordings compact while still honoring the exact moment a player jumped in.

## Branches & Visibility

- By default the game only keeps the latest branch per character. That keeps causality tidy.
- Special characters (the Oracle class) can request several previous versions for preview-only playback—handy for planning but not for undoing.
- UI goal: present branches as “destiny cards” sorted by modification time so players can reason about cause and effect without scanning folders.

## Cause & Effect Matrix

| Trigger | Immediate result | System reference |
| --- | --- | --- |
| NPC touches a switch inside its recording | World state flips exactly as recorded unless another actor already changed it | `NPC_BEHAVIOR.md` |
| Player interrupts recording | writes new canonical destiny; other NPCs adapt based on new behavior | This doc + `ADAPTIVE_PATHFINDING.md` |
| Recorded target no longer exists | NPC falls back to next meaningful state (continue route, trade for equivalent, mark objective failed) | `NPC_BEHAVIOR.md` |

The design target is **no paradoxes** without removing agency. If something can’t happen because the world changed, the recording doesn’t retroactively edit history; the NPC adapts in real-time.

## Data Surface Area (for quick reference)

- **Inputs** – Button presses, releases, navigation clicks.
- **State snapshots** – Periodic position, floor, z-height, carried item, followed target.
- **Interactions** – Items traded or attacked, objects clicked, follow start/stop.

All of that detail stays in the recording docs so we can update formats in one place. Destiny mechanics simply define how the files are honored during play.

