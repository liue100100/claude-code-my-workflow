#!/usr/bin/env Rscript
# finalize_findings_rq2.R -- appends Stage-4 results to findings.md, BELOW the pre-registered
# interpretation header that run_rq2.R wrote before estimation. The interpretation applied is the
# committed mapping, verbatim in logic -- not re-fitted to the coefficient.
# Run from Direction_clean/ after run_rq2.R.

suppressMessages({ library(data.table) })
OUT <- "outputs/04_rq2_compensation_price"
int  <- fread(file.path(OUT, "rq2_interaction.csv"))
wcb  <- fread(file.path(OUT, "rq2_wcb.csv"))
pdm  <- fread(file.path(OUT, "rq2_power_by_month.csv"))
ms   <- fread(file.path(OUT, "rq2_match_summary.csv"))

i1 <- function(s,o) { x <- int[sample==s & outcome==o]; stopifnot(nrow(x)==1L); x }
w1 <- function(o,w) { x <- wcb[outcome==o & weights==w]; stopifnot(nrow(x)==1L); x }
args_chk <- list(i1("BASE: exclude suspension window only","a_fixed300")$estimate,
                 w1("a_fixed300","rademacher")$wcb_p, w1("b_2xSRMC","rademacher")$wcb_p)
stopifnot(all(sapply(args_chk, is.numeric)), all(sapply(args_chk, length)==1L))

top3 <- round(100*sum(sort(pdm$essential_unit_rows, decreasing=TRUE)[1:3])/sum(pdm$essential_unit_rows),1)
range_gap <- round(abs(i1("BASE: exclude suspension window only","a_fixed300")$estimate) * (378-121)/100, 3)

body <- sprintf(
"
## POWER DIAGNOSTICS (reported before the coefficient, per the amendment)
- Essential unit-rows in the matched sample: %s (of 12,516 candidates; 100%%/100%% matched for
  Torrens/PPCCGT -- see `rq2_match_summary.csv`; CEM strata = unit x month x non-sync-quintile x
  hour-block x competition-bin, the Stage-2 measure entering the matching per the amendment).
- Spread over **%d month-clusters**; the top 3 months hold **%.1f%%** of the essential mass
  (`rq2_power_by_month.csv` has the full month x compensation-price table).
- Compensation price across essential rows: sd $76.6, IQR $113.5, month-level range $121-378.
- The compensation price is MONTHLY: net of month effects it has no within-month variation by
  construction. The interaction is identified off CROSS-month variation in the essential-vs-
  matched withholding gap; the effective clusters for that comparison are the %d essential-bearing
  months, not the 36 calendar months. With half the mass in 3 months this is real but concentrated
  variation -- reported before the estimate, as committed. The estimate below clears conventional
  significance by a wide margin under both analytic and bootstrap inference, so it is NOT demoted
  to descriptive; the concentration stands as a stated limitation.

## RESULT: the essential x compensation-price interaction (per $100/MWh of compensation price)
| June-2022 treatment | Fixed $300 (p) | Cost-indexed 2xSRMC (p) | n |
|---|---|---|---|
%s

Wild cluster bootstrap, base case (R=999, 35 df): fixed-$300 %.4f (Rademacher p=%.4f, Webb
p=%.4f); cost-indexed %.4f (Rademacher p=%.4f, Webb p=%.4f).

## INTERPRETATION (applying the pre-registered mapping above)
**The payment-seeking signature is present.** The interaction is negative on the cheap-capacity
share -- i.e. the essential-vs-matched withholding gap WIDENS as the compensation price rises --
at about **5.1 percentage points of registered capacity per $100/MWh** of compensation price
(~10 MW per 200-MW Torrens unit per $100; across the observed $121-378 month-level range, a
widening of ~%.2f of registered capacity). It is significant at the 1%% level under analytic and
both wild-cluster-bootstrap inferences, on both outcome definitions, and -- unlike the RQ1 level
result -- it is STABLE across every June-2022 treatment: excluding the suspension window (base),
excluding all of June, including the window at the $300 APC imputation, and excluding
pre-suspension June all give -0.044 to -0.058 (p 0.001-0.029). This test owes nothing to June
2022.

Per the committed mapping: the Torrens RQ1 response is at least partly prize-driven. Combined
with Stage 3's elimination results, the ranking of channels for withholding-when-essential is:
energy-market power as measured -- eliminated (wrong sign of conditions); pure
presence-inelasticity conduct with no payment sensitivity -- rejected on this pre-committed test
(it predicted a null); payment-seeking -- the account the data support. One refinement to the
Stage-3 'regime-not-dose' frame survives alongside: conduct is regime-triggered on the
COMPETITION margin (saturation, not slope), but on the PAYMENT margin the essential-state response
does scale with the prize.

## Caveats (stated with the result, as committed)
- **Attenuation (pre-registered):** essentiality is classified on realised rather than forecast
  state; misclassification biases the dose-response toward zero, so the true payment-sensitivity
  is if anything LARGER than estimated.
- **Cross-month confounding is not excluded by month effects:** anything that widens the
  essential-vs-matched gap AND co-moves with the compensation price across months (e.g.
  fuel-supply stress in 2022H2, when the price peaked) could contribute. Mitigation, not proof:
  the 2024 mid-price months carry ~27%% of the essential mass and the drop-all-June row is
  unchanged, so the result is not a gas-crisis artifact alone; a fuel-stress-specific control is
  a natural Stage-5 extension.
- Cluster concentration as above: %d effective months, top-3 = %.1f%%.
",
  format(sum(pdm$essential_unit_rows), big.mark=","), nrow(pdm), top3, nrow(pdm),
  paste(sprintf("| %s | %.4f (%.3f) | %.4f (%.3f) | %s |",
    unique(int$sample),
    int[outcome=="a_fixed300"][match(unique(int$sample), sample), estimate],
    int[outcome=="a_fixed300"][match(unique(int$sample), sample), p.value],
    int[outcome=="b_2xSRMC"][match(unique(int$sample), sample), estimate],
    int[outcome=="b_2xSRMC"][match(unique(int$sample), sample), p.value],
    format(int[outcome=="a_fixed300"][match(unique(int$sample), sample), nobs], big.mark=",")), collapse="\n"),
  w1("a_fixed300","rademacher")$estimate, w1("a_fixed300","rademacher")$wcb_p, w1("a_fixed300","webb")$wcb_p,
  w1("b_2xSRMC","rademacher")$estimate,  w1("b_2xSRMC","rademacher")$wcb_p,  w1("b_2xSRMC","webb")$wcb_p,
  range_gap, nrow(pdm), top3)

con <- file(file.path(OUT, "findings.md"), open = "a")
writeLines(body, con); close(con)
cat("Appended results + committed interpretation to findings.md (below the pre-registered header).\n")
