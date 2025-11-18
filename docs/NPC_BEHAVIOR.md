# NPC Behavior & Interaction Systems

## Guiding Idea

NPCs are playback-first actors with enough autonomy to survive timeline drift. They obey recordings until reality disagrees, then lean on navigation, objectives, and a lightweight “needs” stack to improvise.

## Needs Stack (used by all archetypes)

1. **Survive** – Don’t die en route to anything.
2. **Primary objective** – Keep pursuing the recorded goal unless it’s impossible.
3. **Dependencies** – Acquire required items / allies (trading if possible, stealing if necessary).
4. **Opportunistic help** – If assisting another character also advances your agenda, do it.
5. **Return to script** – Once the disruption passes, rejoin your destiny via `ADAPTIVE_PATHFINDING.md`.

This replaces pages of bespoke rules; archetypes simply weight the stack differently (e.g., terminators downplay “help” while cooperative characters boost it).

## Interaction Cheatsheet

| Situation | Default response |
| --- | --- |
| Target NPC already dead | Mark objective as failed, proceed to next priority |
| Required item missing | Look for trade partner → fallback to theft/force if archetype allows |
| Clicked object in wrong state | Attempt to set it, otherwise wait until timer/ally restores it |
| Player-controlled character approaches | Evaluate follow/trade/avoid using the same needs stack |

These behaviours piggyback on the data already stored in recordings (clicked object IDs, follow events, etc.).

## Archetype Overrides (examples)

- **Terminator** – Boost survival + objective, allow forceful item acquisition, confirm kills before leaving.
- **Cooperative agent** – Willing to pause progress to trade or escort allies.
- **Reverse-time operative** – Reads recordings backward but still uses the same decision stack.

Add more overrides inline with `CHARACTER_SYSTEM.md` when new archetypes appear.

## Systems Touched

- **Navigation** – Uses the minimal tardiness loop to physically reach the next meaningful waypoint.
- **Objective engine** – Writes success/failure as soon as the needs stack abandons an objective.
- **State service** – Shared registry for items, switches, and doors. NPCs query before acting so they don’t repeat impossible steps.

## Tooling / Debug Views

- Toggle to display current need and target for any NPC (helps tune the stack).
- Path preview from the adaptive navigator.
- Timeline inspector showing when a recording was interrupted and why the fallback triggered.

These are primarily for designers; the player-facing feedback stays minimal (glows, icons, etc.).

