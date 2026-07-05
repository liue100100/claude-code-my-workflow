# Task 2 pre-registration — the price of the marginal committed megawatt

**Written and committed BEFORE any outcome construction or estimation. 2026-07-05.**
Every threshold, reference choice, and decision rule below is fixed here. Deviations, if any
become unavoidable, will be documented in the findings as deviations, not silently applied.

## Research questions (verbatim, registered)

**RQ1:** Is the price of the marginal committed megawatt higher on days the unit is essential
for system security — holding spot conditions, fuel cost (SRMC), and the competition measure
fixed?

**RQ2 (the registered dose-response):** among essential days, does that price rise with the
direction compensation price, after controlling for expected running losses?

**Committed interpretations:**
- RQ2 positive and surviving the loss control and the mechanical-break check: exit conduct
  responds to what a direction pays (the strategic reading).
- RQ2 explained away by the loss control: exits are ordinary loss-avoidance (the innocent
  reading).
- Data too thin (frequency gate below): we report the bound, not a forced estimate.

**Disagreement rule for the three-part outcome:** the composite is the headline only if its
result is supported by at least one component; if the components disagree, the component
results are the finding — a withdrawal-only result means essentiality provokes availability
withdrawal (physical); a pricing-only result means it provokes repricing with availability
intact (economic); we report whichever the data shows.

## Outcome definitions (fixed)

**Grain:** unit × trading day (calendar day, market time Etc/GMT-10), 2022-01-01 → 2024-12-31.
Test units TORRB2/3/4, PPCCGT; OSB-AG in the frequency gate as descriptive only.

**Bid stance:** the day-ahead stance — the bid version in force at 00:00 of the trading day
(latest OFFERDATETIME ≤ day start), daily ladder likewise (latest OFFERDATE ≤ day start). The
Task-1c trading-date fix applies everywhere: BIDOFFERPERIOD keyed by the calendar day of its own
intervals; BIDDAYOFFER label shifted +1 day. Rationale for day-ahead: intraday rebids on
direction days include AEMO-direction RTS rebids (Task 1c), which would contaminate the conduct
measure with the direction's own consequence.

**Operating floor:** TORRB2/3/4 = 40 MW (Task 1, exact across all three units). PPCCGT:
configuration inferred per unit-day from the day-ahead stance's maximum MAXAVAIL — ≤ 239 MW =
one-turbine mode, > 239 MW = two-turbine mode (the MSL memo's ceiling rule; the memo itself is
not in the repo — `master_supporting_docs/` holds placeholders only). Floor VALUES per
configuration = the 5th percentile of positive realised output among that configuration's
intervals, computed once in the frequency-gate step, reported there, then frozen. Days with
day-ahead MAXAVAIL = 0 all day inherit the most recent prior day's configuration
(carry-forward; count reported).

**Per-interval primitive p_floor(i):** cumulate BANDAVAIL up price bands 1→10 (AEMO bands are
ascending by construction), cumulative quantity capped at MAXAVAIL(i). p_floor(i) = the price of
the band in which the floor-th cumulative MW falls. If MAXAVAIL(i) < floor: no such MW is
offered — impute the market price cap for that interval (imputation, flagged as such).
MPC schedule (financial years): 2021-22 $15,100; 2022-23 $15,500; 2023-24 $16,600; 2024-25
$17,500 — cross-checked in the gate step against the maximum observed SA1 RRP per FY;
discrepancies reported, schedule retained.

