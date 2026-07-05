#!/usr/bin/env Rscript
# task13_roster_requirement.R -- the registered roster-vs-requirement test
# (task13_preregistration.md, committed first) + the handover companion.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TOR <- c("TORRB2","TORRB3","TORRB4")

# ---- combination machinery (verbatim conventions from pivotality.R / task7) ----
combos <- fread(file.path(ROOT, "Direction/sa_minimum_generator_combinations.csv"))
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x) { x[is.na(x)] <- 0L; as.integer(x) }), .SDcols=STATIONS]
cs <- combos[regime=="system_normal"]; REQ <- as.matrix(cs[, ..STATIONS]); THRESH <- cs$non_sync_mw
STATION_DUIDS <- list(torrens_island_b=c("TORRB1","TORRB2","TORRB3","TORRB4"),
  dry_creek=c("DRYCGT1","DRYCGT2","DRYCGT3"), pelican_point_gt="PPCCGT", osborne_gt_st="OSB-AG",
  quarantine_5="QPS5", mintaro="MINTARO", bips="BARKIPS1", snapper_point="SNAPPER1")
SYNC_DUIDS <- unlist(STATION_DUIDS, use.names=FALSE)
mw_units <- function(duid, mw) switch(duid,
  PPCCGT = fifelse(mw > 250, 2L, fifelse(mw > 0, 1L, 0L)),
  `OSB-AG` = fifelse(mw > 120, 2L, fifelse(mw > 0, 1L, 0L)),
  BARKIPS1 = pmin(as.integer(round(mw/16.1)), 12L),
  SNAPPER1 = pmin(as.integer(round(mw/20.0)), 5L), fifelse(mw > 0, 1L, 0L))
feasible_any <- function(counts, nonsync) {
  appl <- THRESH >= nonsync; if (!any(appl)) appl <- THRESH == max(THRESH)
  R <- REQ[appl, , drop=FALSE]
  any(rowSums(sweep(R, 2, counts, FUN=function(req, have) req > have)) == 0)
}
jj <- match("torrens_island_b", STATIONS)

# ---- per-interval minimum Torrens requirement (36-month DISPATCHLOAD pass, cached) ----
RC <- file.path(OUT, "task13_minreq.rds")
if (file.exists(RC)) { MR <- readRDS(RC) } else {
  MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")
  mr <- vector("list", length(MONTHS))
  for (k in seq_along(MONTHS)) {
    M <- MONTHS[k]
    dl <- as.data.table(readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))))
    dl <- dl[INTERVENTION == 0]
    setorder(dl, SETTLEMENTDATE, DUID, -TOTALCLEARED)
    dl <- unique(dl, by=c("SETTLEMENTDATE","DUID"))
    if ("UIGF" %in% names(dl) && dl[, any(!is.na(UIGF))]) {
      nsd <- dl[, .(fl=any(UIGF>0, na.rm=TRUE)), DUID][fl==TRUE, DUID]
    } else nsd <- dl[, .(fl=any(SEMIDISPATCHCAP>0, na.rm=TRUE)), DUID][fl==TRUE, DUID]
    nsd <- setdiff(nsd, SYNC_DUIDS)
    ns <- dl[DUID %in% nsd, .(nonsync=sum(pmax(TOTALCLEARED,0), na.rm=TRUE)), by=SETTLEMENTDATE]
    syn <- dl[DUID %in% SYNC_DUIDS]
    d2s <- rbindlist(lapply(names(STATION_DUIDS), function(s) data.table(DUID=STATION_DUIDS[[s]], station=s)))
    syn <- merge(syn, d2s, by="DUID")
    multi <- c("TORRB1","TORRB2","TORRB3","TORRB4","DRYCGT1","DRYCGT2","DRYCGT3")
    syn[, avail_units := fifelse(DUID %in% multi, as.integer(AVAILABILITY > 0),
                                 mapply(mw_units, DUID, fifelse(AVAILABILITY > 0, pmax(AVAILABILITY, TOTALCLEARED), 0)))]
    av <- dcast(syn[, .(avail=sum(avail_units)), by=.(SETTLEMENTDATE, station)],
                SETTLEMENTDATE ~ station, value.var="avail", fill=0)
    for (s in STATIONS) if (!s %in% names(av)) av[[s]] <- 0L
    setkey(av, SETTLEMENTDATE); setkey(ns, SETTLEMENTDATE)
    W <- ns[av]; W[is.na(nonsync), nonsync := 0]
    AV <- as.matrix(W[, ..STATIONS]); NS <- W$nonsync
    req <- integer(nrow(W))
    for (t in seq_len(nrow(W))) {
      v <- AV[t, ]; found <- FALSE
      for (kk in 0:4) { v[jj] <- kk
        if (feasible_any(v, NS[t])) { req[t] <- kk; found <- TRUE; break } }
      if (!found) req[t] <- 5L
    }
    mr[[k]] <- data.table(SETTLEMENTDATE = W$SETTLEMENTDATE, min_req = req)
    cat(sprintf("  %s done\n", M))
  }
  MR <- rbindlist(mr); saveRDS(MR, RC)
}
MR[, cal_day := dt10(force10(SETTLEMENTDATE) - 1)]
RQ <- MR[, .(req_max = max(min_req), req_mean = round(mean(min_req),2)), by=cal_day]

