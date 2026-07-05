#!/usr/bin/env Rscript
# run_rq2.R -- Stage 4: RQ2. Conditional on being essential, does withholding respond to the SIZE
# of the direction compensation price?
#
# Design (user spec + amendments, on file in the plan of record):
#   - Sample: essential intervals + a CEM-matched comparison set. Strata = unit x month x
#     non-sync-quintile x hour-block x COMPETITION BIN (saturated / slope tercile among
#     non-saturated) -- the Stage-2 competition measure enters the matching, per the amendment.
#   - Test: share ~ essential x comp_price + controls | unit + month, matched sample, cluster
#     month. The comp price is MONTHLY, so its main effect is absorbed by the month effects
#     (fixest drops it -- expected); the INTERACTION is the identifying object: does the
#     essential-vs-matched withholding GAP scale with what essentiality pays that month?
#   - June 2022 (three-way split from Stage 3b, AEMO MARKETSUSPENDEDFLAG):
#       BASE: exclude the suspension window ONLY; pre/post-suspension June stay in at their
#             ordinary ex-ante compensation price = the daily trailing-365d d_t evaluated at
#             2022-06-01 ($241.38 -- window ends 31 May; predetermined, uncontaminated).
#       (i)   exclude all of June 2022;
#       (ii)  include the suspension window at the EX-ANTE administered-price imputation
#             ($300/MWh, the administered price cap in force -- NEVER realised ex-post
#             compensation, which embeds look-ahead);
#       (iii) leave-one-segment-out on the June segment that matters within the base sample
#             (post-suspension June holds 0 essential rows, so that is pre-suspension June).
#   - PRE-REGISTERED interpretation: written to findings.md by this script BEFORE any estimation
#     code runs (see below); power diagnostics reported BEFORE the coefficient.
#   - Inference: analytic cluster-month + wild cluster bootstrap (sandwich::vcovBS; type="wild"
#     Rademacher / type="wild-webb" -- the corrected usage), R=999, on the interaction, base case.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich); library(ggplot2) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/04_rq2_compensation_price")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

JUNE_COMP_PRICE <- 241.38   # daily trailing-365d d_t at 2022-06-01 (d_t_SA_90pct_365d.csv); ex-ante
APC_IMPUTE      <- 300      # robustness (ii): administered price cap in force during suspension
WCB_R <- 999L

# ---------------------------------------------------------------------------
# PRE-REGISTERED INTERPRETATION -- written BEFORE estimation (committed, not fitted to results)
# ---------------------------------------------------------------------------
prereg <- "# Stage 4 findings -- RQ2: does withholding respond to the size of the compensation price?

## PRE-REGISTERED INTERPRETATION (written before estimation; committed 2026-07-05)
- A POSITIVE, SIGNIFICANT interaction (essential x compensation price, on withholding) specific to
  essential intervals = the payment-seeking signature: the Torrens RQ1 response is at least partly
  prize-driven. (Sign note: the outcome is the cheap-capacity share, higher = less withholding, so
  payment-seeking withholding appears as a NEGATIVE interaction coefficient on the share -- i.e.
  the essential-vs-matched gap in the share widens downward as the compensation price rises.)
- A NULL = regime-triggered conduct consistent with the presence-inelasticity / insurance account:
  the unit responds to BEING essential, not to what essentiality pays this period. Given that both
  measured margins in Stage 3 (essentiality, saturation) show regime responses rather than
  dose-responses, a null here completes a consistent pattern and is reported as an INFORMATIVE
  BOUND, not a failed test.
- ATTENUATION CAVEAT (applies to the result either way): essentiality is classified on realised
  rather than forecast system state, so misclassification relative to the generator's bid-time
  information biases the dose-response toward zero. The test bounds large effects, not small ones.
"
writeLines(prereg, file.path(OUT, "findings.md"))
cat("Pre-registered interpretation written to findings.md BEFORE estimation.\n")

# ---------------------------------------------------------------------------
# Panel assembly
# ---------------------------------------------------------------------------
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
n0 <- nrow(D)

# June-2022 segment map (same construction as Stage 3b, from AEMO's own flags)
prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID=="SA1" & as.numeric(INTERVENTION)==0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(interval_dt)]
seg_map <- prc[, .(interval_dt, segment = fifelse(interval_dt < susp[1], "pre_suspension",
                            fifelse(interval_dt <= susp[2], "suspension_window", "post_suspension")))]
D <- merge(D, seg_map, by="interval_dt", all.x=TRUE)
D[is.na(segment), segment := "outside_june2022"]
stopifnot(nrow(D) == n0)

