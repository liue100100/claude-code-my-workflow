#!/usr/bin/env Rscript
# wo_stage3_threshold_dt.R  --  Stage 3 of the withhold-to-be-directed design.
#
# Two independent, previously-blocking decisions, both resolved this session:
#   (A) Threshold sweep -- how sensitive is the withheld/as-usual classification (Stage 2's
#       sense-check) to the cheap300 cutoff? Sweep a fixed grid alongside each unit's empirical
#       trough (the headline default, from wo_stage2_opportunity.R TROUGH).
#   (B) d_t finalisation -- 202206 (June-2022 market suspension) has NO row in gate0_dt_series.rds,
#       so `dt` in stage2_panel.rds is NA for all June-2022 intervals (19% of TORRB's opportunity
#       set). Decision (user, 2026-07-04): BASE CASE excludes 202206 (dt stays NA, dropped via
#       !is.na(dt) in any dt-based regression); ROBUSTNESS ROW imputes dt for 202206 from the
#       direction_costs-implied $/MWh (directed_mwh-weighted mean across the June-2022 events).
#
# Run from Direction/. Reads + re-saves outputs/withhold_opportunity/.

suppressMessages({ library(data.table) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/withhold_opportunity"

FOCUS  <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
TROUGH <- c(TORRB2=170, TORRB3=131, TORRB4=171, PPCCGT=180, `OSB-AG`=90)  # locked in Stage 2, headline default
SWEEP  <- c(80,100,120,150,170)                                          # per stage1b_diagnostics.md

X <- readRDS(file.path(OUT, "stage2_panel.rds"))
cat(sprintf("Loaded stage2_panel.rds: %d rows\n", nrow(X)))

# ---- (A) threshold sweep: withheld%/as-usual% among OPPORTUNITY intervals, per unit ----
sweep_one <- function(duid_, thr, label) {
  o <- X[duid==duid_ & opp==TRUE]
  data.table(duid=duid_, threshold=thr, label=label, n_opp=nrow(o),
             withheld_pct = round(100*mean(o$cheap300 <  thr),1),
             asusual_pct  = round(100*mean(o$cheap300 >= thr),1))
}
sens <- rbindlist(lapply(FOCUS, function(u) {
  rbindlist(c(
    lapply(SWEEP, function(t) sweep_one(u, t, "sweep")),
    list(sweep_one(u, TROUGH[[u]], "trough_default"))
  ))
}))
setorder(sens, duid, threshold)
fwrite(sens, file.path(OUT, "stage3_threshold_sensitivity.csv"))
cat("\n=== STAGE 3(A): withheld/as-usual sensitivity to the cheap300 cutoff (opportunity intervals only) ===\n")
print(sens)

# reproduces-Stage-2 check: trough_default row must match stage2_opportunity_summary.csv exactly
stage2_summ <- fread(file.path(OUT, "stage2_opportunity_summary.csv"))
chk <- merge(sens[label=="trough_default", .(duid, withheld_pct, asusual_pct)],
             stage2_summ[, .(duid, withheld_share_opp, asusual_share_opp)], by="duid")
if (!all(chk$withheld_pct == chk$withheld_share_opp) || !all(chk$asusual_pct == chk$asusual_share_opp)) {
  stop("Stage 3 trough-default sensitivity row does not reproduce Stage 2 exactly -- investigate before proceeding.")
}
cat("\nOK: trough-default row reproduces Stage 2's opportunity_summary exactly (see checks above).\n")

# ---- headline withheld flag on the full panel (trough default; the outcome Stage 4 uses) ----
X[, withheld := cheap300 < TROUGH[duid]]

# ---- (B) d_t finalisation ----
n_na_pre <- X[, sum(is.na(dt) & yyyymm==202206)]
n_202206 <- X[yyyymm==202206, .N]
stopifnot(n_na_pre == n_202206)   # every 202206 row, and only 202206, is currently NA on dt
stopifnot(X[yyyymm!=202206, sum(is.na(dt))] == 0)
cat(sprintf("\ndt pre-check: 202206 rows = %d, all NA on dt (%d); no other month is NA on dt.\n",
            n_202206, n_na_pre))

dc <- readRDS("direction_data/parsed/direction_costs.rds")
june22 <- dc[report_year==2022 & report_month==6 & !is.na(compensation_payment) & !is.na(directed_mwh) & directed_mwh>0]
stopifnot(nrow(june22) > 0)
june22[, implied_dt := compensation_payment/directed_mwh]
dt_impute_val <- june22[, sum(compensation_payment)/sum(directed_mwh)]  # directed_mwh-weighted mean
cat(sprintf("\nJune-2022 direction_costs events (n=%d): implied $/MWh per event = %s\n",
            nrow(june22), paste(round(june22$implied_dt,1), collapse=", ")))
cat(sprintf("directed_mwh-weighted imputed dt for 202206: $%.2f/MWh\n", dt_impute_val))

X[, dt_imputed := (yyyymm==202206)]
X[, dt_robust  := dt]
X[yyyymm==202206, dt_robust := dt_impute_val]
stopifnot(X[, sum(is.na(dt_robust))] == 0)  # post-fix, dt_robust has zero NA
cat("OK: dt_robust has zero NA after 202206 imputation; dt (base case) retains NA on 202206 by design.\n")

saveRDS(X, file.path(OUT, "stage3_panel.rds"))
findings_note <- sprintf(
"# Stage 3 findings -- threshold sensitivity + d_t finalisation

Script: `04_market_power/wo_stage3_threshold_dt.R`. Reads `stage2_panel.rds` (%d rows), re-saves as
`stage3_panel.rds` with two additions: `withheld` (headline flag, cheap300 < per-unit trough) and
`dt_robust`/`dt_imputed` (the resolved 202206 handling).

## (A) Threshold sensitivity (see `stage3_threshold_sensitivity.csv`)
Swept {80,100,120,150,170} MW alongside each unit's empirical trough (%s) on the OPPORTUNITY set.
Verified: the trough-default row reproduces `stage2_opportunity_summary.csv`'s withheld_share_opp /
asusual_share_opp exactly, unit by unit (self-check passed, see console log).

## (B) d_t finalisation (resolved decision, 2026-07-04)
- **Base case (`dt`):** unchanged -- 202206 stays NA, dropped in any dt-based regression via
  `!is.na(dt)`.
- **Robustness (`dt_robust`):** 202206 imputed at **\\$%.2f/MWh** -- the directed_mwh-weighted mean
  implied \\$/MWh (`compensation_payment/directed_mwh`) across the %d June-2022 `direction_costs`
  report-events. `dt_imputed` flags the %d rows (yyyymm==202206) this applies to.
- Assertions passed: pre-fix, is.na(dt) is TRUE for 202206 rows and only those; post-fix,
  `dt_robust` has zero NA.

Next: Stage 4 -- the identifying test (does withheld sort on dt, specific to opportunity vs.
matched-comparison intervals), run on both dt and dt_robust.
", nrow(X), paste(sprintf('%s=%d',names(TROUGH),TROUGH),collapse=", "),
   dt_impute_val, nrow(june22), n_202206)
writeLines(findings_note, file.path(OUT, "stage3_findings.md"))
cat("\nSaved stage3_panel.rds, stage3_threshold_sensitivity.csv, stage3_findings.md.\n")
