#!/usr/bin/env Rscript
# test3c_gate_corrected.R -- corrects the 3c inventory bug in test3_battery.R (hard-coded flag
# list missed pex_{quarantine_5,dry_creek,mintaro,bips,snapper_point}). Gate diagnostics only,
# per the Test-3 registration's committed criteria; no estimation, no new flag construction.
suppressMessages(library(data.table))
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/06_round2")

piv <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(piv)
flag_cols <- grep("^pex_", names(piv), value = TRUE)
n_iv <- nrow(piv)
cat("Pivotality panel rows (intervals):", n_iv, "\n")
rates <- piv[, lapply(.SD, function(x) round(100 * mean(x, na.rm = TRUE), 3)), .SDcols = flag_cols]
cat("\nEssential (pex) interval rates by station flag (%):\n"); print(rates)
ess_rows <- piv[, lapply(.SD, function(x) sum(x, na.rm = TRUE)), .SDcols = flag_cols]
cat("\nEssential interval counts (36 months, station grain):\n"); print(ess_rows)

# Criterion 4: direction exposure by station -- corrected event record
ev <- readRDS(file.path(ROOT, "Direction/direction_data/parsed/direction_events.rds")); setDT(ev)
duid_col <- intersect(c("DUID", "duid"), names(ev))[1]
cat("\nDirection events by DUID (all 1,638 events; corrected clock):\n")
print(ev[, .N, by = duid_col][order(-N)])

# Station -> candidate DUIDs (SA synchronous units in the cache)
map <- list(quarantine_5 = c("QPS1","QPS2","QPS3","QPS4","QPS5"),
            dry_creek    = c("DRYCGT1","DRYCGT2","DRYCGT3"),
            mintaro      = "MINTARO",
            bips         = "BARKIPS1",
            snapper_point = "SNAPPER1")
gate <- rbindlist(lapply(names(map), function(st) {
  fl <- paste0("pex_", st)
  data.table(station = st, duids = paste(map[[st]], collapse = "+"),
             ess_intervals = if (fl %in% flag_cols) sum(piv[[fl]], na.rm = TRUE) else NA_integer_,
             n_directions = ev[get(duid_col) %in% map[[st]], .N])
}))
gate[, crit3_500rows := ess_intervals >= 500]   # interval grain, station flag (unit-rows >= this)
gate[, note := ""]
cat("\n=== Corrected 3c gate table ===\n"); print(gate)
fwrite(gate, file.path(OUT, "test3c_gate_corrected.csv"))
