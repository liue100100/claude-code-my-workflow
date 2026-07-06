# Test 3 pre-registration — supporting battery (month-grain, horse race, placebo gate, inference)

**Committed BEFORE any estimation code for this battery is written or run.** Plan of record:
`quality_reports/plans/2026-07-06_round2-referee-response.md`. These are supporting diagnostics:
the headline decision rule was fixed in the plan and executed by Tests 1–2 (headline retained on
the eligibility margin; cross-month causal language softened to "consistent with
payment-seeking"). Nothing below re-opens that adjudication; committed readings state what each
diagnostic adds or subtracts.

## 3a — Month-grain regression (the referee's 36-point object)
Monthly essential-vs-matched gap in `reach` (base sample, CEM-matched, months with ≥ 30
essential rows — the Stage-4 figure rule), regressed on the monthly compensation price, weighted
by essential rows; HC-robust SEs (months are the units; no clustering below month exists).
**Readings:** negative and significant slope = the interval result survives aggregation to the
grain the referee trusts; insignificant with consistent magnitude = power note (~20 points), the
interval estimate stands as primary; sign flip = flagged prominently as an aggregation
inconsistency requiring investigation before submission.

## 3b — Fuel horse race
Stage-4 base specification (reach primary, share co-primary) with BOTH interactions:
`essential x comp_price_100 + essential x gas_gj` (gas = the STTM Adelaide monthly price already
on the panel; the spot-fuel margin is NOT used — spot is an outcome of conduct, a bad control).
Known collinearity input: cor(d_t, gas) ≈ 0.48 across months. **Readings:** (i) comp-price
interaction retains ≥ half its Test-1 magnitude and analytic p < 0.10 with gas present → the
confound does not displace the payment channel; reported as supporting. (ii) comp-price
interaction collapses (|estimate| < half Test-1's, or p > 0.30) while essential x gas is
negative and significant → the fuel channel absorbs it; the manuscript's softened language is
further weakened to "cannot be separated from fuel-stress co-movement" (this weakens the paper
and is reported with the same prominence). (iii) both interactions material → shared variance
stated; softened language stands. WCB (vcovBS, Rademacher + Webb, R = 999) on the comp-price
interaction, base case.

## 3c — Placebo unit (feasibility gate; committed criteria, not named units)
Inventory the bid cache and existing flags. A credible placebo unit must satisfy ALL of:
(1) complete bid-ladder coverage 2022–2024 in the existing cache; (2) a rivals-only
essentiality-type flag already constructed (no new flag construction inside this registration);
(3) ≥ 500 essential unit-rows on the matched design; (4) materially outside the direction
channel (< 5% of the unit's essential intervals under direction over the sample).
**Committed handling:** if no unit passes all four, the placebo is reported INFEASIBLE with the
inventory table — an honest limitation, not a forced test. (Known from the record: OSB-AG fails
(3) with 18 essential intervals and is itself directed; the three Torrens units and PPCCGT are
the treatment set.) No new essentiality flags are built under this registration.

## 3d — Inference upgrade on the Test-1 primary estimate
First choice: `fwildclusterboot` (null-imposed WCB) from the maintainer's r-universe binary
repository, applied to the Test-1 base-case reach regression (Rademacher + Webb, B = 9,999,
cluster = month). If the package cannot be installed as a binary in this environment (no
compilation toolchain), fall back to randomization inference, committed as: permute the
month-to-comp-price assignment across the 36 sample months uniformly (999 draws, seed 20260705),
re-estimate the base-case reach interaction per draw, two-sided RI p = share of |b_perm| ≥
|b_obs| (add-one). **Readings:** null-imposed/RI p < 0.05 = the Test-1 inference is robust to
the bootstrap-variant critique (MC6/RO4 answered); p in [0.05, 0.10] = reported alongside the
analytic and unrestricted-WCB values, inference caveat retained in text; p > 0.10 = the
inference caveat is escalated in the manuscript (the eligibility-margin claim carries it
visibly). Applies to the Test-1 estimate because it is the manuscript's sharpest number.

## Not licensed
No outcome or window changes; no additional interactions beyond 3b's two; no placebo flag
construction. Follow-ups need a fresh registration.
