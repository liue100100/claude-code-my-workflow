#!/usr/bin/env Rscript
# pivotality.R
# Interval-level system-strength pivotality for SA synchronous units, from
# AEMO's minimum-generator-combinations standard + DISPATCHLOAD online status.
#
# Pivotal_t(s) = 1 iff removing station s makes every APPLICABLE acceptable
# combination infeasible -> AEMO must keep/direct s on. Two faces:
#   incumbency  (online s that cannot be released without breaching the standard)
#   completion  (offline-but-available s that must be directed on when short)
#
# Runs on whatever bid_cache/DISPATCHLOAD_<M>.rds files exist (extraction may be
# in flight); re-run when all 36 months are present. Writes per-month caches and
# a combined panel.
#
# ASSUMPTIONS (documented in pivotality_readout.md):
#  - synchronised = TOTALCLEARED > 0
#  - multi-DUID stations counted exactly (TORRB 4, DRYCGT 3); single-DUID
#    multi-unit stations (PPCCGT GTs, OSB, BIPS engines, SNAPPER) approximated by MW
#  - non-sync penetration = sum TOTALCLEARED over SA semi-scheduled units;
#    a combination at threshold T applies when non-sync <= T (higher non-sync ->
#    fewer, stricter combinations remain)
#  - 4 synchronous condensers available throughout (true post-2021); syn_cons met
#  - regime = system_normal (risk_island handled as robustness, not headline)

suppressMessages({ library(data.table) })
setwd("C:/Users/ericl/Documents/my-project/Direction")

CACHE <- "bid_cache"
OUT   <- "outputs/descriptives_v3"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# 1. Combinations standard
# ---------------------------------------------------------------------------
combos <- fread("sa_minimum_generator_combinations.csv")
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x) { x[is.na(x)] <- 0L; as.integer(x) }), .SDcols = STATIONS]
combos_sn <- combos[regime == "system_normal"]
REQ <- as.matrix(combos_sn[, ..STATIONS])          # rows = combinations, cols = stations
THRESH <- combos_sn$non_sync_mw                     # validity threshold per combination

# station -> DUIDs (multi-DUID) ; single-DUID multi-unit handled by MW
STATION_DUIDS <- list(
  torrens_island_b = c("TORRB1","TORRB2","TORRB3","TORRB4"),
  dry_creek        = c("DRYCGT1","DRYCGT2","DRYCGT3"),
  pelican_point_gt = "PPCCGT", osborne_gt_st = "OSB-AG",
  quarantine_5     = "QPS5",   mintaro       = "MINTARO",
  bips             = "BARKIPS1", snapper_point = "SNAPPER1")
SYNC_DUIDS <- unlist(STATION_DUIDS, use.names = FALSE)

# MW->unit-count for single-DUID multi-unit stations (approx; see assumptions)
mw_units <- function(duid, mw) {
  # returns integer count of "units/engines" represented by this DUID's MW
  switch(duid,
    PPCCGT   = fifelse(mw > 250, 2L, fifelse(mw > 0, 1L, 0L)),   # 2 GTs
    `OSB-AG` = fifelse(mw > 120, 2L, fifelse(mw > 0, 1L, 0L)),   # GT+ST
    BARKIPS1 = pmin(as.integer(round(mw / 16.1)), 12L),          # ~12 Wartsila engines
    SNAPPER1 = pmin(as.integer(round(mw / 20.0)),  5L),          # island combos only
    fifelse(mw > 0, 1L, 0L))
}

# ---------------------------------------------------------------------------
# 2. Feasibility test: does ANY applicable combination fit a station-count vector?
# ---------------------------------------------------------------------------
# counts: named integer vector over STATIONS; nonsync: scalar MW
# Applicable combos = THRESH >= nonsync (validity up to threshold). If none
# (nonsync above max threshold) -> use the strictest tier (max THRESH).
feasible_any <- function(counts, nonsync) {
  appl <- THRESH >= nonsync
  if (!any(appl)) appl <- THRESH == max(THRESH)
  R <- REQ[appl, , drop = FALSE]
  # combination c feasible iff counts >= R[c,] for every station
  ok <- rowSums(sweep(R, 2, counts, FUN = function(req, have) req > have)) == 0
  any(ok)
}

# count of APPLICABLE combinations that a station-count vector still satisfies
# (same applicability rule as feasible_any). Used for the decomposition cut
# "how many combinations survive removal of unit i".
feasible_count <- function(counts, nonsync) {
  appl <- THRESH >= nonsync
  if (!any(appl)) appl <- THRESH == max(THRESH)
  R <- REQ[appl, , drop = FALSE]
  sum(rowSums(sweep(R, 2, counts, FUN = function(req, have) req > have)) == 0)
}

