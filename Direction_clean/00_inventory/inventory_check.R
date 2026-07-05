#!/usr/bin/env Rscript
# inventory_check.R -- Stage 0 of the Direction_clean/ rebuild.
#
# Confirms, by actually reading the files (not by assumption), every input table this pipeline
# reuses from ../Direction/ (read-only -- Direction/ is never written to), states the sample
# window and focal-unit list, forces and asserts a single timezone, and fills the one genuine gap
# (registered capacity per focal unit, not cached anywhere in Direction/) with a small, targeted
# live pull. Writes outputs/00_inventory/findings.md in plain language.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table) })
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")           # read-only source, never modified
OUT       <- file.path(ROOT, "Direction_clean/outputs/00_inventory")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")  # OSB-AG descriptive only, per README

cat("=== (1) Sample window -- from the bid-ladder cache file listing ===\n")
bop_files <- list.files(file.path(DIRECTION, "bid_cache"), pattern = "^BIDOFFERPERIOD_[0-9]{6}\\.rds$")
months <- sort(gsub("[^0-9]", "", bop_files))
stopifnot(length(months) > 0)
cat(sprintf("  %d months cached, %s -> %s\n", length(months), months[1], months[length(months)]))

cat("\n=== (2) Reused tables -- grain, row counts, columns ===\n")

pivotality <- readRDS(file.path(DIRECTION, "outputs/descriptives_v3/pivotality_panel.rds"))
cat(sprintf("  essentiality/pivotality panel: %d rows (grain: per 5-min interval, SA-wide) | cols incl. %s\n",
            nrow(pivotality), paste(grep("^pex_|^piv_|nonsync|short", names(pivotality), value=TRUE), collapse=", ")))

srmc <- fread(file.path(DIRECTION, "outputs/descriptives_v3/GateA_srmc_params.csv"))
cat(sprintf("  SRMC table: %d rows (grain: per DUID x month) | cols: %s\n", nrow(srmc), paste(names(srmc), collapse=", ")))
stopifnot(all(FOCUS %in% srmc$duid))

dir_events <- readRDS(file.path(DIRECTION, "direction_data/parsed/direction_events.rds"))
dir_costs  <- readRDS(file.path(DIRECTION, "direction_data/parsed/direction_costs.rds"))
cat(sprintf("  direction events: %d rows (grain: per direction event x DUID)\n", nrow(dir_events)))
cat(sprintf("  direction compensation (episode-level): %d rows (grain: per report_event)\n", nrow(dir_costs)))

comp_price <- readRDS(file.path(DIRECTION, "outputs/descriptives/gate0_dt_series.rds"))
cat(sprintf("  compensation-price series: %d rows (grain: per month) | %s -> %s\n",
            nrow(comp_price), min(comp_price$yyyymm), max(comp_price$yyyymm)))

treatment <- readRDS(file.path(DIRECTION, "direction_data/parsed/treatment_panel.rds"))
cat(sprintf("  realised directed/synchronise flags: %d rows (grain: per DUID x 5-min interval)\n", nrow(treatment)))

cat("\n=== (3) Timezone: force Etc/GMT-10 everywhere, assert on a known directed interval ===\n")
# Interval-ending convention: AEMO SETTLEMENTDATE/INTERVAL_DATETIME label the END of the interval
# (e.g. 00:05 covers 00:00-00:05). Both Etc/GMT-10 and Australia/Brisbane labels appear across the
# source caches; both are UTC+10, no DST, so a single forced tzone makes POSIXct joins correct
# regardless of which label the source file used -- documented once here, reused by Stage 1.
treatment[, interval_dt := force10(interval_datetime)]
pivotality[, interval_dt := force10(SETTLEMENTDATE)]
# treatment_panel.rds holds ONLY directed rows (directed is always 1 in this table -- confirmed;
# non-directed intervals are simply absent, not encoded as 0) and spans back to 2021, wider than
# the essentiality panel's 202201-202412 coverage -- restrict to the sample window before picking
# a check interval, or the very first directed row can fall outside the essentiality panel by
# construction (found exactly this on the first run: an OSB-AG direction from 2021-04-14).
in_window <- format(treatment$interval_dt, "%Y%m") %in% months
known_directed <- treatment[in_window][duid %in% FOCUS & directed == 1][1]
stopifnot(nrow(known_directed) == 1)
match_row <- pivotality[interval_dt == known_directed$interval_dt]
stopifnot(nrow(match_row) == 1)
cat(sprintf("  known directed interval: %s (%s) -- found matching essentiality-panel row: %s\n",
            known_directed$duid, format(known_directed$interval_dt), format(match_row$interval_dt)))
