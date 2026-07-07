#!/usr/bin/env Rscript
# boundary_battery.R -- Steps 1-7 of the boundary-test registration (gate passed; choices
# fixed in outputs/10_boundary_test/step0_note.md). Run from Direction_clean/.

suppressMessages(library(data.table))
set.seed(20260705)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/10_boundary_test")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
W_MAIN <- 30e3; WS <- c(20e3, 30e3, 50e3); N_PLACEBO <- 199L; RI_R <- 999L
TOR <- c("TORRB2", "TORRB3", "TORRB4")

X <- readRDS(file.path(ROOT, "Direction_clean/outputs/09_foregone_profit/foregone_profit_panel.rds"))
setDT(X)
X[, `:=`(R_base = V_base - M_base, R_pess = V_pess - M_pess)]
X[, sit_out := absent]

jump <- function(d, rvar, w, c0 = 0) {
  lo <- d[get(rvar) > c0 - w & get(rvar) <= c0, .(n = .N, rate = mean(sit_out))]
  hi <- d[get(rvar) > c0 & get(rvar) <= c0 + w, .(n = .N, rate = mean(sit_out))]
  data.table(c0 = c0, w = w, n_lo = lo$n, n_hi = hi$n,
             rate_lo = lo$rate, rate_hi = hi$rate, delta = hi$rate - lo$rate)
}
placebo_p <- function(d, rvar, w, n_pl = N_PLACEBO) {
  d0 <- jump(d, rvar, w)
  r <- d[[rvar]]
  qs <- quantile(r, seq(0.025, 0.975, length.out = 4 * n_pl))
  qs <- qs[abs(qs) > w]
  cs <- qs[round(seq(1, length(qs), length.out = n_pl))]
  dpl <- rbindlist(lapply(cs, function(cc) jump(d, rvar, w, cc)))
  dpl <- dpl[n_lo >= 15 & n_hi >= 15]
  p <- (1 + sum(abs(dpl$delta) >= abs(d0$delta), na.rm = TRUE)) / (nrow(dpl) + 1)
  list(d0 = d0, p = p, n_placebo = nrow(dpl), placebos = dpl)
}

battery <- function(d, rvar, label) {
  cat(sprintf("\n======== %s ========\n", label))
  # Step 1: picture
  bins <- d[, .(n = .N, sit_out_rate = mean(sit_out)), by = .(bin_lo = floor(get(rvar) / 10e3) * 10)][order(bin_lo)]
  fwrite(bins, file.path(OUT, sprintf("step1_bins_%s.csv", gsub("[^a-z0-9]", "_", tolower(label)))))
  # Step 2: jumps
  js <- rbindlist(lapply(WS, function(w) jump(d, rvar, w)))
  cat("Step 2 -- jumps:\n"); print(js)
  # Step 3: placebo lines + within-month RI at w main
  pl <- placebo_p(d, rvar, W_MAIN)
  cat(sprintf("Step 3 -- placebo-line rank p = %.4f (%d usable placebo lines) | delta_0 = %+.3f\n",
              pl$p, pl$n_placebo, pl$d0$delta))
  b_perm <- numeric(RI_R)
  dp <- copy(d)
  for (r in seq_len(RI_R)) {
    dp[, sit_out := sample(sit_out), by = yyyymm]
    b_perm[r] <- jump(dp, rvar, W_MAIN)$delta
  }
  d0 <- jump(d, rvar, W_MAIN)$delta
  ri_p <- (1 + sum(abs(b_perm) >= abs(d0))) / (RI_R + 1)
  cat(sprintf("Step 3 -- within-month RI p = %.4f\n", ri_p))
  list(jumps = js, placebo = pl, ri_p = ri_p, bins = bins)
}

# ============================ Torrens, base ============================
T <- X[DUID %chin% TOR]
res_T <- battery(T, "R_base", "TORRENS base")

# Step 4: bundling guard (pi terciles, N-1 strata), w = 30k
cat("\nStep 4 -- bundling guard (descriptive where any side < 15):\n")
T[, pi_terc := cut(pi_day, quantile(pi_day, 0:3 / 3), include.lowest = TRUE, labels = c("t1", "t2", "t3"))]
g4 <- rbindlist(c(
  lapply(levels(T$pi_terc), function(tt) jump(T[pi_terc == tt], "R_base", W_MAIN)[, stratum := paste0("pi_", tt)]),
  lapply(c(TRUE, FALSE), function(nn) jump(T[n1_day == nn], "R_base", W_MAIN)[, stratum := paste0("n1_", nn)])))
