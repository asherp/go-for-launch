# Gameplay Vision - Time Travel Game

## Snapshot

A systemic time-travel playground where player recordings crystalize into NPC destinies. You choose when to observe, when to interfere, and which character’s fate is worth rewriting—knowing that every nudge can ripple across a cast of 100+ simultaneous actors.

## Experience Pillars

- **Pivotal agency** – The player always feels like the butterfly that might trigger (or avert) a hurricane.
- **Readable chaos** – The world can zoom out to show every destiny unfolding at once, then zoom back into the moment you grab the wheel.
- **Character-first time travel** – Each hero (or villain) bends time in a signature way. See `CHARACTER_SYSTEM.md` for full ability notes.
- **Consequences that linger** – Changed recordings become new canon. Later runs inherit every blessing and blemish. See `DESTINY_MECHANICS.md`.

## Core Loop (One Run)

1. **Pick a character** – Only unlocked characters are selectable.
2. **Observe** – Their latest recording auto-plays. No input, no divergence.
3. **Intervene** – Provide any input to take over. Recording splits and you own the new timeline.
4. **Impact** – NPCs reroute, objectives succeed or collapse, items change hands.
5. **Debrief & Unlock** – Completed objectives update progression and may surface fresh characters or gear.

## Systems Map

| Question | Where it’s answered |
| --- | --- |
| What counts as “destiny”? | `DESTINY_MECHANICS.md` |
| How do characters move through time? | `CHARACTER_SYSTEM.md` |
| How do NPCs catch up when late? | `ADAPTIVE_PATHFINDING.md` |
| How are objectives tallied? | `OBJECTIVE_SYSTEM.md` |
| What logic drives NPC decisions? | `NPC_BEHAVIOR.md` |
| How do we scale to 100+ actors? | `TECHNICAL_ARCHITECTURE.md` |

## Camera & Scale Notes

- Idle players get a macro view: pan and zoom far enough to see every destiny thread at once, perfect for planning.
- As soon as you steer a character, the camera recenters and prioritizes moment-to-moment clarity.
- Technical target: 100+ concurrently simulated NPCs, all fed by recordings. Storage may graduate from flat files to a lightweight database when needed (`TECHNICAL_ARCHITECTURE.md`).

## Narrative Hooks

- Tone leans into pulpy sci-fi (Deloreans, phone booths, reverse-time agents, terminators) while keeping the stakes grounded: sabotage or safeguard the launch.
- Unlock order becomes story structure. Which objectives you save or sacrifice determines which time travelers appear next.

