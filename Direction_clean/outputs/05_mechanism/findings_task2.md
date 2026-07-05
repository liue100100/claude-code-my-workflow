# Task 2 findings -- the registered mechanism test on the price of the marginal committed MW

> **Interpretation of this and all subsequent mechanism results is fixed in
> `interpretation_staged_framework.md` (recorded 2026-07-05, before the station-split table and
> Task B). Read that note first; its amendment rule governs any change of reading.**

Pre-registration: `05_mechanism/task2_preregistration.md`, committed 405ef65 BEFORE any data
work; every threshold below was fixed there. Scripts: `task2_build_outcome.R`,
`task2_estimation.R`, `task2_secondary.R`. Grain: unit x trading day (day-ahead bid stance),
TORRB2/3/4 + PPCCGT, 2022-01 -> 2024-12 (4,384 unit-days; OSB-AG descriptive only).

## VERDICT (committed interpretations applied)
- **RQ1: yes on the pricing margin, no on the withdrawal margin — the components disagree, so
  per the registered disagreement rule the component results are the finding.** On essential
  days the unit is LESS likely to withdraw availability below its floor (Component A: −12.7 pp,
  WCB p = 0.0004) and MORE expensive when the floor is offered (Component B: +$1,983/MWh toward
  the cap, WCB p = 0.020). Essentiality shifts conduct from physical absence toward priced
  presence — repricing with availability intact, the economic margin.
- **RQ2 (the registered dose-response): NULL — reported as the bound, not a forced estimate.**
  No outcome shows an essential x compensation-price interaction (p 0.12–0.94 across all four
  outcomes, all four June-2022 treatments, analytic and wild-bootstrap). The loss control
  explains nothing (all loss terms null; interactions barely move), so the innocent
  "loss-avoidance" reading gets no support either — the data say the day-ahead commitment
  price responds to the essential STATE, not to what the state pays. This completes the Stage-3
  regime-not-dose pattern on this outcome.
- **The mechanical-break backstop is infeasible as registered** (0 matched essential days in
  the PRE window) — moot for a null, but reported: nothing here "lives on the break."

## Step 1 -- frequency gate (PASSED; tables `task2_gate_*.csv`, `task2_floors.csv`)
- Component-A events among essential days, pooled test units: **109 (rule: stop if < 30)**;
  top-3 months hold 39.4% (flag threshold 60%). Gate passes.
- Frozen floors: TORRB2/3/4 = 40 MW; PPCCGT one-turbine (48 unit-days, ceiling <= 239 MW) = 42
  MW, two-turbine = 125 MW; OSB-AG = 134 MW. MPC schedule verified exactly against the maximum
  observed SA1 RRP in all four financial years (15100/15500/16600/17500).
- The composite lives at its mass points, as pre-registered expectations said it would:
  54–91% of unit-days at the cap (>= 1 h below floor is routine two-shifting), 5–26% at the
  −$1,000 floor band, 0–27% in between. **Component A is near-universal conduct** (3,161 of
  4,384 test unit-days, 72%) — which is why the withdrawal margin needed the essential-day
  contrast, not a raw count. Component B is bimodal: on full-availability days the floor MW is
  priced either at −$1,000 or near the cap (Torrens: 34–65% of B-days above $300 by unit-year).
- **Lever table** (`task2_lever_table.csv`): composite up-jumps are availability cuts (467 of
  506); down-jumps are quantity reallocation (522 of 525); day-over-day band-price changes
  occurred TWICE in ~1,030 jumps — the floor band's prices never move, as expected. The levers
  are quantity and availability, never the printed price.
- Essential days: 186 of 4,384 unit-days (4.2%); the three Torrens units share the station flag
  (60 days each), PPCCGT has 6.

## Step 2 -- RQ1 (`task2_rq1_results.csv`, `_wcb.csv`, `_robustness.csv`)
Outcome ~ essential_day + SRMC + demand + non-sync MW + spot + [competition] | unit + month FE,
cluster month, n = 4,384 (B: 1,223 no-withdrawal days).

| Outcome | M1 (no competition) | M3 (with competition) | WCB p (M3) |
|---|---|---|---|
| Composite, raw $ | +163 (p 0.68) | +85 (p 0.81) | 0.81 |
| Composite, within-unit rank | −0.023 (p 0.030) | **−0.027 (p 0.014)** | 0.012 |
| Component A (withdrawal, LPM) | −0.134 (p 0.0006) | **−0.127 (p 0.0005)** | 0.0004 |
| Component B (price of offered floor, $) | +2,351 (p 0.007) | **+1,983 (p 0.024)** | 0.020 |

The competition control moves nothing materially (M1 -> M3 shifts of 5–16%) — consistent with
Stage 3's essentiality-is-not-scarcity finding. Robustness: Torrens-only and drop-June-2022
preserve all three component signs (A: −0.097/−0.140, p <= 0.001; B: +1,636/+1,650, p ~ 0.05).
Raw composite is null because the outcome is corner-dominated and the two components pull
against each other; the rank version nets to the A margin.

**In words:** when the system needs this unit, the unit is 13 pp less likely (off a 72% base)
to have made itself unavailable — and 34–65% more of its remaining days price the committed MW
near the cap rather than at −$1,000. It stays, and charges for staying.

