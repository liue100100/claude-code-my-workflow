#!/usr/bin/env Rscript
# test2_rolloff_contrast.R -- Round 2, Test 2: the mid-2023 roll-off / lag-wedge era contrast.
# Registered FIRST: 06_round2/test2_preregistration.md (commit 6b5d084). Assembly identical to
# test1_floor_reach.R (itself the exact Stage-4 machinery); the estimation replaces
# essential x comp_price with essential x {PRE, A, B} (C = post-roll-off omitted).
# Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich); library(ggplot2) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/06_round2")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
JUNE_COMP_PRICE <- 241.38; APC_IMPUTE <- 300; WCB_R <- 999L

# --- Assembly (identical to test1) -----------------------------------------
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
setDT(D); n0 <- nrow(D)
O <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
O <- O[, .(DUID, interval_dt, td, cheap_a_mw = cheap_a, cheap_b_mw = cheap_b, MAXAVAIL)]
D <- merge(D, O, by = c("DUID", "interval_dt"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(cheap_a_mw))] == 0)
D[, day_ceiling := max(MAXAVAIL), by = .(DUID, td)]
D[, floor_mw := fifelse(DUID == "PPCCGT", fifelse(day_ceiling <= 239, 42, 125), 40)]
D[, reach := as.integer(cheap_a_mw >= floor_mw)]   # reach_a == reach_b (Test 1); one measure

prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID == "SA1" & as.numeric(INTERVENTION) == 0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(interval_dt)]
seg_map <- prc[, .(interval_dt, segment = fifelse(interval_dt < susp[1], "pre_suspension",
                            fifelse(interval_dt <= susp[2], "suspension_window", "post_suspension")))]
D <- merge(D, seg_map, by = "interval_dt", all.x = TRUE)
D[is.na(segment), segment := "outside_june2022"]

g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)]
cp <- rbind(cp, data.table(yyyymm = 202206L, comp_price = JUNE_COMP_PRICE))
D <- merge(D, cp, by = "yyyymm", all.x = TRUE)
stopifnot(nrow(D) == n0)
D[, hour_block := cut(as.integer(format(interval_dt, "%H")), c(-1, 6, 12, 18, 24),
                      labels = c("0-6", "6-12", "12-18", "18-24"))]
D[, nsq := cut(nonsync_mw, quantile(nonsync_mw, seq(0, 1, .2), na.rm = TRUE), include.lowest = TRUE, labels = 1:5)]
slope_terc <- quantile(D[saturated == FALSE, slope_kernel], c(1/3, 2/3), na.rm = TRUE)
D[, comp_bin := fifelse(saturated, "saturated",
                 fifelse(slope_kernel <= slope_terc[1], "t1_steepest",
                  fifelse(slope_kernel <= slope_terc[2], "t2", "t3_nearest_zero")))]
D[, stratum := paste(DUID, yyyymm, nsq, hour_block, comp_bin, sep = "|")]
strata_ok <- D[, .(ne = sum(essential), nc = sum(!essential)), by = stratum][ne > 0 & nc > 0, stratum]
D[, matched := stratum %in% strata_ok]
M <- D[matched == TRUE]

# --- Periods (registered calendar boundaries) -------------------------------
M[, period := fifelse(yyyymm <= 202206, "PRE",
              fifelse(yyyymm <= 202209, "A_crisis",
               fifelse(yyyymm <= 202306, "B_lagwedge", "C_postroll")))]
M[, `:=`(PRE = as.integer(period == "PRE"), A = as.integer(period == "A_crisis"),
         B = as.integer(period == "B_lagwedge"))]

# --- Feasibility gate (registered thresholds) --------------------------------
cat("=== FEASIBILITY GATE (base sample: suspension window excluded) ===\n")
Bs <- M[segment != "suspension_window"]
gate <- Bs[essential == TRUE, .(ess_rows = .N, ess_months = uniqueN(yyyymm)), by = period][order(period)]
print(gate)
gate[, verdict := fifelse(ess_rows >= 500 & ess_months >= 3, "PASS", "BOUND")]
print(gate[, .(period, verdict)])
fwrite(gate, file.path(OUT, "test2_gate.csv"))