# ---------------------------------------------------------------------------
# DEPTH OF PIVOTALITY (k_i): minimum number of rival units to remove from the
# count vector `cnt` before it satisfies NO applicable combination.
#   k_i = 0  <=>  cnt already infeasible  <=>  unit i (already excluded from cnt)
#               is essential  =>  reproduces the binary pivotal flag.
#   k_i = Inf (censored upstream to n_rivals+1) when an applicable combination has
#               all-zero requirements -> the fleet can never be made infeasible.
# Method: monotone size-ordered search, implemented exactly and efficiently as a
# recursion that, to break feasibility, reduces some station below the requirement
# of the first still-satisfied combination, then recurses (memoized). Reducing a
# station to req-1 is the minimal removal to block that combination via that
# station; recursion captures deeper reductions needed for other combinations.
DEPTH_MEMO <- new.env(parent = emptyenv())

min_removals <- function(cnt, R_appl, tierkey) {
  key <- paste0(tierkey, "|", paste0(cnt, collapse = ","))
  hit <- DEPTH_MEMO[[key]]
  if (!is.null(hit)) return(hit)
  unmet <- rowSums(sweep(R_appl, 2, cnt, FUN = function(req, have) req > have))
  sat <- which(unmet == 0)                         # combinations still satisfied
  if (length(sat) == 0L) { assign(key, 0L, envir = DEPTH_MEMO); return(0L) }
  req0 <- R_appl[sat[1L], ]
  js <- which(req0 >= 1L & cnt >= req0)            # stations that can block this combination
  best <- Inf
  for (j in js) {
    cnt2 <- cnt; cnt2[j] <- req0[j] - 1L
    cost <- cnt[j] - cnt2[j]
    if (cost >= best) next                         # prune (sub-removals are >= 0)
    sub <- min_removals(cnt2, R_appl, tierkey)
    if (is.finite(sub) && cost + sub < best) best <- cost + sub
  }
  assign(key, best, envir = DEPTH_MEMO)
  best
}

# depth of station j: exclude all of j's units from `counts`, then min_removals over
# the rivals. Censor at (n_rivals + 1) when j never becomes essential.
depth_station <- function(counts, j, R_appl, tierkey) {
  cnt <- counts; cnt[j] <- 0L
  k <- min_removals(cnt, R_appl, tierkey)
  if (!is.finite(k)) sum(cnt) + 1L else k
}

