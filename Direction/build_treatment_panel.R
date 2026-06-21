#!/usr/bin/env Rscript
# build_treatment_panel.R
# Convert direction_events.rds into a 5-minute interval treatment panel.
#
# Outputs (Direction/direction_data/parsed/):
#   treatment_panel.rds  -- (duid, interval_datetime, directed, synchronise)
#
# Treatment rules:
#   - directed = 1: DUID had an active direction during that 5-min interval
#   - synchronise = 1: at least one active direction for that (duid, interval) was "Synchronise"
#   - Union per DUID: overlapping event rows are unioned, not summed
#   - INTERVAL_DATETIME = t is "directed" iff effective_time < t <= cancellation_time
#   - Pre-effective cancellations (cancellation <= effective): direction never took effect;
#     these rows remain in the events log but contribute 0 intervals here.

suppressMessages(library(data.table))

IN_FILE  <- "direction_data/parsed/direction_events.rds"
OUT_FILE <- "direction_data/parsed/treatment_panel.rds"

# ---- Load events ----
ev <- readRDS(IN_FILE)
cat(sprintf("Loaded: %d rows, %d unique DUIDs\n",
            nrow(ev), uniqueN(ev$duid, na.rm = TRUE)))

# ---- DUID fixes ----

# 1. Drop fully-null row (parse artefact from new-format file)
n_null <- sum(is.na(ev$duid))
if (n_null > 0) {
  cat(sprintf("Dropping %d all-NA row(s)\n", n_null))
  ev <- ev[!is.na(duid)]
}

# 2. Reconcile concatenation artefacts confirmed by cross-checking event windows:
#    TORRB35 = TORRB3 rows from Sep 2024 (non-overlapping with clean TORRB3 rows)
#    TORRB46 = TORRB4 rows from Sep 2024 (non-overlapping with clean TORRB4 rows)
#    MINTARO1 = MINTARO from Apr 2023 event (no clean MINTARO rows for same event)
duid_map <- c(TORRB35 = "TORRB3", TORRB46 = "TORRB4", MINTARO1 = "MINTARO")
for (bad in names(duid_map)) {
  n <- sum(ev$duid == bad, na.rm = TRUE)
  if (n > 0) {
    cat(sprintf("DUID recode: %-10s -> %s  (%d row(s))\n", bad, duid_map[bad], n))
    ev[duid == bad, duid := duid_map[[bad]]]
  }
}

# 3. Report non-SA1 generators (legitimate DUIDs directed in multi-region events;
#    they won't appear in the SA bid panel so they naturally drop out on merge)
non_sa <- ev[region != "SA1", unique(.SD), .SDcols = c("duid", "region", "participant")]
if (nrow(non_sa)) {
  cat("\nNon-SA1 DUIDs (not filtered — they won't match SA bid panel):\n")
  print(non_sa[order(region, duid)])
}

cat(sprintf("\nAfter DUID fixes: %d rows, %d unique DUIDs\n",
            nrow(ev), uniqueN(ev$duid)))

# ---- Classify negative-duration rows ----
ev[, dur_hrs := as.numeric(difftime(cancellation_time, effective_time, units = "hours"))]
n_pre_cancel <- sum(ev$dur_hrs <= 0L, na.rm = TRUE)
cat(sprintf(
  "Pre-effective cancellations (direction cancelled before generator came online): %d rows\n",
  n_pre_cancel
))
if (n_pre_cancel > 0) {
  cat("  These stay in direction_events.rds but contribute 0 directed intervals.\n")
  cat("  DUID breakdown:\n")
  print(ev[dur_hrs <= 0, .N, by = duid][order(-N)])
}

# ---- Expand to 5-minute intervals ----
# INTERVAL_DATETIME convention: t = end of interval, covers (t-300, t].
# A direction with effective_time E is active in interval t iff E < t.
# It ends when cancellation_time C is reached: last directed t = floor(C/300)*300.
# So directed intervals: seq( floor(E/300)*300 + 300, floor(C/300)*300, by=300 ).

ev_valid <- ev[dur_hrs > 0]
cat(sprintf("\nExpanding %d effective direction rows to 5-min intervals...\n", nrow(ev_valid)))

ev_valid[, first_intv := (floor(as.numeric(effective_time)   / 300) + 1) * 300]
ev_valid[, last_intv  :=  floor(as.numeric(cancellation_time) / 300)     * 300]

# A direction can be shorter than one interval (last < first): contribute 0 intervals.
n_sub_interval <- sum(ev_valid$last_intv < ev_valid$first_intv)
if (n_sub_interval > 0)
  cat(sprintf("  Sub-interval rows skipped (duration < 5 min): %d\n", n_sub_interval))

ev_expand <- ev_valid[last_intv >= first_intv]

rows_list <- lapply(seq_len(nrow(ev_expand)), function(i) {
  data.table(
    duid          = ev_expand$duid[i],
    interval_secs = seq.int(ev_expand$first_intv[i], ev_expand$last_intv[i], by = 300L),
    is_sync       = ev_expand$direction_instruction[i] == "Synchronise"
  )
})

expanded <- rbindlist(rows_list, use.names = TRUE)
cat(sprintf("  %d (duid × interval) rows before union\n", nrow(expanded)))

# ---- Union per DUID (take max to combine overlapping events) ----
panel <- expanded[, .(
  directed    = 1L,
  synchronise = as.integer(any(is_sync))
), keyby = .(duid, interval_secs)]

panel[, interval_datetime := as.POSIXct(interval_secs, origin = "1970-01-01",
                                         tz = "Etc/GMT-10")]
panel[, interval_secs := NULL]
setkey(panel, duid, interval_datetime)

# ---- Summary ----
cat(sprintf("\nTreatment panel: %d rows, %d DUIDs\n", nrow(panel), uniqueN(panel$duid)))
cat(sprintf("Period: %s  to  %s\n",
            format(min(panel$interval_datetime)),
            format(max(panel$interval_datetime))))
cat(sprintf("Directed intervals:    %d\n", sum(panel$directed)))
cat(sprintf("Synchronise intervals: %d\n", sum(panel$synchronise)))

cat("\nPer-DUID summary:\n")
summary_tbl <- panel[, .(
  n_directed_intervals = .N,
  n_sync_intervals     = sum(synchronise),
  first_directed       = min(interval_datetime),
  last_directed        = max(interval_datetime)
), by = duid][order(duid)]
print(summary_tbl)

# ---- Save ----
saveRDS(panel, OUT_FILE)
cat(sprintf("\nSaved: %s\n", OUT_FILE))
