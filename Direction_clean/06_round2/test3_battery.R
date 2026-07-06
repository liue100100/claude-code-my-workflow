#!/usr/bin/env Rscript
# test3_battery.R -- Round 2, Test 3: supporting battery (3a month-grain; 3b fuel horse race;
# 3c placebo feasibility gate; 3d null-imposed WCB / randomization inference).
# Registered FIRST: 06_round2/test3_preregistration.md (commit 8ed73e1).
# Assembly identical to test1/test2 (exact Stage-4 machinery). Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/06_round2")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
JUNE_COMP_PRICE <- 241.38; WCB_R <- 999L; RI_R <- 999L

# --- Assembly (identical to test1/test2; gas_gj added for 3b) ----------------
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
setDT(D); n0 <- nrow(D)
O <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
O2 <- O[, .(DUID, interval_dt, td, cheap_a_mw = cheap_a, MAXAVAIL, gas_gj)]
D <- merge(D, O2, by = c("DUID", "interval_dt"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(cheap_a_mw))] == 0, D[, sum(is.na(gas_gj))] == 0)
D[, day_ceiling := max(MAXAVAIL), by = .(DUID, td)]
D[, floor_mw := fifelse(DUID == "PPCCGT", fifelse(day_ceiling <= 239, 42, 125), 40)]
D[, reach := as.integer(cheap_a_mw >= floor_mw)]

prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID == "SA1" & as.numeric(INTERVENTION) == 0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(interval_dt)]
seg_map <- prc[, .(interval_dt, segment = fifelse(interval_dt < susp[1], "pre_suspension",
                            fifelse(interval_dt <= susp[2], "suspension_window", "post_suspension")))]
D <- merge(D, seg_map, by = "interval_dt", all.x = TRUE)
D[is.na(segment), segment := "outside_june2022"]
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- rbind(g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)],
            data.table(yyyymm = 202206L, comp_price = JUNE_COMP_PRICE))
D <- merge(D, cp, by = "yyyymm", all.x = TRUE)
D[, comp_price_100 := comp_price / 100]
D[, hour_block := cut(as.integer(format(interval_dt, "%H")), c(-1, 6, 12, 18, 24),
                      labels = c("0-6", "6-12", "12-18", "18-24"))]
D[, nsq := cut(nonsync_mw, quantile(nonsync_mw, seq(0, 1, .2), na.rm = TRUE), include.lowest = TRUE, labels = 1:5)]
slope_terc <- quantile(D[saturated == FALSE, slope_kernel], c(1/3, 2/3), na.rm = TRUE)
D[, comp_bin := fifelse(saturated, "saturated",
                 fifelse(slope_kernel <= slope_terc[1], "t1_steepest",
                  fifelse(slope_kernel <= slope_terc[2], "t2", "t3_nearest_zero")))]
D[, stratum := paste(DUID, yyyymm, nsq, hour_block, comp_bin, sep = "|")]
strata_ok <- D[, .(ne = sum(essential), nc = sum(!essential)), by = stratum][ne > 0 & nc > 0, stratum]
M <- D[stratum %in% strata_ok]
B <- M[segment != "suspension_window"]

# ============================ 3a: month-grain ================================
cat("=== 3a: month-grain regression (gap in reach on comp price, WLS by essential rows) ===\n")
gm <- B[, .(gap = mean(reach[essential]) - mean(reach[!essential]),
            n_ess = sum(essential), comp_price_100 = mean(comp_price) / 100), by = yyyymm][n_ess >= 30]
