#!/usr/bin/env Rscript
# task5a2_floor_block_migration.R -- follow-up to Task A: did the FLOOR BLOCK move UP in price
# bands? Tracks the price class of the floor megawatt (p_floor, per interval, midnight stance)
# and its day-over-day migration in the D-3 -> D-1 pre-direction windows vs quiet 48h windows.
# Classes: withdrawn (MAXAVAIL < floor) | floor band (<= $0) | cheap (0,300] | mid (300,1000] |
# high (1000, 0.9xMPC) | near-cap (>= 0.9xMPC). "Moved up in bands" = hours shifted from
# cheap-or-below to > $1,000 while offered.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
MPC <- c(`2022`=15100, `2023`=15500, `2024`=16600, `2025`=17500)
fy_end <- function(d) year(d) + (month(d) >= 7L)

PF <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))
PF <- PF[DUID %in% c("TORRB2","TORRB3","TORRB4","PPCCGT")]
PF[, mpc := MPC[as.character(fy_end(cal_day))]]
PF[, cls := fcase(avail_below_floor==TRUE, "withdrawn",
                  p_floor <= 0, "floor_band",
                  p_floor <= 300, "cheap",
                  p_floor <= 1000, "mid",
                  p_floor < 0.9*mpc, "high",
                  default = "near_cap")]
H <- dcast(PF[, .N, by=.(DUID, cal_day, cls)], DUID + cal_day ~ cls, value.var="N", fill=0)
for (cc in c("withdrawn","floor_band","cheap","mid","high","near_cap")) if (!cc %in% names(H)) H[, (cc) := 0L]
H <- H[, .(DUID, cal_day, h_wdr=withdrawn/12, h_floor=floor_band/12, h_cheap=cheap/12,
           h_mid=mid/12, h_high=high/12, h_cap=near_cap/12)]

P <- fread(file.path(OUT, "task5a_pairs.csv"))   # DUID, d0, d1, grp from Task A
P[, `:=`(d0=as.Date(d0), d1=as.Date(d1))]
add <- function(P, side) {
  x <- copy(H); setnames(x, setdiff(names(x), c("DUID","cal_day")),
                         paste0(setdiff(names(x), c("DUID","cal_day")), "_", side))
  merge(P, x, by.x=c("DUID", ifelse(side=="a","d1","d0")), by.y=c("DUID","cal_day"))
}
P <- add(add(P, "a"), "b")   # a = later day (D-1), b = earlier (D-3 / quiet d-2)
for (cc in c("wdr","floor","cheap","mid","high","cap"))
  P[, (paste0("d_", cc)) := get(paste0("h_",cc,"_a")) - get(paste0("h_",cc,"_b"))]
P[, d_lowside := d_floor + d_cheap]          # hours with the floor MW cheap
P[, d_highside := d_high + d_cap]            # hours with the floor MW > $1,000 (offered)
P[, up_move := d_highside >= 1 & d_lowside <= -1]     # >=1h shifted cheap -> expensive
P[, down_move := d_highside <= -1 & d_lowside >= 1]

S <- P[, .(n=.N,
  up_move_pct = round(100*mean(up_move),1), down_move_pct = round(100*mean(down_move),1),
  mean_d_low = round(mean(d_lowside),2), mean_d_high = round(mean(d_highside),2),
  mean_d_wdr = round(mean(d_wdr),2),
  low_p25 = round(quantile(d_lowside,.25),1), low_p75 = round(quantile(d_lowside,.75),1),
  high_p25 = round(quantile(d_highside,.25),1), high_p75 = round(quantile(d_highside,.75),1)), by=grp]
cat("=== Floor-MW hours by price class: D-3 -> D-1 change, pre-direction vs quiet ===\n")
print(S)
cat("\nBaseline composition (hours/day, later day of each window):\n")
print(P[, .(wdr=round(mean(h_wdr_a),1), floor_band=round(mean(h_floor_a),1), cheap=round(mean(h_cheap_a),1),
            mid=round(mean(h_mid_a),1), high=round(mean(h_high_a),1), near_cap=round(mean(h_cap_a),1)), by=grp])
cat("\nAmong windows WITH an up-move (cheap -> >$1,000, >=1h both sides):\n")
print(P[up_move==TRUE, .(n=.N, mean_hours_moved = round(mean(pmin(-d_lowside, d_highside)),1),
                         to_near_cap_share = round(mean(d_cap/pmax(d_highside, 1e-9)),2)), by=grp])
fwrite(P, file.path(OUT, "task5a2_floor_migration_pairs.csv"))
fwrite(S, file.path(OUT, "task5a2_floor_migration_summary.csv"))
cat("\nSaved task5a2_floor_migration_{pairs,summary}.csv\n")
