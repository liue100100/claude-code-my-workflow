#!/usr/bin/env Rscript
# task5a_did_the_bid_change.R -- Task A: did the pre-direction bid touching actually change the
# bid? Direct comparison: the unit's midnight stance at D-3 vs D-1 before each clean first
# direction (both lodged pre-issue), against quiet 48-hour windows.
#
# FIXED BEFORE RUNNING: material change = |net movement| >= 5% of registered capacity
# (TORRB 200 MW -> 10 MW; PPCCGT 478 MW -> 23.9 MW) on EITHER day-mean cheap capacity
# (effective MW offered <= $300) OR day-mean declared availability. Absence depth (hours below
# floor) reported alongside as deeper/shallower. Means AND distributions, not just medians.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
REG <- c(TORRB2=200, TORRB3=200, TORRB4=200, PPCCGT=478)
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

# day-level stance measures
IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TEST_UNITS]
bam <- as.matrix(IV[, ..ba_cols]); bam[is.na(bam)] <- 0
pbm <- as.matrix(IV[, ..pb_cols])
cum <- bam; for (j in 2:10) cum[,j] <- cum[,j-1] + bam[,j]
cum <- pmin(cum, IV$MAXAVAIL)
eff <- cum; eff[,2:10] <- cum[,2:10] - cum[,1:9]
IV[, cheap300 := rowSums(eff * (pbm <= 300), na.rm=TRUE)]
DM <- IV[, .(mean_ma = mean(MAXAVAIL), mean_cheap = mean(cheap300)), by=.(DUID, cal_day)]
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
DM <- merge(DM, UD[, .(DUID, cal_day, absent_h = n_below_floor/12)], by=c("DUID","cal_day"))

