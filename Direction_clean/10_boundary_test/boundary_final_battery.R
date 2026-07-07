#!/usr/bin/env Rscript
# boundary_final_battery.R -- Steps 1-6 of the REBUILT boundary test (registration_final.md;
# gate passed; choices completed in the dated note). Run from Direction_clean/.

suppressMessages(library(data.table))
set.seed(20260705)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/10_boundary_test")
W_MAIN <- 30e3; WS <- c(20e3, 30e3, 50e3); N_PLACEBO <- 199L; RI_R <- 999L
TOR <- c("TORRB2", "TORRB3", "TORRB4")

X <- readRDS(file.path(OUT, "boundary_final_panel_step0.rds")); setDT(X)
AB <- readRDS(file.path(ROOT, "Direction_clean/outputs/09_foregone_profit/foregone_profit_panel.rds"))
setDT(AB)
X <- merge(X, AB[, .(DUID, cal_day, sit_out = absent)], by = c("DUID", "cal_day"))
stopifnot(X[, sum(is.na(sit_out))] == 0)

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
  list(d0 = d0, p = p, n_placebo = nrow(dpl))
}
battery <- function(d, rvar, label) {
  cat(sprintf("\n======== %s ========\n", label))
  bins <- d[, .(n = .N, sit_out_rate = mean(sit_out)), by = .(bin_lo = floor(get(rvar) / 10e3) * 10)][order(bin_lo)]
  fwrite(bins, file.path(OUT, sprintf("final_step1_bins_%s.csv", gsub("[^a-z0-9]", "_", tolower(label)))))
  js <- rbindlist(lapply(WS, function(w) jump(d, rvar, w)))
  cat("Step 2 -- jumps:\n"); print(js)
  pl <- placebo_p(d, rvar, W_MAIN)
  cat(sprintf("Step 3 -- placebo rank p = %.4f (%d lines) | delta_0 = %+.3f\n", pl$p, pl$n_placebo, pl$d0$delta))
  b_perm <- numeric(RI_R); dp <- copy(d)
  for (r in seq_len(RI_R)) { dp[, sit_out := sample(sit_out), by = yyyymm]
    b_perm[r] <- jump(dp, rvar, W_MAIN)$delta }
  d0 <- jump(d, rvar, W_MAIN)$delta
  cat(sprintf("Step 3 -- within-month RI p = %.4f\n", (1 + sum(abs(b_perm) >= abs(d0))) / (RI_R + 1)))
  list(jumps = js, placebo = pl)
}

T <- X[DUID %chin% TOR]
res_T <- battery(T, "R_new", "TORRENS rebuilt")

cat("\nStep 4 -- proximity guard (descriptive where any side < 15):\n")
T[, pi_terc := cut(pi_day, quantile(pi_day, 0:3 / 3), include.lowest = TRUE, labels = c("t1", "t2", "t3"))]
g4 <- rbindlist(c(
  lapply(levels(T$pi_terc), function(tt) jump(T[pi_terc == tt], "R_new", W_MAIN)[, stratum := paste0("pi_", tt)]),
  lapply(c(TRUE, FALSE), function(nn) jump(T[n1_day == nn], "R_new", W_MAIN)[, stratum := paste0("n1_", nn)])))
g4[, descriptive_only := n_lo < 15 | n_hi < 15]
print(g4[, .(stratum, n_lo, n_hi, delta = round(delta, 3), descriptive_only)])
fwrite(g4, file.path(OUT, "final_step4_proximity.csv"))

res_P <- battery(X[DUID == "PPCCGT"], "R_new", "PPCCGT rebuilt (negative control)")

cat("\nStep 6 -- the commercial threshold under the rebuilt M (M_new = 0):\n")
for (w in WS) {
  lo <- T[M_new > -w & M_new <= 0, .(n = .N, rate = mean(sit_out))]
  hi <- T[M_new > 0 & M_new <= w, .(n = .N, rate = mean(sit_out))]
  cat(sprintf("  w=%2.0fk: sit-out %0.3f (n=%d) below vs %0.3f (n=%d) above -> drop %+.3f\n",
              w / 1e3, lo$rate, lo$n, hi$rate, hi$n, lo$rate - hi$rate))
}
cat("global: sit-out on M_new<=0 days %.3f (n=%d) vs M_new>0 days %.3f (n=%d)\n" |> sprintf(
    T[M_new <= 0, mean(sit_out)], T[M_new <= 0, .N], T[M_new > 0, mean(sit_out)], T[M_new > 0, .N]))
mj <- rbindlist(lapply(WS, function(w) jump(T, "M_new", w)))
fwrite(mj, file.path(OUT, "final_step6_commercial.csv"))

allj <- rbind(res_T$jumps[, run := "torrens_rebuilt"], res_P$jumps[, run := "ppccgt_rebuilt"])
fwrite(allj, file.path(OUT, "final_step2_jumps.csv"))
cat("\nDONE final battery\n")
