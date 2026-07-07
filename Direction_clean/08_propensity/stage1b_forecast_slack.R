#!/usr/bin/env Rscript
# stage1b_forecast_slack.R -- Stage 1 (forecast half): slack at pre-dispatch horizons
# h in {1, 4, 8} hours, per the registration. Rivals-only by construction.
#
# Information set at decision time tau = t - h, for target half-hour t:
#   - Rival unit availability: MAXAVAIL of the latest offer version lodged at or before tau
#     (RIVAL_BOP_<M>.rds; focal excluded at source). Pre-dispatch consumes exactly these bids.
#   - Slow-start rule (registration: "a combination needing an offline steam rival is
#     infeasible within lead time"): PPCCGT and OSB-AG (CCGT / cogen-ST; start ~4 h) offline at
#     tau contribute 0 units when h < 4; fast OCGT/recip rivals are startable at all h here.
#   - Non-synchronous forecast: PDPASA_RS latest run at or before tau, SS_WIND_UIGF +
#     SS_SOLAR_UIGF for interval t (fallback SEMISCHEDULEDCAPACITY, then realized nonsync_mw;
#     source flagged per row).
# Slack = depth_station(counts, torrens) -- verbatim pivotality.R machinery (min rival-unit
# removals before no applicable combination is satisfiable without Torrens).
# Output: stage1_panel.rds (current + forecast columns), stage1b log. Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")
HORIZONS <- c(1, 4, 8)                       # hours
SLOW <- c("PPCCGT", "OSB-AG"); SLOW_START_H <- 4

# ---- combination machinery: verbatim from Direction/04_market_power/pivotality.R ----
combos <- fread(file.path(ROOT, "Direction/sa_minimum_generator_combinations.csv"))
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x) { x[is.na(x)] <- 0L; as.integer(x) }), .SDcols = STATIONS]
cs <- combos[regime == "system_normal"]; REQ <- as.matrix(cs[, ..STATIONS]); THRESH <- cs$non_sync_mw
DUID2STATION <- c(PPCCGT = "pelican_point_gt", `OSB-AG` = "osborne_gt_st", QPS5 = "quarantine_5",
                  DRYCGT1 = "dry_creek", DRYCGT2 = "dry_creek", DRYCGT3 = "dry_creek",
                  MINTARO = "mintaro", BARKIPS1 = "bips", SNAPPER1 = "snapper_point")
mw_units <- function(duid, mw) switch(duid,
  PPCCGT   = fifelse(mw > 250, 2L, fifelse(mw > 0, 1L, 0L)),
  `OSB-AG` = fifelse(mw > 120, 2L, fifelse(mw > 0, 1L, 0L)),
  BARKIPS1 = pmin(as.integer(round(mw / 16.1)), 12L),
  SNAPPER1 = pmin(as.integer(round(mw / 20.0)), 5L),
  fifelse(mw > 0, 1L, 0L))
DEPTH_MEMO <- new.env(parent = emptyenv())
min_removals <- function(cnt, R_appl, tierkey) {
  key <- paste0(tierkey, "|", paste0(cnt, collapse = ","))
  hit <- DEPTH_MEMO[[key]]; if (!is.null(hit)) return(hit)
  unmet <- rowSums(sweep(R_appl, 2, cnt, FUN = function(req, have) req > have))
  sat <- which(unmet == 0)
  if (length(sat) == 0L) { assign(key, 0L, envir = DEPTH_MEMO); return(0L) }
  req0 <- R_appl[sat[1L], ]
  js <- which(req0 >= 1L & cnt >= req0)
  best <- Inf
  for (j in js) {
    cnt2 <- cnt; cnt2[j] <- req0[j] - 1L
    cost <- cnt[j] - cnt2[j]
    if (cost >= best) next
    sub <- min_removals(cnt2, R_appl, tierkey)
    if (is.finite(sub) && cost + sub < best) best <- cost + sub
  }
  assign(key, best, envir = DEPTH_MEMO); best
}
depth_torrens <- function(counts, nonsync) {
  appl <- THRESH >= nonsync
  if (!any(appl)) appl <- THRESH == max(THRESH)
  R_appl <- REQ[appl, , drop = FALSE]
  tkey <- paste(which(appl), collapse = "")
  cnt <- counts; cnt["torrens_island_b"] <- 0L
  k <- min_removals(cnt, R_appl, tkey)
  if (!is.finite(k)) sum(cnt) + 1L else k
}

