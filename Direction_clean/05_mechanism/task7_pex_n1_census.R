#!/usr/bin/env Rscript
# task7_pex_n1_census.R -- ex-ante N-1 essentiality (pex_n1): BUILD + CENSUS ONLY.
# No regression, no adjudicated re-test (that requires a new pre-registration).
#
# pex_n1_<station> at interval t: zero the focal station out of the AVAILABLE fleet, then
# remove ONE unit of the largest-per-unit-MW available RIVAL station (the ex-ante mirror of
# piv_n1's largest-online-unit convention); the station is N-1-essential ex-ante iff no
# applicable minimum combination survives. Rivals-only by construction (own offer never
# enters); leakage audit run below. Also reported: the worst-case variant depth_ex <= 1
# (any single rival outage makes the station essential), which the existing panel carries.
#
# Constructions copied verbatim from Direction/04_market_power/pivotality.R (INTERVENTION==0,
# dedup keep-max-TOTALCLEARED, non-sync definition, mw_units approximations, threshold rule).
# VALIDATION: recomputed pex must equal the panel's pex for every interval.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")

combos <- fread(file.path(ROOT, "Direction/sa_minimum_generator_combinations.csv"))
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x) { x[is.na(x)] <- 0L; as.integer(x) }), .SDcols=STATIONS]
cs <- combos[regime == "system_normal"]
REQ <- as.matrix(cs[, ..STATIONS]); THRESH <- cs$non_sync_mw
STATION_DUIDS <- list(torrens_island_b=c("TORRB1","TORRB2","TORRB3","TORRB4"),
  dry_creek=c("DRYCGT1","DRYCGT2","DRYCGT3"), pelican_point_gt="PPCCGT", osborne_gt_st="OSB-AG",
  quarantine_5="QPS5", mintaro="MINTARO", bips="BARKIPS1", snapper_point="SNAPPER1")
SYNC_DUIDS <- unlist(STATION_DUIDS, use.names=FALSE)
mw_units <- function(duid, mw) switch(duid,
  PPCCGT   = fifelse(mw > 250, 2L, fifelse(mw > 0, 1L, 0L)),
  `OSB-AG` = fifelse(mw > 120, 2L, fifelse(mw > 0, 1L, 0L)),
  BARKIPS1 = pmin(as.integer(round(mw/16.1)), 12L),
  SNAPPER1 = pmin(as.integer(round(mw/20.0)), 5L),
  fifelse(mw > 0, 1L, 0L))
feasible_any <- function(counts, nonsync) {
  appl <- THRESH >= nonsync
  if (!any(appl)) appl <- THRESH == max(THRESH)
  R <- REQ[appl, , drop=FALSE]
  any(rowSums(sweep(R, 2, counts, FUN=function(req, have) req > have)) == 0)
}
FOCAL_ST <- c("torrens_island_b","pelican_point_gt")