# --- Estimation: essential x {PRE, A, B}, C omitted --------------------------
rhs <- "essential*(PRE + A + B) + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
samples <- list(
  "BASE: exclude suspension window only" = quote(segment != "suspension_window"),
  "(i) exclude all June 2022"            = quote(segment == "outside_june2022"),
  "(ii) include window (in PRE period)"  = quote(rep(TRUE, .N)),
  "(iii) base minus pre-suspension June" = quote(!segment %in% c("suspension_window", "pre_suspension"))
)
outcomes <- c(reach = "reach", share_a = "cheap_a_share")

tidy_int <- function(f, samp, o) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  ct[, `:=`(sample = samp, outcome = o, nobs = nobs(f))][]
}
res <- list(); base_fits <- list()
for (s in names(samples)) for (o in names(outcomes)) {
  d <- M[eval(samples[[s]])]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs)), d, vcov = ~yyyymm)
  if (startsWith(s, "BASE")) base_fits[[o]] <- list(fit = f, data = d, var = outcomes[[o]])
  res[[paste(s, o)]] <- tidy_int(f, s, o)
}
res <- rbindlist(res)
fwrite(res, file.path(OUT, "test2_results_full.csv"))
int <- res[grepl("^essentialTRUE:", term)]
fwrite(int, file.path(OUT, "test2_interactions.csv"))
cat("\n=== Test 2: essential x period interactions (C = post-roll-off omitted) ===\n")
print(int[, .(sample, outcome, term, estimate, std.error, p.value)])

# --- WCB on the primary contrast (essential x B), base case, both outcomes ---
cat("\n=== WCB on essential x B (lag-wedge vs post-roll-off), base case ===\n")
wt_types <- c(rademacher = "wild", webb = "wild-webb")
wcb <- list()
for (o in names(outcomes)) {
  d <- base_fits[[o]]$data
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", base_fits[[o]]$var, rhs))
  lmf <- lm(fml, d)
  bn <- grep("^essentialTRUE:B$|^B:essentialTRUE$", names(coef(lmf)), value = TRUE)
  b_lm <- coef(lmf)[[bn]]
  b_fx <- coef(base_fits[[o]]$fit)[["essentialTRUE:B"]]
  stopifnot(abs(b_lm - b_fx) < 1e-6)
  for (wt in names(wt_types)) {
    set.seed(20260705)
    v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt_types[[wt]])
    se <- sqrt(v[bn, bn]); df <- uniqueN(d$yyyymm) - 1L
    pv <- 2 * pt(-abs(b_lm / se), df = df)
    wcb[[paste(o, wt)]] <- data.table(outcome = o, weights = wt, estimate = b_lm, wcb_se = se,
                                      wcb_t = b_lm / se, wcb_p = pv, R = WCB_R, df = df)
    cat(sprintf("  [%s %s] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", o, wt, b_lm, se, b_lm / se, pv))
  }
  rm(lmf); gc(verbose = FALSE)
}
wcb <- rbindlist(wcb)
fwrite(wcb, file.path(OUT, "test2_wcb.csv"))

# --- Companion figure: monthly gap (reach), event line at 2023-07, d_t overlaid
gap <- Bs[, .(gap = mean(reach[essential]) - mean(reach[!essential]),
              n_ess = sum(essential), comp_price = mean(comp_price)), by = yyyymm][n_ess >= 30][order(yyyymm)]
gap[, period := as.Date(paste0(substr(yyyymm, 1, 4), "-", substr(yyyymm, 5, 6), "-01"))]
sc <- max(abs(gap$gap)) / max(gap$comp_price)
p <- ggplot(gap, aes(period, gap)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = as.Date("2023-07-01"), linetype = "dotted") +
  geom_line(aes(y = comp_price * sc), colour = "grey60") +
  geom_point(aes(size = n_ess), colour = "steelblue", alpha = .8) +
  scale_y_continuous(sec.axis = sec_axis(~ . / sc, name = "Compensation price ($/MWh, grey line)")) +
  labs(title = "Monthly essential-vs-matched gap in floor-reach, around the mechanical d_t roll-off (dotted line)",
       x = NULL, y = "Essential minus matched floor-reach rate", size = "Essential rows") +
  theme_bw(base_size = 10)
ggsave(file.path(OUT, "test2_gap_eventtime.png"), p, width = 10, height = 6, dpi = 150)

cat("\nSaved test2_{gate,results_full,interactions,wcb}.csv + test2_gap_eventtime.png.\n")
cat("=== STOP: adjudicate against test2_preregistration.md. ===\n")
