# Test 2 pre-registration — the mid-2023 roll-off / lag-wedge era contrast

**Committed BEFORE any estimation code for this test is written or run.** Plan of record:
`quality_reports/plans/2026-07-06_round2-referee-response.md`. Question: does the
essential-vs-matched gap track the compensation price d_t when d_t moves for a purely
mechanical, ex-ante-computable reason (the 2022 crisis rolling out of the trailing-365-day
window), or does it track fuel/crisis conditions (the referee's confound)? The design exploits
the fact that gas and d_t fell at DIFFERENT times: gas fell Oct 2022–Jan 2023; d_t stayed at its
plateau until June 2023 and fell over Jul–Sep 2023.

## Periods (calendar-defined, fixed here; essential matched-row mass from Stage 4's published
## power table `rq2_power_by_month.csv` — a design input, not an outcome)

| Period | Months | Gas | d_t | Essential rows / months |
|---|---|---|---|---|
| PRE (placebo-in-time) | 202201–202206 | mixed | LOW-MID ($121–253) | 3,787 / 6 |
| A — crisis | 202207–202209 | HIGH ($27) | HIGH ($350–378) | 2,577 / 3 |
| B — lag-wedge | 202210–202306 | LOW ($12.6–18.6) | HIGH ($329–351) | 1,191 / 4 |
| C — post-roll-off (omitted) | 202307–202412 | LOW (sd ~$1.2) | LOW-MID ($177–224) | 4,958 / 8 |

**Feasibility gate (passes on the published table; registered anyway):** each period must hold
≥ 500 essential matched rows over ≥ 3 essential-bearing months; if any period fails on the
as-built sample, its contrast is reported as a bound.

## Outcomes
Primary: `reach` (floor within dispatch's reach — the eligibility margin, per Test 1's
adjudicated interpretation 1, which directs the sharpened margin; sequencing was itself part of
the approved plan). Co-primary for continuity: `cheap_a_share`. No intensive margin here.

## Specification
Exact Stage-4 assembly (CEM strata, controls, unit + month FE, month clustering, June-2022
treatments, seed). Replace essential × comp_price with essential × {PRE, A, B} (C omitted):
`y ~ essential*(PRE + A + B) + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated | DUID + yyyymm`.
Period main effects are absorbed by month FE; the essential × period interactions are the
objects. Inference: analytic month-cluster + wild cluster bootstrap (vcovBS, Rademacher + Webb,
R = 999) on the primary contrast, base June treatment; all four June treatments reported.
Companion figure: monthly essential-vs-matched gap (reach), months with ≥ 30 essential rows,
event line at 2023-07, d_t overlaid.

## Committed predictions and interpretations (fixed now)

The primary contrast is **β_B (essential × lag-wedge, relative to post-roll-off C)** — d_t falls
between B and C while gas is low-and-flat on both sides:

1. **Payment-seeking signature:** β_B < 0 and significant (the gap is wider when the formula
   still pays crisis rates into a cheap-fuel world), with β_A ≈ β_B (both high-d_t; gas
   irrelevant conditional on the prize) and β_PRE ≈ 0 (early 2022 had post-roll-off-level
   prizes: the placebo-in-time). Reading: the dose response is confirmed on formula-driven
   variation; MC1/MC2's confound story fails on the timing wedge. Headline decision rule:
   Test 1 rule 1 + Test 2 narrowing → **headline stands, strengthened**.
2. **Fuel-stress signature:** β_A < 0 but β_B ≈ 0 (the gap collapsed when GAS fell, ~9 months
   before d_t did) — the cross-month RQ2 estimate is attributed to crisis variation, and per the
   approved plan's decision rule the manuscript headline moves to the mechanism-design
   accounting with the dose response reported as suggestive ("mixed" row).
3. **Mixed/intermediate** (β_B < 0 but materially smaller than β_A, or unstable across June
   treatments): both reported; abstract softened to "consistent with payment-seeking"; the
   lag-wedge ambiguity stated plainly.
4. **Underpowered** (B's 4 effective clusters yield CIs spanning both readings under WCB): the
   contrast is reported as a bound; no reading is forced; the Stage-4 caveat stands unchanged.

Known tensions recorded now, to be reported alongside whichever result obtains: Task 11's
posture-LEVEL era split (no softening after the roll-off) is a statement about unconditional
levels, not the essential-vs-matched gap — the two can differ, and this test is the first
computation of the gap version. Task 2's day-grain break check was infeasible (0 matched
essential days in its PRE window); this interval-grain version is feasible because the essential
mass at the interval grain spans all four periods above.

## Not licensed
No re-windowing after seeing results; no alternative period boundaries; the four June treatments
are the only sample variants. Follow-ups need a fresh registration.
