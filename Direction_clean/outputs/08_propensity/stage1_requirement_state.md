# Stage 1 findings — the deterministic requirement state (rivals-only, two margins, three horizons)

Registration: `08_propensity/registration.md`. Scripts: `stage1_requirement_state.R` (current
state), `stage1a_rival_bop_cache.R` (rival bid-version caches), `stage1b_forecast_slack.R`
(forecast slack). Panel: `outputs/08_propensity/stage1_panel.rds` — 52,608 half-hours,
2022–2024. All numbers below from the run logs and saved outputs.

## Construction (what the slack is)

Slack = minimum number of rival-unit departures separating the system from needing a Torrens
unit, computed by the project's verified combination-table machinery (pivotality.R
`depth_station`: zero the focal station, then find the minimum removals from the rival
count-vector before no applicable minimum-synchronous combination is satisfiable; applicability
by non-synchronous-MW tier). Two current-state margins plus three forecast horizons:

| measure | rival fleet counted | information time |
|---|---|---|
| `slack_avail` | declared available (bid MAXAVAIL > 0) | realized, t |
| `slack_commit` | online (committed, INITIALMW > 0) | realized, t |
| `slack_fc_{1,4,8}h` | bid-declared MAXAVAIL from the latest offer version lodged ≤ t−h; PPCCGT/OSB-AG excluded if offline at t−h and h < 4 (slow-start rule); non-sync from the latest PDPASA run ≤ t−h (SS_WIND_UIGF + SS_SOLAR_UIGF; ARCHIVE months filtered to RUNTYPE OUTAGE_LRC; realized fallback < 0.03%) | t−h |

Rivals-only holds throughout: the focal station's availability, bids, directed status, and the
spot price enter nowhere; the depth search zeroes Torrens before it runs. Every input is public
(bids next-day, PDPASA real-time, the TLA combination tables). Single-vintage caveat from Stage
0 stands: the combination table is the syn_cons=4, two-unit-standard vintage, valid across
2022–2024 at the standard level; in-window band revisions unverified.

## Committed validation 1 — slack = 0 reproduces pex: EXACT

30-min confusion matrix (slack_avail == 0 vs pex): 714 / 714 both-true, 51,894 / 51,894
both-false, **zero off-diagonal cells**. This is by construction — the slack generalizes the pex
machinery and the pivotality build enforces `depth_ex == 0 ⇔ pex` as a regression test every
month — and the min/any 30-min aggregation preserves it exactly.

## Committed validation 2 — slack ≤ 1 vs the N−1 flag: one-way nesting, investigated

| | N−1 fires | N−1 does not |
|---|---|---|
| slack_commit ≤ 1 | 34,590 | 3,913 |
| slack_commit > 1 | **0** | 14,105 |

The N−1 flag never fires outside slack ≤ 1 (perfect containment). The 7.4% cell (above the 5%
investigation threshold, so investigated as committed): 76% of those half-hours sit at 2–3
committed rival units, and 84% are at slack = 1 exactly. The cause is definitional, not a bug:
the N−1 flag removes the single **largest** online unit; the slack removes the **adversarial**
one. With a thin committed roster, losing the *specifically required* rival (a Pelican GT in a
combination that names Pelican Point) breaks feasibility when losing the largest unit does not.
Adversarial-implies-largest gives the observed one-way nesting.

## The Stage-1 result: the requirement lives on the commitment margin

| state, share of 52,608 half-hours | availability margin | commitment margin |
|---|---|---|
| rivals alone satisfy the standard (slack > 0) | 98.64% | 50.61% |
| a Torrens unit is needed (slack = 0) | **1.36%** | **49.39%** |
| one departure from needing Torrens (slack ≤ 1) | 15.71% | 73.19% |

This is the order-of-magnitude gap in the registration's motivation, decomposed: on *declared
availability* the SA rival fleet covers the minimum-synchronous standard 98.6% of the time (the
pex world, 1.36%); on *actual commitment* the system needs a Torrens unit **half of all
half-hours**. Directed time (~23% of the sample) sits between the two margins — directions are
triggered by commitment shortfalls, not availability shortfalls. Slack distributions:
availability slack is concentrated at 2–3 departures (median 3); commitment slack at 0–1
(median 1).

## Forecast slack (the operator's ex-ante view)

| horizon | slack_fc = 0 | slack_fc ≤ 1 | cor with slack_commit |
|---|---|---|---|
| 1 h | 1.27% | 19.15% | 0.661 |
| 4 h | 0.94% | 15.35% | 0.578 |
| 8 h | 0.94% | 15.38% | 0.572 |

The forecast slack tracks the availability margin (bids declare availability, not commitment),
tightened at 1 h by the slow-start rule — the 1h zero-rate (1.27%) exceeds 4h/8h (0.94%)
because offline Pelican/Osborne stop counting inside their start window. Non-sync forecast
coverage is effectively complete (realized fallback ≤ 0.03% of rows). Consistency check:
final-run PREDISPATCH rival unit counts correlate 0.66 with the availability slack (coarse —
counts vs depth; both objects derive from the same lodged bids by construction).

## Handoff to Stage 2 (one definition fixed before estimation)

The five-bucket decomposition's "requirement failure" and the hazard's "core need" use
**slack_commit = 0** (the operator directs units to be *on*; the commitment margin is the
operative one — see the table above), with slack_avail = 0 reported as the strict-availability
sensitivity. The hazard's registered workhorse (minimum forecast slack over the commitment lead
window) uses `slack_fc_{1,4,8}h` as built. This choice is stated here, before any Stage-2
estimation code, per the stage-gate discipline.