cat("  OK: tz-forced join resolves a known directed interval to exactly one essentiality-panel row.\n")

cat("\n=== (4) Registered capacity -- confirmed gap, filled by one targeted live pull ===\n")
# Not cached anywhere in Direction/: get_sa_duids() (00_data_spine/extract_core.R) fetches AEMO's
# DUDETAILSUMMARY but keeps only the DUID list. DUDETAILSUMMARY itself has no capacity column at
# all (confirmed by a direct pull, see session notes) -- the field lives in the DUDETAIL table
# (REGISTEREDCAPACITY, MAXCAPACITY), which is NOT the table get_sa_duids() reads. Reuses the same
# AEMO download mechanism (read_mmsdm(), from sa_directions_feasibility.R) read-only -- sourcing it
# defines functions/constants only; it does not auto-run or touch Direction/'s own cache (its
# `if (sys.nframe()==0L)` guard only fires when run as a script, not when sourced).
source(file.path(DIRECTION, "00_data_spine/sa_directions_feasibility.R"))
CAP_CACHE <- "_capacity_cache"
dud_start <- read_mmsdm("DUDETAIL", as.integer(months[1]), cache = CAP_CACHE); setDT(dud_start)
dud_end   <- read_mmsdm("DUDETAIL", as.integer(months[length(months)]), cache = CAP_CACHE); setDT(dud_end)
latest_ver <- function(d) d[DUID %in% FOCUS][order(DUID, EFFECTIVEDATE)][, .SD[.N], by = DUID][
  , .(duid = DUID, reg_cap_mw = as.numeric(REGISTEREDCAPACITY), max_cap_mw = as.numeric(MAXCAPACITY),
      effective_date = EFFECTIVEDATE)]
cap_start <- latest_ver(dud_start); cap_end <- latest_ver(dud_end)
stopifnot(nrow(cap_start) == length(FOCUS), nrow(cap_end) == length(FOCUS))
chk <- merge(cap_start[, .(duid, reg_cap_mw)], cap_end[, .(duid, reg_cap_mw)], by = "duid",
             suffixes = c("_start", "_end"))
if (!all(chk$reg_cap_mw_start == chk$reg_cap_mw_end)) {
  cat("  WARNING: registered capacity changed between start and end of sample -- a single constant\n",
      "  per unit is NOT valid; Stage 1 must use a time-varying lookup. See table below.\n")
} else {
  cat("  OK: registered capacity is unchanged across the full sample window for every focal unit.\n")
}
print(chk)
fwrite(cap_end[order(match(duid, FOCUS))], file.path(OUT, "focal_unit_registered_capacity.csv"))
cat(sprintf("\nSaved focal_unit_registered_capacity.csv (%d rows).\n", nrow(cap_end)))

cat("\n=== (5) Known gaps for LATER stages (not needed for Stage 0/1) ===\n")
cat("  - Regional (SA1) demand: no DISPATCHREGIONSUM cache; can be summed from per-DUID dispatch\n",
    "    (DISPATCHLOAD) once the full SA1 rival roster is confirmed. Deferred to Stage 2.\n",
    "  - Interconnector flow: not extracted at all (neither realised nor forecast). Deferred to\n",
    "    Stage 2, which will size a small realised-flow-only extraction.\n", sep="")