# ---------------------------------------------------------------------------
# 3. Per-month pivotality
# ---------------------------------------------------------------------------
pivotality_month <- function(M) {
  rds_out <- file.path(CACHE, sprintf("pivotality_%s.rds", M))
  if (file.exists(rds_out)) return(readRDS(rds_out))
  dl <- as.data.table(readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))))
  dl <- dl[INTERVENTION == 0]                      # base run (only run present in sample)
  # De-duplicate (SETTLEMENTDATE, DUID): some early months (e.g. 202201) carry 4x
  # duplicate rows that inflate online/available unit counts (TIB count up to 12 vs
  # physical max 4). Harmless for the binary feasibility flag (thresholds <= 4) but
  # fatal for the depth measure, which counts actual unit removals. Keep the row with
  # the largest TOTALCLEARED per key.
  setorder(dl, SETTLEMENTDATE, DUID, -TOTALCLEARED)
  dl <- unique(dl, by = c("SETTLEMENTDATE", "DUID"))

  # non-sync penetration: SA semi-scheduled units (wind/solar)
  if ("UIGF" %in% names(dl) && dl[, any(!is.na(UIGF))]) {
    nonsync_duids <- dl[ , .(f = any(UIGF > 0, na.rm = TRUE)), DUID][f == TRUE, DUID]
  } else {
    nonsync_duids <- dl[ , .(f = any(SEMIDISPATCHCAP > 0, na.rm = TRUE)), DUID][f == TRUE, DUID]
  }
  nonsync_duids <- setdiff(nonsync_duids, SYNC_DUIDS)
  ns <- dl[DUID %in% nonsync_duids, .(nonsync_mw = sum(pmax(TOTALCLEARED, 0), na.rm = TRUE)),
           by = SETTLEMENTDATE]

  # synchronous-fleet online & available counts per station per interval
  syn <- dl[DUID %in% SYNC_DUIDS]
  # map each DUID to its station
  d2s <- rbindlist(lapply(names(STATION_DUIDS),
                          function(s) data.table(DUID = STATION_DUIDS[[s]], station = s)))
  syn <- merge(syn, d2s, by = "DUID")
  syn[, online_units := fifelse(DUID %in% c("TORRB1","TORRB2","TORRB3","TORRB4",
                                            "DRYCGT1","DRYCGT2","DRYCGT3"),
                               as.integer(TOTALCLEARED > 0),
                               mapply(mw_units, DUID, fifelse(TOTALCLEARED > 0, TOTALCLEARED, 0)))]
  syn[, avail_units  := fifelse(DUID %in% c("TORRB1","TORRB2","TORRB3","TORRB4",
                                            "DRYCGT1","DRYCGT2","DRYCGT3"),
                               as.integer(AVAILABILITY > 0),
                               mapply(mw_units, DUID, fifelse(AVAILABILITY > 0, pmax(AVAILABILITY, TOTALCLEARED), 0)))]
  on  <- syn[, .(online = sum(online_units)), by = .(SETTLEMENTDATE, station)]
  av  <- syn[, .(avail  = sum(avail_units)),  by = .(SETTLEMENTDATE, station)]

  # N-1: per-unit MW of each online synchronous unit (TOTALCLEARED spread over its
  # online unit count); the credible contingency is loss of the single largest such
  # unit -> identify which station it belongs to, per interval.
  syn[, per_unit_mw := fifelse(online_units > 0, TOTALCLEARED / online_units, 0)]
  largest <- syn[online_units > 0,
                 .(Lstation = station[which.max(per_unit_mw)]), by = SETTLEMENTDATE]

  on_w <- dcast(on, SETTLEMENTDATE ~ station, value.var = "online", fill = 0)
  av_w <- dcast(av, SETTLEMENTDATE ~ station, value.var = "avail",  fill = 0)
  for (s in STATIONS) { if (!s %in% names(on_w)) on_w[[s]] <- 0L
                        if (!s %in% names(av_w)) av_w[[s]] <- 0L }
  setkey(on_w, SETTLEMENTDATE); setkey(av_w, SETTLEMENTDATE); setkey(ns, SETTLEMENTDATE)
  W <- ns[on_w][av_w]
  W[is.na(nonsync_mw), nonsync_mw := 0]
  W[largest, Lstation := i.Lstation, on = "SETTLEMENTDATE"]   # largest online unit's station

  ON <- as.matrix(W[, ..STATIONS]); colnames(ON) <- STATIONS
  AVc <- paste0("i.", STATIONS)
  AV <- as.matrix(W[, ..AVc]);      colnames(AV) <- STATIONS
  NS <- W$nonsync_mw
  LIDX <- match(W$Lstation, STATIONS)                          # NA where no online unit

  nI <- nrow(W)
  short    <- logical(nI)
  short_n1 <- logical(nI)                                      # not N-1 secure
  piv    <- matrix(FALSE, nI, length(STATIONS), dimnames = list(NULL, STATIONS))  # realised
  pex    <- matrix(FALSE, nI, length(STATIONS), dimnames = list(NULL, STATIONS))  # ex-ante
  piv_n1 <- matrix(FALSE, nI, length(STATIONS), dimnames = list(NULL, STATIONS))  # post-N-1
  depth_ex <- matrix(NA_integer_, nI, length(STATIONS), dimnames = list(NULL, STATIONS))  # depth, available rivals
  depth_rl <- matrix(NA_integer_, nI, length(STATIONS), dimnames = list(NULL, STATIONS))  # depth, online rivals
  for (t in seq_len(nI)) {
    on_t <- ON[t, ]; av_t <- AV[t, ]; ns_t <- NS[t]
    feas_on <- feasible_any(on_t, ns_t)
    short[t] <- !feas_on
    # --- N-1 post-contingency online vector: remove the single largest online unit ---
    on_pc <- on_t
    li <- LIDX[t]
    if (!is.na(li) && on_pc[li] > 0) on_pc[li] <- on_pc[li] - 1L
    short_n1[t] <- !feasible_any(on_pc, ns_t)
    # applicable combinations at this non-sync tier (mirror feasible_any) for the depth search
    appl_t <- THRESH >= ns_t; if (!any(appl_t)) appl_t <- THRESH == max(THRESH)
    R_appl <- REQ[appl_t, , drop = FALSE]
    tkey   <- paste0(which(appl_t), collapse = ",")
    for (j in seq_along(STATIONS)) {
      # --- REALISED pivotality (uses s's own online status) ---
      if (feas_on) {
        # incumbency: drop one unit of s from ONLINE -> still feasible?
        if (on_t[j] > 0) {
          on_drop <- on_t; on_drop[j] <- on_t[j] - 1L
          piv[t, j] <- !feasible_any(on_drop, ns_t)
        }
      } else {
        # short: completion pivotality on the AVAILABLE menu
        av_drop <- av_t; av_drop[j] <- 0L
        piv[t, j] <- !feasible_any(av_drop, ns_t)
      }
      # --- N-1 pivotality: drop one unit of s from the POST-CONTINGENCY vector;
      #     s is N-1-pivotal iff the system then cannot satisfy any combination.
      #     Stricter security envelope than base -> a superset of base piv. ---
      on_pc_j <- on_pc; on_pc_j[j] <- max(on_pc_j[j] - 1L, 0L)
      piv_n1[t, j] <- !feasible_any(on_pc_j, ns_t)
      # --- EX-ANTE pivotality (rivals' availability only; independent of s's
      #     own online/offer choice). s essential iff the system cannot be
      #     secured from the available fleet WITHOUT s. Exogenous to s's own
      #     withholding -> the clean treatment for the bidding test.
      av_rivals <- av_t; av_rivals[j] <- 0L
      pex[t, j] <- !feasible_any(av_rivals, ns_t)
      # --- DEPTH of pivotality: min rival removals before j becomes essential ---
      depth_ex[t, j] <- depth_station(av_t, j, R_appl, tkey)   # primary: available rivals
      depth_rl[t, j] <- depth_station(on_t, j, R_appl, tkey)   # online rivals
    }
  }

  res <- data.table(SETTLEMENTDATE = W$SETTLEMENTDATE, nonsync_mw = NS,
                    short = short, short_n1 = short_n1)
  for (s in STATIONS) res[[paste0("piv_",     s)]] <- piv[, s]
  for (s in STATIONS) res[[paste0("pex_",     s)]] <- pex[, s]
  for (s in STATIONS) res[[paste0("piv_n1_",  s)]] <- piv_n1[, s]
  for (s in STATIONS) res[[paste0("depth_ex_", s)]] <- depth_ex[, s]   # k_i, available rivals (primary)
  for (s in STATIONS) res[[paste0("depth_rl_", s)]] <- depth_rl[, s]   # k_i, online rivals
  for (s in STATIONS) res[[paste0("on_",      s)]] <- ON[, s]   # online count (for combo-survival cut)
  # REGRESSION TEST: depth_exante == 0  <=>  binary ex-ante pivotal (pex), exactly.
  if (!identical(as.vector(depth_ex == 0L), as.vector(pex)))
    stop(sprintf("[%s] DEPTH REGRESSION FAILED: depth_ex==0 != pex", M))
  res[, yyyymm := M]
  saveRDS(res, rds_out)
  message(sprintf("[%s] pivotality: %d int, short=%.1f%% short_n1=%.1f%% | base-piv=%.1f%% N-1=%.1f%% | depth_ex==0==pex OK",
                  M, nI, 100*mean(short), 100*mean(short_n1),
                  100*mean(rowSums(piv) > 0), 100*mean(rowSums(piv_n1) > 0)))
  res
}

