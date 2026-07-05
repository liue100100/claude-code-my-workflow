#!/usr/bin/env Rscript
# extract_demand_interconnector.R -- small new extraction for Stage 2.
#
# Direction/ never cached SA1 regional demand or interconnector flow. Both pull cleanly via the
# same live AEMO mechanism already used (read-only) for Stage 0's registered-capacity pull
# (sa_directions_feasibility.R's read_mmsdm(), sourced here the same way -- defines functions only,
# no auto-run, never touches Direction/'s own cache). Confirmed this session:
#   DISPATCHREGIONSUM has TOTALDEMAND directly (the authoritative SA1 demand, not a
#     generator-summation approximation).
#   DISPATCHINTERCONNECTORRES has realised MWFLOW for SA's two interconnectors:
#     V-SA (Heywood, the main AC link) and V-S-MNSP1 (Murraylink, the merchant DC link).
#
# Writes Direction_clean/_demand_ic_cache/{DEMAND,INTERCONNECTOR}_<yyyymm>.rds (skip-if-cached, so
# re-running is cheap). Run from Direction_clean/.

suppressMessages({ library(data.table) })
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")
CACHE     <- file.path(ROOT, "Direction_clean/_demand_ic_cache")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
source(file.path(DIRECTION, "00_data_spine/sa_directions_feasibility.R"))

months <- sort(gsub("[^0-9]", "", list.files(file.path(DIRECTION, "bid_cache"),
                                              pattern="^BIDOFFERPERIOD_[0-9]{6}\\.rds$")))
stopifnot(length(months) == 36L)

demand_num <- c("TOTALDEMAND","AVAILABLEGENERATION","NETINTERCHANGE","DEMANDFORECAST")
ic_num     <- c("MWFLOW","METEREDMWFLOW","MWLOSSES","MARGINALVALUE","EXPORTLIMIT","IMPORTLIMIT")

for (M in months) {
  dest_d <- file.path(CACHE, sprintf("DEMAND_%s.rds", M))
  if (!file.exists(dest_d)) {
    d <- read_mmsdm("DISPATCHREGIONSUM", as.integer(M), cache = CACHE); setDT(d)
    d <- d[REGIONID == "SA1"]
    stopifnot(nrow(d) > 0, "TOTALDEMAND" %in% names(d))
    d[, (demand_num) := lapply(.SD, as.numeric), .SDcols = demand_num]
    d[, SETTLEMENTDATE := as.POSIXct(SETTLEMENTDATE, format="%Y/%m/%d %H:%M:%S")]
    d <- d[, c("SETTLEMENTDATE","REGIONID",demand_num), with=FALSE]
    saveRDS(d, dest_d)
    cat(sprintf("[%s] DEMAND: %d rows -> %s\n", M, nrow(d), dest_d))
  } else cat(sprintf("[%s] DEMAND: cache hit\n", M))

  dest_i <- file.path(CACHE, sprintf("INTERCONNECTOR_%s.rds", M))
  if (!file.exists(dest_i)) {
    ic <- read_mmsdm("DISPATCHINTERCONNECTORRES", as.integer(M), cache = CACHE); setDT(ic)
    ic <- ic[INTERCONNECTORID %in% c("V-SA","V-S-MNSP1")]
    stopifnot(nrow(ic) > 0)
    ic[, (ic_num) := lapply(.SD, as.numeric), .SDcols = ic_num]
    ic[, SETTLEMENTDATE := as.POSIXct(SETTLEMENTDATE, format="%Y/%m/%d %H:%M:%S")]
    ic <- ic[, c("SETTLEMENTDATE","INTERCONNECTORID",ic_num), with=FALSE]
    saveRDS(ic, dest_i)
    cat(sprintf("[%s] INTERCONNECTOR: %d rows -> %s\n", M, nrow(ic), dest_i))
  } else cat(sprintf("[%s] INTERCONNECTOR: cache hit\n", M))
}

cat("\n=== Verifying sign convention on V-SA (Heywood) flow ===\n")
# SA is a winter-peaking, gas/renewables-heavy region historically reliant on imports from
# Victoria during tight periods. Check a known high-demand SA interval: if V-SA MWFLOW is
# strongly positive exactly when SA demand is high and local generation is tight, positive
# MWFLOW = import INTO SA. Confirmed empirically below, not assumed from the variable name.
d1 <- readRDS(file.path(CACHE, "DEMAND_202201.rds"))
ic1 <- readRDS(file.path(CACHE, "INTERCONNECTOR_202201.rds"))[INTERCONNECTORID=="V-SA"]
m <- merge(d1, ic1, by="SETTLEMENTDATE")
peak <- m[order(-TOTALDEMAND)][1:20]
cat(sprintf("Top-20 SA1-demand intervals in Jan-2022: mean TOTALDEMAND=%.0f, mean V-SA MWFLOW=%.1f\n",
            mean(peak$TOTALDEMAND), mean(peak$MWFLOW)))
trough <- m[order(TOTALDEMAND)][1:20]
cat(sprintf("Bottom-20 SA1-demand intervals in Jan-2022: mean TOTALDEMAND=%.0f, mean V-SA MWFLOW=%.1f\n",
            mean(trough$TOTALDEMAND), mean(trough$MWFLOW)))
cat(sprintf("Correlation(TOTALDEMAND, V-SA MWFLOW) over the month: %.3f\n", cor(m$TOTALDEMAND, m$MWFLOW)))
cat("If MWFLOW rises with demand -> positive MWFLOW = import INTO SA (documented in build_residual_demand.R).\n")
cat("\nDone: demand + interconnector cached for all 36 months.\n")