# compensation price: monthly reconstructed d_t; June 2022 at the ex-ante daily value
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)]
cp <- rbind(cp, data.table(yyyymm = 202206L, comp_price = JUNE_COMP_PRICE))
D <- merge(D, cp, by="yyyymm", all.x=TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(comp_price))] == 0)
D[, comp_price_100 := comp_price / 100]   # $100/MWh units for readable coefficients
D[, hour_block := cut(as.integer(format(interval_dt, "%H")), c(-1,6,12,18,24),
                       labels=c("0-6","6-12","12-18","18-24"))]
cat(sprintf("Panel: %d rows | essential %d | suspension-window rows %d\n",
            nrow(D), D[, sum(essential)], D[segment=="suspension_window", .N]))

# ---------------------------------------------------------------------------
# CEM matching (competition measure included as a matching covariate, per the amendment)
# ---------------------------------------------------------------------------
D[, nsq := cut(nonsync_mw, quantile(nonsync_mw, seq(0,1,.2), na.rm=TRUE), include.lowest=TRUE, labels=1:5)]
slope_terc <- quantile(D[saturated==FALSE, slope_kernel], c(1/3, 2/3), na.rm=TRUE)
D[, comp_bin := fifelse(saturated, "saturated",
                 fifelse(slope_kernel <= slope_terc[1], "t1_steepest",
                  fifelse(slope_kernel <= slope_terc[2], "t2", "t3_nearest_zero")))]
D[, stratum := paste(DUID, yyyymm, nsq, hour_block, comp_bin, sep="|")]
strata_ok <- D[, .(ne = sum(essential), nc = sum(!essential)), by=stratum][ne > 0 & nc > 0, stratum]
D[, matched := stratum %in% strata_ok]
match_summ <- D[, .(
  n_essential = sum(essential), n_essential_matched = sum(essential & matched),
  essential_matched_pct = round(100*sum(essential & matched)/sum(essential),1),
  n_comparison_matched = sum(!essential & matched),
  strata_used = uniqueN(stratum[matched])), by=DUID][order(DUID)]
fwrite(match_summ, file.path(OUT, "rq2_match_summary.csv"))
cat("\n=== CEM match summary (strata: unit x month x nonsync-quintile x hour-block x competition-bin) ===\n")
print(match_summ)

M <- D[matched == TRUE]

# ---------------------------------------------------------------------------
# POWER DIAGNOSTICS (reported before any coefficient, per the amendment)
# ---------------------------------------------------------------------------
cat("\n=== POWER DIAGNOSTICS (before estimation) ===\n")
pd_month <- M[essential==TRUE, .(essential_unit_rows=.N, comp_price=round(mean(comp_price),1)), by=yyyymm][order(yyyymm)]
fwrite(pd_month, file.path(OUT, "rq2_power_by_month.csv"))
print(pd_month)
top3 <- round(100*sum(sort(pd_month$essential_unit_rows, decreasing=TRUE)[1:3])/sum(pd_month$essential_unit_rows),1)
pd <- list(
  n_ess = M[, sum(essential)],
  n_months = nrow(pd_month),
  top3_pct = top3,
  cp_sd_across_ess = round(M[essential==TRUE, sd(comp_price)],1),
  cp_iqr_across_ess = round(M[essential==TRUE, IQR(comp_price)],1),
  cp_range = paste(round(range(pd_month$comp_price)), collapse=" - "))
cat(sprintf("Essential unit-rows in matched sample: %d, spread over %d month-clusters; top-3 months hold %.1f%% of the mass.\n",
            pd$n_ess, pd$n_months, pd$top3_pct))
cat(sprintf("Compensation price across essential rows: sd $%.1f, IQR $%.1f, month-level range $%s.\n",
            pd$cp_sd_across_ess, pd$cp_iqr_across_ess, pd$cp_range))
cat("NB the compensation price is MONTHLY -- within-month (net of month effects) it has NO variation\n",
    "by construction; the interaction is identified off CROSS-month variation in the essential-vs-\n",
    "matched gap. Effective clusters for that comparison = the", pd$n_months, "essential-bearing months.\n")

# ---------------------------------------------------------------------------
# Estimation: base case + three June variants, both outcomes
# ---------------------------------------------------------------------------
rhs <- "essential*comp_price_100 + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
outcomes <- c(a_fixed300 = "cheap_a_share", b_2xSRMC = "cheap_b_share")
samples <- list(
  "BASE: exclude suspension window only" = quote(segment != "suspension_window"),
  "(i) exclude all June 2022"            = quote(segment == "outside_june2022"),
  "(ii) include window at APC $300"      = quote(rep(TRUE, .N)),
  "(iii) base minus pre-suspension June" = quote(!segment %in% c("suspension_window","pre_suspension"))
)

