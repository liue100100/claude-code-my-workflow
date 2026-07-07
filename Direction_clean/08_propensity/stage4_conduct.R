#!/usr/bin/env Rscript
# stage4_conduct.R -- Stage 4 of the direction-propensity registration: the conduct test
# rebuilt on the rivals-only propensity. Licensed by the Stage-2 residual gate (2.8%) and the
# Stage-3 amended-gate PASS (registration.md Amendment 1).
#
# Outcome: floor-within-reach (reach_a). Design: exact Stage-4/Test-1 machinery on the CEM
# matched base sample; pex REPLACED by pi (continuous, 30-min, joined to the 5-min grain).
# Objects, registered: pi x d_t; then pi_slow x d_t + pi_fast x d_t. Robustness: pex spec must
# reproduce Table 4 (-0.0855); pi thresholded at pex-matched incidence; day-ahead pi variant.
# Inference: month-clustered analytic + WCB (vcovBS, R=999) + RI permuting month-to-d_t
# (999 draws, seed 20260705). Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
JUNE_COMP_PRICE <- 241.38; WCB_R <- 999L; RI_R <- 999L

# ---- assembly: byte-identical to test1_floor_reach.R ----
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
setDT(D); n0 <- nrow(D)
O <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
O <- O[, .(DUID, interval_dt, td, cheap_a_mw = cheap_a, MAXAVAIL)]
D <- merge(D, O, by = c("DUID", "interval_dt"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(cheap_a_mw))] == 0)
D[, day_ceiling := max(MAXAVAIL), by = .(DUID, td)]
D[, floor_mw := fifelse(DUID == "PPCCGT", fifelse(day_ceiling <= 239, 42, 125), 40)]
D[, reach_a := as.integer(cheap_a_mw >= floor_mw)]
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
B <- D[stratum %in% strata_ok & segment != "suspension_window"]