month_pass <- function(M) {
  f <- file.path(OUT, sprintf("_pexn1_%s.rds", M))
  if (file.exists(f)) return(readRDS(f))
  dl <- as.data.table(readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))))
  dl <- dl[INTERVENTION == 0]
  setorder(dl, SETTLEMENTDATE, DUID, -TOTALCLEARED)
  dl <- unique(dl, by=c("SETTLEMENTDATE","DUID"))
  if ("UIGF" %in% names(dl) && dl[, any(!is.na(UIGF))]) {
    nsd <- dl[, .(fl = any(UIGF > 0, na.rm=TRUE)), DUID][fl==TRUE, DUID]
  } else nsd <- dl[, .(fl = any(SEMIDISPATCHCAP > 0, na.rm=TRUE)), DUID][fl==TRUE, DUID]
  nsd <- setdiff(nsd, SYNC_DUIDS)
  ns <- dl[DUID %in% nsd, .(nonsync_mw = sum(pmax(TOTALCLEARED,0), na.rm=TRUE)), by=SETTLEMENTDATE]
  syn <- dl[DUID %in% SYNC_DUIDS]
  d2s <- rbindlist(lapply(names(STATION_DUIDS), function(s) data.table(DUID=STATION_DUIDS[[s]], station=s)))
  syn <- merge(syn, d2s, by="DUID")
  multi <- c("TORRB1","TORRB2","TORRB3","TORRB4","DRYCGT1","DRYCGT2","DRYCGT3")
  syn[, avail_units := fifelse(DUID %in% multi, as.integer(AVAILABILITY > 0),
                               mapply(mw_units, DUID, fifelse(AVAILABILITY > 0, pmax(AVAILABILITY, TOTALCLEARED), 0)))]
  # per-unit MW of AVAILABLE units (for the largest-available-rival contingency)
  syn[, per_unit_av_mw := fifelse(avail_units > 0, pmax(AVAILABILITY, TOTALCLEARED)/avail_units, 0)]
  av <- syn[, .(avail = sum(avail_units)), by=.(SETTLEMENTDATE, station)]
  av_w <- dcast(av, SETTLEMENTDATE ~ station, value.var="avail", fill=0)
  for (s in STATIONS) if (!s %in% names(av_w)) av_w[[s]] <- 0L
  setkey(av_w, SETTLEMENTDATE); setkey(ns, SETTLEMENTDATE)
  W <- ns[av_w]; W[is.na(nonsync_mw), nonsync_mw := 0]
  AV <- as.matrix(W[, ..STATIONS]); NS <- W$nonsync_mw
  # largest AVAILABLE unit's station, per interval, EXCLUDING each focal station in turn
  pm <- dcast(syn[avail_units > 0, .(m = max(per_unit_av_mw)), by=.(SETTLEMENTDATE, station)],
              SETTLEMENTDATE ~ station, value.var="m", fill=0)
  for (s in STATIONS) if (!s %in% names(pm)) pm[[s]] <- 0
  pm <- pm[data.table(SETTLEMENTDATE=W$SETTLEMENTDATE), on="SETTLEMENTDATE"]
  PM <- as.matrix(pm[, ..STATIONS]); PM[is.na(PM)] <- 0
  nI <- nrow(W)
  res <- data.table(SETTLEMENTDATE = W$SETTLEMENTDATE)
  for (fs in FOCAL_ST) {
    jj <- match(fs, STATIONS)
    pex <- logical(nI); pexn1 <- logical(nI)
    for (t in seq_len(nI)) {
      avr <- AV[t, ]; avr[jj] <- 0L
      pex[t] <- !feasible_any(avr, NS[t])
      if (pex[t]) { pexn1[t] <- TRUE; next }        # N-0 essential => N-1 essential (superset)
      pmr <- PM[t, ]; pmr[jj] <- 0                   # rivals only for the contingency
      li <- which.max(pmr)
      if (pmr[li] > 0 && avr[li] > 0) { avc <- avr; avc[li] <- avc[li] - 1L
        pexn1[t] <- !feasible_any(avc, NS[t]) }
    }
    res[[paste0("pex_recomp_", fs)]] <- pex
    res[[paste0("pex_n1_", fs)]] <- pexn1
  }
  saveRDS(res, f); cat(sprintf("  %s done (%d intervals)\n", M, nI)); res
}
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")
PX <- rbindlist(lapply(MONTHS, month_pass))
saveRDS(PX, file.path(OUT, "task7_pex_n1_panel.rds"))

# ---- VALIDATION vs the existing panel ----
piv <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(piv)
V <- merge(PX, piv[, .(SETTLEMENTDATE, pex_torrens_island_b, pex_pelican_point_gt,
                       depth_ex_torrens_island_b, depth_ex_pelican_point_gt)], by="SETTLEMENTDATE")
cat(sprintf("\nVALIDATION: recomputed pex == panel pex -- Torrens %s (%.4f%% mismatch), Pelican %s\n",
            V[, all(pex_recomp_torrens_island_b == pex_torrens_island_b)],
            100*V[, mean(pex_recomp_torrens_island_b != pex_torrens_island_b)],
            V[, all(pex_recomp_pelican_point_gt == pex_pelican_point_gt)]))
