#!/usr/bin/env Rscript
# step0_final_support.R -- Step 0 of the REBUILT boundary test (registration_final.md).
# Rebuilt M_d: final-run PREDISPATCH day-mean price, start charge in the base construction.
# NO OUTCOME DATA TOUCHED (absence columns dropped on load). Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/10_boundary_test")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")

X <- readRDS(file.path(ROOT, "Direction_clean/outputs/09_foregone_profit/foregone_profit_panel.rds"))
setDT(X)
X[, c("absent", "absent50", "reach_share") := NULL]     # outcome quarantined

# final-run PD day-mean price
PP <- rbindlist(lapply(MONTHS, function(M) {
  f <- file.path(CACHE, sprintf("PREDISPATCH_PRICE_%s.rds", M))
  if (!file.exists(f)) stop(sprintf("MISSING PREDISPATCH_PRICE_%s", M))
  readRDS(f)
}), fill = TRUE)
PP <- PP[is.na(INTERVENTION) | INTERVENTION == 0]
PP[, cal_day := as.Date(force10(DATETIME) - 1, tz = "Etc/GMT-10")]
PDM <- PP[, .(pd_mean = mean(RRP), n_iv = .N), by = cal_day]
cat(sprintf("PD price days: %d | half-hours/day median %d\n", nrow(PDM), PDM[, median(n_iv)]))
X <- merge(X, PDM[, .(cal_day, pd_mean)], by = "cal_day", all.x = TRUE)
n_na <- X[is.na(pd_mean), .N]
cat(sprintf("unit-days without PD price: %d (dropped, flagged)\n", n_na))
X <- X[!is.na(pd_mean)]

# rebuilt M (start charge in base, exact cached amortization)
RL <- readRDS(file.path(OUT, "torrens_run_lengths.rds"))
run_med_days <- RL[, median(hours)] / 24
START_PER_DAY <- 235 * 200 / run_med_days
cat(sprintf("amortization: median run %.3f days -> start charge $%.0f/day\n", run_med_days, START_PER_DAY))
X[, M_new := 24 * floor_mw * (pd_mean - srmc) - START_PER_DAY]
X[, R_new := V_base - M_new]
X[, grp := fifelse(DUID == "PPCCGT", "PPCCGT", "TORRENS")]

# measurement noise now vs before
X[, mae_new := mean(abs(rrp - pd_mean)), by = .(DUID, yyyymm)]
X[, mae_old := mean(abs(rrp - rrp_prev_mean)), by = .(DUID, yyyymm)]
cat(sprintf("day-mean price MAE: final-run PD $%.1f | prev-day realized $%.1f  (dollar blur on M: $%.0fk vs $%.0fk/day at Torrens floor)\n",
            X[, mean(mae_new)], X[, mean(mae_old)],
            X[grp == "TORRENS", mean(24 * floor_mw * mae_new)] / 1e3,
            X[grp == "TORRENS", mean(24 * floor_mw * mae_old)] / 1e3))

# movement vs the regions task (flag sizes, per the constraint)
reg <- function(M, V) fifelse(M <= 0, "A", fifelse(M < V, "B", "C"))
X[, `:=`(region_old = reg(M_base, V_base), region_new = reg(M_new, V_base))]
mv <- X[, .(moved = mean(region_old != region_new)), by = grp]
cat("region movement under rebuilt M:\n"); print(mv)
cat("cross-tab (pooled):\n"); print(X[, table(old = region_old, new = region_new)])

# support report
lines <- c("# Boundary support (REBUILT M) — where the days sit (Step 0; outcome untouched)", "",
  sprintf("Panel: %d clean unit-days with a final-run PD price (%d dropped for missing price).", nrow(X), n_na),
  sprintf("Rebuilt M_d = 24h x floor x (final-run PD day-mean - SRMC) - $%.0f/day start charge.", START_PER_DAY),
  sprintf("Measurement blur: day-mean price MAE $%.1f (was $%.1f with prev-day realized); in dollars at the Torrens floor: ~$%.0fk/day (was ~$%.0fk).",
          X[, mean(mae_new)], X[, mean(mae_old)],
          X[grp == "TORRENS", mean(24 * floor_mw * mae_new)] / 1e3,
          X[grp == "TORRENS", mean(24 * floor_mw * mae_old)] / 1e3),
  sprintf("Timing caveat (dated note item 1): final-run PD prices form ~30 min before delivery, not at bid formation."), "")
hist_all <- list()
for (g in c("TORRENS", "PPCCGT")) {
  r <- X[grp == g, R_new] / 1000
  h <- data.table(bin_lo = floor(r / 10) * 10)[, .N, by = bin_lo][order(bin_lo)][, grp := g]
  hist_all[[g]] <- h
  lines <- c(lines, sprintf("## %s", g),
             sprintf("R range $%.0fk to $%.0fk | median $%.0fk | share R>0: %.1f%%", min(r), max(r), median(r), 100 * mean(r > 0)),
             sprintf("days within ±$20k: **%d** | ±$30k: **%d** | ±$50k: %d", sum(abs(r) <= 20), sum(abs(r) <= 30), sum(abs(r) <= 50)), "")
}
fwrite(rbindlist(hist_all), file.path(OUT, "boundary_final_support_hist.csv"))
nb <- X[grp == "TORRENS" & abs(R_new) <= 30000]
mcl <- nb[, .N, by = yyyymm][order(-N)]
lines <- c(lines, "## Gate, clustering, movement",
  sprintf("Pooled Torrens days within ±$30k: **%d** (gate 60) → **%s**.", nrow(nb), if (nrow(nb) < 60) "GATE FIRES" else "gate passes"),
  sprintf("Near-boundary months: %d distinct; top-3 hold %.0f%% (%s).", nrow(mcl), 100 * sum(head(mcl$N, 3)) / max(nrow(nb), 1), paste(head(mcl$yyyymm, 3), collapse = ", ")),
  sprintf("Region movement vs the regions task: TORRENS %.1f%%, PPCCGT %.1f%% of days change region (cross-tab in log).",
          100 * mv[grp == "TORRENS", moved], 100 * mv[grp == "PPCCGT", moved]))
writeLines(lines, file.path(OUT, "boundary_final_support.md"))
saveRDS(X, file.path(OUT, "boundary_final_panel_step0.rds"))
cat(readLines(file.path(OUT, "boundary_final_support.md")), sep = "\n")
cat("\nDONE step0-final\n")