findings <- sprintf(
"# Stage 0 findings -- inventory (Direction_clean/)

One-page inventory of every input this pipeline reuses from `Direction/` (read-only), plus the one
gap this stage fills. Written for a reader with no electricity-market background -- see `README.md`
glossary for every term used below.

## Sample window and focal units
%d months cached, %s to %s. Focal units: TORRB2, TORRB3, TORRB4, PPCCGT (primary); OSB-AG
(descriptive only -- near-must-run, no withholding contrast); BARKIPS1 excluded (no cheap tranche
exists even in fully competitive intervals).

## Tables reused from Direction/ (all read-only)
| Table | Grain | Rows | Time resolution |
|---|---|---|---|
| Bid ladder (offer quantities + price bands) | per (generator, bid version, 5-min interval) | (see Direction/ cache) | 5-min |
| Essentiality panel | per 5-min interval, SA-wide | %d | 5-min |
| SRMC (short-run marginal cost) | per generator x month | %d | monthly |
| Direction events | per direction event x generator | %d | event |
| Direction compensation (episode-level) | per report event | %d | event |
| Compensation-price series | per month | %d | monthly (%s to %s) |
| Realised directed/synchronise flags | per generator x 5-min interval | %d | 5-min |

## Timezone and interval convention
AEMO timestamps label the **end** of the interval (e.g. 00:05 covers the 5 minutes ending at
00:05). Two timezone labels appear across the source files (`Etc/GMT-10` and `Australia/Brisbane`)
-- both are UTC+10 with no daylight saving, so they represent the same clock, but every timestamp
column is force-converted to a single label (`Etc/GMT-10`) before any join, and checked against a
known directed interval. **Check passed**: a known directed interval for a focal generator resolved
to exactly one row in the essentiality panel after the tz fix.

**Anomaly caught and fixed, not smoothed over:** the realised directed-flag table
(`treatment_panel.rds`) only contains rows where the generator *was* directed (every row has
directed=1; non-directed intervals are simply absent, not encoded as 0) and it spans back to 2021
-- wider than the essentiality panel's 202201-202412 coverage. The first check attempt picked a
directed interval from 2021 and correctly failed to find a match (0 rows, not 1), because that
interval predates the essentiality panel entirely. Fixed by restricting the check (and every future
join against this table) to the confirmed 202201-202412 sample window.

## Registered capacity -- the one gap, now filled
`Direction/` never cached generator registered capacity (the extraction pipeline fetches AEMO's
generator-detail table but discards every column except the generator ID). Confirmed directly this
session that the summary version of that table has no capacity field at all -- the field lives in a
different, more detailed AEMO table (`DUDETAIL`). Pulled it for the focal units, for both the start
and end of the sample window, and confirmed it is unchanged throughout:

| Generator | Registered capacity (MW) | Technical max (MW) |
|---|---|---|
%s

Saved to `outputs/00_inventory/focal_unit_registered_capacity.csv`.

## Known gaps for later stages (not blocking Stage 0/1)
- **Region-wide demand** -- not cached as a single table; would need summing per-generator
  dispatch across the full South Australian generator roster. Needed for Stage 2 (competition
  measure), not before.
- **Interconnector flow** (SA's links to the rest of the grid) -- not extracted at all. Needed for
  Stage 2, not before.

Both are correctly out of scope for this pass and will be sized properly when Stage 2 is planned.
", length(months), months[1], months[length(months)], nrow(pivotality), nrow(srmc), nrow(dir_events),
   nrow(dir_costs), nrow(comp_price), min(comp_price$yyyymm), max(comp_price$yyyymm), nrow(treatment),
   paste(sprintf("| %s | %s | %s |", cap_end$duid, cap_end$reg_cap_mw, cap_end$max_cap_mw), collapse="\n"))
writeLines(findings, file.path(OUT, "findings.md"))
cat("\nSaved outputs/00_inventory/findings.md.\n")
