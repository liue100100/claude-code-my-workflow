#!/usr/bin/env Rscript
# stage5_expected_prize.R -- Stage 5: the expected-prize test EP = pi x rent
# (stage5_expected_prize_registration.md, committed first). Run from Direction_clean/.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
JUNE_COMP_PRICE <- 241.38; WCB_R <- 999L; RI_R <- 999L
TEST_UNITS <- c("TORRB2", "TORRB3", "TORRB4", "PPCCGT")

# ---- assembly: byte-identical to stage4_conduct.R / test1 ----
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

# ---- dose construction: rent (Test-4 primary) + pi (Stage-3 pi2) ----
sp <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
sp <- sp[duid %chin% TEST_UNITS, .(DUID = duid, yyyymm = as.integer(yyyymm), srmc_allin)]
B <- merge(B, sp, by = c("DUID", "yyyymm"), all.x = TRUE)
stopifnot(B[, sum(is.na(srmc_allin))] == 0)
B[, `:=`(rent = pmax(comp_price - srmc_allin, 0), allin_100 = srmc_allin / 100)]
S2 <- readRDS(file.path(OUT, "stage2_panel.rds")); setDT(S2)
B[, t30 := as.POSIXct(ceiling(as.numeric(interval_dt) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
B <- merge(B, S2[, .(t30, pi2_8h, pi_da_8h)], by = "t30", all.x = TRUE)
B <- B[!is.na(pi2_8h)]
B[, `:=`(ep_100 = pi2_8h * rent / 100, ep_da_100 = pi_da_8h * rent / 100, rent_100 = rent / 100)]
cat(sprintf("B: %d rows (%d essential)\n", nrow(B), B[, sum(essential)]))

# ---- power report BEFORE any coefficient (registered) ----
cat("\n=== POWER REPORT: expected prize EP = pi x rent ($/MWh) ===\n")
pr <- function(x, lab) cat(sprintf("  [%s] sd %.1f | IQR %.1f | range %.1f-%.1f | share EP==0 %.1f%%\n",
      lab, sd(x), IQR(x), min(x), max(x), 100 * mean(x == 0)))
pr(B[essential == TRUE, ep_100 * 100], "essential rows")
pr(B[, ep_100 * 100], "all matched rows")
cat(sprintf("  cor(EP, d_t) %.3f | cor(EP, pi) %.3f | cor(EP, rent) %.3f\n",
            B[, cor(ep_100, comp_price_100)], B[, cor(ep_100, pi2_8h)], B[, cor(ep_100, rent_100)]))
ep_iqr_ess <- B[essential == TRUE, IQR(ep_100 * 100)]
cat(sprintf("  committed degeneracy screen: essential-row EP IQR = $%.1f (bound-not-evidence if < $5)\n", ep_iqr_ess))

rhs_ctl <- "srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
tidy <- function(f, lab) { ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  ct[, `:=`(spec = lab, nobs = nobs(f))][] }
res <- list()

# ---- anchor ----
f_anchor <- feols(as.formula(sprintf("reach_a ~ essential*comp_price_100 + %s | DUID + yyyymm", rhs_ctl)),
                  B, vcov = ~yyyymm)
b_anchor <- coef(f_anchor)[["essentialTRUE:comp_price_100"]]
t1 <- fread(file.path(ROOT, "Direction_clean/outputs/06_round2/test1_interaction.csv"))
b_ref <- t1[startsWith(sample, "BASE") & outcome == "reach_a", estimate]
cat(sprintf("\nanchor: %.6f vs %.6f\n", b_anchor, b_ref))
stopifnot(abs(b_anchor - b_ref) < 1e-6)

# ---- primary: reach ~ pi + EP + controls ----
f_ep <- feols(as.formula(sprintf("reach_a ~ pi2_8h + ep_100 + %s | DUID + yyyymm", rhs_ctl)),
              B, vcov = ~yyyymm)
res$ep <- tidy(f_ep, "primary: pi + EP")
cat("\n=== PRIMARY: expected prize, probability held fixed ===\n")
print(res$ep[term %in% c("pi2_8h", "ep_100"), .(term, estimate, std.error, p.value)])

# ---- horse race + make-whole restriction ----
f_hr <- feols(as.formula(sprintf("reach_a ~ pi2_8h + pi2_8h:comp_price_100 + pi2_8h:allin_100 + %s | DUID + yyyymm", rhs_ctl)),
              B, vcov = ~yyyymm)
res$hr <- tidy(f_hr, "horse race: pi x d_t + pi x allin")
V <- vcov(f_hr)
tdt <- "pi2_8h:comp_price_100"; tal <- "pi2_8h:allin_100"
cmb <- coef(f_hr)[[tdt]] + coef(f_hr)[[tal]]
vc  <- V[tdt, tdt] + V[tal, tal] + 2 * V[tdt, tal]
p_r <- 2 * pt(-abs(cmb / sqrt(vc)), df = uniqueN(B$yyyymm) - 1L)
cat(sprintf("\nhorse race: b(pi x d_t)=%.4f  b(pi x allin)=%.4f | restriction sum=%.4f p=%.4f\n",
            coef(f_hr)[[tdt]], coef(f_hr)[[tal]], cmb, p_r))

# ---- robustness: day-ahead pi ----
BD <- B[!is.na(ep_da_100)]
f_da <- feols(as.formula(sprintf("reach_a ~ pi_da_8h + ep_da_100 + %s | DUID + yyyymm", rhs_ctl)),
              BD, vcov = ~yyyymm)
res$da <- tidy(f_da, "robustness: day-ahead pi + EP_da")
cat("\nday-ahead: "); print(res$da[term %in% c("pi_da_8h", "ep_da_100"), .(term, estimate, std.error, p.value)])

# ---- WCB on EP_100 (base) ----
cat("\n=== WCB on ep_100 ===\n")
lmf <- lm(as.formula(sprintf("reach_a ~ pi2_8h + ep_100 + %s + factor(DUID) + factor(yyyymm)", rhs_ctl)), B)
b_lm <- coef(lmf)[["ep_100"]]
stopifnot(abs(b_lm - coef(f_ep)[["ep_100"]]) < 1e-6)
wcb <- list()
for (wt in c(rademacher = "wild", webb = "wild-webb")) {
  set.seed(20260705)
  v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt)
  se <- sqrt(v["ep_100", "ep_100"]); df <- uniqueN(B$yyyymm) - 1L
  pv <- 2 * pt(-abs(b_lm / se), df = df)
  cat(sprintf("  [%s] b=%.5f se=%.5f p=%.4f\n", wt, b_lm, se, pv))
  wcb[[wt]] <- data.table(weights = wt, estimate = b_lm, wcb_se = se, wcb_p = pv)
}
fwrite(rbindlist(wcb), file.path(OUT, "stage5_wcb.csv"))
rm(lmf); gc(verbose = FALSE)

# ---- RI: permute month labels of the unit x month rent map (4-unit blocks); pi fixed ----
cat("\n=== RI: month-block permutation of the rent map, 999 draws ===\n")
months <- B[, sort(unique(yyyymm))]
rmap <- merge(sp, cp, by = "yyyymm")[yyyymm %in% months]
rmap[, rent := pmax(comp_price - srmc_allin, 0)]
rmap <- rmap[, .(DUID, yyyymm, rent)]
stopifnot(rmap[, .N, by = yyyymm][, all(N == length(TEST_UNITS))])
b_obs <- coef(f_ep)[["ep_100"]]
Bp <- copy(B)
idm <- rmap[, .(DUID, yyyymm, v = rent)]
Bp[idm, rent_p := i.v, on = c("DUID", "yyyymm")]
stopifnot(Bp[, all(abs(rent_p - rent) < 1e-12)])
Bp[, ep_p := pi2_8h * rent_p / 100]
f_id <- feols(as.formula(sprintf("reach_a ~ pi2_8h + ep_p + %s | DUID + yyyymm", rhs_ctl)),
              Bp, lean = TRUE, notes = FALSE)
stopifnot(abs(coef(f_id)[["ep_p"]] - b_obs) < 1e-10)
cat(sprintf("identity check OK (b_obs=%.5f)\n", b_obs))
set.seed(20260705)
b_perm <- numeric(RI_R)
for (r in seq_len(RI_R)) {
  perm <- data.table(yyyymm_to = months, yyyymm_from = sample(months))
  pm <- rmap[perm, on = .(yyyymm = yyyymm_from)][, .(DUID, yyyymm = yyyymm_to, v = rent)]
  Bp[pm, rent_p := i.v, on = c("DUID", "yyyymm")]
  Bp[, ep_p := pi2_8h * rent_p / 100]
  fp <- feols(as.formula(sprintf("reach_a ~ pi2_8h + ep_p + %s | DUID + yyyymm", rhs_ctl)),
              Bp, lean = TRUE, notes = FALSE)
  b_perm[r] <- coef(fp)[["ep_p"]]
  if (r %% 100 == 0) cat(sprintf("  RI draw %d/%d\n", r, RI_R))
}
ri_p <- (1 + sum(abs(b_perm) >= abs(b_obs))) / (RI_R + 1)
cat(sprintf("RI: b_obs=%.5f two-sided p=%.4f (exceed %d/%d)\n",
            b_obs, ri_p, sum(abs(b_perm) >= abs(b_obs)), RI_R))
fwrite(data.table(b_perm = b_perm), file.path(OUT, "stage5_ri_draws.csv"))
fwrite(data.table(estimate = b_obs, ri_p = ri_p, ep_iqr_ess = ep_iqr_ess), file.path(OUT, "stage5_ri.csv"))

RES <- rbindlist(res)
fwrite(RES, file.path(OUT, "stage5_results.csv"))
cat("\nSaved stage5_{results,wcb,ri,ri_draws}.csv\n")
cat("=== STOP: adjudicate against stage5_expected_prize_registration.md. ===\n")
