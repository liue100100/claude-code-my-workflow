#!/usr/bin/env Rscript
# stage0_gate.R -- Stage 0 data gate for the direction-propensity registration
# (08_propensity/registration.md). Gate item (c): independent direction onsets net of
# extension chaining, sensitivity N in {4, 8, 24} hours. Also documents (a) PREDISPATCH
# coverage from the cache manifest. Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

# ---------------------------------------------------------------------------
# (a) PREDISPATCH coverage: enumerate cache tables
# ---------------------------------------------------------------------------
cache_files <- list.files(file.path(ROOT, "Direction/bid_cache"))
tabs <- unique(sub("_\\d{6}\\.rds$", "", grep("\\.rds$", cache_files, value = TRUE)))
cat("Cache tables present:", paste(sort(tabs), collapse = ", "), "\n")
pd_months <- grep("^PREDISPATCH", cache_files, value = TRUE)
cat(sprintf("(a) PREDISPATCH files in cache: %d  -> coverage 0 months (gate threshold: >= 24)\n",
            length(pd_months)))

# ---------------------------------------------------------------------------
# (c) Independent direction onsets, 2022-2024, market level (any SA unit)
# ---------------------------------------------------------------------------
ev <- readRDS(file.path(ROOT, "Direction/direction_data/parsed/direction_events.rds")); setDT(ev)

# Build direction windows. Old format: event grain; new format: per-DUID -> pool to market level.
w_old <- ev[source_format == "old" & !is.na(effective_time) & !is.na(cancellation_time),
            .(s = force10(effective_time), e = force10(cancellation_time), fmt = "old")]
w_new <- ev[source_format == "new" & !is.na(effective_time) & !is.na(cancellation_time),
            .(s = force10(effective_time), e = force10(cancellation_time), fmt = "new")]
W <- rbind(w_old, w_new)
W <- W[!is.na(s) & !is.na(e) & e > s]
W <- W[s >= as.POSIXct("2022-01-01", tz = "Etc/GMT-10") &
         s <  as.POSIXct("2025-01-01", tz = "Etc/GMT-10")]
setorder(W, s)
cat(sprintf("\n(c) direction windows 2022-2024 (raw rows, market level): %d (old %d / new %d)\n",
            nrow(W), W[fmt == "old", .N], W[fmt == "new", .N]))

# Merge overlapping/abutting windows into continuous directed spells
W[, grp := cumsum(s > shift(cummax(as.numeric(e)), fill = -Inf))]
SP <- W[, .(s = min(s), e = max(e)), by = grp][order(s)]
cat(sprintf("merged directed spells: %d | total directed time: %.0f h | median spell %.1f h | max %.1f h\n",
            nrow(SP), SP[, sum(as.numeric(e - s, units = "hours"))],
            SP[, median(as.numeric(e - s, units = "hours"))],
            SP[, max(as.numeric(e - s, units = "hours"))]))

# Independent onsets: spell start with no spell active or ended within the prior N hours
res <- list()
for (N in c(4, 8, 24)) {
  SP[, gap_h := as.numeric(s - shift(e), units = "hours")]
  onsets <- SP[is.na(gap_h) | gap_h > N]
  by_yr <- onsets[, .N, by = year(s)][order(year)]
  cat(sprintf("  N=%2dh: independent onsets = %3d   (%s)\n", N, nrow(onsets),
              paste(sprintf("%d: %d", by_yr$year, by_yr$N), collapse = ", ")))
  res[[as.character(N)]] <- data.table(N_hours = N, onsets = nrow(onsets),
                                       y2022 = by_yr[year == 2022, N], y2023 = by_yr[year == 2023, N],
                                       y2024 = if (nrow(by_yr[year == 2024]) > 0) by_yr[year == 2024, N] else 0L)
}
res <- rbindlist(res)
fwrite(res, file.path(OUT, "stage0_onsets.csv"))
SPX <- copy(SP)[, .(spell_start = s, spell_end = e, gap_to_prev_h = round(gap_h, 1))]
fwrite(SPX, file.path(OUT, "stage0_spells.csv"))

# Gate arithmetic per registration: onsets < 150, or onsets/15 < 10 params (i.e. < 150), halts
cat(sprintf("\nGate check: min onsets over N grid = %d; thresholds: >= 150 (both conditions coincide at 150 for 10 params)\n",
            res[, min(onsets)]))
cat("DONE stage0\n")
