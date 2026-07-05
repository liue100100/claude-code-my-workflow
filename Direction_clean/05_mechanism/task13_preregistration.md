# Pre-registration — does the Torrens roster level track the combination requirement?

**Written and committed BEFORE estimation. 2026-07-05.** Motivated by the task-12 discovery
(rotating 1–2-of-3 roster; three units offered together on 4% of days) and the open
observation flagged there. Grain: STATION-day — the three units treated as one decision.

## Definitions (fixed)
- **Roster level** (the choice): number of Torrens units whose day-ahead midnight stance
  declares any availability ≥ 40 MW that day (0–3), from the stance table.
- **Requirement** (the standard's ask): per 5-minute interval, the minimum number of Torrens
  units k (0–4) such that the applicable minimum synchronous combinations are satisfiable
  with rivals' AVAILABLE units plus k Torrens units (rivals-only construction, the pivotality
  machinery; censored at 5 if infeasible even with 4). Day value: the day's MAXIMUM (the peak
  ask) primary; day mean secondary.
- Sample: all 1,096 station-days, 2022–2024, corrected clock. Contamination is not screened
  here — the roster is a slow state and the requirement is system-side; noted, not screened
  (a clean-day robustness row is reported).
- **Test:** roster ~ requirement, month fixed effects, cluster month, wild cluster bootstrap
  (Rademacher/Webb, R=999); M1 requirement only, M2 + day-mean demand, day-mean spot, monthly
  gas (the market/seasonal confound — winter loads the roster, solar loads the requirement).
  Cross-tab of roster × peak ask reported before any coefficient. Realised directions never
  on the right-hand side.

## Committed readings
1. **Positive, surviving M2:** the station manages its portfolio to the security standard —
  the standing absence is bounded below by compliance at station level ("minimum viable
  roster"). A refinement of the standing-posture account, not a contradiction.
2. **Null or negative:** the roster follows the market and maintenance calendar; alignment
  with the standard is incidental, and the operator's directions bridge whatever gap the
  roster leaves. The standing-posture account stands unrefined.
3. **Degenerate variation** (requirement nearly constant): reported as a bound, no test forced.

## Descriptive companion (no test): were the 45 pre-direction evening zeroings handovers?
For each depth-check D−1 evening floor-crossing day, compare STATION-level evening
availability (sum of three units) day-over-day: reduction vs swap (a sister adding what the
crosser removed). This re-reads an existing descriptive result at the new grain; whichever
way it falls is reported plainly.