# ---- inputs ----
S <- readRDS(file.path(OUT, "stage1_panel_current.rds")); setDT(S)

miss_rb <- MONTHS[!file.exists(file.path(CACHE, sprintf("RIVAL_BOP_%s.rds", MONTHS)))]
miss_pd <- MONTHS[!file.exists(file.path(CACHE, sprintf("PDPASA_RS_%s.rds", MONTHS)))]
if (length(miss_rb) || length(miss_pd))
  stop(sprintf("MISSING CACHES -- RIVAL_BOP: %s | PDPASA_RS: %s",
               paste(miss_rb, collapse = ","), paste(miss_pd, collapse = ",")))

RB <- rbindlist(lapply(MONTHS, function(M) readRDS(file.path(CACHE, sprintf("RIVAL_BOP_%s.rds", M)))))
RB[, `:=`(INTERVAL_DATETIME = force10(INTERVAL_DATETIME), OFFERDATETIME = force10(OFFERDATETIME))]
setkey(RB, DUID, INTERVAL_DATETIME, OFFERDATETIME)
cat(sprintf("RIVAL_BOP rows: %d\n", nrow(RB)))

PD <- rbindlist(lapply(MONTHS, function(M) readRDS(file.path(CACHE, sprintf("PDPASA_RS_%s.rds", M)))), fill = TRUE)
# ARCHIVE months (202408+) carry a second RUNTYPE (LOR); DVD months have OUTAGE_LRC only.
# Use OUTAGE_LRC uniformly (present in all 37 months).
PD <- PD[is.na(RUNTYPE) | RUNTYPE == "OUTAGE_LRC"]
PD[, `:=`(RUN_DATETIME = force10(RUN_DATETIME), INTERVAL_DATETIME = force10(INTERVAL_DATETIME))]
PD[, ns_fc := fifelse(!is.na(SS_WIND_UIGF) | !is.na(SS_SOLAR_UIGF),
                      fcoalesce(SS_WIND_UIGF, 0) + fcoalesce(SS_SOLAR_UIGF, 0), NA_real_)]
PD[is.na(ns_fc), ns_fc := SEMISCHEDULEDCAPACITY]
PD <- PD[!is.na(ns_fc), .(RUN_DATETIME, INTERVAL_DATETIME, ns_fc)]
setkey(PD, INTERVAL_DATETIME, RUN_DATETIME)
cat(sprintf("PDPASA rows with usable non-sync forecast: %d\n", nrow(PD)))

# Slow-rival commitment at tau: INITIALMW from DISPATCHLOAD (cached slim pass)
SC_F <- file.path(OUT, "slow_commit_cache.rds")
if (file.exists(SC_F)) { SC <- readRDS(SC_F) } else {
  SC <- rbindlist(lapply(MONTHS, function(M) {
    dl <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(dl)
    dl <- dl[DUID %chin% SLOW & INTERVENTION == 0, .(SETTLEMENTDATE, DUID, INITIALMW)]
    dl[, SETTLEMENTDATE := force10(SETTLEMENTDATE)]
    unique(dl, by = c("SETTLEMENTDATE", "DUID"))
  }))
  saveRDS(SC, SC_F)
}
SC[, on := INITIALMW > 1]
SCW <- dcast(SC, SETTLEMENTDATE ~ DUID, value.var = "on")
setnames(SCW, make.names(names(SCW)))          # OSB-AG -> OSB.AG
setkey(SCW, SETTLEMENTDATE)
cat(sprintf("slow-commit rows: %d\n", nrow(SCW)))