g4[, descriptive_only := n_lo < 15 | n_hi < 15]
print(g4[, .(stratum, n_lo, n_hi, delta = round(delta, 3), descriptive_only)])
fwrite(g4, file.path(OUT, "step4_bundling.csv"))

# ============================ Step 5: haircut ============================
# run lengths (licensed haircut input): TORRB commitment spells from DISPATCHLOAD
RL_F <- file.path(OUT, "torrens_run_lengths.rds")
if (file.exists(RL_F)) { RL <- readRDS(RL_F) } else {
  MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")
  cm <- rbindlist(lapply(MONTHS, function(M) {
    dl <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(dl)
    dl <- dl[DUID %chin% TOR & INTERVENTION == 0, .(SETTLEMENTDATE, DUID, INITIALMW)]
    dl[, SETTLEMENTDATE := force10(SETTLEMENTDATE)]
    unique(dl, by = c("SETTLEMENTDATE", "DUID"))
  }))
  setorder(cm, DUID, SETTLEMENTDATE)
  cm[, on := INITIALMW > 1]
  cm[, run_id := cumsum(on != shift(on, fill = FALSE)), by = DUID]
  RL <- cm[on == TRUE, .(hours = .N / 12), by = .(DUID, run_id)]
  saveRDS(RL, RL_F)
}
run_med_days <- RL[, median(hours)] / 24
START_PER_DAY <- 235 * 200 / max(run_med_days, 1/24)   # $47k midpoint amortized per committed day
cat(sprintf("\nStep 5 -- haircut inputs: median committed run %.1f days -> start charge $%.0f/day;\n",
            run_med_days, START_PER_DAY))
X[, mae_um := mean(abs(rrp - rrp_prev_mean)), by = .(DUID, yyyymm)]
X[, M_hair := M_base - 24 * floor_mw * mae_um - START_PER_DAY]
X[, R_hair := V_base - M_hair]
T2 <- X[DUID %chin% TOR]
cat(sprintf("mean MAE penalty $%.0fk/day | share of near-boundary days reclassified: %.1f%%\n",
            T2[, mean(24 * floor_mw * mae_um)] / 1e3,
            100 * T2[abs(R_base) <= W_MAIN, mean(sign(R_base) != sign(R_hair))]))
j_new <- jump(T2, "R_hair", W_MAIN)                 # at the NEW line
j_old <- jump(T2, "R_base", W_MAIN)                 # at the old line (for the glue check)
pl_new <- placebo_p(T2, "R_hair", W_MAIN)
cat("at the NEW zero (R_hair):\n"); print(j_new)
cat(sprintf("placebo rank p at the new line: %.4f\n", pl_new$p))
cat("at the OLD zero (R_base), unchanged data:\n"); print(j_old)
fwrite(rbind(j_new[, line := "new (haircut)"], j_old[, line := "old"]), file.path(OUT, "step5_haircut.csv"))

# ============================ Step 6: PPCCGT ============================
P6 <- X[DUID == "PPCCGT"]
res_P <- battery(P6, "R_base", "PPCCGT base (nothing at stake)")

# ============================ Step 7: pessimistic ============================
res_Tp <- battery(T, "R_pess", "TORRENS pessimistic")

# save headline tables
allj <- rbindlist(list(
  res_T$jumps[, run := "torrens_base"], res_Tp$jumps[, run := "torrens_pess"],
  res_P$jumps[, run := "ppccgt_base"]), fill = TRUE)
fwrite(allj, file.path(OUT, "step2_jumps.csv"))
fwrite(data.table(run = c("torrens_base", "torrens_pess", "ppccgt_base"),
                  placebo_p = c(res_T$placebo$p, res_Tp$placebo$p, res_P$placebo$p),
                  ri_within_month_p = c(res_T$ri_p, res_Tp$ri_p, res_P$ri_p)),
       file.path(OUT, "step3_inference.csv"))
cat("\nDONE battery\n")
