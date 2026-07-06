# Round 2, Test 3 findings — supporting battery, adjudicated

Registered before estimation: `06_round2/test3_preregistration.md` (commit 8ed73e1). Scripts
`test3_battery.R` + `test3c_gate_corrected.R`; tables `test3*.csv` in outputs/06_round2/.

## 3a — Month-grain regression: CONFIRMED (committed reading 1)
Monthly essential-vs-matched gap in floor-reach on the compensation price, 19 months (≥30
essential rows), WLS by essential mass: **slope −0.0964 per $100/MWh (HC1 p = 0.0012)** —
statistically significant at the grain the referee trusts, and matching the interval-level
Test-1 estimate (−0.0855) within one standard error. The interval result survives aggregation.

## 3b — Fuel horse race: intermediate; the softened language stands
Both interactions in the Stage-4 base specification (cor(d_t, gas) ≈ 0.48 across months):

| Outcome | essential × comp price | essential × gas |
|---|---|---|
| reach | −0.0455 (p 0.26; WCB 0.25–0.26) — 53% of Test-1 magnitude | −0.0061 (p 0.094) |
| share | **−0.0535 (p 0.013)** — full Stage-4 magnitude | +0.0003 (p 0.85) |

Adjudication against the committed readings: reading (ii) — the adverse one, fuel displaces the
payment channel — **did not fire** (no collapse: magnitude retained ≥ half; p ≤ 0.30; gas not
significant at 5% anywhere, and dead zero on the share). Reading (i) is met on the share
outcome outright, but not on reach (magnitude retained, significance lost). The honest summary:
on the eligibility margin the two monthly series split the variance and neither is individually
significant — a conditional horse race between series correlated at 0.48, identified off 21
essential-bearing months, cannot separate them; on the share margin the payment channel wins
cleanly and gas carries nothing. The Test-2 timing design (which separates the channels by WHEN
they moved rather than by conditioning) remains the sharper instrument, and the two tests agree:
the softened "consistent with payment-seeking" language stands — neither restored to full
strength nor further weakened.

## 3c — Placebo unit: INFEASIBLE, on corrected grounds
**Correction reported, not hidden:** the battery script's first inventory hard-coded the flag
list and wrongly marked five stations flag-less; the pivotality panel in fact carries station
flags for Quarantine, Dry Creek, Mintaro, Barker Inlet, and Snapper Point. The corrected gate
(`test3c_gate_corrected.R`, `test3c_gate_corrected.csv`) evaluates them properly and all fail
criterion 3 by two orders of magnitude — essential intervals over 36 months: Quarantine 39,
Dry Creek 27, Mintaro 45, Barker Inlet 39, Snapper Point 0, against the registered 500 minimum
(Torrens: 4,083) — and most also fail criterion 4 (direction events: Mintaro 236, Quarantine 55,
Dry Creek 54). The infeasibility is structural, and worth a sentence in the paper: essentiality
in this system concentrates on exactly the units the direction channel pays, so an
often-essential-but-never-paid placebo does not exist. The treatment and the absence of a
placebo have the same cause.

## 3d — Inference upgrade: Test-1 inference ROBUST (committed reading 1, at the margin)
`fwildclusterboot` is source-only on CRAN/r-universe for this environment (no compilation
toolchain) — the registered fallback ran: randomization inference permuting the month-to-price
assignment (999 draws, seed 20260705) on the Test-1 base reach regression.
**Two-sided RI p = 0.0460** (45 of 999 permuted |coefficients| ≥ |−0.0855|). Under the committed
reading, the eligibility-margin estimate survives inference that imposes the null by
construction — reported exactly, with the value's proximity to 0.05 stated rather than rounded
away. Upgrade path unchanged: Rtools + null-imposed WCB before submission.

## Net effect on the manuscript (feeds the Test-4 writing batch)
(1) §6 gains the month-grain slope and the RI p-value beside the Test-1 result; (2) §8 gains the
horse race with its honest split; (3) the placebo paragraph states structural infeasibility;
(4) no change to the Test-2 adjudication: headline retained on the eligibility margin,
cross-month causal language "consistent with payment-seeking."

**STOP — battery complete and adjudicated. Test 4 (writing batch) is the remaining plan item.**
