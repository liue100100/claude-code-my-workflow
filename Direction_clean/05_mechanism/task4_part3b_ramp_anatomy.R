#!/usr/bin/env Rscript
# task4_part3b_ramp_anatomy.R -- Part 3b: what are the pre-direction rewrites actually doing?
# Descriptive decomposition of the established churn ramp (Part 3, question iv). No hypothesis
# test, no new registration -- this reads the record. Windows: D-3..D-1 before the clean first
# directions (approach days themselves clean, as in Part 3); contrast: the quiet baseline days.
# A "rewrite" on day d = the change from day d-1's midnight stance to day d's midnight stance
# (lodged during d-1, i.e. pre-issue for 99-100% of episodes -- checked in Part 3).
#
# Price classes by each band's own daily price: cheap <= $300 (Stage-1 threshold), mid
# (300,1000], expensive (1000, 0.9xMPC), top >= 0.9xMPC (FY schedule). Deepening availability
# mass = downward MAXAVAIL moves that END below the unit's floor.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
MPC <- c(`2022`=15100, `2023`=15500, `2024`=16600, `2025`=17500)
fy_end <- function(d) year(d) + (month(d) >= 7L)

# ---- day sets: approach (rel -3..-1, clean) and quiet baseline (Part 3 definitions) ----
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
APP <- rbindlist(lapply(1:3, function(k) CLF[, .(DUID=duid, cal_day=cal_day-k, rel=-k)]))
APP <- merge(APP, DC[clean==TRUE, .(DUID, cal_day)], by=c("DUID","cal_day"))
tol <- rbindlist(lapply(seq_len(nrow(ep740)), function(j)
  data.table(DUID=ep740$duid[j], cal_day=seq(dt10(ep740$s[j])-2, dt10(ep740$c[j])+2, by="day"))))
tol <- unique(rbind(tol, TRS[, .(DUID, cal_day)], TRS[, .(DUID, cal_day=cal_day-1)], TRS[, .(DUID, cal_day=cal_day+1)]))
QUIET <- DC[clean==TRUE][!paste(DUID, cal_day) %in% tol[, paste(DUID, cal_day)], .(DUID, cal_day)][, rel := NA_integer_]
cat(sprintf("Approach rewrite-days (clean): D-1 %d, D-2 %d, D-3 %d | quiet rewrite-days %d\n",
            APP[rel==-1,.N], APP[rel==-2,.N], APP[rel==-3,.N], nrow(QUIET)))
TGT <- rbind(APP[, .(DUID, cal_day, rel)], QUIET[, .(DUID, cal_day, rel=-99L)])
setorder(TGT, DUID, cal_day, -rel)                 # closest rel wins (-1 before -2 before -3)
TGT <- unique(TGT, by=c("DUID","cal_day"))         # a day can approach several episodes; count once
TGT[, grp := fifelse(rel==-99L, "quiet", paste0("D", rel))][, rel := NULL]
cat(sprintf("Deduplicated rewrite-days: %s\n",
            paste(capture.output(print(TGT[, .N, by=grp][order(grp)])), collapse=" | ")))

# ---- per-interval deltas for target days ----
IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TEST_UNITS]
need <- unique(rbind(TGT[, .(DUID, cal_day)], TGT[, .(DUID, cal_day=cal_day-1)]))
IV <- merge(IV, need, by=c("DUID","cal_day"))
setorder(IV, DUID, cal_day, idt)
IV[, ivx := seq_len(.N), by=.(DUID, cal_day)]
yd <- copy(IV)[, cal_day := cal_day + 1L]
setnames(yd, c("MAXAVAIL", ba_cols, pb_cols), c("y_ma", paste0("y_", ba_cols), paste0("y_", pb_cols)))
X <- merge(IV, yd[, c("DUID","cal_day","ivx","y_ma", paste0("y_",ba_cols), paste0("y_",pb_cols)), with=FALSE],
           by=c("DUID","cal_day","ivx"))
X <- merge(X, TGT, by=c("DUID","cal_day"))
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
X <- merge(X, unique(UD[, .(DUID, cal_day, floor_mw)]), by=c("DUID","cal_day"), all.x=TRUE)
X[, `:=`(dma = MAXAVAIL - y_ma, hh = as.integer(format(idt - 1, "%H", tz="Etc/GMT-10")),
         mpc = MPC[as.character(fy_end(cal_day))])]

# (a)+(b) availability decomposition per rewrite-day
b1 <- as.matrix(X[, ..ba_cols]); b0 <- as.matrix(X[, paste0("y_",ba_cols), with=FALSE])
p1 <- as.matrix(X[, ..pb_cols]);  b1[is.na(b1)] <- 0; b0[is.na(b0)] <- 0
dB <- b1 - b0
cls_of <- function(p, mpc) fifelse(p <= 300, "cheap", fifelse(p <= 1000, "mid", fifelse(p < 0.9*mpc, "expensive", "top")))
flow_in <- matrix(0, nrow(X), 4, dimnames=list(NULL, c("cheap","mid","expensive","top")))
flow_out <- flow_in
for (k in 1:10) {
  cl <- cls_of(p1[,k], X$mpc)
  pos <- pmax(dB[,k],0); neg <- pmax(-dB[,k],0)
  for (cc in colnames(flow_in)) { w <- cl==cc & !is.na(cl)
    flow_in[w, cc] <- flow_in[w, cc] + pos[w]; flow_out[w, cc] <- flow_out[w, cc] + neg[w] }
}
X[, `:=`(band_gross = rowSums(abs(dB)),
         in_cheap = flow_in[,"cheap"], in_mid = flow_in[,"mid"], in_exp = flow_in[,"expensive"], in_top = flow_in[,"top"],
         out_cheap = flow_out[,"cheap"], out_mid = flow_out[,"mid"], out_exp = flow_out[,"expensive"], out_top = flow_out[,"top"])]