# ---- per-horizon forecast slack ----
t5_of <- function(t30) t30 - 25 * 60           # first 5-min interval of the half-hour
for (h in HORIZONS) {
  cat(sprintf("\n--- horizon %dh ---\n", h))
  tau <- S$t30 - h * 3600

  # (1) rival availability: versioned MAXAVAIL for the half-hour's six 5-min intervals
  qs <- CJ(t30 = S$t30, off = seq(0, 25, by = 5) * 60)[, t5 := t30 - 1500 + off][]
  qs[, tau := t30 - h * 3600]
  units_by_station <- NULL
  for (dd in unique(RB$DUID)) {
    q <- RB[.(dd, qs$t5, qs$tau), roll = Inf, on = .(DUID, INTERVAL_DATETIME, OFFERDATETIME),
            .(t5 = INTERVAL_DATETIME, MAXAVAIL)]
    q[, t30 := qs$t30]
    q[is.na(MAXAVAIL), MAXAVAIL := 0]          # no version lodged by tau (sample start) -> 0
    q[, u := mw_units(dd, MAXAVAIL)]
    agg <- q[, .(u = min(u)), by = t30]        # conservative: min across the half-hour
    agg[, station := DUID2STATION[[dd]]]
    units_by_station <- rbind(units_by_station, agg)
  }
  CTS <- dcast(units_by_station[, .(u = sum(u)), by = .(t30, station)],
               t30 ~ station, value.var = "u", fill = 0L)

  # (2) slow-start rule: offline at tau and h < SLOW_START_H -> station contributes 0
  if (h < SLOW_START_H) {
    tau5 <- as.POSIXct(ceiling(as.numeric(tau) / 300) * 300, origin = "1970-01-01", tz = "Etc/GMT-10")
    st <- SCW[.(tau5), roll = TRUE, on = "SETTLEMENTDATE"]
    CTS[!is.na(st$PPCCGT) & st$PPCCGT == FALSE, pelican_point_gt := 0L]
    CTS[!is.na(st$OSB.AG) & st$OSB.AG == FALSE, osborne_gt_st := 0L]
  }

  # (3) non-sync forecast at tau for interval t30 (latest run <= tau); fallback realized
  qpd <- data.table(INTERVAL_DATETIME = S$t30, RUN_DATETIME = tau)
  pd <- PD[qpd, roll = Inf, on = .(INTERVAL_DATETIME, RUN_DATETIME), mult = "last"]
  X <- merge(CTS, pd[, .(t30 = INTERVAL_DATETIME, ns_fc)], by = "t30", all.x = TRUE)
  X <- merge(X, S[, .(t30, nonsync_mw)], by = "t30", all.x = TRUE)
  n_fb <- X[is.na(ns_fc), .N]
  if (n_fb) cat(sprintf("  ns_fc fallback to realized on %d rows (%.2f%%)\n", n_fb, 100 * n_fb / nrow(X)))
  X[is.na(ns_fc), ns_fc := nonsync_mw]

  # (4) depth
  for (s in STATIONS) if (!s %in% names(X)) X[[s]] <- 0L
  CM <- as.matrix(X[, ..STATIONS]); NSV <- X$ns_fc
  sl <- integer(nrow(X))
  for (i in seq_len(nrow(X))) sl[i] <- depth_torrens(CM[i, ], NSV[i])
  vs <- sprintf("slack_fc_%dh", h); vn <- sprintf("ns_fc_%dh", h)
  X[, (vs) := sl]; setnames(X, "ns_fc", vn)
  S <- merge(S, X[, c("t30", vs, vn), with = FALSE], by = "t30", all.x = TRUE)
  cat(sprintf("  %s: %.2f%% zero | %.2f%% <=1 | cor with current slack_commit %.3f\n",
              vs, 100 * S[, mean(get(vs) == 0, na.rm = TRUE)],
              100 * S[, mean(get(vs) <= 1, na.rm = TRUE)],
              S[, cor(get(vs), slack_commit, use = "complete.obs")]))
}

# ---- validation vs final-run PREDISPATCH unit availability ----
# The final-run PD availability (last run before t) should agree closely with the bid-implied
# rival unit count at the shortest horizon; report the rival-fleet unit-count agreement.
PL <- rbindlist(lapply(MONTHS, function(M) {
  f <- file.path(CACHE, sprintf("PREDISPATCH_LOAD_%s.rds", M))
  if (file.exists(f)) readRDS(f) else NULL
}), fill = TRUE)
if (nrow(PL)) {
  PL[, DATETIME := force10(DATETIME)]
  PL <- PL[DUID %chin% names(DUID2STATION)]
  PL[, u_pd := mapply(mw_units, DUID, AVAILABILITY)]
  pl30 <- PL[, .(u_pd_rivals = sum(u_pd)), by = .(t30 = DATETIME)]
  V <- merge(S[, .(t30, slack_fc_1h)], pl30, by = "t30")
  cat(sprintf("final-run PD validation rows: %d | written stage1b_pd_finalrun_units.csv\n", nrow(V)))
  fwrite(pl30, file.path(OUT, "stage1b_pd_finalrun_units.csv"))
}

saveRDS(S, file.path(OUT, "stage1_panel.rds"))
cat(sprintf("\nSaved stage1_panel.rds: %d half-hours x %d cols\n", nrow(S), ncol(S)))
cat("DONE stage1b\n")
