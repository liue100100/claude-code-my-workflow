# Mechanism check, Task 1b -- dollar reconciliation of the compensation formula (Direction_clean/)

**CORRECTED VERSION (Job 1, timestamp fix).** The original 1b findings were computed on direction
windows carrying the +10-hour parser bug (`findings_task1d.md`); the pre-fix text is archived at
`_pre_tzfix/findings_task1b.md`. Grain documentation, sources, and the join design are unchanged
from the original; every number below is from the corrected re-run (`_task1b_rerun.log`).

## VERDICT: GROSS WORLD -- now essentially exact
Direction compensation is **gross directed output x the directed price**, and on corrected
windows the formula is no longer approximate: **comp = 0.948 x (Q_gross x P), R-squared 0.990**;
the DCP form (gross minus retained trading amount) fits at 0.974 with coefficient 0.962. The
wedge (increment-over-floor-block) model collapses from its artifact-inflated 0.888 to
**R-squared 0.364**, and in the joint regression the dollars load entirely on gross (0.962) with
the wedge at -0.036. Construction validation: corr(computed window MWh, event-reported MWh) =
**0.992** (was 0.95), median abs diff 35.7 MWh.

## The artifact the fix removed
- **Misfit episodes: 41% (111 of 271) -> 0.7% (2 of 271).** The "additional-compensation
  top-ups dominate small episodes" reading of the misfits is dead -- the misfits were windows
  measured 10 hours late.
- **The lobe payout asymmetry is gone.** Zero-excess lobe (now 121 of 271; was 69):
  median compensation $82,858, comp-to-gross-energy-value ratio **0.93** -- identical to the
  positive lobe's 0.93 (was 3.12 vs 0.75). Payments run at ~93% of gross energy value at the
  directed price in BOTH lobes; there is no separately-shaped payout for low-excess episodes.
- Aggregate scale cross-check unchanged ($180M over 121 report events vs $58.8M over these 271
  unit-episodes -- consistent orders of magnitude).

## Implication for the Task 2 pre-registration (unchanged in direction, stronger in force)
Every directed MWh pays at the directed price regardless of the unit's bid-established
counterfactual; the strategic margin, if any, is being directed at all. This was already the
registered basis of Task 2 (run and reported: RQ2 null; see `findings_task2.md`).

## Caveat (carried over, unchanged)
Unit-episode dollars exist only for 2023-10 -> 2024-12; the gross-world verdict carries back to
2022 by the methodology-unchanged institutional assumption, not by measurement.
