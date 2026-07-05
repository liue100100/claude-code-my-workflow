#!/usr/bin/env Rscript
# run_rq1.R -- Stage 3: the RQ1 regression.
#
#   Do generators withhold more capacity when they are essential for system security?
#
# Withholding (cheap-capacity share of registered capacity; HIGHER share = LESS withholding) on
# the essentiality flag, with unit + month fixed effects, SRMC, market-state controls (regional
# demand, non-synchronous share, spot price), and the Stage-2 competition measure. The HEADLINE is
# the movement of the essentiality coefficient when the competition control enters (M1 -> M3):
# how much of the essentiality response is ordinary market power vs. something beyond it.
#
# Competition-measure sign (per the corrected Stage-2 gate): slope_kernel <= 0, MW per $/MWh.
# More negative = rivals more price-responsive = MORE competition; == 0 = rivals saturated =
# LEAST competition ("saturated" indicator carries this mass point explicitly).
#
# Inference: analytic cluster-robust (month clusters, the project convention) AND a wild cluster
# bootstrap via sandwich::vcovBS (Rademacher primary, Webb sensitivity). fwildclusterboot (the
# null-imposed boottest implementation) cannot be installed on this machine (no Rtools; package
# archived from CRAN so no Windows binary) -- vcovBS is the canonical installed alternative; it is
# the UNRESTRICTED wild cluster bootstrap (variance-based), not the null-imposed WCR-11; with 36
# clusters the distinction is second-order but it is documented in the findings, not hidden.
# R = 999 replicates (not the 9,999 first planned): each replicate is O(n) in pure R on a 1.2M-row
# design, and 999 is the standard applied choice (Cameron-Gelbach-Miller 2008); documented.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich); library(ggplot2) })
set.seed(20260704)
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")
OUT       <- file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")   # OSB-AG descriptive-only, excluded
grp_map <- c(TORRB2="torrens_island_b", TORRB3="torrens_island_b", TORRB4="torrens_island_b",
             PPCCGT="pelican_point_gt")
WCB_R <- 999L

# ---------------------------------------------------------------------------
# Panel assembly (row counts asserted + reported at every join)
# ---------------------------------------------------------------------------
cat("=== Assembling the RQ1 regression panel ===\n")
Y <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
Y <- Y[DUID %in% TEST_UNITS, .(DUID, interval_dt, yyyymm, srmc, cheap_a_share, cheap_b_share, essential)]
n0 <- nrow(Y)
cat(sprintf("Outcome rows (4 test units): %d\n", n0))

Y[, grp := grp_map[DUID]]
C2 <- readRDS(file.path(ROOT, "Direction_clean/outputs/02_competition_control/residual_demand_panel.rds"))
C2 <- C2[, .(grp, interval_dt, slope_kernel, slope_direct_20, RRP, TOTALDEMAND)]
Y <- merge(Y, C2, by=c("grp","interval_dt"), all.x=TRUE)
stopifnot(nrow(Y) == n0)   # 1:1 join -- no blowup
n_no_comp <- Y[, sum(is.na(slope_kernel))]
cat(sprintf("After competition join: %d rows; %d (%.3f%%) missing the competition measure (Stage-2 boundary gap)\n",
            nrow(Y), n_no_comp, 100*n_no_comp/n0))

piv <- readRDS(file.path(DIRECTION, "outputs/descriptives_v3/pivotality_panel.rds"))
piv[, interval_dt := force10(SETTLEMENTDATE)]
Y <- merge(Y, unique(piv[, .(interval_dt, nonsync_mw)], by="interval_dt"), by="interval_dt", all.x=TRUE)
stopifnot(nrow(Y) == n0)
n_no_ns <- Y[, sum(is.na(nonsync_mw))]
cat(sprintf("After non-sync join: %d (%.3f%%) missing nonsync\n", n_no_ns, 100*n_no_ns/n0))

