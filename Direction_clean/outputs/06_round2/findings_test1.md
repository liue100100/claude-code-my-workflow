# Round 2, Test 1 findings — the floor-reach decomposition of RQ2

Registered before estimation: `06_round2/test1_preregistration.md` (commit c21789e). Script
`06_round2/test1_floor_reach.R`; tables `test1_{gate,gate_months,results_full,interaction,wcb}.csv`.
Design = the exact Stage-4 specification; only the dependent variable changed.

## Power gate (reported first, as registered): PASS
Pooled essential-row reach rate 10.1% (rule: 5–95%); 13 essential-bearing months show both reach
states (rule: ≥ 8). Level composition, base matched sample: Torrens essential intervals have the
floor within reach in 4.2–10.8% of rows vs 18.7–21.2% in matched comparison rows; PPCCGT the
reverse (84.9% vs 59.3%). Note: `reach_a` and `reach_b` coincide exactly — the floor block, when
offered, sits at the −$1,000 band, below both cheap thresholds, so the eligibility measure is
definition-invariant. (Sample note: base-filter matched rows 140,259 = Stage 4 exactly; the
11,120 essential base rows vs Stage 4's quoted 12,513 is the suspension-window mass, excluded
from the base sample in both analyses.)

## Result: the dose response lives entirely on the eligibility margin

Essential × compensation price (per $100/MWh), base sample:

| Outcome | Estimate | Analytic p | WCB p (Rad/Webb) | June treatments |
|---|---|---|---|---|
| **reach (floor within dispatch's reach)** | **−0.0855** | 0.003 | 0.0028 / 0.0026 | −0.076 to −0.088, p 0.001–0.014 |
| intensive (share, reach = 1 subsample) | +0.005 / −0.019 | 0.79 / 0.55 | 0.54–0.79 | null in all four |

## Adjudication: committed interpretation 1 applies (verbatim from the registration)
"Interaction negative and significant on `reach` (both definitions, surviving WCB, stable across
June treatments): the dose response lives on the direction-eligibility margin — the
payment-seeking reading is confirmed on exactly the margin the mechanism requires. The paper
keeps its headline and adds the mechanical stance paragraph (S5.1)."

The intensive-margin null sharpens this beyond what interpretation 1 required: conditional on the
floor being within reach, offered depth shows NO response to the compensation price. The entire
Stage-4 share response is the eligibility margin diluted by unresponsive intensive variation —
which is also why the share coefficient (−0.051) is smaller than the reach coefficient (−0.086).
In direction terms: what scales with the payment is the probability that the unit is in the
order-only posture — self-commitment of the minimum-stable quantum withdrawn from dispatch's
reach — on the intervals where that posture converts into a paid direction. Not how much extra
capacity is offered when the unit is willing to run.

## Magnitude
Against a base essential-row reach rate of ~10% (comparison ~21%), −8.6 pp per $100/MWh is a
large semi-elasticity; across the observed $121–378 month range it spans more than the entire
baseline gap. The attenuation caveat (realised-state classification) carries over unchanged.

## Carried caveats
Cross-month identification and its fuel-stress confound are NOT addressed by this test — that is
Test 2 (roll-off event study) and Test 3(b) (horse race), per the approved plan. This test answers
one question only: WHICH margin carries the dose response. Answer: the one that triggers and is
paid by directions.

**STOP — registered test complete and adjudicated. Test 2 next per the approved plan.**