fit3a <- lm(gap ~ comp_price_100, gm, weights = n_ess)
v3a <- vcovHC(fit3a, type = "HC1")
b3a <- coef(fit3a)[["comp_price_100"]]; se3a <- sqrt(v3a["comp_price_100", "comp_price_100"])
p3a <- 2 * pt(-abs(b3a / se3a), df = nrow(gm) - 2)
cat(sprintf("Months: %d. Slope per $100: %.4f (HC1 se %.4f, p=%.4f)\n", nrow(gm), b3a, se3a, p3a))
fwrite(gm, file.path(OUT, "test3a_month_gaps.csv"))
res3a <- data.table(slope = b3a, se = se3a, p = p3a, n_months = nrow(gm))
fwrite(res3a, file.path(OUT, "test3a_result.csv"))

# ============================ 3b: fuel horse race ============================
cat("\n=== 3b: horse race -- essential x comp_price AND essential x gas, base sample ===\n")
rhs_hr <- "essential*comp_price_100 + essential*gas_gj + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
hr <- list()
for (o in c(reach = "reach", share_a = "cheap_a_share")) {
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", o, rhs_hr)), B, vcov = ~yyyymm)
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  hr[[o]] <- ct[grepl("^essentialTRUE:", term)][, outcome := o]
}
hr <- rbindlist(hr)
print(hr)
fwrite(hr, file.path(OUT, "test3b_horserace.csv"))

# WCB on the comp interaction with gas present (reach, base)
cat("\n--- 3b WCB on essential x comp_price (gas in the model), reach ---\n")
fml <- as.formula(sprintf("reach ~ %s + factor(DUID) + factor(yyyymm)", rhs_hr))
lmf <- lm(fml, B)
b_lm <- coef(lmf)[["essentialTRUE:comp_price_100"]]
wcb3b <- list()
for (wt in c(rademacher = "wild", webb = "wild-webb")) {
  set.seed(20260705)
  v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt)
  se <- sqrt(v["essentialTRUE:comp_price_100", "essentialTRUE:comp_price_100"])
  df <- uniqueN(B$yyyymm) - 1L
  pv <- 2 * pt(-abs(b_lm / se), df = df)
  cat(sprintf("  [%s] b=%.5f  WCB se=%.5f  p=%.4f\n", wt, b_lm, se, pv))
  wcb3b[[wt]] <- data.table(weights = wt, estimate = b_lm, wcb_se = se, wcb_p = pv)
}
fwrite(rbindlist(wcb3b), file.path(OUT, "test3b_wcb.csv"))
rm(lmf); gc(verbose = FALSE)

# ============================ 3c: placebo gate ===============================
cat("\n=== 3c: placebo feasibility inventory (committed criteria) ===\n")
bo <- readRDS(file.path(ROOT, "Direction/bid_cache/BIDOFFERPERIOD_202301.rds")); setDT(bo)
cache_duids <- sort(unique(bo$DUID))
piv <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(piv)
flag_cols <- grep("^pex_", names(piv), value = TRUE)
inv <- data.table(DUID = cache_duids)
inv[, in_cache := TRUE]
inv[, flag_available := DUID %in% c("TORRB2","TORRB3","TORRB4") | DUID == "PPCCGT" | DUID == "OSB-AG"]
osb_ess <- O[DUID == "OSB-AG", sum(essential, na.rm = TRUE)]
inv[, note := fifelse(DUID %in% c("TORRB2","TORRB3","TORRB4","PPCCGT"), "treatment set",
              fifelse(DUID == "OSB-AG",
                      sprintf("fails criterion 3: %d essential unit-rows (<500); also directed in-sample", osb_ess),
                      "fails criterion 2: no rivals-only essentiality flag constructed"))]
print(inv)
cat(sprintf("Existing pex flags: %s (station-level, focal only).\n", paste(flag_cols, collapse = ", ")))
verdict3c <- if (all(inv[!(DUID %in% c("TORRB2","TORRB3","TORRB4","PPCCGT")),
                         note != ""])) "INFEASIBLE" else "CANDIDATE FOUND"
cat("3c VERDICT:", verdict3c, "-- reported per the registration; no new flags built.\n")
fwrite(inv, file.path(OUT, "test3c_placebo_inventory.csv"))

