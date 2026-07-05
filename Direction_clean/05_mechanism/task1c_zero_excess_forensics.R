#!/usr/bin/env Rscript
# task1c_zero_excess_forensics.R -- Mechanism check, Task 1c: why are zero-excess episodes
# directed? (gates Task 2). Target set: the 69 zero/negative-excess episodes in task1b_panel.rds
# (new-format comp window, 2023-10 -> 2024-12; n=271).
#
# Checks (per user instruction, verbatim structure):
#   (a) Duration     -- window-consistent counterfactual over [s, c], per-interval in-force bid
#                       at issue tau (incl. next-trading-day bids where they existed at tau).
#   (b) Sequencing   -- rebid history 48h before issue: availability cuts, exit signals,
#                       reversals; classify no-signal-ever / signal-then-direction /
#                       signal-after-direction.
#   (c) Combination  -- state of the station's other units + the binding minimum combination at
#                       issue; share where the directed unit completed a combination another
#                       unit had put at risk.
#   (d) Instrument   -- operative wording of the direction instruments + market-notice IDs.
#   (e) Anticipation -- forecastability: directed in preceding days, security state binding
#                       pre-issue; zero-excess vs positive-excess contrast.
#                       LIMITATION: realised system state, not pre-dispatch forecasts -- no
#                       PREDISPATCH/P5MIN extraction exists in this repo (facts memo [F21]).
#
# Definitions committed BEFORE running (stated in findings):
#   - floor_i        = sum(BANDAVAIL at PRICEBAND <= $0) in the bid version in force at tau for
#                      interval i (latest OFFERDATETIME <= tau; daily ladder latest OFFERDATE <=
#                      tau for that trading date). Uncapped, matching Task 1's definition.
#   - floor_cap_i    = min(floor_i, MAXAVAIL_i) -- robustness column.
#   - price-aware    = sum(BANDAVAIL at PRICEBAND <= RRP_i) capped at MAXAVAIL_i -- supplementary
#                      only (RRP under direction is not the no-direction counterfactual price).
#   - no-bid interval: no version with OFFERDATETIME <= tau existed for that trading date ->
#                      floor 0 (nothing was offered at issue), counted and reported separately.
#                      This is conservative AGAINST the duration-artifact explanation.
#   - exit signal    = a bid version in [tau-48h, c] setting MAXAVAIL = 0 for >= 12 consecutive
#                      future intervals (>= 1h) of a trading date overlapping the direction window.
#   - availability reduction = version cuts mean future-window MAXAVAIL >= 20 MW vs the
#                      immediately preceding version for the same trading date.
#   - reversal       = a later version restoring mean MAXAVAIL to > 50% of the pre-cut level.
#   - sister heading off = online at tau (INITIALMW > 1) but offline (INITIALMW <= 1) at some
#                      point within (tau, tau+4h]; recently off = online in [tau-4h, tau) but
#                      offline at tau.
#
# Run from my-project root. STOP after findings; Task 2 pre-registration follows.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
SISTERS <- list(TORRB2=c("TORRB1","TORRB3","TORRB4"), TORRB3=c("TORRB1","TORRB2","TORRB4"),
                TORRB4=c("TORRB1","TORRB2","TORRB3"), PPCCGT=character(0), `OSB-AG`=character(0))
