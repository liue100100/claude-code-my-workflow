#!/usr/bin/env Rscript
# task6_part1_gate.R -- Final regression, Part 1: who could even take the exit act?
# Population = Torrens unit-days d (clean per Job 2) where YESTERDAY's midnight stance offered
# a full evening (all five hourly means 19:00-24:00 >= 40 MW). Act = today's stance crosses
# >= 1 of those hours below 40 (depth-check case 2). Essential = same-day pex flag (system
# conditions only). STOPPING RULE (fixed): essential row < 30 days OR < 10 cancellations
# in the essential row -> stop, no test.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
TOR <- c("TORRB2","TORRB3","TORRB4")
FLOOR <- 40

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TOR, .(DUID, cal_day, idt, MAXAVAIL)]
IV[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]
HM <- IV[hh %in% 19:23, .(ma = mean(MAXAVAIL)), by=.(DUID, cal_day, hh)]
EV <- HM[, .(evening_on = all(ma >= FLOOR), n_h = .N), by=.(DUID, cal_day)]
prev <- HM[, .(DUID, cal_day = cal_day + 1L, hh, ma0 = ma)]
X <- merge(HM, prev, by=c("DUID","cal_day","hh"))
CX <- X[, .(cancel = any(ma0 >= FLOOR & ma < FLOOR & (ma0 - ma) >= 1)), by=.(DUID, cal_day)]
P <- merge(EV[, .(DUID, cal_day = cal_day + 1L, evening_on_yday = evening_on)], CX, by=c("DUID","cal_day"))
D <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
P <- merge(P, D[, .(DUID, cal_day, essential_day, yyyymm, segment, srmc, dem, ns, rrp,
                    slope_mean, sat_share, exp_loss)], by=c("DUID","cal_day"))
DC <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
P <- merge(P, DC[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"))
POP <- P[evening_on_yday==TRUE & clean==TRUE]
cat(sprintf("Population: %d clean Torrens unit-days with a full evening on offer yesterday (of %d clean Torrens days)\n",
            nrow(POP), P[clean==TRUE, .N]))
cat("\n=== THE 2x2 ===\n")
t22 <- POP[, .N, by=.(row = fifelse(essential_day, "Essential day", "Ordinary day"),
                      col = fifelse(cancel, "Cancelled the evening", "Didn't"))]
print(dcast(t22, row ~ col, value.var="N", fill=0))
ess_n <- POP[essential_day==TRUE, .N]; ess_c <- POP[essential_day==TRUE & cancel==TRUE, .N]
cat(sprintf("\nRates: essential %d/%d = %.1f%% | ordinary %d/%d = %.1f%%\n",
            ess_c, ess_n, 100*POP[essential_day==TRUE, mean(cancel)],
            POP[essential_day==FALSE & cancel==TRUE, .N], POP[essential_day==FALSE, .N],
            100*POP[essential_day==FALSE, mean(cancel)]))
cat(sprintf("STOPPING RULE: essential days = %d (need >= 30); essential cancellations = %d (need >= 10) -> %s\n",
            ess_n, ess_c, if (ess_n >= 30 && ess_c >= 10) "GATE PASSES" else "STOP -- too thin for a test"))
saveRDS(POP, file.path(OUT, "task6_population.rds"))
fwrite(t22, file.path(OUT, "task6_2x2.csv"))
