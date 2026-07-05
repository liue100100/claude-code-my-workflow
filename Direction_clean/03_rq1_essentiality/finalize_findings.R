#!/usr/bin/env Rscript
# finalize_findings.R -- Stage 3 findings, generated from the saved result tables.
# Split out of run_rq1.R after its in-line findings sprintf crashed post-WCB (the expensive
# estimation all completed; only the report text failed). Separating report generation from the
# ~1h estimation run also means findings edits never require re-estimating.
# Run from Direction_clean/, after run_rq1.R (and _fix_webb_rows.R, if applicable).

suppressMessages({ library(data.table) })
OUT <- "outputs/03_rq1_essentiality"
core <- fread(file.path(OUT, "rq1_core_results.csv"))
wcb  <- fread(file.path(OUT, "rq1_wcb.csv"))
hl   <- fread(file.path(OUT, "rq1_headline_comparison.csv"))
rob  <- fread(file.path(OUT, "rq1_robustness.csv"))
D_n  <- nrow(readRDS(file.path(OUT, "regression_panel.rds")))

ess <- core[term=="essentialTRUE"]
g1 <- function(o,m) ess[outcome==o & model==m]
w1 <- function(o,m) wcb[outcome==o & model==m & weights=="rademacher"]
sat_a <- core[outcome=="a_fixed300" & model=="M3" & term=="saturatedTRUE"]
slp_a <- core[outcome=="a_fixed300" & model=="M3" & term=="slope_kernel"]
r1 <- function(lbl,o,m) rob[row==lbl & outcome==o & model==m]
jsp <- fread(file.path(OUT, "stage3b_june_split.csv"))   # Stage-3b three-way June split (Torrens, M3)
js <- function(v,o) { x <- jsp[variant==v & outcome==o]; stopifnot(nrow(x)==1L); x }

# class audit -- identifies which argument type crashed the original in-line sprintf
args_num <- list(g1("a_fixed300","M1")$estimate, w1("a_fixed300","M1")$wcb_p,
                 g1("a_fixed300","M3")$estimate, w1("a_fixed300","M3")$wcb_p,
                 hl[outcome=="a_fixed300", pct_change_M1_to_M3],
                 g1("b_2xSRMC","M1")$estimate, w1("b_2xSRMC","M1")$wcb_p,
                 g1("b_2xSRMC","M3")$estimate, w1("b_2xSRMC","M3")$wcb_p,
                 hl[outcome=="b_2xSRMC", pct_change_M1_to_M3],
                 slp_a$estimate, slp_a$p.value, sat_a$estimate, sat_a$p.value)
cat("Class audit of numeric sprintf args:", paste(sapply(args_num, class), collapse=", "), "\n")
cat("Length audit:", paste(sapply(args_num, length), collapse=", "), "\n")
stopifnot(all(sapply(args_num, is.numeric)), all(sapply(args_num, length) == 1L))

reading <- sprintf(paste0(
"Pooled across the four test units, being essential moves the cheap-capacity share by %.3f ",
"(fixed-$300 definition; WCB p=%.2f -- a precise null) and %.3f (cost-indexed; WCB p=%.2f -- ",
"negative but not significant). The M1->M3 movement is tiny (%.1f%%/%.1f%%): whatever essentiality ",
"response exists is NOT absorbed by the local energy-market competition control, consistent with ",
"the Stage-2 gate finding that essentiality and energy-market competition are nearly orthogonal. ",
"BUT the pooled numbers mask heterogeneous unit responses (robustness table + the Stage-3b ",
"close-out diagnostics, `findings_3b.md`): TORRENS withholds more when essential (%.3f fixed / ",
"%.3f cost-indexed, analytic p=%.2f/%.2f), and the Stage-3b leave-one-month-out path shows the ",
"coefficient NEGATIVE IN ALL 72 re-estimates -- a stable, borderline-significant response. ",
"PELICAN POINT's ostensibly positive response (%.3f, p=%.2f) DOES NOT SURVIVE the same ",
"diagnostic: dropping October 2023 alone flips its sign -- a one-month artifact, withdrawn as a ",
"substantive finding (footnote-level at most). On the June-2022 dependence of the Torrens result, ",
"the Stage-3b three-way split refines the earlier caveat: the coefficient survives dropping the ",
"suspension window alone (%.3f, p=%.2f cost-indexed) and dropping the pre-suspension fortnight ",
"alone (%.3f, p=%.2f); only removing ALL of June -- 19%% of Torrens's essential unit-rows -- ",
"degrades it (p=%.2f/%.2f). The dependence is on June's essential-interval MASS (statistical ",
"power), not on suspension-era administered-price conduct. (Within Torrens-only, SRMC drops out ",
"by collinearity with the month effects -- one station, one monthly SRMC.)"),
  g1("a_fixed300","M3")$estimate, w1("a_fixed300","M3")$wcb_p,
  g1("b_2xSRMC","M3")$estimate,  w1("b_2xSRMC","M3")$wcb_p,
  hl[outcome=="a_fixed300", pct_change_M1_to_M3], hl[outcome=="b_2xSRMC", pct_change_M1_to_M3],
  r1("Torrens only","a_fixed300","M3")$estimate, r1("Torrens only","b_2xSRMC","M3")$estimate,
  r1("Torrens only","a_fixed300","M3")$p.value,  r1("Torrens only","b_2xSRMC","M3")$p.value,
  r1("PPCCGT only (no unit FE possible)","a_fixed300","M3")$estimate,
  r1("PPCCGT only (no unit FE possible)","a_fixed300","M3")$p.value,
  js("drop suspension window only","b_2xSRMC")$estimate,
  js("drop suspension window only","b_2xSRMC")$p.value,
  js("drop pre-suspension June only","b_2xSRMC")$estimate,
  js("drop pre-suspension June only","b_2xSRMC")$p.value,
  js("drop all of June 2022","a_fixed300")$p.value,
  js("drop all of June 2022","b_2xSRMC")$p.value)

