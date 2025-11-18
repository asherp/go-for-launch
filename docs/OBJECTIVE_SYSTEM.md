# Objective System & Emergent Gameplay

## Objective Taxonomy (one-liners)

| Type | Description | Example hook |
| --- | --- | --- |
| Solo | Character can succeed without outside help | “Deliver the ignition key before T‑0” |
| Cooperative | Requires timing or item exchange between two+ actors | “Trade clearance codes so both characters can reach the pad” |
| Adversarial | One character’s win guarantees another’s failure | “Sabotage the launch” vs “Prevent the saboteur” |

Objectives double as narrative beats. A mission that fails still teaches the player who else cares about that outcome.

## Tracking & Payoffs

- Each run ends with a checklist: which objectives succeeded, failed, or were abandoned.
- Unlock logic reads that checklist to decide which characters, props, or timeline modifiers appear next.
- Items or states can be “reserved” for later runs (e.g., “if Character A finishes with the fuel valve, allow Character C to spawn”).

## Cooperation Rules of Thumb

- **Coincidence of wants** – If two NPCs each hold what the other needs, they auto-trade when they meet and remain in-character about it. No UI prompts.
- **Shared timers** – Some events (like the launch) require several objectives to be green simultaneously; otherwise the event fizzles.
- **Failures propagate** – When a prerequisite character is late or dead, dependent objectives auto-mark as failed so unlock logic stays honest.

## Dynamic / Adaptive Objectives (future)

- We want the ability to mutate objectives mid-run (“Sabotage succeeded? Now evacuate civilians”) but haven’t locked the UX.
- Considerations: player messaging, recording format changes, and how to store branching requirements without bloating files.

## Visualization Sketch

- HUD: minimalist icon per tracked objective (color-coded for success/failure/pending).
- Map overlay: highlight characters currently critical to shared events.
- End-of-run report: matrix showing who helped/hurt whom, feeding directly into the unlock narrative.

## Why It Matters for Replayability

- No single run can satisfy every objective; scarcity of time and conflicting goals guarantee variety.
- Players chase different “perfect outcomes” by picking different characters to champion each time.
- Unlock tree plus possession mechanic (`CHARACTER_SYSTEM.md`) ensures late-game runs feel fundamentally different from the first.

