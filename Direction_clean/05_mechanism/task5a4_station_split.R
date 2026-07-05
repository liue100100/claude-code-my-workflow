#!/usr/bin/env Rscript
# task5a4_station_split.R -- Open check (i) of interpretation_staged_framework.md:
# is the hourly re-timing present in TORRENS'S OWN numbers? Same decomposition as
# task5a3, split Torrens (TORRB2/3/4) vs PPCCGT. Counts before content.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

DAYD <- fread(file.path(OUT, "task4_part3b_day_decomp.csv")); DAYD[, cal_day := as.Date(cal_day)]
D <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
DC <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
EO <- D[essential_day==TRUE][order(DUID, cal_day)]
EO[, prev7 := sapply(seq_len(.N), function(i) D[DUID==EO$DUID[i] & cal_day >= EO$cal_day[i]-7 &
                                                cal_day < EO$cal_day[i], sum(essential_day, na.rm=TRUE)])]
EO <- EO[prev7==0]
eo1 <- merge(EO[, .(DUID, cal_day = cal_day-1)], DC[clean==TRUE, .(DUID, cal_day)], by=c("DUID","cal_day"))
TGT <- rbind(DAYD[, .(DUID, cal_day, grp)], eo1[, .(DUID, cal_day, grp="pre-essential-onset D-1")])
TGT <- unique(TGT, by=c("DUID","cal_day","grp"))
TGT[, station := fifelse(DUID=="PPCCGT", "PPCCGT", "Torrens")]
cat("COUNTS FIRST -- rewrite-days per group x station:\n")
print(dcast(TGT[, .N, by=.(grp, station)], grp ~ station, value.var="N", fill=0))

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TEST_UNITS]
need <- unique(rbind(TGT[, .(DUID, cal_day)], TGT[, .(DUID, cal_day=cal_day-1)]))
IV <- merge(IV, need, by=c("DUID","cal_day"))
setorder(IV, DUID, cal_day, idt)
IV[, ivx := seq_len(.N), by=.(DUID, cal_day)]
yd <- copy(IV)[, cal_day := cal_day + 1L]
setnames(yd, c("MAXAVAIL", ba_cols), c("y_ma", paste0("y_", ba_cols)))
X <- merge(IV, yd[, c("DUID","cal_day","ivx","y_ma", paste0("y_",ba_cols)), with=FALSE],
           by=c("DUID","cal_day","ivx"))
X <- merge(X, TGT, by=c("DUID","cal_day"), allow.cartesian=TRUE)
X[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]

nd <- TGT[, .(nd=.N), by=.(grp, station)]
hr <- X[, .(net = sum(MAXAVAIL - y_ma)/12), by=.(grp, station, hh)]
hr <- merge(hr, nd, by=c("grp","station"))
hr[, net_per_day := round(net/nd, 2)]
cat("\n=== Hourly net availability change (MWh per rewrite-day), TORRENS ONLY ===\n")
print(dcast(hr[station=="Torrens"], hh ~ grp, value.var="net_per_day"), nrows=24)
cat("\n=== Same, PPCCGT ===\n")
print(dcast(hr[station=="PPCCGT"], hh ~ grp, value.var="net_per_day"), nrows=24)
fwrite(hr, file.path(OUT, "task5a4_hourly_by_station.csv"))

# block summary for the findings: evening/overnight vs daytime, Torrens only
blk <- X[, .(net = sum(MAXAVAIL - y_ma)/12), by=.(grp, station,
          blk = fifelse(hh %in% 11:18, "day 11-19h", fifelse(hh %in% 19:23 | hh %in% 0:4, "night 19-05h", "morning 05-11h")))]
blk <- merge(blk, nd, by=c("grp","station"))
blk[, net_per_day := round(net/nd,1)]
cat("\n=== Block summary: net MWh/rewrite-day by station ===\n")
print(dcast(blk, grp + station ~ blk, value.var="net_per_day"))
fwrite(blk, file.path(OUT, "task5a4_blocks.csv"))

# band nets by station (the Stage-2 attribution check)
b1 <- as.matrix(X[, ..ba_cols]); b0 <- as.matrix(X[, paste0("y_",ba_cols), with=FALSE])
p1 <- as.matrix(X[, ..pb_cols]); b1[is.na(b1)] <- 0; b0[is.na(b0)] <- 0
dB <- b1 - b0
bt <- rbindlist(lapply(1:10, function(k)
  X[, .(band=k, price_med=round(median(p1[.I,k], na.rm=TRUE)), net=round(sum(dB[.I,k])/12)), by=.(grp, station)]))
bt <- merge(bt, nd, by=c("grp","station"))
bt[, net_per_day := round(net/nd,1)]
cat("\n=== Band nets per rewrite-day by station (pre-essential-onset + D-1 rows) ===\n")
print(dcast(bt[grp %in% c("pre-essential-onset D-1","D-1")], band + price_med ~ grp + station, value.var="net_per_day", fill=0), nrows=25)
fwrite(bt, file.path(OUT, "task5a4_bands_by_station.csv"))
cat("\nSaved task5a4_{hourly_by_station,blocks,bands_by_station}.csv\n")
