#!/usr/bin/env Rscript
# task5c_depth_check.R -- depth check on the pre-direction evening withdrawal (last open item
# under the framework note's amendment rule). Torrens only, evening hours 19:00-24:00,
# pre-direction rewrite-days (D-1/D-2/D-3 from the station split) vs quiet windows.
# Hour-level availability = mean MAXAVAIL over the hour's 12 intervals, midnight stances.
# Withdrawal event = hourly mean falls >= 1 MW day-over-day. Fixed 40 MW floor. Cases:
#   1 trim headroom: before >= 40 & after >= 40
#   2 floor-crossing: before >= 40 & after < 40   (the only direction-relevant case)
#   3 deepening existing absence: before < 40
# COMMITTED READINGS (before running): case 2 meaningful and above quiet -> the "deepens the
# absence the order will cover" sentence stands with the share quoted; cases 1+3 dominate and
# case 2 rare/no different from quiet -> the sentence comes out and the pre-direction finding
# is restated as availability movement without direction-relevant content.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
TOR <- c("TORRB2","TORRB3","TORRB4")
FLOOR <- 40

TGT <- fread(file.path(OUT, "task4_part3b_day_decomp.csv"))[, .(DUID, cal_day=as.Date(cal_day), grp)]
TGT <- TGT[DUID %in% TOR]
cat("Rewrite-days (Torrens):\n"); print(TGT[, .N, by=grp][order(grp)])

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TOR, .(DUID, cal_day, idt, MAXAVAIL)]
need <- unique(rbind(TGT[, .(DUID, cal_day)], TGT[, .(DUID, cal_day=cal_day-1)]))
IV <- merge(IV, need, by=c("DUID","cal_day"))
IV[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]
HM <- IV[hh %in% 19:23, .(ma = mean(MAXAVAIL)), by=.(DUID, cal_day, hh)]
prev <- copy(HM)[, cal_day := cal_day + 1L]; setnames(prev, "ma", "ma0")
H <- merge(HM, prev, by=c("DUID","cal_day","hh"))
H <- merge(H, TGT, by=c("DUID","cal_day"))
H[, drop := ma0 - ma]
W <- H[drop >= 1]                       # withdrawal events
W[, case := fcase(ma0 >= FLOOR & ma >= FLOOR, "1 trim headroom",
                  ma0 >= FLOOR & ma <  FLOOR, "2 floor-crossing",
                  default = "3 deepen existing absence")]
W[, pre := fifelse(grp=="quiet", "quiet", "pre-direction")]

cat("\n=== THE TABLE: withdrawn evening hours by case (hour counts = denominators) ===\n")
tab <- W[, .N, by=.(pre, DUID, case)]
tab[, share := round(100*N/sum(N),1), by=.(pre, DUID)]
print(dcast(tab, pre + DUID ~ case, value.var=c("N","share"), fill=0))
pool <- W[, .N, by=.(pre, case)][, share := round(100*N/sum(N),1), by=pre][]
cat("\nPooled:\n"); print(dcast(pool, pre ~ case, value.var=c("N","share"), fill=0))
fwrite(tab, file.path(OUT, "task5c_case_table.csv"))

cat("\n=== Case 2 detail: D-1 rewrite-days with >= 1 evening floor-crossing ===\n")
d1 <- TGT[grp=="D-1"]
c2 <- W[case=="2 floor-crossing" & grp=="D-1", .(n_cross=.N, max_drop=max(drop)), by=.(DUID, cal_day)]
cat(sprintf("Episodes (D-1 rewrite-days) with a crossing: %d of %d (%.1f%%)\n",
            nrow(c2), nrow(d1), 100*nrow(c2)/nrow(d1)))
allc2 <- W[case=="2 floor-crossing" & pre=="pre-direction"]
if (nrow(allc2)) { cat("Crossing sizes (before -> after MW), pre-direction all windows:\n")
  print(allc2[, .(n=.N, before_med=round(median(ma0)), after_med=round(median(ma)),
                  drop_p25=round(quantile(drop,.25)), drop_med=round(median(drop)), drop_p75=round(quantile(drop,.75)))]) }
cat(sprintf("Quiet-window floor-crossing rate per rewrite-day: %.3f (n=%d crossings / %d days) vs pre-direction %.3f (%d / %d)\n",
            W[case=="2 floor-crossing" & pre=="quiet", .N]/TGT[grp=="quiet", .N],
            W[case=="2 floor-crossing" & pre=="quiet", .N], TGT[grp=="quiet", .N],
            W[case=="2 floor-crossing" & pre=="pre-direction", .N]/TGT[grp!="quiet", .N],
            W[case=="2 floor-crossing" & pre=="pre-direction", .N], TGT[grp!="quiet", .N]))

cat("\n=== Before-levels of withdrawn evening hours ===\n")
W[, before_bin := fcase(ma0 >= 100, "ample (>=100)", ma0 >= FLOOR, "near floor (40-100)", default="under floor (<40)")]
bl <- W[, .N, by=.(pre, before_bin)][, share := round(100*N/sum(N),1), by=pre][]
print(dcast(bl, pre ~ before_bin, value.var=c("N","share"), fill=0))
fwrite(W, file.path(OUT, "task5c_withdrawal_events.csv"))
cat("\nSaved task5c_{case_table,withdrawal_events}.csv\n")
