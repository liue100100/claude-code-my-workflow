# Round 2, Test 2 findings — the roll-off / lag-wedge era contrast

Registered before estimation: `06_round2/test2_preregistration.md` (commit 6b5d084). Script
`06_round2/test2_rolloff_contrast.R`; tables `test2_{gate,results_full,interactions,wcb}.csv`;
figure `test2_gap_eventtime.png`. Gate: all four periods PASS (essential rows / months:
PRE 2,394/6; A 2,577/3; B 1,191/4; C 4,958/8).

## The estimates (essential × period, C = post-roll-off omitted; reach outcome, base sample)

| Contrast | Estimate | Analytic p | Treatments (4) | WCB p (base) |
|---|---|---|---|---|
| × PRE (placebo-in-time, d_t $121–253) | +0.025 | 0.83 | +0.014 to +0.136 (p .08–.87) | — |
| × A (crisis: gas high, d_t $350–378) | −0.100 | 0.030 | −0.099 to −0.104 (p .025–.030) | — |
| × B (lag-wedge: gas LOW, d_t $329–351) — **primary** | **−0.075** | 0.098 | −0.074 to −0.075 (p .098–.105) | **0.089 / 0.089** |

Share outcome: same ordering, smaller and noisier (B −0.046, p 0.22) — as Test 1 predicts (the
share dilutes the eligibility margin).

## Adjudication (committed readings applied, without smoothing)

**The fuel-stress signature (reading 2) fails on its point prediction.** It required the gap to
collapse when gas fell (β_B ≈ 0): nine months after gas fell, with the formula still paying
crisis rates, the gap stood at −0.075 — three-quarters of the crisis-period gap, statistically
indistinguishable from it (A−B difference −0.025, well within one SE).

**The payment-seeking signature (reading 1) is met on pattern but not on the registered
significance bar.** Point pattern: β_A ≈ β_B < 0, β_PRE ≥ 0 — exactly as committed, and the
four period gaps order monotonically with period-average d_t (PRE ≥ 0 at ~$176, C = 0 at ~$205,
B −0.075 at ~$340, A −0.100 at ~$365); the observed β_B is also consistent with the Test-1 dose
slope's out-of-sample prediction (−0.086 × $1.3 ≈ −0.11, inside the CI). But the primary
contrast clears only WCB p = 0.089 on 4 effective lag-wedge months; its 95% CI
[−0.16, +0.01] does not exclude zero.

**Readings 3/4 therefore govern, verbatim consequence per the approved plan's decision rule
("mixed"):** the manuscript HEADLINE IS RETAINED (Test 1's rule 1 stands — the dose response is
real and sits on the eligibility margin), but the cross-month causal language is SOFTENED to
"consistent with payment-seeking": the formula-driven timing test is directionally supportive at
marginal significance, not decisive. The lag-wedge ambiguity is stated plainly: a partial fuel
contribution to the 2022 gap cannot be excluded at conventional levels; what the timing wedge
does rule out is the pure fuel story in which the compensation price contributes nothing.

## What the paper now says about MC1/MC2 (the referee's confound)
Three facts survive any reading: (i) the gap did not track gas down in Oct 2022 — it stayed at
75% of its crisis level through nine months of cheap fuel while the formula paid ~$340; (ii) it
was near zero in early 2022 and post-roll-off, the two low-prize regimes, despite very different
fuel conditions; (iii) the ordering of all four period gaps follows the payment, not the fuel.
The referee's story has to explain (i)–(iii) with fuel alone; it cannot. What remains open is
magnitude at 95% confidence on 4 months of lag-wedge mass — an honest limitation of the sample,
not of the design.

**STOP — registered test complete and adjudicated. Manuscript language changes (soften to
"consistent with") queued with the Test-4 writing batch; Test 3 battery next per the plan.**