# ---- pi join (30-min -> 5-min) ----
S2 <- readRDS(file.path(OUT, "stage2_panel.rds")); setDT(S2)
B[, t30 := as.POSIXct(ceiling(as.numeric(interval_dt) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
B <- merge(B, S2[, .(t30, pi2_8h, pi2_slow, pi2_fast, pi_da_8h)], by = "t30", all.x = TRUE)
cat(sprintf("B: %d rows | NA pi2_8h: %d | NA pi2_slow (edge months): %d\n",
            nrow(B), B[is.na(pi2_8h), .N], B[is.na(pi2_slow), .N]))

rhs_ctl <- "srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
tidy <- function(f, lab) { ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  ct[, `:=`(spec = lab, nobs = nobs(f))][] }
res <- list()

# ---- S4a: anchor -- the pex specification must reproduce Table 4 ----
f_anchor <- feols(as.formula(sprintf("reach_a ~ essential*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
                  B, vcov = ~yyyymm)
b_anchor <- coef(f_anchor)[["essentialTRUE:comp_price_100"]]
t1 <- fread(file.path(ROOT, "Direction_clean/outputs/06_round2/test1_interaction.csv"))
b_ref <- t1[startsWith(sample, "BASE") & outcome == "reach_a", estimate]
cat(sprintf("S4a anchor: %.6f vs Table-4 %.6f\n", b_anchor, b_ref))
stopifnot(abs(b_anchor - b_ref) < 1e-6)
res$anchor <- tidy(f_anchor, "anchor: pex spec (Table 4)")

# ---- S4b: primary -- pi2 x d_t ----
BP <- B[!is.na(pi2_8h)]
f_pi <- feols(as.formula(sprintf("reach_a ~ pi2_8h*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
              BP, vcov = ~yyyymm)
res$pi <- tidy(f_pi, "primary: pi2_8h x d_t")
cat("\n=== S4b primary: pi2_8h x comp_price_100 ===\n")
print(res$pi[grepl("pi2_8h", term), .(term, estimate, std.error, p.value)])

# ---- S4c: slow/fast decomposition ----
BS <- B[!is.na(pi2_slow)]
f_sf <- feols(as.formula(sprintf("reach_a ~ pi2_slow*comp_price_100 + pi2_fast*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
              BS, vcov = ~yyyymm)
res$sf <- tidy(f_sf, "slow/fast: pi2_slow x d_t + pi2_fast x d_t")
cat("\n=== S4c slow/fast ===\n")
print(res$sf[grepl("pi2_", term), .(term, estimate, std.error, p.value)])

# ---- S4d robustness: thresholded pi at pex-matched incidence; day-ahead pi ----
inc <- BP[, mean(essential)]
thr <- BP[, quantile(pi2_8h, 1 - inc)]
BP[, pi_flag := pi2_8h > thr]
cat(sprintf("\nthresholded pi: incidence target %.4f -> threshold %.4f -> flag incidence %.4f\n",
            inc, thr, BP[, mean(pi_flag)]))
f_thr <- feols(as.formula(sprintf("reach_a ~ pi_flag*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
               BP, vcov = ~yyyymm)
res$thr <- tidy(f_thr, sprintf("robustness: pi > %.3f (pex-matched incidence)", thr))
BD <- B[!is.na(pi_da_8h)]
f_da <- feols(as.formula(sprintf("reach_a ~ pi_da_8h*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
              BD, vcov = ~yyyymm)
res$da <- tidy(f_da, "robustness: day-ahead pi x d_t")
cat("\n=== S4d robustness ===\n")
print(rbind(res$thr[grepl("pi_flag", term)], res$da[grepl("pi_da", term)])[
  , .(spec, term, estimate, std.error, p.value)])

# ---- S4e inference on the primary: WCB + RI ----
cat("\n=== S4e: WCB (vcovBS R=999) on pi2_8h:comp_price_100, base ===\n")
fml_lm <- as.formula(sprintf("reach_a ~ pi2_8h*comp_price_100 + %s + factor(DUID) + factor(yyyymm)", rhs_ctl))
lmf <- lm(fml_lm, BP)
b_lm <- coef(lmf)[["pi2_8h:comp_price_100"]]
stopifnot(abs(b_lm - coef(f_pi)[["pi2_8h:comp_price_100"]]) < 1e-6)
wcb <- list()
for (wt in c(rademacher = "wild", webb = "wild-webb")) {
  set.seed(20260705)
  v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt)
  se <- sqrt(v["pi2_8h:comp_price_100", "pi2_8h:comp_price_100"])
  df <- uniqueN(BP$yyyymm) - 1L
  pv <- 2 * pt(-abs(b_lm / se), df = df)
  cat(sprintf("  [%s] b=%.5f  se=%.5f  p=%.4f\n", wt, b_lm, se, pv))
  wcb[[wt]] <- data.table(weights = wt, estimate = b_lm, wcb_se = se, wcb_p = pv)
}
fwrite(rbindlist(wcb), file.path(OUT, "stage4_wcb.csv"))
rm(lmf); gc(verbose = FALSE)

cat("\n=== S4e: RI (month-to-d_t permutation, 999 draws) on the primary ===\n")
months <- BP[, sort(unique(yyyymm))]
price_map <- BP[, .(cp = first(comp_price_100)), keyby = yyyymm]
b_obs <- coef(f_pi)[["pi2_8h:comp_price_100"]]
set.seed(20260705)
b_perm <- numeric(RI_R)
Bp <- copy(BP)
for (r in seq_len(RI_R)) {
  perm <- data.table(yyyymm = months, cp_p = sample(price_map$cp))
  Bp[perm, comp_p := i.cp_p, on = "yyyymm"]
  fp <- feols(as.formula(sprintf("reach_a ~ pi2_8h*comp_p + %s | DUID + yyyymm", rhs_ctl)),
              Bp, lean = TRUE, notes = FALSE)
  b_perm[r] <- coef(fp)[["pi2_8h:comp_p"]]
  if (r %% 100 == 0) cat(sprintf("  RI draw %d/%d\n", r, RI_R))
}
ri_p <- (1 + sum(abs(b_perm) >= abs(b_obs))) / (RI_R + 1)
cat(sprintf("RI: b_obs=%.5f  two-sided p=%.4f (exceed %d/%d)\n",
            b_obs, ri_p, sum(abs(b_perm) >= abs(b_obs)), RI_R))
fwrite(data.table(b_perm = b_perm), file.path(OUT, "stage4_ri_draws.csv"))
fwrite(data.table(estimate = b_obs, ri_p = ri_p, draws = RI_R), file.path(OUT, "stage4_ri.csv"))

RES <- rbindlist(res)
fwrite(RES, file.path(OUT, "stage4_results.csv"))
cat("\nSaved stage4_{results,wcb,ri,ri_draws}.csv\n")
cat("=== STOP: adjudicate against the registration's committed interpretations. ===\n")
