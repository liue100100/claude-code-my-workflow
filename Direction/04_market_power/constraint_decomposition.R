#!/usr/bin/env Rscript
# constraint_decomposition.R
# ---------------------------------------------------------------------------
# Decompose SA AEMO directions by which SECURITY constraint binds, per the brief
# `directions_constraint_decomposition_brief.md`.
#
# The pivotality moderator in the triple-difference is built from the fault-level
# combinations file ONLY. Directions driven by inertia / voltage / locational
# reasons are intervals where the d_t direction option is live but the fault-level
# pivotal indicator reads zero -> treatment MISCLASSIFICATION (false negatives in
# the "pivotal" leg). This script widens the security-binding indicator to a UNION
# of binding constraints and produces a per-interval decomposition of which one(s)
# bound, so the exact subset of directions the d_t identification applies to is
# delimited.
#
# FLAGS (one row per directed 5-min interval x DUID):
#   fl_n0             fault-level SATISFACTORY (N-0): removing the directed unit breaks
#                     the SA minimum synchronous combination NOW (realised piv_*).
#   fl_n1             fault-level SECURE (N-1): the unit is needed so the system still
#                     satisfies a combination after loss of the largest online unit
#                     (piv_n1_*; a superset of fl_n0). AEMO operates to the SECURE
#                     standard, so fl_n1 — not fl_n0 — is the correct fault-level flag.
#   inertia_binding   PROXY: online synchronous inertia (sum H*MVA, incl. 4 syncons)
#                     minus the directed unit's contribution falls below the
#                     period-appropriate SA islanded-secure inertia threshold.
#                     >>> constants + thresholds are PLACEHOLDERS in lookups/ <<<
#   voltage_lowdemand PROXY: low-demand / high-renewable voltage condition, flagged
#                     by high SA non-sync penetration (nonsync_mw >= threshold).
#                     The AEMO directions 'reason' field is NOT used — it is a
#                     report-template label, constant within each report, that steps
#                     strength->security->voltage purely by report vintage and is
#                     perfectly time-confounded (see lookups/voltage_lowdemand_proxy.csv).
#   network_outage    STUB = NA: no transmission-outage records are extracted in this
#                     repo. Excluded from the union; residual-coverage reported.
#
#   security_binding_union = fl_n1 | inertia_binding | voltage_lowdemand
#   residual               = directed AND none of the (available) flags -> manual
#                            inspection (likely locational / outage / pre-dispatch buffer).
#
# MECHANISM (mutually exclusive, why a direction fires above the bare minimum):
#   n0_satisfactory       removing the unit breaks the present-state minimum.
#   n1_collective_restore system not N-1 secure -> directed to restore secure operation.
#   n1_unit_incumbency    N-1 secure, but the unit is pivotal under the credible contingency.
#   voltage_lowdemand     low-demand voltage proxy (only one binding).
#   inertia               inertia proxy (only one binding).
#   residual              above every observable strength standard (locational/outage/buffer).
#
# Proxies are labelled as such and all constants/thresholds live in editable
# lookups/ CSVs (placeholder=TRUE) — DO NOT trust inertia/voltage prevalences until
# the lookups are filled from source AEMO documents.
# ---------------------------------------------------------------------------