# ---------------------------------------------------------------------------
# 4. Run on available months; combine
# ---------------------------------------------------------------------------
# Headline panel = analysis window 202201-202412. 2021 DISPATCHLOAD may be on
# disk (used only by reason_pivotality.R for the [F17] label test) but is
# EXCLUDED here: 2021 pivotality is unreliable (syncons commissioned through
# 2021; the 4-syncon assumption fails). See facts_memo [F17].
have <- sort(sub(".*DISPATCHLOAD_([0-9]{6})\\.rds", "\\1",
                 list.files(CACHE, pattern = "DISPATCHLOAD_[0-9]{6}\\.rds$", full.names = TRUE)))
have <- have[have >= "202201"]
message("DISPATCHLOAD months in headline panel: ", length(have), " (", paste(range(have), collapse="-"), ")")
all_piv <- rbindlist(lapply(have, pivotality_month), fill = TRUE)
saveRDS(all_piv, file.path(OUT, "pivotality_panel.rds"))
message("Combined pivotality panel: ", nrow(all_piv), " interval rows -> pivotality_panel.rds")

# station-level base / N-1 / ex-ante pivotal shares (shrinkage visible)
shr <- rbindlist(lapply(STATIONS, function(s) data.table(
  station = s,
  base_pct    = round(100*mean(all_piv[[paste0("piv_",    s)]]), 2),
  n1_pct      = round(100*mean(all_piv[[paste0("piv_n1_", s)]]), 2),
  exante_pct  = round(100*mean(all_piv[[paste0("pex_",    s)]]), 2))))
message("short=", round(100*mean(all_piv$short),2), "%  short_n1=", round(100*mean(all_piv$short_n1),2), "%")
print(shr[order(-base_pct)])

# quick station-level summary (realised vs ex-ante)
piv_cols <- paste0("piv_", STATIONS)
pex_cols <- paste0("pex_", STATIONS)
summ <- all_piv[, lapply(.SD, function(x) round(100*mean(x),1)), .SDcols = c("short", piv_cols, pex_cols)]
print(t(summ))