# episode + quiet windows (same machinery as Parts 3/3b)
DC  <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
TRS <- fread(file.path(OUT, "task3_part4_transitions.csv")); TRS[, cal_day := as.Date(cal_day)]
ep  <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep  <- ep[duid %in% TEST_UNITS]; ep[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
ep740 <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
LG <- readRDS(file.path(OUT, "task2_stance_lodgement.rds"))
RX <- fread(file.path(OUT, "task1c_redux_sequencing.csv"))
p26_ids <- RX[class=="signal after direction" & in_new_lobe==TRUE, episode_id]
ep740[, cal_day := dt10(s)]
ep740 <- merge(ep740, LG, by.x=c("duid","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)[!is.na(lodge)]
ep740[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
cls1 <- function(u, lodge, day_start, excl_id) {
  e <- ep[duid==u & episode_id != excl_id]
  if (e[s < day_start & c > lodge, .N] > 0) return("continuation-active")
  if (e[tau <= day_start & s >= day_start & s < day_start+86400, .N] > 0) return("issued-pending")
  ld0 <- force10(as.POSIXct(paste(dt10(lodge), "00:00:00"), tz="Etc/GMT-10"))
  if (e[c >= ld0 & c <= lodge, .N] > 0) return("boundary")
  "clean"
}
ep740[, contam := mapply(cls1, duid, lodge, day_start, episode_id)]
CLF <- ep740[contam=="clean" & !episode_id %in% p26_ids]
tol <- rbindlist(lapply(seq_len(nrow(ep740)), function(j)
  data.table(DUID=ep740$duid[j], cal_day=seq(dt10(ep740$s[j])-2, dt10(ep740$c[j])+2, by="day"))))
tol <- unique(rbind(tol, TRS[, .(DUID, cal_day)], TRS[, .(DUID, cal_day=cal_day-1)], TRS[, .(DUID, cal_day=cal_day+1)]))
DC[, quiet := clean==TRUE & !paste(DUID, cal_day) %in% tol[, paste(DUID, cal_day)]]

mk_pairs <- function(anchors) { # anchors: DUID, d1 (later day), with d0 = d1-2
  P <- merge(anchors, DM[, .(DUID, cal_day, ma1=mean_ma, ch1=mean_cheap, ab1=absent_h)],
             by.x=c("DUID","d1"), by.y=c("DUID","cal_day"))
  P <- merge(P, DM[, .(DUID, cal_day, ma0=mean_ma, ch0=mean_cheap, ab0=absent_h)],
             by.x=c("DUID","d0"), by.y=c("DUID","cal_day"))
  P[, `:=`(d_ma = ma1-ma0, d_ch = ch1-ch0, d_ab = ab1-ab0, reg = REG[DUID])]
  P[, material := abs(d_ch) >= 0.05*reg | abs(d_ma) >= 0.05*reg]
  P
}
epA <- CLF[, .(DUID=duid, d1=cal_day-1, d0=cal_day-3)]
epA <- merge(epA, DC[clean==TRUE, .(DUID, cal_day)], by.x=c("DUID","d1"), by.y=c("DUID","cal_day"))
epA <- merge(epA, DC[clean==TRUE, .(DUID, cal_day)], by.x=c("DUID","d0"), by.y=c("DUID","cal_day"))
PA <- mk_pairs(epA)
qd <- DC[quiet==TRUE, .(DUID, d1=cal_day, d0=cal_day-2)]
qd <- merge(qd, DC[quiet==TRUE, .(DUID, cal_day)], by.x=c("DUID","d0"), by.y=c("DUID","cal_day"))
PQ <- mk_pairs(qd)
cat(sprintf("Episode windows with both D-3 and D-1 clean and measurable: %d of %d clean first directions | quiet 48h windows: %d\n",
            nrow(PA), nrow(CLF), nrow(PQ)))

summ <- function(P, lab) {
  m <- P[material==TRUE]
  data.table(group=lab, n_windows=nrow(P), pct_material=round(100*mean(P$material),1), n_material=nrow(m),
    cheap_mean=round(mean(m$d_ch),1), cheap_up_pct=round(100*mean(m$d_ch > 0),1),
    cheap_p25=round(quantile(m$d_ch,.25),1), cheap_p75=round(quantile(m$d_ch,.75),1),
    avail_mean=round(mean(m$d_ma),1), avail_up_pct=round(100*mean(m$d_ma > 0),1),
    avail_p25=round(quantile(m$d_ma,.25),1), avail_p75=round(quantile(m$d_ma,.75),1),
    absent_mean_h=round(mean(m$d_ab),2), deeper_pct=round(100*mean(m$d_ab > 0),1))
}
S <- rbind(summ(PA, "pre-direction (D-3 -> D-1)"), summ(PQ, "quiet 48h"))
cat("\n=== Side-by-side (material = |net| >= 5% of registered capacity on cheap or availability) ===\n")
print(S)
cat("\nAll-window means (not just material; the cancel-vs-add-up check on the full sample):\n")
print(rbind(PA[, .(group="pre-direction", n=.N, cheap_mean=round(mean(d_ch),1), avail_mean=round(mean(d_ma),1),
                   absent_mean_h=round(mean(d_ab),2), cheap_dn_pct=round(100*mean(d_ch < -0.05*reg),1),
                   cheap_up_pct=round(100*mean(d_ch > 0.05*reg),1))],
            PQ[, .(group="quiet", n=.N, cheap_mean=round(mean(d_ch),1), avail_mean=round(mean(d_ma),1),
                   absent_mean_h=round(mean(d_ab),2), cheap_dn_pct=round(100*mean(d_ch < -0.05*reg),1),
                   cheap_up_pct=round(100*mean(d_ch > 0.05*reg),1))]))
fwrite(rbind(PA[, grp := "pre-direction"], PQ[, grp := "quiet"], fill=TRUE),
       file.path(OUT, "task5a_pairs.csv"))
fwrite(S, file.path(OUT, "task5a_summary.csv"))
cat("\nSaved task5a_{pairs,summary}.csv\n")
