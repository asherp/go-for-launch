# Adaptive Pathfinding - Minimal Tardiness System

## Why We Need It

Recordings describe *what* should happen, not *how to recover* when the world diverges. The adaptive navigation layer keeps NPCs believable when doors get blocked, items move, or players interrupt destinies.

## Minimal Tardiness In Plain English

- Stay on script if you are within tolerance of the recorded position/time.
- If you fall behind, target a point **Δt** seconds ahead in the same recording.
- If you still miss that rendezvous, double Δt and try again.
- Eventually you either catch the script or aim for the final checkpoint and accept the failure state.

```
Δt progression: 2s → 4s → 8s → … (cap at “end of file”)
```

This produces characters who naturally hurry, reroute, or give up—without teleporting.

## Implementation Notes

| Component | Role |
| --- | --- |
| `NavigationAgent2D` | Provides obstacle-aware steering per floor |
| Position correction | Watches deviation and kicks off Δt targeting when thresholds are exceeded |
| Rendezvous lookup | Scans the recording for the next waypoint that matches the requested timestamp |

Edge cases:
- **End of recording** – NPC keeps marching toward the last checkpoint even if the timer expired. That failure can cascade into other objectives (`OBJECTIVE_SYSTEM.md`).
- **Blocked forever** – After several doubled windows, mark the objective as failed so other systems can react.
- **Multiple delays** – Δt doubling makes the NPC skip ahead instead of stalling.

## Performance Cheatsheet

- Update cadence defaults to 1 Hz; increase locally for critical characters only.
- Batch navigation recalculations (e.g., spread across frames) to keep 100+ agents affordable.
- When zoomed out or off-screen, let Δt grow faster to avoid micromanaging invisible NPCs.

