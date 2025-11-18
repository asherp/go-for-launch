# Character System & Time Travel Abilities

## Selection & Observation

- Runs begin with a **character pick**. Only unlocked travelers appear in the menu (see `OBJECTIVE_SYSTEM.md` for how unlocks work).
- On spawn, their most recent recording plays in full view. Until the player injects input, the recording is law—details live in `DESTINY_MECHANICS.md`.
- Taking control mid-run writes a new recording for that character. Future playthroughs inherit the overwrite.

## Ability Roster (living list)

| Archetype | Signature mechanic | Design hook |
| --- | --- | --- |
| Delorean pilot | Can jump backward in time while maintaining location if travelling > 88 mph | Rewards route-planning and momentum puzzles |
| Phone-booth courier | Enters/exits via static booths | Forces spatial objectives around booth placement |
| Terminator | Spawns “from nowhere”, confirms kills | Prioritizes assassinations and ruthless item acquisition |
| Tenet operative | Experiences time in reverse | Recordings/replays appear backward to other players |
| Oracle (future) | Sees multiple prior recordings | Enables multi-ghost previews and strategic scouting |

> Add new archetypes here as they’re defined; reference sub-systems instead of restating behavior.

## Progression & Unlocks

- Objectives (solo, cooperative, or adversarial) determine which characters and gadgets surface next.
- Only a subset of characters will complete their goals in any single timeline, so unlock order becomes a narrative branching tree.
- Items gained during a run can seed future unlock requirements (“possess the ignition key at end-of-day to recruit …”).

## Possession & Character Handoff

- Long-term goal: allow mid-run character switching once the player earns the “possession” upgrade.
- Implementation outline:
  - Paused character continues on auto-pilot using its in-progress recording.
  - Interventions append to whichever character you currently embody; recordings keep provenance metadata so we can splice hybrid destinies cleanly.
  - UX will surface a time-aligned roster to avoid timeline confusion.

## Identity & Storage

- Character names originate from `assets/character_names.txt`, ensuring unique, lore-friendly handles.
- Recordings are saved under `res://recordings/<character>.json` via `player_recorder.gd`. See `RECORDING_SYSTEM.md` for schema.
- Metadata (`spawn_as_character`, objective state, time-travel device) lives alongside the recording and is what the selection screen reads.