# ============================ 3d: inference upgrade ==========================
cat("\n=== 3d: null-imposed WCB (fwildclusterboot binary) else randomization inference ===\n")
f_base <- feols(reach ~ essential*comp_price_100 + srmc + TOTALDEMAND + nonsync_mw + RRP +
                  slope_kernel + saturated | DUID + yyyymm, B, vcov = ~yyyymm)
b_obs <- coef(f_base)[["essentialTRUE:comp_price_100"]]
used <- "none"
fw_ok <- suppressWarnings(requireNamespace("fwildclusterboot", quietly = TRUE))
if (!fw_ok) {
  fw_ok <- tryCatch({
    install.packages("fwildclusterboot",
                     repos = c("https://s3alfisc.r-universe.dev", "https://cloud.r-project.org"),
                     quiet = TRUE)
    requireNamespace("fwildclusterboot", quietly = TRUE)
  }, error = function(e) FALSE)
}
res3d <- list()
if (fw_ok) {
  used <- "fwildclusterboot (null-imposed)"
  for (wt in c("rademacher", "webb")) {
    bt <- tryCatch(fwildclusterboot::boottest(f_base, param = "essentialTRUE:comp_price_100",
                                              clustid = "yyyymm", B = 9999, type = wt,
                                              impose_null = TRUE, seed = 20260705),
                   error = function(e) NULL)
    if (is.null(bt)) { fw_ok <- FALSE; break }
    cat(sprintf("  [boottest %s] p=%.4f  CI=[%.4f, %.4f]\n", wt, bt$p_val, bt$conf_int[1], bt$conf_int[2]))
    res3d[[wt]] <- data.table(method = used, weights = wt, estimate = b_obs, p = bt$p_val,
                              ci_lo = bt$conf_int[1], ci_hi = bt$conf_int[2])
  }
}
if (!fw_ok) {
  used <- "randomization inference (month-price permutation)"
  cat("fwildclusterboot unavailable/failed -> registered fallback:", used, "\n")
  months <- B[, sort(unique(yyyymm))]
  price_map <- B[, .(comp_price_100 = first(comp_price_100)), keyby = yyyymm]
  set.seed(20260705)
  b_perm <- numeric(RI_R)
  Bp <- copy(B)
  for (r in seq_len(RI_R)) {
    perm <- data.table(yyyymm = months, comp_perm = sample(price_map$comp_price_100))
    Bp[perm, comp_p := i.comp_perm, on = "yyyymm"]
    fp <- feols(reach ~ essential*comp_p + srmc + TOTALDEMAND + nonsync_mw + RRP +
                  slope_kernel + saturated | DUID + yyyymm, Bp, lean = TRUE, notes = FALSE)
    b_perm[r] <- coef(fp)[["essentialTRUE:comp_p"]]
    if (r %% 100 == 0) cat(sprintf("  RI draw %d/%d\n", r, RI_R))
  }
  ri_p <- (1 + sum(abs(b_perm) >= abs(b_obs))) / (RI_R + 1)
  cat(sprintf("RI: b_obs=%.5f; two-sided RI p=%.4f (%d draws; |b_perm|>=|b_obs| in %d)\n",
              b_obs, ri_p, RI_R, sum(abs(b_perm) >= abs(b_obs))))
  res3d[["ri"]] <- data.table(method = used, weights = "uniform month permutation",
                              estimate = b_obs, p = ri_p, ci_lo = NA_real_, ci_hi = NA_real_)
  fwrite(data.table(b_perm = b_perm), file.path(OUT, "test3d_ri_draws.csv"))
}
fwrite(rbindlist(res3d), file.path(OUT, "test3d_inference.csv"))

cat("\nSaved test3{a_month_gaps,a_result,b_horserace,b_wcb,c_placebo_inventory,d_inference}.csv.\n")
cat("=== STOP: adjudicate against test3_preregistration.md. ===\n")
