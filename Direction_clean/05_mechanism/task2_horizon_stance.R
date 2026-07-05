#!/usr/bin/env Rscript
# task2_horizon_stance.R -- Horizon-consistent stance measure (descriptive upgrade ONLY).
# No regressions, no essentiality interactions, no compensation-price tests; RQ1/RQ2 stand as
# adjudicated (findings_job2_contamination.md).
#
# Rules fixed in advance:
#  - Horizon = MEDIAN duration of the 740 corrected episodes; P25/P75 as sensitivity rows.
#    Never per-episode durations (longer directions happen in worse conditions -- bias).
#  - Information cutoff: episode analysis = bids lodged BEFORE ISSUE (odt < tau); panel
#    analysis = bids lodged before midnight (the existing day-ahead stance). Never later.
#  - "Not yet bid" is its own category: horizon intervals on trading days with no version
#    lodged by the cutoff are reported separately, never counted absent or committed.
#  - Stance categories per interval (bid intervals): withdrawn = MAXAVAIL < floor;
#    priced-out = floor-MW price > $300 (effective ladder capped at MAXAVAIL, Task-2 rules,
#    Task-1c trading-date re-key); committed-cheap = otherwise. Version present but no daily
#    ladder by cutoff -> counted with not-yet-bid (reported).
#  - Episode/day classification: the established >=1 cumulative hour convention (>=12
#    intervals), swept at 6/24/36 per the Job-3 sweep; coverage shares reported alongside so
#    "across the horizon" is not carried by the 1-hour cliff.
#
# Outputs: task2_horizon_{durations,episode,panel,persistence}.csv; findings after inspection.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