n_no_ess <- Y[, sum(is.na(essential))]
Y[, nonsync_share := nonsync_mw / TOTALDEMAND]
Y[, saturated := slope_kernel == 0]
# NON-SYNC CONTROL: the spec asked for the non-synchronous SHARE, but SA TOTALDEMAND crosses zero
# in-sample (rooftop solar pushes grid demand negative), so the ratio explodes and flips sign
# around the crossing -- found on the first run: nonsync_share ranged [-24529, +9041]. A control
# with a zero-crossing denominator is statistically indefensible, so the PRIMARY spec uses the
# non-sync LEVEL (nonsync_mw) with demand entering separately; the share is retained as a
# robustness row restricted to TOTALDEMAND > 500 MW where the ratio is well-defined. Documented in
# findings, not silently swapped.
cat(sprintf("nonsync_share range: [%.2f, %.2f] (TOTALDEMAND range [%.0f, %.0f]; %d rows with TOTALDEMAND<=0) -> share replaced by LEVEL in primary spec, share kept as restricted robustness row\n",
            min(Y$nonsync_share, na.rm=TRUE), max(Y$nonsync_share, na.rm=TRUE),
            min(Y$TOTALDEMAND, na.rm=TRUE), max(Y$TOTALDEMAND, na.rm=TRUE),
            Y[, sum(TOTALDEMAND <= 0, na.rm=TRUE)]))

D <- Y[!is.na(essential) & !is.na(slope_kernel) & !is.na(nonsync_mw) & !is.na(RRP)]
cat(sprintf("Estimation sample: %d of %d rows (dropped: %d no-essential, %d no-competition, %d no-nonsync/other)\n",
            nrow(D), n0, n_no_ess, n_no_comp, n0 - nrow(D) - 0L))
saveRDS(D, file.path(OUT, "regression_panel.rds"))

# ---------------------------------------------------------------------------
# Core models: M1 (no competition control), M2 (+slope), M3 (+slope +saturated), x 2 outcomes
# ---------------------------------------------------------------------------
rhs <- c(M1 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP",
         M2 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel",
         M3 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated")
outcomes <- c(a_fixed300 = "cheap_a_share", b_2xSRMC = "cheap_b_share")

tidy_fx <- function(f, model, outcome) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct[, `:=`(model=model, outcome=outcome, nobs=nobs(f))][]
}

core <- list(); fits <- list()
for (o in names(outcomes)) for (m in names(rhs)) {
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs[[m]])), D, vcov=~yyyymm)
  fits[[paste(o,m,sep="_")]] <- f
  core[[paste(o,m,sep="_")]] <- tidy_fx(f, m, o)
}
core <- rbindlist(core)
fwrite(core, file.path(OUT, "rq1_core_results.csv"))
cat("\n=== Core: essential coefficient by model x outcome (analytic, cluster month) ===\n")
ess <- core[term=="essentialTRUE"]
print(ess[, .(outcome, model, estimate, std.error, statistic, p.value, nobs)])

# headline comparison table: M1 -> M3 movement
hl <- dcast(ess, outcome ~ model, value.var="estimate")
hl[, pct_change_M1_to_M3 := round(100*(M3-M1)/abs(M1), 1)]
fwrite(hl, file.path(OUT, "rq1_headline_comparison.csv"))
cat("\n=== HEADLINE: essentiality coefficient, without vs. with the competition control ===\n"); print(hl)

# ---------------------------------------------------------------------------
# Wild cluster bootstrap on the essential coefficient, all 6 core models
# (lm re-fit with explicit dummies; coefficient asserted equal to feols first)
# ---------------------------------------------------------------------------
cat("\n=== Wild cluster bootstrap (sandwich::vcovBS, R=999, cluster=month, df=35) ===\n")
wcb <- list()
for (o in names(outcomes)) for (m in names(rhs)) {
  key <- paste(o,m,sep="_")
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", outcomes[[o]], rhs[[m]]))
  lmf <- lm(fml, D)
  b_lm <- coef(lmf)[["essentialTRUE"]]
  b_fx <- coef(fits[[key]])[["essentialTRUE"]]
  stopifnot(abs(b_lm - b_fx) < 1e-6)     # identical specification check
  # NB sandwich selects the wild-weight family via `type` ("wild" = Rademacher, "wild-webb" =
  # Webb) -- a `wild=` argument is silently swallowed by `...` (caught when both families
  # returned bit-identical SEs on the first run; fixed here).
  wt_types <- c(rademacher = "wild", webb = "wild-webb")
  for (wt in names(wt_types)) {
    set.seed(20260704)
    v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt_types[[wt]])
    se <- sqrt(v["essentialTRUE","essentialTRUE"])
    tt <- b_lm / se
    pv <- 2*pt(-abs(tt), df = uniqueN(D$yyyymm) - 1L)
    wcb[[paste(key,wt,sep="_")]] <- data.table(outcome=o, model=m, weights=wt,
      estimate=b_lm, wcb_se=se, wcb_t=tt, wcb_p=pv, R=WCB_R, df=uniqueN(D$yyyymm)-1L)
    cat(sprintf("  [%s %s %s] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", o, m, wt, b_lm, se, tt, pv))
  }
  rm(lmf); gc(verbose=FALSE)
}
wcb <- rbindlist(wcb)
fwrite(wcb, file.path(OUT, "rq1_wcb.csv"))