findings <- sprintf(
"# Stage 3 findings -- RQ1: do generators withhold more when essential? (Direction_clean/)

Sample: TORRB2/3/4 + PPCCGT, %s rows. OSB-AG excluded (18 essential intervals; descriptive only).
Unit + month fixed effects; controls: SRMC, regional demand, non-synchronous generation (LEVEL,
MW), spot price. Cluster: month (36). Full tables: `rq1_core_results.csv`, `rq1_wcb.csv`,
`rq1_robustness.csv`; figure: `rq1_coefficient_plot.png`.

## Documented deviation: non-sync LEVEL instead of SHARE
The spec asked for the non-synchronous share, but SA regional demand crosses zero in-sample
(rooftop solar; 1,524 interval-rows at or below zero), so the share explodes and flips sign around
the crossing (observed range [-24,529, +9,041]). A control with a zero-crossing denominator is
statistically indefensible; the primary spec uses the non-sync level with demand entering
separately, and the share version is a robustness row restricted to demand > 500 MW. The switch
MATTERS: with the broken share control the essentiality coefficients were inflated ~10x (-0.062 /
-0.107) -- a few thousand extreme-leverage rows were doing the work. Reported, not hidden.

## Sign convention (read this first)
The outcome is the CHEAP-CAPACITY SHARE of registered capacity -- higher = LESS withholding, so a
NEGATIVE essentiality coefficient = more withholding when essential. The competition measure
(residual-demand slope) is <= 0: more negative = MORE competition; exactly zero ('saturated') =
rivals saturated = LEAST competition.

## Headline: the essentiality coefficient, without vs. with the competition control
| Outcome definition | M1 (no control) | M3 (with control) | Movement |
|---|---|---|---|
| Fixed $300 | %.4f (WCB p=%.3f) | %.4f (WCB p=%.3f) | %+.1f%% |
| Cost-indexed 2xSRMC | %.4f (WCB p=%.3f) | %.4f (WCB p=%.3f) | %+.1f%% |

## In words
%s

## The competition control itself (M3, fixed-$300 outcome)
- Continuous slope: %.6f (p=%.3f) -- carries essentially nothing.
- **Saturated indicator: %.4f (p=%.5f)** -- when rivals are locally saturated (maximum market
  power), the unit offers ~3.2 percentage points less of its registered capacity cheaply. This is
  the strongest conduct correlate in the model, and it vindicates the Stage-2 gate flag: the
  competition-conduct relationship lives almost entirely at the zero-slope mass point, not in the
  continuous part of the measure.

## Named finding: essentiality is not scarcity -- the market-power alternative predicts the WRONG SIGN of conditions
Essential periods carry MORE rival energy supply near the clearing price, not less: for Torrens
the residual-demand slope averages -5.04 MW per $/MWh in essential intervals vs -3.31 in
non-essential ones (steeper = rivals more responsive = more competition; Stage-2
`distribution_by_essentiality.csv`), and the overall correlation between the competition measure
and essentiality is -0.04. The reason is structural: essentiality is a system-SECURITY condition
that fires in high-renewables, low-demand periods -- typically cheap-energy periods with plenty of
rival capacity near the (low) clearing price -- whereas energy-market power fires in scarcity.
This is stronger than 'the control does not move the coefficient': the energy-market-power
account of withholding-when-essential predicts essential periods should be TIGHT, and they are
measurably the opposite. The alternative fails on the sign of conditions, not just on magnitude.

## Named finding: conduct responds to regimes, not doses
Both measured conduct margins in this stage are DISCRETE regime responses, not dose-responses:
- Competition: conduct moves with the regime of facing no local competition at all (saturated
  indicator, -3.2 pp, p<0.001) and not at all with the degree of competition when some exists
  (continuous slope, p=0.99).
- Essentiality: the response (where present, i.e. Torrens) is to the essential/not-essential
  state; whether it scales with what essentiality PAYS is exactly RQ2's dose question.
This shape is what a regime-triggered ('insurance') model of conduct predicts -- maintain a
standing withheld posture whenever the regime makes it valuable, regardless of the marginal payoff
that interval -- and is not what interval-level payoff optimisation predicts (which would produce
smooth responses in the continuous measures). It sets the interpretive frame for Stage 4: under
the insurance account, the compensation-price coefficient should be near zero even if the Torrens
essentiality response is real; under payoff optimisation, it should be positive.

## Inference notes (documented deviations, not hidden)
- Wild cluster bootstrap via `sandwich::vcovBS` (Rademacher primary; Webb sensitivity in
  `rq1_wcb.csv`), R=999, t with 35 df. `fwildclusterboot` (the null-imposed boottest
  implementation) cannot be installed here (archived from CRAN, no Windows binary, no Rtools for
  source compilation); vcovBS is the UNRESTRICTED wild cluster bootstrap -- second-order different
  at 36 clusters, but a real caveat. Upgrade path: install Rtools + fwildclusterboot.
- R=999 replicates rather than the 9,999 first planned (each replicate is O(n) in pure R on a
  1.26M-row design; 999 is the standard applied choice). WCB and analytic p-values agree closely
  throughout, as expected at 36 clusters.
- A bug in the first WCB pass made the Webb rows Rademacher duplicates (sandwich selects the
  weight family via `type=`, and silently swallowed a `wild=` argument); caught via bit-identical
  SEs, recomputed correctly (`_fix_webb_rows.R`).
- The identical specification was re-estimated by lm() with explicit dummies for the bootstrap and
  the essentiality coefficient asserted equal to the fixed-effects estimate (passed, all 6 models).

## What this stage eliminated, and what remains (the elimination logic, stated precisely)
What Stage 3 eliminated is energy-market power AS MEASURED by the local residual-demand slope --
it explains essentially none of the essentiality response, and (per the named finding above) it
predicts the wrong sign of conditions. That does NOT leave compensation-seeking as the only live
channel. A third channel remains: SECURITY-DIMENSION INELASTICITY -- when the minimum-synchronous
constraint binds, demand for the unit's PRESENCE is perfectly inelastic regardless of
energy-market conditions, and a unit can withhold on that position for reasons unrelated to the
compensation price (bargaining posture, avoiding uncompensated must-run commitment, standing
policy). The energy-space competition measure cannot see this channel, because this channel IS
the essentiality flag. So RQ1's residual is: **either payment-seeking, or presence-inelasticity
conduct that the payment does not drive.** RQ2 (Stage 4) is the test that splits those two --
withholding that sorts on the compensation price is payment-seeking; withholding that responds to
the essential state but not its price is presence-inelasticity conduct. Stage 4 must treat June
2022 with segment-level care (see `findings_3b.md`) given its role in the Torrens result.
",
  format(D_n, big.mark=","),
  g1("a_fixed300","M1")$estimate, w1("a_fixed300","M1")$wcb_p,
  g1("a_fixed300","M3")$estimate, w1("a_fixed300","M3")$wcb_p,
  hl[outcome=="a_fixed300", pct_change_M1_to_M3],
  g1("b_2xSRMC","M1")$estimate, w1("b_2xSRMC","M1")$wcb_p,
  g1("b_2xSRMC","M3")$estimate, w1("b_2xSRMC","M3")$wcb_p,
  hl[outcome=="b_2xSRMC", pct_change_M1_to_M3],
  reading,
  slp_a$estimate, slp_a$p.value, sat_a$estimate, sat_a$p.value)
writeLines(findings, file.path(OUT, "findings.md"))
cat("Saved findings.md.\n")