cat("\n=== Interval rates (%): current pex | NEW pex_n1 | depth_ex<=1 (worst-case) ===\n")
print(V[, .(torrens_pex=round(100*mean(pex_torrens_island_b),2),
            torrens_pex_n1=round(100*mean(pex_n1_torrens_island_b),2),
            torrens_depth_le1=round(100*mean(depth_ex_torrens_island_b <= 1),2),
            pelican_pex=round(100*mean(pex_pelican_point_gt),2),
            pelican_pex_n1=round(100*mean(pex_n1_pelican_point_gt),2),
            pelican_depth_le1=round(100*mean(depth_ex_pelican_point_gt <= 1),2))])

# ---- day-level census (>=1h rule, unchanged), clean intersection, A-events ----
V[, cal_day := dt10(force10(SETTLEMENTDATE) - 1)]
day <- V[, .(ess_pex_t = sum(pex_torrens_island_b) >= 12, ess_n1_t = sum(pex_n1_torrens_island_b) >= 12,
             ess_d1_t = sum(depth_ex_torrens_island_b <= 1) >= 12,
             ess_pex_p = sum(pex_pelican_point_gt) >= 12, ess_n1_p = sum(pex_n1_pelican_point_gt) >= 12,
             ess_d1_p = sum(depth_ex_pelican_point_gt <= 1) >= 12), by=cal_day]
DC <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
grid <- rbindlist(lapply(c("TORRB2","TORRB3","TORRB4","PPCCGT"), function(u)
  day[, .(DUID=u, cal_day, ess_pex = if (u=="PPCCGT") ess_pex_p else ess_pex_t,
          ess_n1 = if (u=="PPCCGT") ess_n1_p else ess_n1_t,
          ess_d1 = if (u=="PPCCGT") ess_d1_p else ess_d1_t)]))
grid <- merge(grid, DC[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"))
grid <- merge(grid, UD[, .(DUID, cal_day, comp_A)], by=c("DUID","cal_day"), all.x=TRUE)
cens <- grid[, .(
  ess_days_pex = sum(ess_pex), ess_days_n1 = sum(ess_n1), ess_days_d1 = sum(ess_d1),
  clean_ess_pex = sum(ess_pex & clean), clean_ess_n1 = sum(ess_n1 & clean), clean_ess_d1 = sum(ess_d1 & clean),
  Aev_ess_n1 = sum(ess_n1 & comp_A, na.rm=TRUE), Aev_clean_ess_n1 = sum(ess_n1 & clean & comp_A, na.rm=TRUE))]
cat("\n=== DAY CENSUS (4 test units x 1,096 days; >=1h rule) ===\n"); print(cens)
cat("\nPer unit:\n")
print(grid[, .(ess_pex=sum(ess_pex), ess_n1=sum(ess_n1), ess_d1=sum(ess_d1),
               clean_ess_n1=sum(ess_n1 & clean)), by=DUID])
cat("\nOverlap (unit-days): pex&n1 =", grid[ess_pex & ess_n1, .N],
    "| n1 only =", grid[!ess_pex & ess_n1, .N], "| pex only =", grid[ess_pex & !ess_n1, .N], "\n")
fwrite(grid, file.path(OUT, "task7_label_census.csv"))

# ---- leakage audit (Stage-1 pattern): pex_n1 on OWN availability / cheap capacity ----
SH <- readRDS(file.path(OUT, "task4_ladder_shape.rds"))
LA <- merge(grid, UD[, .(DUID, cal_day, day_max_ma)], by=c("DUID","cal_day"))
LA <- merge(LA, SH[, .(DUID, cal_day, q_2xsrmc)], by=c("DUID","cal_day"), all.x=TRUE)
la <- LA[, .(r2_ma = summary(lm(as.integer(ess_n1) ~ day_max_ma))$r.squared,
             r2_cheap = summary(lm(as.integer(ess_n1) ~ q_2xsrmc))$r.squared), by=DUID]
cat("\nLEAKAGE AUDIT (ess_n1 day flag on own day-max MAXAVAIL / own cheap MW; PASS = R^2 ~ 0):\n")
print(la[, .(DUID, r2_ma=round(r2_ma,4), r2_cheap=round(r2_cheap,4))])
cat("\nCENSUS ONLY -- no regression run; any test under a relaxed label needs a new pre-registration.\n")