# receiving price of expensive+top inflows (MW-weighted)
recv_num <- rep(0, nrow(X)); recv_den <- rep(0, nrow(X))
for (k in 1:10) { cl <- cls_of(p1[,k], X$mpc); pos <- pmax(dB[,k],0)
  w <- cl %in% c("expensive","top") & !is.na(cl)
  recv_num[w] <- recv_num[w] + pos[w]*p1[w,k]; recv_den[w] <- recv_den[w] + pos[w] }
X[, `:=`(recv_num=recv_num, recv_den=recv_den)]

DAY <- X[, .(
  churn_ma = sum(abs(dma))/12, churn_band = sum(band_gross)/12,
  net_ma = sum(dma)/12, deep_ma = sum(-dma[dma<0 & MAXAVAIL < floor_mw])/12,
  shal_ma = sum(dma[dma>0])/12,
  net_cheap = (sum(in_cheap)-sum(out_cheap))/12, gross_cheap = (sum(in_cheap)+sum(out_cheap))/12,
  net_top = (sum(in_top)-sum(out_top))/12,
  gross_expexp = (sum(in_exp)+sum(in_top)+sum(out_exp)+sum(out_top))/12,
  recv_price = sum(recv_num)/max(sum(recv_den),1e-9)
), by=.(DUID, cal_day, grp)]
DAY[, `:=`(total = churn_ma + churn_band, changed = churn_ma + churn_band > 1)]
DAY[, ma_share := fifelse(total>0, churn_ma/total, NA_real_)]
DAY[, rewrite_type := fcase(total <= 1, "no change",
      abs(net_cheap) >= 5 | deep_ma >= 5, "posture-relevant (cheap moved / absence deepened)",
      churn_ma > churn_band & abs(net_ma) < 0.2*churn_ma, "availability re-profiling (net ~ 0)",
      churn_band >= churn_ma, "expensive-side reshuffle",
      default = "availability shift (net)")]
fwrite(DAY, file.path(OUT, "task4_part3b_day_decomp.csv"))

cat("\n=== (a) Churn composition by window (medians over changed rewrite-days; denominators shown) ===\n")
s_a <- DAY[changed==TRUE, .(n=.N, ma_share=round(median(ma_share, na.rm=TRUE),2),
        churn_ma=round(median(churn_ma)), churn_band=round(median(churn_band)),
        net_ma=round(median(net_ma)), deep_ma=round(median(deep_ma)),
        net_cheap=round(median(net_cheap),1), gross_expexp=round(median(gross_expexp)),
        recv_price=round(median(recv_price[recv_den>0], na.rm=TRUE))), by=grp][order(grp)]
print(s_a)
cat("\nShare of days changed at all: "); print(DAY[, .(pct_changed=round(100*mean(changed),1), n=.N), by=grp])
cat("\n=== Rewrite type mix (share of changed days) ===\n")
print(dcast(DAY[changed==TRUE, .N, by=.(grp, rewrite_type)], grp ~ rewrite_type, value.var="N", fill=0))

cat("\n=== (b) Availability moves: hour-of-day profile of |dMA| mass (share by 6h block) ===\n")
hb <- X[abs(dma)>0, .(mass=sum(abs(dma))), by=.(grp, blk=cut(hh, c(-1,5,11,17,23), labels=c("00-06","06-12","12-18","18-24")))]
hb[, share := round(mass/sum(mass),2), by=grp]
print(dcast(hb, grp ~ blk, value.var="share"))

cat("\n=== (c) Band flow (MWh/day medians over changed days): cheap vs expensive sides ===\n")
s_c <- DAY[changed==TRUE, .(n=.N,
       gross_cheap=round(median(gross_cheap),1), net_cheap=round(median(net_cheap),1),
       pct_cheap_touched=round(100*mean(gross_cheap>=5),1),
       gross_expexp=round(median(gross_expexp)), net_top=round(median(net_top))), by=grp][order(grp)]
print(s_c)

# (d) lodgement record behind the rewrites: rebids lodged on d-1 targeting trading day d
RBP <- readRDS(file.path(OUT, "task4_rebid_panel.rds")); BD <- RBP$BD
BD[, dir_tag := grepl("RTS|direction|MN ?#?[0-9]", REBIDEXPLANATION, ignore.case=TRUE)]
BD[, `:=`(lodge_day = dt10(od), hh = as.integer(format(od, "%H")))]
LK <- merge(TGT, BD[, .(DUID, cal_day=td, lodge_day, hh, cat, dir_tag)], by=c("DUID","cal_day"))
LK <- LK[lodge_day == cal_day - 1]     # lodged during d-1 = the rewrite's content
cat("\n=== (d) Lodgements behind the rewrites (rebids on d-1 targeting day d), per day + category mix ===\n")
print(LK[, .(rebids_per_day=round(.N/uniqueN(paste(DUID,cal_day)),2)), by=grp])
print(dcast(LK[, .N, by=.(grp, cat)], grp ~ cat, value.var="N", fill=0))
cat("Lodgement hours (share 12-18 / 18-24):\n")
print(LK[, .(pct_12_18=round(100*mean(hh %in% 12:17),1), pct_18_24=round(100*mean(hh>=18),1)), by=grp])
fwrite(LK[, .N, by=.(grp, cat, hh)], file.path(OUT, "task4_part3b_lodgements.csv"))
cat("\nSaved task4_part3b_{day_decomp,lodgements}.csv\n")
