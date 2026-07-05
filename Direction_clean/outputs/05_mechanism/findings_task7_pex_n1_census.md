# Ex-ante N-1 essentiality (pex_n1) -- build and census (NO test run)

Build: `task7_pex_n1_census.R`; panel `task7_pex_n1_panel.rds`; day table
`task7_label_census.csv`. Definition: zero the focal station out of the AVAILABLE fleet,
remove one unit of the largest-per-unit-MW available RIVAL station (the ex-ante mirror of
piv_n1's largest-online-unit convention); essential iff no applicable minimum combination
survives. Rivals-only by construction; strictly nests the current label (every pex interval is
pex_n1 -- verified, zero exceptions). Worst-case variant (depth_ex <= 1: ANY single rival
outage) reported alongside. **Construction validated: the recomputed pex matches the existing
panel interval-for-interval (0.0000% mismatch, both stations).**

## The census

| | Current pex (N-0) | **pex_n1 (N-1, largest-unit)** | depth_ex <= 1 (worst case) |
|---|---|---|---|
| Torrens interval rate | 1.29% | **12.41%** | 15.42% |
| Pelican interval rate | 0.08% | **2.64%** | 3.24% |
| Essential unit-days (>= 1h rule, of 4,384) | 186 | **1,290** | 1,406 |
| CLEAN essential unit-days | 80 | **606** | 651 |
| Per unit (Torrens each / PPCCGT) | 60 / 6 | **392 / 114** | 424 / 134 |
| Withdrawal (A) events among essential days | 109 | **896** | -- |
| ...among CLEAN essential days | 64 | **491** | -- |

- The relaxation is a strict superset: pex-and-n1 overlap 186, n1-only 1,104, pex-only 0.
- **Leakage audit** (day flag on own day-max MAXAVAIL / own cheap MW): R-squared 0.004-0.016
  for Torrens, 0.010-0.034 for PPCCGT -- effectively rivals-only, though PPCCGT's 0.034 is a
  notch above the old audit's 0.000-0.003 benchmark; reported, not hidden.

## What this buys, and the rule that binds
The binding constraint of every gated test this project has stopped at -- thin clean essential
cells (80 days; 20 in the final gate; 0 in the break window) -- relaxes by a factor of ~7.6,
and PPCCGT moves from untestable (3-6 days) to 110 clean essential days. The assumption doing
the work is the operator's own: AEMO runs the system to the secure N-1 standard, and the
corrected-clock decomposition shows that standard explains 98.4% of actual directions -- so
"needed under the credible contingency" is arguably the RIGHT definition, not a loosening.

**No test was run.** Adopting pex_n1 for any re-test of adjudicated questions (RQ1/RQ2, the
exit-act gate, the break design) requires a fresh pre-registration that fixes the label, the
day rule, and the interpretations before estimation -- per the standing discipline and the
interpretation note's boundary.

**STOP -- census complete. The label choice and any re-registration are the author's call.**
