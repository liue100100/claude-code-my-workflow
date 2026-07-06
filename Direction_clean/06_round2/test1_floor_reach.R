#!/usr/bin/env Rscript
# test1_floor_reach.R -- Round 2, Test 1: the floor-reach decomposition of RQ2.
#
# Registered FIRST: 06_round2/test1_preregistration.md (commit c21789e). Design is the exact
# Stage-4 specification (04_rq2_compensation_price/run_rq2.R); the ONLY change is the dependent
# variable: (i) reach_a / reach_b = 1{cheap MW >= frozen floor} (the direction-eligibility
# margin), (ii) the cheap share on the reach==1 subsample (intensive margin, decomposition aid).
# Power gate reported BEFORE any coefficient; degeneracy rule per the registration.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/06_round2")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

JUNE_COMP_PRICE <- 241.38
APC_IMPUTE      <- 300
WCB_R <- 999L

# ---------------------------------------------------------------------------
# Panel assembly -- regression panel + cheap MW levels + MAXAVAIL (for the PPCCGT config rule)
# ---------------------------------------------------------------------------
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
setDT(D); n0 <- nrow(D)

O <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
O <- O[, .(DUID, interval_dt, td, cheap_a_mw = cheap_a, cheap_b_mw = cheap_b, MAXAVAIL)]
D <- merge(D, O, by = c("DUID", "interval_dt"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(cheap_a_mw))] == 0)

# Frozen floors (Task 2, reused as-is). PPCCGT: single-turbine day iff unit-day MAXAVAIL
# ceiling <= 239 MW (Task-2 rule) -> floor 42, else 125. TORRB* = 40. OSB-AG not in panel.
D[, day_ceiling := max(MAXAVAIL), by = .(DUID, td)]
D[, floor_mw := fifelse(DUID == "PPCCGT", fifelse(day_ceiling <= 239, 42, 125), 40)]
D[, `:=`(reach_a = as.integer(cheap_a_mw >= floor_mw),
         reach_b = as.integer(cheap_b_mw >= floor_mw))]

# June-2022 segment map (identical to run_rq2.R)
prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID == "SA1" & as.numeric(INTERVENTION) == 0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(interval_dt)]
seg_map <- prc[, .(interval_dt, segment = fifelse(interval_dt < susp[1], "pre_suspension",
                            fifelse(interval_dt <= susp[2], "suspension_window", "post_suspension")))]
D <- merge(D, seg_map, by = "interval_dt", all.x = TRUE)
D[is.na(segment), segment := "outside_june2022"]
stopifnot(nrow(D) == n0)

# Compensation price (identical)
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)]
cp <- rbind(cp, data.table(yyyymm = 202206L, comp_price = JUNE_COMP_PRICE))
D <- merge(D, cp, by = "yyyymm", all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(comp_price))] == 0)
D[, comp_price_100 := comp_price / 100]
D[, hour_block := cut(as.integer(format(interval_dt, "%H")), c(-1, 6, 12, 18, 24),
                      labels = c("0-6", "6-12", "12-18", "18-24"))]

# CEM matching (identical strata)
D[, nsq := cut(nonsync_mw, quantile(nonsync_mw, seq(0, 1, .2), na.rm = TRUE), include.lowest = TRUE, labels = 1:5)]
slope_terc <- quantile(D[saturated == FALSE, slope_kernel], c(1/3, 2/3), na.rm = TRUE)
D[, comp_bin := fifelse(saturated, "saturated",
                 fifelse(slope_kernel <= slope_terc[1], "t1_steepest",
                  fifelse(slope_kernel <= slope_terc[2], "t2", "t3_nearest_zero")))]
D[, stratum := paste(DUID, yyyymm, nsq, hour_block, comp_bin, sep = "|")]
strata_ok <- D[, .(ne = sum(essential), nc = sum(!essential)), by = stratum][ne > 0 & nc > 0, stratum]
D[, matched := stratum %in% strata_ok]
M <- D[matched == TRUE]
cat(sprintf("Matched sample: %d rows (%d essential) -- must equal Stage 4's 140,259/12,513 on the base filter.\n",
            M[segment != "suspension_window", .N], M[segment != "suspension_window", sum(essential)]))

# ---------------------------------------------------------------------------
# POWER GATE (before any coefficient; degeneracy rule from the registration)
# ---------------------------------------------------------------------------
cat("\n=== POWER GATE: floor-reach rates on the matched base sample ===\n")
B <- M[segment != "suspension_window"]
gate_unit <- B[, .(
  n_ess = sum(essential),
  reach_a_ess = round(100 * mean(reach_a[essential]), 1),
  reach_a_cmp = round(100 * mean(reach_a[!essential]), 1),
  reach_b_ess = round(100 * mean(reach_b[essential]), 1),
  reach_b_cmp = round(100 * mean(reach_b[!essential]), 1)), by = DUID][order(DUID)]
gate_pool <- B[, .(DUID = "POOLED",
  n_ess = sum(essential),
  reach_a_ess = round(100 * mean(reach_a[essential]), 1),
  reach_a_cmp = round(100 * mean(reach_a[!essential]), 1),
  reach_b_ess = round(100 * mean(reach_b[essential]), 1),
  reach_b_cmp = round(100 * mean(reach_b[!essential]), 1))]