# ---------------------------------------------------------------------------
# Robustness (analytic CRVE; essential coefficient under M1 and M3)
# ---------------------------------------------------------------------------
cat("\n=== Robustness rows ===\n")
rob_run <- function(d, label, fe = "DUID + yyyymm", swap_slope = FALSE) {
  rhs_l <- rhs
  if (swap_slope) rhs_l <- gsub("slope_kernel", "slope_direct_20", rhs_l)
  if (swap_slope) rhs_l <- gsub("saturated", "(slope_direct_20 == 0)", rhs_l)
  rbindlist(lapply(names(outcomes), function(o) rbindlist(lapply(c("M1","M3"), function(m) {
    f <- feols(as.formula(sprintf("%s ~ %s | %s", outcomes[[o]], rhs_l[[m]], fe)), d, vcov=~yyyymm)
    ct <- tidy_fx(f, m, o)[term=="essentialTRUE"]
    ct[, row := label][]
  }))))
}
rob_share <- local({   # spec-fidelity row: the SHARE control, on the subsample where it is well-defined
  d <- D[TOTALDEMAND > 500 & is.finite(nonsync_share)]
  rhs_s <- gsub("nonsync_mw", "nonsync_share", rhs)
  rbindlist(lapply(names(outcomes), function(o) rbindlist(lapply(c("M1","M3"), function(m) {
    f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs_s[[m]])), d, vcov=~yyyymm)
    ct <- tidy_fx(f, m, o)[term=="essentialTRUE"]
    ct[, row := "nonsync SHARE control (TOTALDEMAND>500 only)"][]
  }))))
})
rob <- rbindlist(list(
  rob_run(D[yyyymm != 202206], "drop 2022-06 (market suspension)"),
  rob_run(D[DUID %in% c("TORRB2","TORRB3","TORRB4")], "Torrens only"),
  rob_run(D[DUID == "PPCCGT"], "PPCCGT only (no unit FE possible)", fe = "yyyymm"),
  rob_run(D, "slope_direct_20 in place of slope_kernel", swap_slope = TRUE),
  rob_share
))
fwrite(rob, file.path(OUT, "rq1_robustness.csv"))
print(rob[, .(row, outcome, model, estimate, std.error, p.value, nobs)])

# ---------------------------------------------------------------------------
# Coefficient plot: essential coefficient across models/outcomes with WCB CIs
# ---------------------------------------------------------------------------
pw <- wcb[weights=="rademacher"]
pw[, `:=`(lo = estimate - qt(.975, df)*wcb_se, hi = estimate + qt(.975, df)*wcb_se)]
pw[, outcome_lab := fifelse(outcome=="a_fixed300", "Fixed $300 definition", "Cost-indexed 2xSRMC definition")]
pw[, model_lab := factor(model, levels=c("M1","M2","M3"),
     labels=c("No competition control","+ competition (continuous)","+ competition + saturated indicator"))]
p <- ggplot(pw, aes(model_lab, estimate)) +
  geom_hline(yintercept=0, linetype="dashed", colour="grey50") +
  geom_pointrange(aes(ymin=lo, ymax=hi), colour="steelblue") +
  facet_wrap(~outcome_lab) + coord_flip() +
  labs(title="RQ1: effect of being essential on the cheap-capacity share",
       subtitle="Negative = more withholding when essential. Bars = 95% CI from the wild cluster bootstrap (Rademacher, month clusters).",
       x=NULL, y="Essentiality coefficient (change in cheap-capacity share of registered capacity)") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "rq1_coefficient_plot.png"), p, width=10, height=4.5, dpi=150)

# ---------------------------------------------------------------------------
# Findings are generated by finalize_findings.R (split out after the in-line sprintf here crashed
# post-estimation on a format/argument mismatch; the separate generator reads the saved CSVs,
# asserts numeric class + length-1 on every numeric argument, and never requires re-estimation).
# ---------------------------------------------------------------------------
cat("\nSaved rq1_{core_results,headline_comparison,wcb,robustness}.csv, rq1_coefficient_plot.png, regression_panel.rds.\n")
cat("Now run: Rscript 03_rq1_essentiality/finalize_findings.R  (writes findings.md)\n")
cat("\n=== STOP: Stage 3 complete. Awaiting review before Stage 4 (RQ2) planning. ===\n")