# ---------------------------------------------------------------------------
# 0. Duration distribution -> horizons (fixed rule: median; P25/P75 sensitivity)
# ---------------------------------------------------------------------------
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% FOCUS & !is.na(s) & !is.na(c) & c > s]
ep[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
ep740 <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
ep740[, dur_h := as.numeric(difftime(c, s, units="hours"))]
qs <- ep740[, quantile(dur_h, c(.10,.25,.50,.75,.90))]
dur_tbl <- data.table(stat=c("P10","P25","median","P75","P90","mean","max","n"),
                      hours=round(c(qs, ep740[,mean(dur_h)], ep740[,max(dur_h)], nrow(ep740)),1))
fwrite(dur_tbl, file.path(OUT, "task2_horizon_durations.csv"))
cat("=== Duration distribution, 740 corrected episodes (hours) ===\n"); print(dur_tbl)
H_MED <- round(qs[["50%"]]*12)  # intervals
H_P25 <- round(qs[["25%"]]*12); H_P75 <- round(qs[["75%"]]*12)
cat(sprintf("Horizons (5-min intervals): P25 %d | MEDIAN %d | P75 %d\n", H_P25, H_MED, H_P75))

# clean-day first directions from Job 2 (recompute with the same machinery)
LG <- readRDS(file.path(OUT, "task2_stance_lodgement.rds"))
RX <- fread(file.path(OUT, "task1c_redux_sequencing.csv"))
p26_ids <- RX[class=="signal after direction" & in_new_lobe==TRUE, episode_id]
ep740[, cal_day := dt10(s)]
ep740 <- merge(ep740, LG, by.x=c("duid","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)
ep740 <- ep740[!is.na(lodge)]
ep740[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
classify_day <- function(u, lodge, day_start, excl_id) {
  e <- ep[duid == u & episode_id != excl_id]
  active  <- e[s < day_start & c > lodge, .N] > 0
  pending <- e[tau <= day_start & s >= day_start & s < day_start+86400, .N] > 0
  lodge_day0 <- force10(as.POSIXct(paste(dt10(lodge), "00:00:00"), tz="Etc/GMT-10"))
  bound   <- e[c >= lodge_day0 & c <= lodge, .N] > 0
  if (active) "continuation-active" else if (pending) "issued-pending" else if (bound) "boundary" else "clean"
}
ep740[, contam := mapply(classify_day, duid, lodge, day_start, episode_id)]
CL <- ep740[contam=="clean" & !episode_id %in% p26_ids]
cat(sprintf("Clean-day first directions: %d (Job-2 benchmark: 280)\n", nrow(CL)))

# ---------------------------------------------------------------------------
# 1. (a) Episode analysis: stance over [s, s+H) with cutoff odt < tau
# ---------------------------------------------------------------------------
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
FLOORS <- unique(UD[, .(duid=DUID, cal_day, floor_mw)])
H_MAX <- H_P75
CL[, `:=`(h_end = s + H_MAX*300)]
CL[, mm_lo := format(dt10(s), "%Y%m")]
need <- CL[, .(episode_id, duid, tau, s, h_end)]
need_days <- need[, .(cal_day = seq(dt10(s), dt10(h_end - 1), by="day")), by=.(episode_id, duid, tau, s, h_end)]
need_days <- need_days[cal_day <= as.Date("2024-12-31")]
mm_all <- sort(unique(format(need_days$cal_day, "%Y%m")))
cat(sprintf("Episode-day lookups: %d over %d months\n", nrow(need_days), length(mm_all)))

iv_list <- vector("list", length(mm_all))
for (k in seq_along(mm_all)) {
  M <- mm_all[k]
  nd <- need_days[format(cal_day, "%Y%m") == M]
  b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
  b <- b[DUID %in% unique(nd$duid) & BIDTYPE=="ENERGY",
         c("DUID","OFFERDATETIME","MAXAVAIL","INTERVAL_DATETIME", ba_cols), with=FALSE]
  b[, `:=`(odt = force10(OFFERDATETIME), idt = force10(INTERVAL_DATETIME))]
  b[, cal_day := dt10(idt - 1)]
  d <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(d)
  d <- d[DUID %in% unique(nd$duid) & BIDTYPE=="ENERGY",
         c("DUID","SETTLEMENTDATE","OFFERDATE", pb_cols), with=FALSE]
  d[, `:=`(od = force10(OFFERDATE), cal_day = as.Date(SETTLEMENTDATE) + 1L)]
  rows <- lapply(seq_len(nrow(nd)), function(j) {
    e <- nd[j]
    v <- b[DUID == e$duid & cal_day == e$cal_day & odt < e$tau]
    if (!nrow(v)) return(data.table(episode_id=e$episode_id, cal_day=e$cal_day, idt=as.POSIXct(NA), cat="not_yet_bid", n288=0L))
    v <- v[odt == max(odt)]
    l <- d[DUID == e$duid & cal_day == e$cal_day & od < e$tau]
    if (!nrow(l)) return(data.table(episode_id=e$episode_id, cal_day=e$cal_day, idt=as.POSIXct(NA), cat="not_yet_bid", n288=0L))
    l <- l[od == max(od)]
    ba <- as.matrix(v[, ..ba_cols]); ba[is.na(ba)] <- 0
    pbv <- as.numeric(l[1, ..pb_cols])
    cum <- t(apply(ba, 1, cumsum)); cum <- pmin(cum, v$MAXAVAIL)
    fl <- FLOORS[duid==e$duid & cal_day==e$cal_day, floor_mw]
    if (!length(fl)) fl <- FLOORS[duid==e$duid, median(floor_mw, na.rm=TRUE)]
    bix <- 11L - rowSums(cum >= fl)
    pf <- ifelse(bix > 10L | cum[,10] < fl, Inf, pbv[pmin(bix,10L)])
    data.table(episode_id=e$episode_id, cal_day=e$cal_day, idt=v$idt,
               cat=fifelse(v$MAXAVAIL < fl, "withdrawn", fifelse(pf > 300, "priced_out", "committed_cheap")),
               n288=nrow(v))
  })
  iv_list[[k]] <- rbindlist(rows, fill=TRUE)
  rm(b, d); gc(verbose=FALSE)
  cat(sprintf("  %s done (%d episode-days)\n", M, nrow(nd)))
}
IVH <- rbindlist(iv_list, fill=TRUE)
saveRDS(IVH, file.path(OUT, "_task2_horizon_iv.rds"))

# assemble per-episode horizon shares; classify at each horizon x rank threshold
mk_ep <- function(H, K) {
  rbindlist(lapply(seq_len(nrow(CL)), function(j) {
    e <- CL[j]
    # grid-aligned interval END times covering [s, s+H): first = end of the interval containing s
    hz0 <- force10(as.POSIXct(floor(as.numeric(e$s)/300)*300 + 300, origin="1970-01-01"))
    hz <- hz0 + (0:(H-1))*300
    beyond <- dt10(hz - 1) > as.Date("2024-12-31")        # past the data edge, NOT "not yet bid"
    hz_d <- hz[!beyond]
    x <- IVH[episode_id == e$episode_id]
    xb <- x[!is.na(idt)][idt %in% hz_d]
    n_w <- xb[cat=="withdrawn", .N]; n_p <- xb[cat=="priced_out", .N]
    cls <- if (nrow(xb) < K) "insufficient bid coverage"
           else if (n_w >= K) "withdrawn"
           else if (n_p >= K) "priced_out"
           else "committed_cheap"
    data.table(episode_id=e$episode_id, duid=e$duid, H=H, K=K,
               n_horizon=length(hz), n_beyond_data=sum(beyond), n_bid=nrow(xb),
               n_not_yet_bid=length(hz_d) - nrow(xb),
               share_exit_of_bid = (n_w+n_p)/max(nrow(xb),1), class=cls)
  }))
}
EH <- rbindlist(lapply(list(c(H_P25,12L), c(H_MED,6L), c(H_MED,12L), c(H_MED,24L), c(H_MED,36L), c(H_P75,12L)),
                       function(z) mk_ep(z[1], z[2])))
fwrite(EH, file.path(OUT, "task2_horizon_episode.csv"))
cat("\n=== (a) Clean-day first directions: horizon stance classification ===\n")
summ <- EH[, .(n=.N, withdrawn=sum(class=="withdrawn"), priced=sum(class=="priced_out"),
               committed=sum(class=="committed_cheap"), insuff=sum(class=="insufficient bid coverage"),
               exit_pct=round(100*mean(class %in% c("withdrawn","priced_out")),1),
               mean_exit_share=round(mean(share_exit_of_bid),3),
               pct_exit_ge50=round(100*mean(share_exit_of_bid>=.5),1),
               pct_exit_ge90=round(100*mean(share_exit_of_bid>=.9),1),
               mean_nyb_share=round(mean(n_not_yet_bid/n_horizon),3)), by=.(H, K)]
print(summ)
fwrite(summ, file.path(OUT, "task2_horizon_episode_summary.csv"))

# ---------------------------------------------------------------------------
# 2. (b) Panel base rate over the horizon + persistence
# ---------------------------------------------------------------------------
cat("\n=== (b) Clean-day base rate over the horizon + persistence ===\n")
IVP <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))   # midnight-cutoff stance, per day
DCJ <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DCJ[, cal_day := as.Date(cal_day)]
IVP <- merge(IVP, DCJ[, .(DUID, cal_day, contam, clean)], by=c("DUID","cal_day"))
setorder(IVP, DUID, cal_day, idt)
IVP[, ivx := seq_len(.N), by=.(DUID, cal_day)]
pan <- function(H, K) {
  x <- IVP[ivx <= H & clean==TRUE,
           .(n_w = sum(avail_below_floor), n_p = sum(!avail_below_floor & p_floor > 300 & !imputed),
             n_imp_only = sum(imputed & !avail_below_floor)), by=.(DUID, cal_day)]
  x[, exit := (n_w >= K) | (n_p + n_imp_only >= K)]
  x[, .(H=H, K=K, n_days=.N, exit_pct=round(100*mean(exit),1))]
}
pan_tbl <- rbindlist(lapply(list(c(H_P25,12L), c(H_MED,6L), c(H_MED,12L), c(H_MED,24L), c(H_MED,36L), c(H_P75,12L)),
                            function(z) pan(z[1], z[2])))
cat("Clean-day exit-stance rate over [00:00, H) (NB horizons within the day; not-yet-bid cannot arise at the midnight cutoff within-day):\n")
print(pan_tbl)
fwrite(pan_tbl, file.path(OUT, "task2_horizon_panel.csv"))

# persistence of the FULL-DAY exit posture (established Step-6 convention) on clean days
UD2 <- UD[DUID %in% c("TORRB2","TORRB3","TORRB4","PPCCGT")]
UD2 <- merge(UD2, DCJ[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"), all.x=TRUE)
UD2[, exit_day := comp_A==TRUE | (comp_A==FALSE & composite > 300)]
setorder(UD2, DUID, cal_day)
UD2[, `:=`(exit_next = shift(exit_day, -1), day_next = shift(cal_day, -1)), by=DUID]
tr <- UD2[!is.na(exit_day) & !is.na(exit_next) & day_next == cal_day + 1]
cat(sprintf("\nPersistence (all consecutive day-pairs, n=%d): P(exit tomorrow | exit today) = %.1f%% ; P(exit tomorrow | committed today) = %.1f%%\n",
            nrow(tr), 100*tr[exit_day==TRUE, mean(exit_next)], 100*tr[exit_day==FALSE, mean(exit_next)]))
trc <- tr[clean==TRUE]
cat(sprintf("Clean days only (n=%d pairs): P(exit|exit) = %.1f%% ; P(exit|committed) = %.1f%%\n",
            nrow(trc), 100*trc[exit_day==TRUE, mean(exit_next)], 100*trc[exit_day==FALSE, mean(exit_next)]))
runs <- UD2[!is.na(exit_day), .(len = rle(exit_day)$lengths, val = rle(exit_day)$values), by=DUID][val==TRUE]
cat("Run lengths of consecutive exit-posture days (all days):\n")
print(round(quantile(runs$len, c(.25,.5,.75,.9,.99)),1))
fwrite(tr[, .(DUID, cal_day, clean, exit_day, exit_next)], file.path(OUT, "task2_horizon_persistence.csv"))
cat("\nSaved task2_horizon_{durations,episode,episode_summary,panel,persistence}.csv\n")
