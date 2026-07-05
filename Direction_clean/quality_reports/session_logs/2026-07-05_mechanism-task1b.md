# Session log — 2026-07-05 — Mechanism check, Task 1b (dollar reconciliation)

## Goal
Before Task 2 (whose pre-registration waits on this): does direction compensation pay the
increment over the bid-established counterfactual (wedge world) or gross directed output (gross
world)?

## Grain audit (done before any join, per instruction)
Decisive: `direction_events` NEW format (2023-10 → 2025-01) is per DUID × event with per-unit
MWh, compensation, RTA, and additional compensation — true unit-episode grain, no allocation
needed (299 comp-bearing focal rows). Old-format rows carry no dollars; `direction_costs`
(2021→2023-10) is report-event grain aggregating across units — NOT joined at unit-episode grain
(allocation risk stated); used only as an aggregate scale cross-check. Match: 271 of 297
in-window Task-1 episodes (91.2%); construction validated (corr computed-vs-reported MWh = 0.95).

## Verdict: GROSS WORLD
1. **Deciding table:** the zero-excess lobe (69 episodes whose own floor block covered directed
   output — wedge world pays them ~nothing) received a median **$57k**, only 1.4% below $5k, at
   **3.1× their gross energy value** (cost top-ups dominate small episodes). Wedge world rejected
   on this table alone.
2. **Fits:** gross Q×P R²=0.943 (coef 0.88) > DCP gross−RTA 0.936 > wedge 0.888; joint loads on
   gross (0.77) vs wedge (0.13). The wedge model leaves a vertical column of well-paid episodes
   at predicted ~$0 (figure).
3. **Misfits:** 41% of episodes deviate >50% from the best formula. Additional compensation is
   pervasive (70% of ALL episodes) rather than misfit-specific (75.7%); the loss-condition
   concentration test has no contrast in this window (gas flat at ~$12.5/GJ) — reported as
   untestable here, not absent.
4. Caveat: dollars exist only for 2023-10→2024-12; the gross-world verdict carries back to 2022
   by institutional (methodology-unchanged) assumption, not measurement.

## Implication encoded for Task 2's pre-registration
Gross world → payment-seeking predicts sensitivity of **direction-receipt/eligibility itself** to
the price (every directed MWh pays regardless of the counterfactual), NOT floor-pulling to
engineer a low counterfactual. Task 2's commitment-margin classification will be pre-registered
against that prediction.

## Bugs
One trivial: duplicate `instruction` column from a merge crashed the misfit export; coalesced
with an equality assertion and re-run.

## Status: Task 1b COMPLETE — STOPPED. Task 2 next, on the user's go, with the gross-world
pre-registration. Outputs: `outputs/05_mechanism/{findings_task1b.md, task1b_*.csv,
task1b_formula_fit.png, task1b_panel.rds}`.