## Step 3 -- RQ2, the registered test (`task2_rq2_*.csv`)
Power first, per protocol: CEM (unit x month x non-sync quintile x competition bin) matches 140
of 186 essential days (75–83% per unit) over 16 months; top-3 months hold 42.1%; compensation
price sd $76.8, month range $121–378; matched sample 458 unit-days.

Essential x comp-price interaction (per $100/MWh), base June treatment:

| Outcome | No loss control | With loss control | WCB p (base) |
|---|---|---|---|
| Composite raw | +666 (p 0.20) | +471 (p 0.43) | 0.17 |
| Composite rank | +0.013 (p 0.33) | +0.013 (p 0.35) | 0.30 |
| Component A | +0.004 (p 0.94) | +0.015 (p 0.79) | 0.94 |
| Component B | +1,134 (p 0.26) | +517 (p 0.70) | 0.22 |

All four June-2022 treatments agree (full grid in `task2_rq2_results.csv`). The loss-control
terms are themselves null (exp_loss and its essential interaction, p 0.16–0.81), so the null is
not "explained away by losses" — it is a null against both registered alternatives. Informative
bound: the composite CI spans roughly −$300 to +$1,630 per $100 of compensation price on a
~$15,000-range outcome; with 140 essential days over 16 effective months, only a large dose
response was detectable, and none appears.

**Squaring with Stage 4 (stated, not smoothed):** Stage 4's interval-level cheap-capacity share
DID show a significant dose response (−5.1 pp per $100, p < 0.01). The two results coexist:
that outcome measures the whole intraday ladder across 140k matched intervals; this one
measures the day-ahead price of the last committed MW on 458 matched days — a corner-dominated
object with 1/300th the sample. Task 2's registered conclusion is about THIS outcome: the
day-ahead commitment price shows no detectable dose response. It bounds, it does not overturn.

## Step 4 -- mechanical break (`task2_break_results.csv`)
Infeasible as registered: matched essential days = 0 in PRE (2023-01 -> 2023-05) vs 14 in POST
(2023-10 -> 2024-02); even unmatched, the PRE window holds 6 essential unit-days (2023 has ~7
essential station-days all year — the essential mass sits in 2022 and late 2024, and the d_t
plateau/trough line up with exactly those years). No estimate forced. With RQ2 null this
backstop is moot — it exists to protect a positive result from conduct drift. Stated plainly:
there is no world in which this result "survives on the break alone," because there is no
result and no break sample.

## Step 5 -- secondary (supporting only; `task2_step5_secondary.csv`)
Episode times used here and in Step 6 carry the Task-1d **−10 h correction** (see
`findings_task1d.md`). Duration on comp price: −1.6 h per $100, p = 0.38, non-monotone across
terciles (9 / 14 / 9.5 h) — null. Online-when-directed (corrected windows): **99.8% of 194,019
directed intervals** — directly confirming the −10 h fix (the shifted windows had shown units
absent); at-floor share 92.0–97.7% across comp-price terciles, flat in price. Directed running
is floor running, always, at any price.

## Step 6 -- episode reclassification (`task2_step6_reclass.csv`, `_lobes.csv`)
All 740 corrected-window episodes classified on the issue day's day-ahead composite:
**withdrawn 561 (75.8%) + priced-out 163 (22.0%) = 97.8% exit-conduct; committed-cheap 16
(2.2%).** The exit-then-directed share rises above Task 1c's 91% (of 69, on shifted windows)
once pricing-lever exits count — and it now covers all 740 episodes, not a lobe. Lobe movement
(271 comp-matched; lobes themselves were built on shifted windows, caveat): zero-excess lobe
65/69 withdrawn + 3 priced-out; positive lobe 127/202 withdrawn + 74/202 priced-out; 1
committed-cheap in each. Both lobes are exit-conduct; the old lobe split does not survive as an
economic distinction.

## What this means for the paper (one paragraph, plain)
On the day AEMO directs one of these units, its day-ahead offer had almost always either
withdrawn the megawatts that keep it synchronised (76%) or priced them near the market cap
(22%) — 98% of 740 episodes, denominator in hand. That stance is state-dependent: on days the
system visibly needs the unit, it withdraws less and prices more — but the stance does NOT
scale with what a direction pays, on any of the three outcome margins, with or without the
running-loss control, and the loss story finds no support either. The registered conclusion is
the insurance/regime account for the day-ahead commitment margin: being needed changes conduct;
the size of the prize, at this margin and grain, measurably does not. The prize-sensitivity
that exists in this project lives at the intraday withholding margin (Stage 4), not in the
day-ahead price of presence.

## Open items (explicit)
1. The +10 h timestamp fix and the Task 1/1b/1c re-run remain queued on the user's go
   (`findings_task1d.md`); Steps 5–6 above already use the corrected windows.
2. The break check could be rescued only by redefining windows around 2022 -> 2023 (where
   essential mass exists on the PRE side) — that would be a post-hoc deviation from the
   registered windows and is NOT run; noted as the one design that could revisit it.

**STOP -- Task 2 complete. Awaiting review.**
