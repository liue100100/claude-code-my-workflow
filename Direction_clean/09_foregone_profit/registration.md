# Registration: Foregone-profit test — regions of the commitment decision and revealed preference for the directable posture

**Date: 2026-07-07 (saved before any estimation code exists). Status: Registered before
estimation. Amendments only by dated addendum.** Author's text verbatim below; dated addendum
(input-availability substitutions, flagged per the registration's own constraint) follows it.

---

Purpose
Every dose-response test to date asks whether conduct scales with a price. This task asks the
revealed-preference question directly: on days when committing the unit was profitable at spot,
did the desk decline that profit — and where it did, was the declined profit smaller than what
the direction option paid? The exhibit requires no d_t variation and is therefore immune to the
variation-support failure of the rent tests.

Objects
Daily commitment margin (floor-only, no start cost):
M_d = Σ_{h=1}^{48} floor × (p̂_h − SRMC_d)

- p̂_h: pre-dispatch forecast half-hourly price in force at bid-formation time for day d. No
  price-impact adjustment.
- floor: minimum stable generation — 40 MW per Torrens B unit; Pelican Point 42 MW on
  single-turbine days (MAXAVAIL ≤ 239 MW), 125 MW otherwise.
- SRMC_d: engineering SRMC at daily STTM gas.
- Start costs are deliberately excluded. Signed consequence, restated in every output: omitting
  S raises M_d, so region-B occupancy and the foregone-profit figure are upper bounds —
  compounding, in the same direction, the unadjusted-forecast bias. A near-empty region B is
  therefore conservative evidence of emptiness; a material region B carries the caveat.
- The sum runs over the full 24 hours: commitment eats the trough. M_d > 0 reads: "even at bare
  floor output all day, the variable margin was positive."

Direction option value:
V_absent,d = π_d × H̄ × floor × (0.95·d_t − SRMC_d)

- π_d: day-ahead timing-immunized rivals-only propensity, accumulated to the day (h = 24).
  Interpretation, for the record: π_d is P(directed | the unit rests absent) — the rivals-only
  construction delivers this; a committed unit is dispatched, not directed. Calibration error
  bounded by the Stage-3 decile table (cited, not re-derived).
- H̄: median direction-episode duration from the parsed event record; IQR reported alongside.
- No floor at zero on the bracket: a negative bracket places the day in region C regardless, and
  Σ V_absent is computed only on absent region-B days, where the bracket is positive by
  membership.

Regions (clean unit-days only, per the clean-day rule):
- A: M_d ≤ 0 — absence predicted by both accounts; evidentially dead.
- B: 0 < M_d < V_absent,d — commitment profitable, option pays more. The discriminating cell.
- C: M_d ≥ V_absent,d — commitment dominates. Absence here counts against payment-seeking.

Outcome: reach (floor-within-dispatch's-reach), day-grain, as built.

Calibrations
- Base: SRMC at daily STTM; H̄ at median episode duration; π at the day-ahead timing-immunized
  variant.
- Pessimistic (registered, run unconditionally): SRMC at month-maximum daily gas; H̄ at
  25th-percentile duration; π unchanged. Shrinks both M_d and V_absent; what survives is hard.
- Fixed-boundary row (circularity guard): d_t enters the region boundary through V_absent;
  robustness row classifies regions with d_t held at its sample median, absence rates
  re-reported on the fixed classification.

Order of operations, binding
1. Occupancy report first. Clean unit-day counts by region × unit × calibration, written to
   findings/regions_occupancy.md before any absence rate or dollar figure is computed.
2. Degeneracy gate: if region B holds fewer than 30 clean unit-days pooled under the base
   calibration, the exhibit is descriptive only — counts, reading (c), no rates, no cuts. The
   gate firing is a finding, not a failure.
3. Then, in order: absence rates by region; dollar figures; direction-proximity cut; robustness
   rows.

Deliverables (conditional on the gate)
- Absence rate P(reach = 0) by region, per unit and pooled, base and pessimistic.
- Dollar figures on absent region-B days: Σ M_d (spot profit declined) and Σ V_absent,d (option
  value on those days), reported as the pair "declined X to hold an option worth Y."
- Direction-proximity cut within absent-profitable days: N−1 flag and π-above-cutoff splits.
  Existing machinery only.
- Robustness rows: pessimistic; fixed-boundary; M_d on realized prices as a flagged-endogenous
  comparison only.
All outputs to findings/foregone_profit.md, plain declarative prose, signed biases restated
wherever a number could be quoted alone.

Committed interpretations
(a) Material region B, absence concentrated where V_absent > M_d: profitable commitment was
declined in favor of the directable posture, and the declined profit was smaller than the
option's value — the compensated posture revealed-preferred to profitable commitment. Stated as
an upper bound (no start costs, unadjusted forecasts — both inflate B). Does not establish daily
intent (the same-clock caveat of §7 fn 14 applies) and must not be written as if it did.
(b) Material region B, absence not concentrated — flat across B and C: friction-consistent
(roster inertia, start-cost and start-risk considerations, which the M_d construction
deliberately excludes); reported with no mechanism claim. Material absence in region C is
affirmative evidence against payment-seeking and is reported as such.
(c) Region B near-empty (gate fires or counts trivial): "there was no commercial running to
forgo" becomes a measured fact — and a conservative one, since B was constructed to be as large
as the assumptions allow. §7.1 is hardened; the pessimistic row confirms.
Monotonicity, committed: payment-seeking predicts absence rates high in A, high in B, lower in
C; the commercial account predicts the drop at the A/B boundary. The location of the drop is the
finding and is reported wherever it lands.

Constraints
No estimation before the occupancy report exists on disk. No new data construction — every
input (p̂, π, reach, SRMC_d, episode durations, N−1, d_t) exists in the pipeline. Realized
prices appear only in the flagged comparison row. Findings files only; no manuscript edits from
this task. Inputs contradicting prior pipeline outputs (durations, floors, clean-day sets) are
flagged, not silently reconciled.

---

## DATED ADDENDUM (2026-07-07, before estimation code): input-availability substitutions

Three inputs named in the registration do not exist in any pipeline holding. Per the
registration's own constraints ("no new data construction"; "inputs contradicting prior
pipeline outputs are flagged, not silently reconciled"), the following substitutions are fixed
now, before any estimation:

1. **p̂ (bid-formation forecast price).** All-runs pre-dispatch *price* tables do not exist in
   the pipeline (only final-run PREDISPATCHPRICE exists on the MMSDM archive; PDPASA carries no
   prices), and new extraction is barred. Substitute: **the previous trading day's realized
   half-hourly RRP profile** — the pipeline's existing bid-formation-time price expectation
   (task2's `exp_loss`/`rrp_prev_mean` convention). Because floor and SRMC are constant within
   a day, M_d depends only on the profile mean: M_d($) = 24 h × floor × (rrp_prev_mean_d −
   SRMC_d). Bias note: this substitution is not signed a priori (naive forecasts overshoot
   after spikes and undershoot before them); the two signed biases (no start costs, no price
   impact) still push region B outward as registered.
2. **SRMC_d "at daily STTM gas."** The pipeline's gas series is the quarterly-step AER STTM
   average (one value per month within quarter); daily STTM prices are not held. Base
   calibration: the panel's as-built `srmc` (marginal heat rate × quarterly-step gas). The
   registered pessimistic leg "month-maximum daily gas" is infeasible; substitute pessimistic:
   **all-in SRMC (static heat rate, GateA `srmc_allin`)** with H̄ at the 25th percentile —
   higher cost shrinks both M_d and the option bracket, preserving the registered direction
   ("what survives is hard").
3. **Day-grain reach "as built."** The as-built day-grain posture object is the Task-2
   **day-ahead stance** (bid version in force at 00:00; `task2_interval_stance.rds`). Absence
   is measured on it, matching M_d's decision clock: **absent_d = 1 if the stance keeps the
   floor out of $300-reach in every half-hour of day d** (cheap-at-$300 MW < floor throughout);
   the share-based variant (stance-reach share < 0.5) is reported alongside.

Fixed constants, recorded now: H̄ = 11.8 h (median of the 480 merged direction spells; IQR
7.0–31.0), pessimistic H̄ = 7.0 h (p25); the 0.95 gross-fit factor from Task 1b; π_d = 1 −
Π_{t∈d}(1 − ĥ_da,t) accumulated over day d's 48 half-hours from the day-ahead conditions-only
hazard (Stage 3c), calibration bounded by the Stage-3 decile table.