**Composite (headline):** the 12th-highest p_floor(i) across the day's 288 intervals — the
price of the marginal committed MW sustained for at least one cumulative hour. Reported raw AND
as a within-unit percentile rank (computed over that unit's full sample of days). The mass
points at −$1,000 and at the cap are behaviour and are never trimmed.

**Component A — withdrawal margin (binary, no imputation):** ≥ 12 intervals (one cumulative
hour) of the unit-day with MAXAVAIL < floor.

**Component B — pricing margin (continuous, conditional, no imputation):** on unit-days where
Component A is FALSE, the 12th-highest p_floor(i) computed over non-imputed intervals only.
Every value is a price the unit actually asked.

**Lever decomposition:** a "jump" is a day-over-day (within unit) change in the composite of
more than $100/MWh or a flip in Component A. Attribution by counterfactual recomputation:
(1) availability cut — Component A flipped on; (2) quantity reallocation — composite reproduced
by today's band quantities at yesterday's band prices; (3) band-price change — residual case
(expected rare: band prices are daily-fixed and the floor band historically never moves).
Precedence in that order when multiple apply; counts reported per lever.

## Design definitions (fixed)

- **Essential day:** ≥ 12 intervals (one cumulative hour) with the station's ex-ante
  essentiality flag (`pex_<station>`, the Stage-1 leakage-audited rivals-only flag) TRUE.
- **Controls (day grain):** SRMC (unit × month); day means of TOTALDEMAND, non-synchronous MW
  (LEVEL, per the Stage-3 documented deviation), spot RRP; competition = day mean
  `slope_kernel` + day share of saturated (zero-slope) intervals. RQ1 reported with (M3) and
  without (M1) the competition terms, per Stage 3.
- **CEM matching (RQ2):** strata = unit × month × non-sync-day-quintile × competition bin
  (bin = "saturated-day" if the day's saturated share ≥ 50%, else terciles of day-mean slope).
  Hour-block from Stage 4 does not exist at day grain — stated adaptation, not a silent drop.
- **Compensation price:** monthly reconstructed d_t (`gate0_dt_series.rds`, dt_recon), in
  $100/MWh units. Its main effect is absorbed by month effects; the interaction is the object.
- **Expected-running-loss control:** exp_loss = SRMC − (previous trading day's mean realised
  SA1 RRP), $/MWh, positive = expected loss-making; secondary form = share of previous-day
  intervals with RRP < SRMC. The previous day's realised profile proxies the bid-day
  expectation — no forecast archive exists in this repo; stated as a proxy. Enters RQ2 as main
  effect + interaction with essential; RQ2 reported with and without it.
- **June 2022:** suspension day = trading day containing ≥ 1 MARKETSUSPENDEDFLAG interval.
  BASE excludes suspension days only; non-suspension June days carry the ex-ante June price
  $241.38. Robustness: (i) exclude all June 2022; (ii) include suspension days at the ex-ante
  APC imputation $300/MWh; (iii) base minus pre-suspension June. Never realised compensation.
- **Mechanical break (Step 4):** from the daily trailing-365-day d_t series
  (`d_t_SA_90pct_365d.csv`), whose mid-2023 fall is the 2022 crisis prices exiting the window
  on computable dates ([F1]). PRE = 2023-01-01 → 2023-05-31 (crisis inside the window);
  POST = 2023-10-01 → 2024-02-29 (crisis fully out); the transition glide 2023-06-01 →
  2023-09-30 excluded. Reported: essential × post reduced form AND essential × comp_price on
  PRE+POST only. Committed reading: survives on the break alone = strong; full-sample only =
  cannot separate strategy from conduct drift, and we say so.
- **Inference:** cluster-robust by month (analytic) + wild cluster bootstrap via
  sandwich::vcovBS (Rademacher primary, Webb sensitivity), R = 999, month clusters
  (fwildclusterboot uninstallable here — documented Stage-3 deviation, carried forward).

## Frequency gate (Step 1, decided before any regression)

Per unit per year: composite distribution, Component A event counts, Component B distribution,
lever table. **Stop rule:** if Component A events among essential days, pooled across the four
test units, number under 30 — stop and report; also flagged (reported, judgment stated) if the
top 3 months hold more than 60% of those events.

## Secondary outcomes (Step 5, supporting only)
Direction-episode duration on comp_price (episode grain, unit FE, month clusters); the
online-at-floor-when-directed share by comp-price tercile.

## Episode reclassification (Step 6, validation)
The 740 Task-1 episodes classified on the issue day's day-ahead composite: withdrawn
(Component A on the issue day) / priced-out (A false, floor-MW price > $300 — the Stage-1 fixed
cheap threshold) / committed-cheap (A false, ≤ $300). Report whether withdrawn + priced-out
exceeds Task 1c's 91% exit share, and how the zero-excess and positive-excess lobes move.

## Task 1d decision rule (parallel)
Set = the 35 capped-survivor episodes from Task 1c (window_excess_capped_mwh ≤ 0; ~zero output,
material payment). A payment shape "fits" if its single-regressor through-origin R² ≥ 0.6 OR its
channel carries ≥ 60% of total dollars: cost-reimbursement shape (additional_compensation
share; scaling with duration/starts/gas, not MWh) vs output-payment shape (MWh × directed
price). Issued-then-cancelled checked from event effective/cancellation times. If neither shape
fits by these thresholds, that is the finding — flagged, stopped, no invented explanations.