# ---- roster + controls ----
SD <- fread(file.path(OUT, "task12_station_config.csv")); SD[, cal_day := as.Date(cal_day)]
D  <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
ctl <- D[DUID=="TORRB2", .(cal_day, yyyymm, dem, rrp, segment)]
srmc <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
gas <- unique(srmc[duid=="TORRB2", .(yyyymm=as.integer(yyyymm), gas_gj)])
X <- Reduce(function(a,b) merge(a,b,by="cal_day",all.x=TRUE), list(SD[, .(cal_day, n_av)], RQ, ctl))
X <- merge(X, gas, by="yyyymm", all.x=TRUE)
X <- X[!is.na(req_max) & !is.na(dem)]
cat(sprintf("Station-days: %d | requirement (day max) distribution:\n", nrow(X)))
print(X[, .N, by=req_max][order(req_max)])
cat("\n=== Cross-tab BEFORE any coefficient: roster level x peak requirement ===\n")
print(dcast(X[, .N, by=.(n_av, req_max)], n_av ~ req_max, value.var="N", fill=0))
cat("\nMean roster by peak requirement:\n")
print(X[, .(mean_roster = round(mean(n_av),2), n_days=.N), by=req_max][order(req_max)])
cat(sprintf("Raw correlation(roster, req_max) = %.2f | (roster, req_mean) = %.2f\n",
            X[, cor(n_av, req_max)], X[, cor(n_av, req_mean)]))

# ---- the registered regressions ----
tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  ex <- list(...); for (nm in names(ex)) set(ct, j=nm, value=ex[[nm]]); ct[] }
res <- list()
res$m1 <- tidy(feols(n_av ~ req_max | yyyymm, X, vcov=~yyyymm), model="M1 month FE")
res$m2 <- tidy(feols(n_av ~ req_max + dem + rrp + gas_gj | yyyymm, X, vcov=~yyyymm), model="M2 + market controls")
DCJ <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DCJ[, cal_day := as.Date(cal_day)]
cln <- DCJ[DUID %in% TOR, .(all_clean = all(clean)), by=cal_day][all_clean==TRUE, cal_day]
res$m3 <- tidy(feols(n_av ~ req_max + dem + rrp + gas_gj | yyyymm, X[cal_day %in% cln], vcov=~yyyymm),
               model="M2 on all-units-clean days")
RES <- rbindlist(res); fwrite(RES, file.path(OUT, "task13_results.csv"))
cat("\n=== Registered coefficients ===\n")
print(RES[term=="req_max", .(model, estimate=round(estimate,3), se=round(std.error,3), p=round(p.value,4), nobs)])
cat("\nWCB on req_max (Rademacher/Webb, R=999):\n")
for (mm in c("M1","M2")) {
  r <- if (mm=="M1") "req_max" else "req_max + dem + rrp + gas_gj"
  lmf <- lm(as.formula(paste("n_av ~", r, "+ factor(yyyymm)")), X)
  b <- coef(lmf)[["req_max"]]
  for (tp in c(rademacher="wild", webb="wild-webb")) {
    set.seed(20260705); v <- vcovBS(lmf, cluster=~yyyymm, R=999L, type=tp)
    se <- sqrt(v["req_max","req_max"]); df <- uniqueN(X$yyyymm)-1L
    cat(sprintf("  [%s | %s] b=%.3f  wcb_p=%.4f\n", mm, tp, b, 2*pt(-abs(b/se), df)))
  }
}

# ---- descriptive companion: the 45 evening zeroings -- reductions or handovers? ----
cat("\n=== Companion: station-level evening availability on the D-1 zeroing days ===\n")
W5 <- fread(file.path(OUT, "task5c_withdrawal_events.csv"))
z <- unique(W5[case=="2 floor-crossing" & grp=="D-1", .(DUID, cal_day=as.Date(cal_day))])
IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TOR, .(DUID, cal_day, idt, MAXAVAIL)]
IV[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]
EV <- IV[hh %in% 19:23, .(ev_ma = sum(MAXAVAIL)/12), by=.(DUID, cal_day)]   # unit evening MWh
ST <- EV[, .(st_ev = sum(ev_ma)), by=cal_day]
setorder(ST, cal_day); ST[, st_ev_prev := shift(st_ev)]
zz <- merge(unique(z[, .(cal_day)]), ST, by="cal_day")
zz[, d_st := st_ev - st_ev_prev]
cat(sprintf("Zeroing days with station data: %d | station evening availability FELL on %d (%.0f%%), rose/flat on %d\n",
            nrow(zz), zz[d_st < -40, .N], 100*zz[, mean(d_st < -40)], zz[d_st >= -40, .N]))
cat(sprintf("Median station-level evening change on zeroing days: %.0f MWh (a full-unit evening ~ 1,000 MWh); handover share (station change > -40 MWh despite a unit zeroing): %.0f%%\n",
            zz[, median(d_st)], 100*zz[, mean(d_st >= -40)]))
fwrite(zz, file.path(OUT, "task13_handover_check.csv"))
cat("\nDone -- findings written against the committed readings.\n")