gate <- rbind(gate_unit, gate_pool)
print(gate)
mv <- B[essential == TRUE, .(varies_a = uniqueN(reach_a) > 1, varies_b = uniqueN(reach_b) > 1), by = yyyymm]
months_var <- c(a = mv[, sum(varies_a)], b = mv[, sum(varies_b)])
cat(sprintf("Essential-bearing months with BOTH reach states: reach_a %d, reach_b %d (rule: >= 8).\n",
            months_var["a"], months_var["b"]))
pooled_a <- B[essential == TRUE, mean(reach_a)]; pooled_b <- B[essential == TRUE, mean(reach_b)]
gate_verdict <- function(p, mv) if (p < .05 || p > .95 || mv < 8) "DEGENERATE -> report as BOUND" else "PASS"
cat(sprintf("GATE reach_a: pooled essential reach %.1f%% -> %s\n", 100 * pooled_a, gate_verdict(pooled_a, months_var["a"])))
cat(sprintf("GATE reach_b: pooled essential reach %.1f%% -> %s\n", 100 * pooled_b, gate_verdict(pooled_b, months_var["b"])))
fwrite(gate, file.path(OUT, "test1_gate.csv"))
fwrite(mv,   file.path(OUT, "test1_gate_months.csv"))

# ---------------------------------------------------------------------------
# Estimation -- exact Stage-4 spec; outcomes: reach LPMs + intensive shares
# ---------------------------------------------------------------------------
rhs <- "essential*comp_price_100 + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
samples <- list(
  "BASE: exclude suspension window only" = quote(segment != "suspension_window"),
  "(i) exclude all June 2022"            = quote(segment == "outside_june2022"),
  "(ii) include window at APC $300"      = quote(rep(TRUE, .N)),
  "(iii) base minus pre-suspension June" = quote(!segment %in% c("suspension_window", "pre_suspension"))
)
outcomes <- list(
  reach_a       = list(var = "reach_a",       subset = quote(rep(TRUE, .N))),
  reach_b       = list(var = "reach_b",       subset = quote(rep(TRUE, .N))),
  intensive_a   = list(var = "cheap_a_share", subset = quote(reach_a == 1L)),
  intensive_b   = list(var = "cheap_b_share", subset = quote(reach_b == 1L))
)

tidy_int <- function(f, samp, o) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  ct[, `:=`(sample = samp, outcome = o, nobs = nobs(f))][]
}
res <- list(); base_fits <- list()
for (s in names(samples)) for (o in names(outcomes)) {
  d <- M[eval(samples[[s]])]
  if (s == "(ii) include window at APC $300") d[segment == "suspension_window", comp_price_100 := APC_IMPUTE / 100]
  d <- d[eval(outcomes[[o]]$subset)]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]]$var, rhs)), d, vcov = ~yyyymm)
  if (startsWith(s, "BASE")) base_fits[[o]] <- list(fit = f, data = d, var = outcomes[[o]]$var)
  res[[paste(s, o)]] <- tidy_int(f, s, o)
}
res <- rbindlist(res)
fwrite(res, file.path(OUT, "test1_results_full.csv"))
int <- res[term == "essentialTRUE:comp_price_100"]
fwrite(int, file.path(OUT, "test1_interaction.csv"))
cat("\n=== Test 1: essential x comp-price interaction (per $100/MWh) ===\n")
print(int[, .(sample, outcome, estimate, std.error, p.value, nobs)])

# ---------------------------------------------------------------------------
# Wild cluster bootstrap, base case, all four outcomes (identical procedure)
# ---------------------------------------------------------------------------
cat("\n=== WCB on the interaction (base case), sandwich::vcovBS, R=999 ===\n")
wt_types <- c(rademacher = "wild", webb = "wild-webb")
wcb <- list()
for (o in names(outcomes)) {
  d <- base_fits[[o]]$data
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", base_fits[[o]]$var, rhs))
  lmf <- lm(fml, d)
  b_lm <- coef(lmf)[["essentialTRUE:comp_price_100"]]
  b_fx <- coef(base_fits[[o]]$fit)[["essentialTRUE:comp_price_100"]]
  stopifnot(abs(b_lm - b_fx) < 1e-6)
  for (wt in names(wt_types)) {
    set.seed(20260705)
    v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt_types[[wt]])
    se <- sqrt(v["essentialTRUE:comp_price_100", "essentialTRUE:comp_price_100"])
    df <- uniqueN(d$yyyymm) - 1L
    pv <- 2 * pt(-abs(b_lm / se), df = df)
    wcb[[paste(o, wt)]] <- data.table(outcome = o, weights = wt, estimate = b_lm, wcb_se = se,
                                      wcb_t = b_lm / se, wcb_p = pv, R = WCB_R, df = df)
    cat(sprintf("  [%s %s] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", o, wt, b_lm, se, b_lm / se, pv))
  }
  rm(lmf); gc(verbose = FALSE)
}
wcb <- rbindlist(wcb)
fwrite(wcb, file.path(OUT, "test1_wcb.csv"))

cat("\nSaved test1_{gate,gate_months,results_full,interaction,wcb}.csv to outputs/06_round2/.\n")
cat("=== STOP: adjudicate against test1_preregistration.md; findings file next. ===\n")