STATION <- c(TORRB2="torrens_island_b", TORRB3="torrens_island_b", TORRB4="torrens_island_b",
             PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

X <- readRDS(file.path(OUT, "task1b_panel.rds"))
X[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
Z <- X[excess_over_floor <= 0]
stopifnot(nrow(X) == 271L, nrow(Z) == 69L)
cat(sprintf("Target set: %d zero/negative-excess episodes (of %d comp-matched, 2023-10 -> 2024-12)\n", nrow(Z), nrow(X)))
print(Z[, .N, by=duid][order(-N)])

# ---------------------------------------------------------------------------
# Cache loads (one pass each; focal units only)
# ---------------------------------------------------------------------------
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
mrange <- function(from, to) format(seq(as.Date(cut(from, "month")), as.Date(cut(to, "month")), by="month"), "%Y%m")
mm_bid <- sort(unique(unlist(mapply(function(a,b) mrange(a,b), dt10(Z$s)-2, pmin(dt10(Z$c)+1, as.Date("2024-12-31"))))))
mm_dl  <- sort(unique(unlist(mapply(function(a,b) mrange(a,b), dt10(X$s)-1, pmin(dt10(X$c)+1, as.Date("2024-12-31"))))))
mm_bid <- mm_bid[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", mm_bid)))]
mm_dl  <- mm_dl [file.exists(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds",  mm_dl)))]
cat(sprintf("Loading BOP/BDO months: %s\nLoading DL/DP months: %s\n",
            paste(mm_bid, collapse=" "), paste(mm_dl, collapse=" ")))

CACHE1C <- file.path(OUT, "_task1c_cache.rds")
if (file.exists(CACHE1C)) {
  cat("Loading cached focal subsets (_task1c_cache.rds)\n")
  cc <- readRDS(CACHE1C); BOP <- cc$BOP; BDO <- cc$BDO; DL <- cc$DL; DP <- cc$DP; rm(cc)
} else {
bop_keep <- c("DUID","TRADINGDATE","OFFERDATETIME","PERIODID","MAXAVAIL","INTERVAL_DATETIME", ba_cols)
BOP <- rbindlist(lapply(mm_bid, function(M) {
  b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
  b <- b[DUID %in% FOCUS & BIDTYPE=="ENERGY", ..bop_keep]
  gc(verbose=FALSE); b
}))
BOP[, `:=`(odt = force10(OFFERDATETIME), idt = force10(INTERVAL_DATETIME), td = as.Date(TRADINGDATE))]

bdo_keep <- c("DUID","SETTLEMENTDATE","OFFERDATE","REBIDEXPLANATION","REBID_CATEGORY","REBID_EVENT_TIME", pb_cols)
BDO <- rbindlist(lapply(mm_bid, function(M) {
  b <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(b)
  b[DUID %in% FOCUS & BIDTYPE=="ENERGY", intersect(bdo_keep, names(b)), with=FALSE]
}), fill=TRUE)
BDO[, `:=`(od = force10(OFFERDATE), td = as.Date(SETTLEMENTDATE))]

ALL_UNITS <- unique(c(FOCUS, unlist(SISTERS)))
DL <- rbindlist(lapply(mm_dl, function(M) {
  d <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(d)
  d <- d[DUID %in% ALL_UNITS, .(DUID, SETTLEMENTDATE, INTERVENTION=as.numeric(INTERVENTION),
                                INITIALMW=as.numeric(INITIALMW), TOTALCLEARED=as.numeric(TOTALCLEARED))]
  d <- unique(d)
  d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1]
}))
DL[, idt := force10(SETTLEMENTDATE)]

DP <- rbindlist(lapply(mm_dl, function(M) {
  f <- file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))
  if (!file.exists(f)) return(NULL)
  d <- readRDS(f); setDT(d)
  keep <- intersect(c("SETTLEMENTDATE","RRP","INTERVENTION","REGIONID"), names(d))
  d <- d[, ..keep]
  if ("REGIONID" %in% names(d)) d <- d[REGIONID=="SA1"]
  if ("INTERVENTION" %in% names(d)) d <- d[d[, .I[which.min(as.numeric(INTERVENTION))], by=SETTLEMENTDATE]$V1]
  d[, .(idt=force10(SETTLEMENTDATE), RRP=as.numeric(RRP))]
}))
DP <- unique(DP, by="idt")
saveRDS(list(BOP=BOP, BDO=BDO, DL=DL, DP=DP), CACHE1C)
}
cat(sprintf("BOP focal rows: %s | versions: %s\n", format(nrow(BOP), big.mark=","),
            format(uniqueN(BOP[, .(DUID, td, odt)]), big.mark=",")))

# CACHE CONVENTION FIX (verified on TORRB2 2023-12): the as.Date(TRADINGDATE) label is one day
# BEHIND the calendar day of the version's own intervals (label D carries intervals of D+1);
# BIDDAYOFFER's SETTLEMENTDATE label shares the same convention (Task 1 paired the two labels by
# equality). Re-key both to the calendar day the bids actually cover, so episode-side calendar-day
# lookups hit the right versions. Task 1 itself is unaffected (it matched on INTERVAL_DATETIME
# directly, label-free); validation against its floors below.
BOP[, td := dt10(idt - 1)]
chk <- BOP[sample(.N, 10000)]
stopifnot(chk[, all(dt10(idt - 1) == td)])
BDO[, td := td + 1L]

PIV <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(PIV)
PIV[, idt := force10(SETTLEMENTDATE)]

EP_ALL <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
EP_ALL[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]

DE <- readRDS(file.path(ROOT, "Direction/direction_data/parsed/direction_events.rds")); setDT(DE)
DE_new <- DE[source_format=="new" & duid %in% FOCUS,
             .(duid, effective_time=force10(effective_time), issue_time=force10(issue_time),
               direction_instruction, market_notice, reason)]

# ---------------------------------------------------------------------------
# (a) Duration check: window-consistent counterfactual over [s, c]
# ---------------------------------------------------------------------------
cat("\n=== (a) Duration check ===\n")
# In-force version per (episode, trading date): latest OFFERDATETIME <= tau. One lookup per
# episode x td, then join its 288 interval rows to the episode's dispatch intervals.
a_rows <- vector("list", nrow(Z))
for (j in seq_len(nrow(Z))) {
  e <- Z[j]
  dl_e <- DL[DUID == e$duid & idt > e$s & idt <= e$c]
  tds <- sort(unique(dt10(dl_e$idt - 1)))  # trading date = calendar day of interval start
  vfl <- rbindlist(lapply(tds, function(D) {
    v <- BOP[DUID == e$duid & td == D & odt <= e$tau]
    if (!nrow(v)) return(NULL)
    v[odt == max(odt)]
  }))
  lfl <- rbindlist(lapply(tds, function(D) {
    l <- BDO[DUID == e$duid & td == D & od <= e$tau]
    if (!nrow(l)) return(NULL)
    l <- l[od == max(od)]
    cbind(data.table(td = D), l[1, ..pb_cols])
  }))
  if (nrow(vfl)) {
    fb <- vfl[lfl, on="td", nomatch=NULL]
    pbm <- as.matrix(fb[, ..pb_cols]); bam <- as.matrix(fb[, ..ba_cols]); bam[is.na(bam)] <- 0
    fb[, floor_mw_i := rowSums(bam * (pbm <= 0), na.rm=TRUE)]
    fb <- fb[, .(idt, MAXAVAIL, floor_mw_i,
                 pb1=pbm[,1],pb2=pbm[,2],pb3=pbm[,3],pb4=pbm[,4],pb5=pbm[,5],
                 pb6=pbm[,6],pb7=pbm[,7],pb8=pbm[,8],pb9=pbm[,9],pb10=pbm[,10],
                 ba1=bam[,1],ba2=bam[,2],ba3=bam[,3],ba4=bam[,4],ba5=bam[,5],
                 ba6=bam[,6],ba7=bam[,7],ba8=bam[,8],ba9=bam[,9],ba10=bam[,10])]
    dl_e <- fb[dl_e, on="idt"]
  } else {
    dl_e[, `:=`(MAXAVAIL=NA_real_, floor_mw_i=NA_real_)]
    for (cc in c(paste0("pb",1:10), paste0("ba",1:10))) dl_e[, (cc) := NA_real_]
  }
  dl_e <- DP[dl_e, on="idt"]
  pbm <- as.matrix(dl_e[, paste0("pb",1:10), with=FALSE])
  bam <- as.matrix(dl_e[, paste0("ba",1:10), with=FALSE])
  cleared <- rowSums(bam * (pbm <= dl_e$RRP), na.rm=TRUE)
  dl_e[, floor_price_aware_i := pmin(cleared, MAXAVAIL)]
  n_nobid <- dl_e[is.na(floor_mw_i), .N]
  dl_e[, covered := !is.na(floor_mw_i)]
  setorder(dl_e, idt)
  floor_first <- dl_e[covered==TRUE, floor_mw_i][1]
  dl_e[, day_idx := as.integer(dt10(idt - 1) - dt10(e$s))]   # 0 = issue-day, 1 = next trading day, ...
  nobid_by_day <- dl_e[, .(nobid = sum(!covered), n = .N), by=day_idx]
  dl_e[is.na(floor_mw_i), floor_mw_i := 0]
  dl_e[is.na(floor_price_aware_i), floor_price_aware_i := 0]
  a_rows[[j]] <- data.table(
    episode_id = e$episode_id, duid = e$duid,
    window_hours = as.numeric(difftime(e$c, e$s, units="hours")),
    n_intervals_window = nrow(dl_e), n_intervals_nobid_at_tau = n_nobid,
    nobid_day0 = nobid_by_day[day_idx==0, sum(nobid)], n_day0 = nobid_by_day[day_idx==0, sum(n)],
    nobid_day1plus = nobid_by_day[day_idx>0, sum(nobid)], n_day1plus = nobid_by_day[day_idx>0, sum(n)],
    excess_at_issue_mw = e$excess_over_floor,
    floor_first_interval = floor_first, floor_task1 = e$floor_mw,
    window_floor_mwh = dl_e[, sum(floor_mw_i)/12],
    window_output_mwh = dl_e[, sum(TOTALCLEARED)/12],
    window_excess_mwh = dl_e[, sum(TOTALCLEARED - floor_mw_i)/12],
    covered_excess_mwh = dl_e[covered==TRUE, sum(TOTALCLEARED - floor_mw_i)/12],
    n_intervals_covered = dl_e[covered==TRUE, .N],
    window_excess_capped_mwh = dl_e[, sum(TOTALCLEARED - pmin(floor_mw_i, fifelse(is.na(MAXAVAIL), floor_mw_i, MAXAVAIL)))/12],
    window_excess_priceaware_mwh = dl_e[, sum(TOTALCLEARED - floor_price_aware_i)/12],
    share_intervals_excess_le0 = dl_e[, mean(TOTALCLEARED - floor_mw_i <= 0)],
    mean_maxavail = dl_e[, mean(MAXAVAIL, na.rm=TRUE)])
}
A <- rbindlist(a_rows)
A[, survivor := window_excess_mwh <= 0]
A[, survivor_covered := covered_excess_mwh <= 0 & n_intervals_covered > 0]
fwrite(A, file.path(OUT, "task1c_a_window_counterfactual.csv"))
cat(sprintf("VALIDATION vs Task 1 (label-free lookup): first-interval floor equals Task 1's floor in %d of %d episodes (corr %.3f) -- confirms the label re-key\n",
            A[abs(floor_first_interval - floor_task1) < 1e-6, .N], nrow(A),
            A[, cor(floor_first_interval, floor_task1, use="complete.obs")]))
cat(sprintf("Windows fully covered by a bid in force at tau: %d of %d episodes (%d have >=1 no-bid interval; %.1f%% of all intervals no-bid)\n",
            A[n_intervals_nobid_at_tau==0, .N], nrow(A), A[n_intervals_nobid_at_tau>0, .N],
            100*A[, sum(n_intervals_nobid_at_tau)/sum(n_intervals_window)]))
cat(sprintf("No-bid diagnostic: issue-day intervals no-bid %.1f%% (%d/%d); day-1+ intervals no-bid %.1f%% (%d/%d) -- if the former is ~0, the gap is later-trading-days-had-no-offer-yet, not a join artifact\n",
            100*A[, sum(nobid_day0)/max(sum(n_day0),1)], A[, sum(nobid_day0)], A[, sum(n_day0)],
            100*A[, sum(nobid_day1plus)/max(sum(n_day1plus),1)], A[, sum(nobid_day1plus)], A[, sum(n_day1plus)]))
cat(sprintf("Median window length: %.1f h (IQR %.1f-%.1f)\n",
            A[, median(window_hours)], A[, quantile(window_hours,.25)], A[, quantile(window_hours,.75)]))
cat(sprintf("Zero-excess under WINDOW-consistent counterfactual (no-bid => floor 0): %d of %d (%.1f%%). Covered-intervals-only: %d. Capped: %d. Price-aware (supplementary): %d.\n",
            A[survivor==TRUE, .N], nrow(A), 100*A[, mean(survivor)], A[survivor_covered==TRUE, .N],
            A[window_excess_capped_mwh <= 0, .N], A[window_excess_priceaware_mwh <= 0, .N]))
print(A[, .N, by=.(duid, survivor)][order(duid, survivor)])

# ---------------------------------------------------------------------------
# (b) Sequencing check: rebid history [tau-48h, c] (all 69; survivors broken out)
# ---------------------------------------------------------------------------
cat("\n=== (b) Sequencing check ===\n")
b_rows <- vector("list", nrow(Z)); b_sig <- vector("list", nrow(Z))
for (j in seq_len(nrow(Z))) {
  e <- Z[j]
  tds <- seq(dt10(e$tau - 48*3600), dt10(e$c) + 1, by="day")
  v <- BOP[DUID == e$duid & td %in% tds & odt >= e$tau - 48*3600 & odt <= e$c]
  if (!nrow(v)) { b_rows[[j]] <- data.table(episode_id=e$episode_id, duid=e$duid, n_versions=0L,
    class="no rebid activity at all", first_exit_rel_h=NA_real_, first_cut_rel_h=NA_real_, reversed=NA); next }
  setorder(v, td, odt, idt)
  # per version x td: future intervals only (idt > odt) INSIDE the direction window (s, c] --
  # a MAXAVAIL=0 block elsewhere in the day is routine two-shifting for these units, not an
  # exit signal; the signal that matters is "my bids say I will not be there" for the window
  # AEMO then directed
  vs <- v[idt > odt & idt > e$s & idt <= e$c,
          .(mean_ma = mean(MAXAVAIL), min_ma = min(MAXAVAIL),
            max_run0 = { r <- rle(MAXAVAIL == 0); m <- r$lengths[r$values]; if (length(m)) max(m) else 0L },
            n_fut = .N), by=.(td, odt)]
  if (!nrow(vs)) { b_rows[[j]] <- data.table(episode_id=e$episode_id, duid=e$duid, n_versions=0L,
    class="no pre-issue version covers the window", class_any_cut="no pre-issue version covers the window",
    first_exit_rel_h=NA_real_, first_cut_rel_h=NA_real_, reversed=NA); next }
  setorder(vs, td, odt)
  vs[, prev_mean := shift(mean_ma), by=td]
  vs[, `:=`(exit0 = max_run0 >= 12, cut = !is.na(prev_mean) & (prev_mean - mean_ma) >= 20)]
  vs[, rel_h := as.numeric(difftime(odt, e$tau, units="hours"))]
  first_exit <- vs[exit0==TRUE][order(odt)][1]
  first_cut  <- vs[cut ==TRUE][order(odt)][1]
  reversed <- FALSE
  if (nrow(first_exit[!is.na(odt)])) {
    later <- vs[td == first_exit$td & odt > first_exit$odt]
    base  <- vs[td == first_exit$td & odt < first_exit$odt, mean_ma]
    if (nrow(later) && length(base)) reversed <- any(later$mean_ma > 0.5*max(base, na.rm=TRUE))
  }
  # headline classification on TRUE exit signals only (MAXAVAIL=0 run >= 1h); a mere >=20 MW
  # mean cut classifies everything (rebids are constant background) -- kept as secondary
  cls_exit <- if (is.na(first_exit$odt)) "no exit signal ever"
              else if (first_exit$rel_h < 0) "signal then direction" else "signal after direction"
  cls_any  <- if (is.na(first_exit$odt) && is.na(first_cut$odt)) "no exit signal ever"
              else { t0 <- min(c(first_exit$rel_h, first_cut$rel_h), na.rm=TRUE)
                     if (t0 < 0) "signal then direction" else "signal after direction" }
  b_rows[[j]] <- data.table(episode_id=e$episode_id, duid=e$duid, n_versions=nrow(vs),
    class=cls_exit, class_any_cut=cls_any,
    first_exit_rel_h = first_exit$rel_h, first_cut_rel_h = first_cut$rel_h, reversed = reversed)
  # capture rebid explanations for signal versions (join BDO on same td + nearest offer time)
  sigv <- vs[exit0==TRUE | cut==TRUE]
  if (nrow(sigv)) {
    ex <- BDO[DUID == e$duid & td %in% sigv$td & od >= e$tau - 48*3600 & od <= e$c,
              .(td, od, REBIDEXPLANATION, REBID_CATEGORY)]
    if (nrow(ex)) { ex[, episode_id := e$episode_id]; b_sig[[j]] <- ex }
  }
}
B <- rbindlist(b_rows, fill=TRUE)
B <- merge(B, A[, .(episode_id, survivor)], by="episode_id")
fwrite(B, file.path(OUT, "task1c_b_sequencing.csv"))
SIG <- rbindlist(b_sig[!sapply(b_sig, is.null)], fill=TRUE)
if (nrow(SIG)) fwrite(SIG, file.path(OUT, "task1c_b_rebid_explanations.csv"))
cat("All 69 (headline: MAXAVAIL=0 exit runs only):\n"); print(B[, .N, by=class][order(-N)])
cat("All 69 (secondary: any >=20 MW cut counts as signal):\n"); print(B[, .N, by=class_any_cut][order(-N)])
cat("Window-consistent survivors only (headline):\n"); print(B[survivor==TRUE, .N, by=class][order(-N)])
cat(sprintf("Median first-exit lead where signal precedes direction: %.1f h before issue\n",
            B[class=="signal then direction", -median(first_exit_rel_h, na.rm=TRUE)]))
cat(sprintf("Signals later reversed: %d of %d signal episodes\n",
            B[class!="no exit signal ever" & reversed==TRUE, .N], B[class!="no exit signal ever", .N]))

# ---------------------------------------------------------------------------
# (c) Combination check at issue (all 69)
# ---------------------------------------------------------------------------
cat("\n=== (c) Combination check ===\n")
grid5 <- function(t) force10(as.POSIXct(floor(as.numeric(t)/300)*300 + 300, origin="1970-01-01"))  # end of the 5-min interval containing t
st_on_cols <- paste0("on_", unique(STATION))
c_rows <- vector("list", nrow(Z))
for (j in seq_len(nrow(Z))) {
  e <- Z[j]; st <- STATION[[e$duid]]
  t0 <- grid5(e$tau)
  pv <- PIV[idt == t0]
  pv_pre <- PIV[idt > t0 - 4*3600 & idt <= t0]
  pv_post <- PIV[idt > t0 & idt <= t0 + 4*3600]
  on_now <- if (nrow(pv)) pv[[paste0("on_", st)]] else NA_integer_
  # sister units (same station, TORRB only)
  sibs <- SISTERS[[e$duid]]
  sib_on_tau <- sib_off_within4h <- sib_offed_prior4h <- NA
  if (length(sibs)) {
    sd <- DL[DUID %in% sibs & idt > e$tau - 4*3600 & idt <= e$tau + 4*3600]
    if (nrow(sd)) {
      at_tau <- sd[idt == t0, .(on = INITIALMW > 1), by=DUID]
      pre    <- sd[idt <= t0,  .(was_on = any(INITIALMW > 1), on_end = INITIALMW[which.max(idt)] > 1), by=DUID]
      post   <- sd[idt > t0,   .(goes_off = any(INITIALMW <= 1)), by=DUID]
      mm2 <- merge(merge(pre, post, by="DUID", all=TRUE), at_tau, by="DUID", all=TRUE)
      sib_on_tau        <- mm2[on==TRUE, .N]
      sib_off_within4h  <- mm2[on==TRUE & goes_off==TRUE, .N]
      sib_offed_prior4h <- mm2[was_on==TRUE & on_end==FALSE, .N]
    }
  }
  # cross-station: any other station in the combinations set losing units around tau
  other_st <- setdiff(unique(STATION), st)
  oth_drop <- if (nrow(pv_pre) && nrow(pv_post)) {
    any(sapply(paste0("on_", other_st), function(cc)
      max(pv_pre[[cc]], na.rm=TRUE) > min(pv_post[[cc]], na.rm=TRUE)))
  } else NA
  c_rows[[j]] <- data.table(
    episode_id = e$episode_id, duid = e$duid, station = st,
    short_at_tau = if (nrow(pv)) as.logical(pv$short) else NA,
    short_n1_at_tau = if (nrow(pv)) as.logical(pv$short_n1) else NA,
    piv_at_tau = if (nrow(pv)) as.logical(pv[[paste0("piv_", st)]]) else NA,
    piv_n1_at_tau = if (nrow(pv)) as.logical(pv[[paste0("piv_n1_", st)]]) else NA,
    on_station_at_tau = on_now,
    sisters_online_at_tau = sib_on_tau, sisters_heading_off_4h = sib_off_within4h,
    sisters_went_off_prior_4h = sib_offed_prior4h, other_station_lost_unit_pm4h = oth_drop)
}
C <- rbindlist(c_rows)
C[, sister_at_risk := (fifelse(is.na(sisters_heading_off_4h), 0L, sisters_heading_off_4h) > 0) |
                      (fifelse(is.na(sisters_went_off_prior_4h), 0L, sisters_went_off_prior_4h) > 0) |
                      (other_station_lost_unit_pm4h %in% TRUE)]
C[, needed_to_complete := (piv_n1_at_tau %in% TRUE | short_at_tau %in% TRUE | short_n1_at_tau %in% TRUE) & sister_at_risk]
C <- merge(C, A[, .(episode_id, survivor)], by="episode_id")
fwrite(C, file.path(OUT, "task1c_c_combination.csv"))
cat(sprintf("At tau: short (N-0) %d/69, short_n1 %d/69, unit piv %d/69, unit piv_n1 %d/69\n",
            C[short_at_tau==TRUE,.N], C[short_n1_at_tau==TRUE,.N], C[piv_at_tau==TRUE,.N], C[piv_n1_at_tau==TRUE,.N]))
cat(sprintf("Sister/other-station unit at risk (+-4h): %d/69; NEEDED-TO-COMPLETE (binding & at-risk): %d/69 (%.0f%%); among survivors: %d/%d\n",
            C[sister_at_risk==TRUE,.N], C[needed_to_complete==TRUE,.N], 100*C[,mean(needed_to_complete)],
            C[survivor==TRUE & needed_to_complete==TRUE,.N], C[survivor==TRUE,.N]))

# ---------------------------------------------------------------------------
# (d) Instrument text
# ---------------------------------------------------------------------------
cat("\n=== (d) Instrument text ===\n")
Z2 <- copy(Z); Z2[, `:=`(lo = s - 7200, hi = s + 7200)]
setkey(DE_new, duid, effective_time)
Dm <- DE_new[Z2, on=.(duid, effective_time >= lo, effective_time <= hi), nomatch=NULL,
             .(episode_id, duid, direction_instruction, market_notice, reason_report = reason)]
Dm <- Dm[Dm[, .I[1], by=episode_id]$V1]
fwrite(Dm, file.path(OUT, "task1c_d_instrument.csv"))
cat("Full distinct instruction strings among the 69 (verbatim from the AEMO report instrument column):\n")
print(Dm[, .N, by=direction_instruction][order(-N)])
cat("vs positive-excess lobe:\n")
print(X[excess_over_floor > 0, .N, by=instruction][order(-N)])
Dm[, mn_id := regmatches(market_notice, regexpr("[0-9]{5,6}", market_notice))[1], by=seq_len(nrow(Dm))]
n_nomn <- Dm[grepl("^No Market Notice", market_notice), .N]
cat(sprintf("Market notices: %d distinct normalized IDs across %d episodes with an ID; %d episodes state 'No Market Notices were issued' (sample IDs: %s)\n",
            uniqueN(Dm[!is.na(mn_id), mn_id]), Dm[!is.na(mn_id), .N], n_nomn,
            paste(head(unique(Dm[!is.na(mn_id), mn_id]), 6), collapse=", ")))

# ---------------------------------------------------------------------------
# (e) Anticipation probe (all 271; zero- vs positive-excess contrast)
# ---------------------------------------------------------------------------
cat("\n=== (e) Anticipation probe ===\n")
ep_hist <- EP_ALL[, .(duid, station, s)]
e_rows <- vector("list", nrow(X))
for (j in seq_len(nrow(X))) {
  e <- X[j]; st <- STATION[[e$duid]]
  t0 <- grid5(e$tau)
  pre24 <- PIV[idt > t0 - 24*3600 & idt <= t0]
  e_rows[[j]] <- data.table(
    episode_id = e$episode_id,
    dir_unit_prior_1d = as.numeric(ep_hist[duid==e$duid & s < e$s & s >= e$s - 1*86400, .N]),
    dir_unit_prior_3d = as.numeric(ep_hist[duid==e$duid & s < e$s & s >= e$s - 3*86400, .N]),
    dir_unit_prior_7d = as.numeric(ep_hist[duid==e$duid & s < e$s & s >= e$s - 7*86400, .N]),
    dir_station_prior_7d = as.numeric(ep_hist[station==EP_ALL[duid==e$duid, station][1] & s < e$s & s >= e$s - 7*86400, .N]),
    pre24_short_share = pre24[, mean(short, na.rm=TRUE)],
    pre24_shortn1_share = pre24[, mean(short_n1, na.rm=TRUE)],
    pre24_piv_share = pre24[, mean(get(paste0("piv_", st)), na.rm=TRUE)],
    pre24_pivn1_share = pre24[, mean(get(paste0("piv_n1_", st)), na.rm=TRUE)])
}
Ea <- rbindlist(e_rows)
Ea <- merge(Ea, X[, .(episode_id, lobe_zero = excess_over_floor <= 0)], by="episode_id")
Ea <- merge(Ea, A[, .(episode_id, survivor)], by="episode_id", all.x=TRUE)
fwrite(Ea, file.path(OUT, "task1c_e_anticipation.csv"))
comp <- Ea[, .(n=.N,
               med_dir7d = as.numeric(median(dir_unit_prior_7d)), pct_dir7d_ge1 = round(100*mean(dir_unit_prior_7d>=1),1),
               pct_dir1d_ge1 = round(100*mean(dir_unit_prior_1d>=1),1),
               med_station7d = median(dir_station_prior_7d),
               med_pre24_shortn1 = round(median(pre24_shortn1_share, na.rm=TRUE),3),
               med_pre24_pivn1 = round(median(pre24_pivn1_share, na.rm=TRUE),3)),
           by=.(group = fifelse(lobe_zero, "zero-excess", "positive-excess"))]
print(comp)
wt <- function(v) suppressWarnings(wilcox.test(v ~ Ea$lobe_zero)$p.value)
cat(sprintf("Wilcoxon p (zero vs positive): dir7d %.3f | station7d %.3f | pre24 short_n1 %.3f | pre24 piv_n1 %.3f\n",
            wt(Ea$dir_unit_prior_7d), wt(Ea$dir_station_prior_7d),
            wt(Ea$pre24_shortn1_share), wt(Ea$pre24_pivn1_share)))
surv_comp <- Ea[lobe_zero==TRUE, .(n=.N, pct_dir7d_ge1 = round(100*mean(dir_unit_prior_7d>=1),1),
                med_pre24_shortn1 = round(median(pre24_shortn1_share, na.rm=TRUE),3)), by=survivor]
cat("Within the 69, by window-consistent survivor status:\n"); print(surv_comp)
fwrite(comp, file.path(OUT, "task1c_e_group_comparison.csv"))

# ---------------------------------------------------------------------------
# Cross-tab for the findings ranking (survivors x explanations)
# ---------------------------------------------------------------------------
cat("\n=== Ranking inputs ===\n")
R <- merge(merge(A[, .(episode_id, duid, survivor, window_excess_mwh)],
                 B[, .(episode_id, seq_class = class)], by="episode_id"),
           C[, .(episode_id, needed_to_complete, short_at_tau, short_n1_at_tau, piv_n1_at_tau)], by="episode_id")
R <- merge(R, Ea[, .(episode_id, dir_unit_prior_7d, pre24_shortn1_share)], by="episode_id")
fwrite(R, file.path(OUT, "task1c_ranking_inputs.csv"))
cat("Survivor x sequencing class x needed-to-complete:\n")
print(R[, .N, by=.(survivor, seq_class, needed_to_complete)][order(-survivor, -N)])
cat("\nSaved task1c_{a_window_counterfactual,b_sequencing,b_rebid_explanations,c_combination,d_instrument,e_anticipation,e_group_comparison,ranking_inputs}.csv\n")
cat("Findings written after inspection (findings_task1c.md).\n")