suppressMessages({ library(data.table) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT  <- "outputs/descriptives_v3"
LK   <- "04_market_power/lookups"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")

# ===========================================================================
# 0. Editable lookups (placeholders flagged)
# ===========================================================================
inertia_const <- fread(file.path(LK, "sa_inertia_unit_constants.csv"))
inertia_thr   <- fread(file.path(LK, "sa_inertia_thresholds.csv"))
vparm         <- fread(file.path(LK, "voltage_lowdemand_proxy.csv"))
getp <- function(p) vparm[param == p, value][1]
NONSYNC_THRESH <- as.numeric(getp("nonsync_mw_threshold"))
SPLIT_DATE     <- as.POSIXct(getp("dt_drop_split_date"), tz = "Etc/GMT-10")

# per-station inertia contribution of ONE online unit (MW*s) = MVA * H
gen_const <- inertia_const[station %in% STATIONS]
setkey(gen_const, station)
unit_mws  <- setNames(gen_const$mva_per_unit * gen_const$h_seconds, gen_const$station)
unit_mws  <- unit_mws[STATIONS]                       # order-aligned
# fixed always-on inertia (synchronous condensers)
fixed_mws <- inertia_const[always_on_units > 0,
                           sum(always_on_units * mva_per_unit * h_seconds)]

threshold_for <- function(dt) {                       # date-keyed SA inertia threshold
  d <- as.Date(dt)
  i <- which(d >= as.Date(inertia_thr$date_from) & d <= as.Date(inertia_thr$date_to))
  if (length(i)) inertia_thr$threshold_mws[i[1]] else NA_real_
}

cat("================ LOOKUPS (all placeholder=TRUE; fill from AEMO source) ================\n")
cat(sprintf("Syncon fixed inertia (always-on): %.0f MW*s\n", fixed_mws))
cat("Per-unit generator inertia contribution (MW*s = MVA*H):\n"); print(round(unit_mws))
cat(sprintf("Non-sync low-demand voltage threshold: %.0f MW\n", NONSYNC_THRESH))
cat("Inertia thresholds by period:\n"); print(inertia_thr[, .(date_from, date_to, threshold_mws)])

# ===========================================================================
# 1. Pivotality panel (fault-level flag + online fleet vector + nonsync)
# ===========================================================================
piv <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
on_cols <- paste0("on_", STATIONS)
stopifnot(all(on_cols %in% names(piv)))
cat(sprintf("\nPivotality panel: %d intervals, %s..%s\n",
            nrow(piv), min(piv$SETTLEMENTDATE), max(piv$SETTLEMENTDATE)))
cat("nonsync_mw distribution (for voltage threshold calibration):\n")
print(round(quantile(piv$nonsync_mw, c(.5,.75,.9,.95,.99))))

# online synchronous inertia per interval (syncons + sum over stations of count*unit_mws)
onmat <- as.matrix(piv[, ..on_cols]); colnames(onmat) <- STATIONS
piv[, online_inertia_mws := fixed_mws + as.numeric(onmat %*% unit_mws)]

# long: one row per (interval, station) carrying that station's fault-level pivotal
# flags (N-0 satisfactory + N-1 secure), online count, and per-interval scalars.
pl <- rbindlist(lapply(STATIONS, function(s) data.table(
  SETTLEMENTDATE     = piv$SETTLEMENTDATE,
  station            = s,
  nonsync_mw         = piv$nonsync_mw,
  short              = as.integer(piv$short),
  short_n1           = as.integer(piv$short_n1),
  online_inertia_mws = piv$online_inertia_mws,
  on_self            = piv[[paste0("on_", s)]],
  fl_n0              = as.integer(piv[[paste0("piv_",    s)]]),
  fl_n1              = as.integer(piv[[paste0("piv_n1_", s)]]))))

# ===========================================================================
# 2. Directed interval x DUID panel  (expand events to 5-min)
# ===========================================================================
STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips", SNAPPER1="snapper_point")
ev <- as.data.table(readRDS("direction_data/parsed/direction_events.rds"))
ev <- ev[!is.na(duid)]
dmap <- c(TORRB35="TORRB3", TORRB46="TORRB4", MINTARO1="MINTARO")   # combined-DUID labels
for (b in names(dmap)) ev[duid == b, duid := dmap[[b]]]
ev[, station := STAT[as.character(duid)]]
ev <- ev[!is.na(station)]                                          # SA combos stations only
ev[, is_sync := as.integer(direction_instruction == "Synchronise")]
# 5-min interval bounds (AEMO market time, UTC+10)
ev[, first_intv := (floor(as.numeric(effective_time)/300)+1)*300]
ev[, last_intv  :=  floor(as.numeric(cancellation_time)/300)*300]
ev <- ev[is.finite(first_intv) & is.finite(last_intv) & last_intv >= first_intv]

expand_events <- function(E) {
  rbindlist(lapply(seq_len(nrow(E)), function(i)
    data.table(duid = E$duid[i], station = E$station[i], is_sync = E$is_sync[i],
               secs = seq.int(E$first_intv[i], E$last_intv[i], by = 300L))))
}

# ===========================================================================
# 3. Core builder: directed interval-DUID panel with all flags
# ===========================================================================
build_decomp <- function(E) {
  exp <- expand_events(E)
  exp[, SETTLEMENTDATE := as.POSIXct(secs, origin = "1970-01-01", tz = "Etc/GMT-10")]
  # union per (interval, duid): Synchronise if ANY directing event is Synchronise
  d <- exp[, .(is_sync = as.integer(any(is_sync == 1L))), by = .(SETTLEMENTDATE, station, duid)]
  # join fault-level flag + interval scalars (station-level)
  d <- merge(d, pl, by = c("SETTLEMENTDATE", "station"))

  # --- inertia flag (PROXY) ---
  d[, unit_mws_self := unit_mws[station]]
  d[, thr := vapply(SETTLEMENTDATE, threshold_for, numeric(1))]
  d[, inertia_post_drop := online_inertia_mws - unit_mws_self]
  d[, inertia_binding := as.integer(inertia_post_drop < thr)]

  # --- voltage flag (PROXY: low-demand via high non-sync) ---
  d[, voltage_lowdemand := as.integer(nonsync_mw >= NONSYNC_THRESH)]

  # --- outage flag (STUB: no data) ---
  d[, network_outage := NA_integer_]

  # --- union + residual (fault-level flag is the SECURE standard, fl_n1) ---
  d[, security_binding_union := as.integer(fl_n1 == 1L | inertia_binding == 1L |
                                           voltage_lowdemand == 1L)]
  d[, residual := as.integer(security_binding_union == 0L)]

  # --- mutually-exclusive mechanism (ordered, strictest standard first) ---
  d[, mechanism := fcase(
    fl_n0 == 1L,                         "n0_satisfactory",
    fl_n1 == 1L & short_n1 == 1L,        "n1_collective_restore",
    fl_n1 == 1L,                         "n1_unit_incumbency",
    voltage_lowdemand == 1L,             "voltage_lowdemand",
    inertia_binding == 1L,               "inertia",
    default =                            "residual")]
  d[]
}

# ===========================================================================
# 4. VALIDATE on one month first (brief: print counts + prevalences, then scale)
# ===========================================================================
ev[, ym := format(as.POSIXct(first_intv, origin="1970-01-01", tz="Etc/GMT-10"), "%Y%m")]
VAL_M <- "202304"
cat(sprintf("\n================ VALIDATION on %s ================\n", VAL_M))
dv <- build_decomp(ev[ym == VAL_M])
cat(sprintf("directed interval-DUID rows: %d  (unique DUIDs: %d)\n", nrow(dv), uniqueN(dv$duid)))
prev <- function(x) round(100*mean(x, na.rm = TRUE), 1)
cat(sprintf("flag prevalences (%%):  fl_n0(satisf)=%.1f  fl_n1(secure)=%.1f  inertia=%.1f  voltage=%.1f  union=%.1f  residual=%.1f\n",
            prev(dv$fl_n0), prev(dv$fl_n1), prev(dv$inertia_binding), prev(dv$voltage_lowdemand),
            prev(dv$security_binding_union), prev(dv$residual)))
cat("mechanism composition:\n"); print(dv[, .N, by = mechanism][order(-N)])

# ===========================================================================
# 5. SCALE to full sample
# ===========================================================================
cat("\n================ FULL SAMPLE ================\n")
d <- build_decomp(ev)
cat(sprintf("directed interval-DUID rows: %d  | intervals %s..%s\n",
            nrow(d), min(d$SETTLEMENTDATE), max(d$SETTLEMENTDATE)))
cat(sprintf("flag prevalences (%%):  fl_n0(satisf)=%.1f  fl_n1(secure)=%.1f  inertia=%.1f  voltage=%.1f  union=%.1f  residual=%.1f\n",
            prev(d$fl_n0), prev(d$fl_n1), prev(d$inertia_binding), prev(d$voltage_lowdemand),
            prev(d$security_binding_union), prev(d$residual)))

# tidy panel out
keep <- c("SETTLEMENTDATE","duid","station","is_sync","nonsync_mw","short","short_n1",
          "online_inertia_mws","thr","fl_n0","fl_n1","inertia_binding","voltage_lowdemand",
          "network_outage","security_binding_union","residual","mechanism")
panel <- d[, ..keep]
saveRDS(panel, file.path(OUT, "constraint_decomposition_panel.rds"))

# ===========================================================================
# 6. SUMMARY: TORRB directions share by binding reason, overall + pre/post d_t drop
# ===========================================================================
d[, period := fifelse(SETTLEMENTDATE < SPLIT_DATE, "pre_dt_drop", "post_dt_drop")]
torrb <- d[station == "torrens_island_b"]

summ_block <- function(DT, grp) {
  n <- nrow(DT)
  data.table(
    group              = grp,
    n_interval_duid    = n,
    approx_unit_hours   = round(n * 5/60, 0),
    pct_n0_satisf      = round(100*mean(DT$fl_n0), 1),
    pct_n1_secure      = round(100*mean(DT$fl_n1), 1),
    pct_inertia        = round(100*mean(DT$inertia_binding), 1),
    pct_voltage_lowdem = round(100*mean(DT$voltage_lowdemand), 1),
    pct_union          = round(100*mean(DT$security_binding_union), 1),
    pct_residual       = round(100*mean(DT$residual), 1))
}
torrb_summary <- rbindlist(list(
  summ_block(torrb, "TORRB_overall"),
  summ_block(torrb[period == "pre_dt_drop"],  "TORRB_pre_dt_drop"),
  summ_block(torrb[period == "post_dt_drop"], "TORRB_post_dt_drop")))
cat("\n---- TORRB directions: N-0 (satisfactory) vs N-1 (secure) vs union (shares overlap) ----\n")
print(torrb_summary)
fwrite(torrb_summary, file.path(OUT, "constraint_decomposition_torrb_summary.csv"))

# mutually-exclusive MECHANISM composition (the answer to "why directed if not N-0 pivotal?")
mech_comp <- function(DT, grp) {
  m <- DT[, .(n_interval_duid = .N, approx_unit_hours = round(.N*5/60,0),
              pct_remain = round(100*mean(is_sync == 0L), 1)), by = mechanism]
  m[, pct := round(100*n_interval_duid/sum(n_interval_duid), 1)]
  m[, group := grp]
  setcolorder(m, c("group","mechanism","n_interval_duid","pct","approx_unit_hours","pct_remain"))
  m[order(-n_interval_duid)]
}
mech_all   <- mech_comp(d, "ALL_stations")
mech_torrb <- mech_comp(torrb, "TORRB")
cat("\n---- MECHANISM composition (mutually exclusive) — ALL directed stations ----\n"); print(mech_all)
cat("\n---- MECHANISM composition (mutually exclusive) — TORRB ----\n"); print(mech_torrb)
fwrite(rbindlist(list(mech_all, mech_torrb)),
       file.path(OUT, "constraint_decomposition_mechanism.csv"))

# residual coverage: how much could the (missing) outage flag still explain?
res <- d[residual == 1L]
cat(sprintf("\nRESIDUAL (directed, no available flag binds): %d interval-DUIDs (%.1f%%), ~%.0f unit-hours\n",
            nrow(res), 100*nrow(res)/nrow(d), nrow(res)*5/60))
cat("  -> network_outage is STUBBED (no data); this residual is the upper bound on what a\n")
cat("     transmission-outage / locational flag could still attribute. By station:\n")
print(res[, .(residual_interval_duids = .N), by = station][order(-residual_interval_duids)])

cat("\nDONE ->\n  constraint_decomposition_panel.rds\n  constraint_decomposition_torrb_summary.csv\n  constraint_decomposition_mechanism.csv\n")
cat("\n*** PROXY CAVEAT: inertia & voltage flags use PLACEHOLDER lookups (04_market_power/lookups/).\n")
cat("    Fill mva/H constants + per-year SA islanded-secure inertia thresholds from AEMO source,\n")
cat("    and calibrate the non-sync voltage threshold, before citing any prevalence. ***\n")