tidy_int <- function(f, samp, o) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct[, `:=`(sample=samp, outcome=o, nobs=nobs(f))][]
}
res <- list(); base_fits <- list()
for (s in names(samples)) for (o in names(outcomes)) {
  d <- M[eval(samples[[s]])]
  if (s == "(ii) include window at APC $300") d[segment=="suspension_window", comp_price_100 := APC_IMPUTE/100]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs)), d, vcov=~yyyymm)
  if (startsWith(s, "BASE")) base_fits[[o]] <- list(fit=f, data=d)
  res[[paste(s,o)]] <- tidy_int(f, s, o)
}
res <- rbindlist(res)
fwrite(res, file.path(OUT, "rq2_results_full.csv"))
int <- res[term == "essentialTRUE:comp_price_100"]
fwrite(int, file.path(OUT, "rq2_interaction.csv"))
cat("\n=== RQ2: essential x compensation-price interaction (per $100/MWh), all June treatments ===\n")
print(int[, .(sample, outcome, estimate, std.error, p.value, nobs)])

# ---------------------------------------------------------------------------
# Wild cluster bootstrap on the interaction, base case, both outcomes
# ---------------------------------------------------------------------------
cat("\n=== WCB on the interaction (base case), sandwich::vcovBS, R=999, df=35 ===\n")
wt_types <- c(rademacher = "wild", webb = "wild-webb")
wcb <- list()
for (o in names(outcomes)) {
  d <- base_fits[[o]]$data
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", outcomes[[o]], rhs))
  lmf <- lm(fml, d)
  b_lm <- coef(lmf)[["essentialTRUE:comp_price_100"]]
  b_fx <- coef(base_fits[[o]]$fit)[["essentialTRUE:comp_price_100"]]
  stopifnot(abs(b_lm - b_fx) < 1e-6)
  for (wt in names(wt_types)) {
    set.seed(20260705)
    v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt_types[[wt]])
    se <- sqrt(v["essentialTRUE:comp_price_100","essentialTRUE:comp_price_100"])
    df <- uniqueN(d$yyyymm) - 1L
    pv <- 2*pt(-abs(b_lm/se), df = df)
    wcb[[paste(o,wt)]] <- data.table(outcome=o, weights=wt, estimate=b_lm, wcb_se=se,
                                      wcb_t=b_lm/se, wcb_p=pv, R=WCB_R, df=df)
    cat(sprintf("  [%s %s] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", o, wt, b_lm, se, b_lm/se, pv))
  }
  rm(lmf); gc(verbose=FALSE)
}
wcb <- rbindlist(wcb)
fwrite(wcb, file.path(OUT, "rq2_wcb.csv"))

# ---------------------------------------------------------------------------
# Figure: per-month essential-vs-matched gap against the compensation price
# ---------------------------------------------------------------------------
gap <- M[segment != "suspension_window",
  .(gap = mean(cheap_a_share[essential]) - mean(cheap_a_share[!essential]),
    n_ess = sum(essential), comp_price = mean(comp_price)), by=yyyymm][n_ess >= 30]
p <- ggplot(gap, aes(comp_price, gap)) +
  geom_hline(yintercept=0, linetype="dashed", colour="grey50") +
  geom_point(aes(size=n_ess), colour="steelblue", alpha=0.8) +
  geom_smooth(method="lm", se=TRUE, colour="firebrick", linewidth=0.7) +
  labs(title="RQ2 raw pattern: monthly essential-vs-matched withholding gap against the compensation price",
       subtitle="Each point = one month (>=30 essential unit-rows; base sample). Downward slope = the payment-seeking signature. Fixed-$300 outcome.",
       x="Compensation price ($/MWh, monthly)", y="Essential minus matched-comparison cheap-capacity share", size="Essential unit-rows") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "rq2_gap_vs_price.png"), p, width=10, height=6, dpi=150)

cat("\nSaved rq2_{match_summary,power_by_month,results_full,interaction,wcb}.csv, rq2_gap_vs_price.png.\n")
cat("Now run: Rscript 04_rq2_compensation_price/finalize_findings_rq2.R  (appends results to findings.md)\n")
cat("\n=== STOP after findings: Stage 4 complete pending review. ===\n")
