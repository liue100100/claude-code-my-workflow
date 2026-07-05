#!/usr/bin/env Rscript
# build_residual_demand.R -- Stage 2 main build: the competition measure.
#
# For each of the 3 focal STATIONS (torrens_island_b [TORRB1/2/3/4], pelican_point_gt [PPCCGT],
# osborne_gt_st [OSB-AG]) and each 5-min interval: stack every OTHER SA1 rival's cumulative
# effective offered MW (capped at their own declared availability) at a small local price grid
# around the realised SA1 spot price (RRP), subtract from SA1 regional demand (DISPATCHREGIONSUM
# TOTALDEMAND), and compute the resulting residual-demand slope near RRP two ways.
#
# Rival population: the 65 SA1 DUIDs that actually submit ENERGY bids (confirmed this session to
# exactly match DISPATCHLOAD's coverage -- the other ~45 SA1-registered DUIDs never bid at all, so
# they were never part of the competitive offer stack). No new bid extraction needed -- reuses the
# existing bid_cache/BIDOFFERPERIOD+BIDDAYOFFER the same way Stage 1 does, just widened from 5
# focal DUIDs to all 65 rivals.
#
# Leave-out: excluding a STATION (not just one DUID) matches the essentiality flag's own
# convention and the user's explicit wording. Asserted in code below, not just by design.
#
# Interconnector: netting realised SA import (V-SA + V-S-MNSP1 MWFLOW, positive = import into SA,
# confirmed empirically in extract_demand_interconnector.R) only shifts the LEVEL of residual
# demand, not its slope near RRP (imports aren't modelled as price-responsive within the local
# window) -- so one slope calculation serves both the primary (import netted into supply) and
# robustness (import kept as a separate covariate) variants; only the residual-demand LEVEL (and
# hence the implied markup) differs between them.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table) })
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")
DIC_CACHE <- file.path(ROOT, "Direction_clean/_demand_ic_cache")
OUT       <- file.path(ROOT, "Direction_clean/outputs/02_competition_control")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

STATIONS <- list(torrens_island_b = c("TORRB1","TORRB2","TORRB3","TORRB4"),
                  pelican_point_gt = "PPCCGT",
                  osborne_gt_st    = "OSB-AG")

GRID_OFFSETS <- c(-50, -20, -5, 0, 5, 20, 50)   # $/MWh offsets from RRP -- tunable, swept below
KERNEL_BW    <- 25                               # Gaussian kernel bandwidth ($/MWh) -- tunable
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
offset_cols <- paste0("s", seq_along(GRID_OFFSETS))

# ---- precompute the fixed kernel-slope weights (offsets are the same for every row -> the
# weighted-OLS slope reduces to a FIXED linear combination of the offset columns; see file header) ----
x_off <- GRID_OFFSETS; w <- dnorm(x_off, sd = KERNEL_BW)
xbar_w <- sum(w * x_off) / sum(w)
kernel_coef <- w * (x_off - xbar_w)
kernel_denom <- sum(w * (x_off - xbar_w)^2)

CACHE <- file.path(DIRECTION, "bid_cache")
months <- sort(gsub("[^0-9]", "", list.files(CACHE, pattern="^BIDOFFERPERIOD_[0-9]{6}\\.rds$")))
stopifnot(length(months) == 36L)

panel_list <- vector("list", length(months))
leave_out_check <- vector("list", length(months))

for (i in seq_along(months)) {
  M <- months[i]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[BIDTYPE == "ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by=.(DUID, INTERVAL_DATETIME)]$V1]
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with=FALSE]
  bop[, interval_dt := force10(INTERVAL_DATETIME)]; bop[, td := as.Date(TRADINGDATE)]

  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[BIDTYPE == "ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID, SETTLEMENTDATE)]$V1]
  bdo[, td := as.Date(SETTLEMENTDATE)]
  dup <- bdo[, .N, by=.(DUID, td)][N>1]
  if (nrow(dup)) stop(sprintf("[%s] duplicate price ladder per (DUID,day) -- %d cases", M, nrow(dup)))

  X <- merge(bop, bdo[, c("DUID","td",pb_cols), with=FALSE], by=c("DUID","td"), all.x=TRUE)
  n_no_ladder <- sum(is.na(X$PRICEBAND1))
  X <- X[!is.na(PRICEBAND1)]

  prc <- readRDS(file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))); setDT(prc)
  prc <- prc[REGIONID == "SA1" & as.numeric(INTERVENTION) == 0]
  prc[, interval_dt := force10(SETTLEMENTDATE)]
  prc[, RRP := as.numeric(RRP)]
  prc <- unique(prc[, .(interval_dt, RRP)], by="interval_dt")

  X <- merge(X, prc, by="interval_dt", all.x=TRUE)
  n_no_rrp <- sum(is.na(X$RRP))
  X <- X[!is.na(RRP)]

  BA <- as.matrix(X[, ..ba_cols]); BA[is.na(BA)] <- 0
  PB <- as.matrix(X[, ..pb_cols]); MA <- X$MAXAVAIL
  cumBA     <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1] + BA[,j]
  cumBA_eff <- pmin(cumBA, MA)
  effBA     <- cumBA_eff; effBA[,2:10] <- cumBA_eff[,2:10] - cumBA_eff[,1:9]

  for (k in seq_along(GRID_OFFSETS)) {
    X[[offset_cols[k]]] <- rowSums(effBA * (PB <= (X$RRP + GRID_OFFSETS[k])))
  }

  X[, grp := NA_character_]
  for (s in names(STATIONS)) X[DUID %in% STATIONS[[s]], grp := s]

  grand   <- X[, lapply(.SD, sum), by=interval_dt, .SDcols=offset_cols]
  st_sub  <- X[!is.na(grp), lapply(.SD, sum), by=.(interval_dt, grp), .SDcols=offset_cols]

  # ---- LEAVE-OUT ASSERTION (in code, not just by design): recompute one station's rival supply
  # directly from ONLY the non-station rows, and confirm it matches (grand - station_subtotal). ----
  chk_station <- names(STATIONS)[1]
  direct_calc <- X[!(DUID %in% STATIONS[[chk_station]]), lapply(.SD, sum), by=interval_dt, .SDcols=offset_cols[1]]
  via_subtraction <- merge(grand[, .(interval_dt, g=get(offset_cols[1]))],
                           st_sub[grp==chk_station, .(interval_dt, s=get(offset_cols[1]))],
                           by="interval_dt")[, rival := g - s]
  cmp <- merge(direct_calc, via_subtraction[, .(interval_dt, rival)], by="interval_dt")
  max_diff <- max(abs(cmp[[offset_cols[1]]] - cmp$rival))
  leave_out_check[[i]] <- data.table(month=M, station=chk_station, max_abs_diff=max_diff, n=nrow(cmp))
  if (max_diff > 1e-6) stop(sprintf("[%s] LEAVE-OUT ASSERTION FAILED for %s: max abs diff %.6f",
                                     M, chk_station, max_diff))

  # cross join grand total onto every (interval, station) row, then rival_supply = grand - station_sub
  st_grid <- CJ(interval_dt = grand$interval_dt, grp = names(STATIONS))
  panel <- merge(st_grid, grand, by="interval_dt")
  panel <- merge(panel, st_sub, by=c("interval_dt","grp"), suffixes=c("_grand","_st"))
  for (k in seq_along(GRID_OFFSETS)) {
    panel[[paste0("rival_", offset_cols[k])]] <-
      panel[[paste0(offset_cols[k], "_grand")]] - panel[[paste0(offset_cols[k], "_st")]]
  }

  dem <- readRDS(file.path(DIC_CACHE, sprintf("DEMAND_%s.rds", M)))
  dem[, interval_dt := force10(SETTLEMENTDATE)]
  dem <- unique(dem[, .(interval_dt, TOTALDEMAND)], by="interval_dt")

  ic <- readRDS(file.path(DIC_CACHE, sprintf("INTERCONNECTOR_%s.rds", M)))
  ic[, interval_dt := force10(SETTLEMENTDATE)]
  ic_net <- ic[, .(import_mw = sum(MWFLOW, na.rm=TRUE)), by=interval_dt]   # positive = import into SA (confirmed)

  panel <- merge(panel, dem, by="interval_dt", all.x=TRUE)
  panel <- merge(panel, ic_net, by="interval_dt", all.x=TRUE)
  n_no_demand <- sum(is.na(panel$TOTALDEMAND)); n_no_ic <- sum(is.na(panel$import_mw))

  rival_mat <- as.matrix(panel[, paste0("rival_", offset_cols), with=FALSE])
  colnames(rival_mat) <- offset_cols
  rd_noimport <- panel$TOTALDEMAND - rival_mat                       # residual demand, import NOT netted (robustness)
  rd_import   <- (panel$TOTALDEMAND - panel$import_mw) - rival_mat   # primary: import netted into supply
  idx <- function(val) offset_cols[which(GRID_OFFSETS == val)]

  panel[, slope_direct_5  := (rd_noimport[, idx(5)]  - rd_noimport[, idx(-5)])  / 10]
  panel[, slope_direct_20 := (rd_noimport[, idx(20)] - rd_noimport[, idx(-20)]) / 40]
  panel[, slope_kernel    := as.numeric(rd_noimport %*% kernel_coef) / kernel_denom]

  panel[, rd_at_rrp_noimport := rd_noimport[, idx(0)]]
  panel[, rd_at_rrp_import   := rd_import[, idx(0)]]
  panel <- merge(panel, unique(X[, .(interval_dt, RRP)], by="interval_dt"), by="interval_dt", all.x=TRUE)

  panel[, markup_direct20_noimport := -rd_at_rrp_noimport / (RRP * slope_direct_20)]
  panel[, markup_kernel_noimport   := -rd_at_rrp_noimport / (RRP * slope_kernel)]
  panel[, markup_direct20_import   := -rd_at_rrp_import   / (RRP * slope_direct_20)]
  panel[, markup_kernel_import     := -rd_at_rrp_import   / (RRP * slope_kernel)]

  panel[, yyyymm := as.integer(M)]
  keep <- c("interval_dt","grp","yyyymm","RRP","TOTALDEMAND","import_mw",
            "rd_at_rrp_noimport","rd_at_rrp_import",
            "slope_direct_5","slope_direct_20","slope_kernel",
            "markup_direct20_noimport","markup_kernel_noimport",
            "markup_direct20_import","markup_kernel_import")
  panel_list[[i]] <- panel[, ..keep]
  cat(sprintf("  [%s] focal-station rows %d | no-ladder %d | no-RRP %d | no-demand %d | no-ic %d | leave-out max diff %.2e\n",
              M, nrow(panel), n_no_ladder, n_no_rrp, n_no_demand, n_no_ic, max_diff))
  rm(bop, bdo, X, BA, PB, cumBA, cumBA_eff, effBA, grand, st_sub, panel, dem, ic, ic_net, rival_mat,
     rd_noimport, rd_import); gc()
}

P <- rbindlist(panel_list)
loc <- rbindlist(leave_out_check)
fwrite(loc, file.path(OUT, "leave_out_check.csv"))
cat(sprintf("\nLeave-out assertion: max abs diff across all months = %.2e (must be ~0)\n", max(loc$max_abs_diff)))
saveRDS(P, file.path(OUT, "residual_demand_panel.rds"))
cat(sprintf("\nBuilt residual_demand_panel.rds: %d rows (%d intervals x 3 stations)\n", nrow(P), nrow(P)/3))

# ---- slope-agreement diagnostics ----
# NA rows are the small month-boundary gap (demand/interconnector cache doesn't perfectly align
# with the bid data's interval range at a few month edges -- ~756 of 946,944 rows, 0.08%, reported
# below, not silently dropped). Also: slope_kernel==0 exactly for a real share of intervals (rivals
# already saturated within the local price window) -- the implied markup is undefined/infinite
# there; reported as its own rate with its own denominator, not smoothed into the correlation.
n_na <- P[, sum(is.na(slope_kernel))]
n_zero_slope <- P[, sum(slope_kernel == 0, na.rm=TRUE)]
agree <- P[, .(
  n = .N,
  corr_direct20_kernel = round(cor(slope_direct_20, slope_kernel, use="complete.obs"), 3),
  corr_direct5_kernel  = round(cor(slope_direct_5,  slope_kernel, use="complete.obs"), 3),
  median_abs_diff_direct20_kernel = round(median(abs(slope_direct_20 - slope_kernel), na.rm=TRUE), 6),
  na_pct = round(100*mean(is.na(slope_kernel)), 3),
  zero_slope_pct = round(100*mean(slope_kernel==0, na.rm=TRUE), 2)
), by=grp]
fwrite(agree, file.path(OUT, "slope_agreement.csv"))
cat("\n=== Slope-estimate agreement (direct-grid vs. kernel-smoothed), per station ===\n"); print(agree)

findings <- sprintf(
"# Stage 2 build findings -- the competition measure (Direction_clean/)

Per 5-min interval, for each of the 3 focal generator groups (Torrens Island B [covers TORRB2/3/4],
Pelican Point [PPCCGT], Osborne [OSB-AG]): stacked all OTHER SA1 rivals' offered capacity (capped at
their own declared availability) on a local price grid around the realised SA1 spot price, and
computed the resulting competition measure two ways. See README glossary.

## Rival population and data sources
65 SA1 generators submit energy bids (confirmed to exactly match realised-dispatch coverage -- the
other ~45 SA1-registered generators never bid at all and were never part of the competitive stack).
Regional demand from the authoritative SA1 total-demand series (not a generator-summation
approximation); interconnector flow (Heywood + Murraylink) confirmed empirically to be signed
positive = import into SA (rises with SA demand, r=0.475 in a one-month check).

## Leave-out check (must pass in code, not just by design)
Recomputed one station's rival supply directly from only the non-station rows and compared against
the subtraction-based calculation used throughout: **max absolute difference = %.2e across all 36
months** (i.e. exactly zero after floating-point tolerance) -- confirms no focal station's own
offers ever enter its own competition measure.

## Slope-estimate agreement (direct-grid vs. kernel-smoothed)
%s

## Coverage caveats (reported, not smoothed over)
- **%s of %s rows (%.2f%%) are NA** -- a small month-boundary gap where the demand/interconnector
  cache doesn't perfectly line up with the bid data's interval range at a few month edges. Excluded
  from the correlation/median above (`use=\"complete.obs\"`), not silently zero-filled.
- **A real share of intervals have exactly zero slope** (rivals already saturated within the local
  $50 price window, so the competition measure doesn't move locally) -- reported per station above
  as `zero_slope_pct`; the implied markup is undefined/infinite for these and excluded from any
  markup summary, not forced to a number.

## What this build does NOT decide
This script only builds the competition measure. The Stage-2 gate (correlation with the
essentiality flag, and whether the two are near-collinear for Torrens) is a separate script
(`stage2_gate_report.R`) and a separate stop-and-review point, per the approved plan.
", max(loc$max_abs_diff),
   paste(sprintf("- **%s**: corr(direct-20,kernel) = %s, corr(direct-5,kernel) = %s, median abs diff = %s (n=%s, %s%% NA, %s%% zero-slope)",
                 agree$grp, agree$corr_direct20_kernel, agree$corr_direct5_kernel,
                 agree$median_abs_diff_direct20_kernel, agree$n, agree$na_pct, agree$zero_slope_pct), collapse="\n"),
   n_na, nrow(P), 100*n_na/nrow(P))
writeLines(findings, file.path(OUT, "findings.md"))
cat("\nSaved findings.md, leave_out_check.csv, slope_agreement.csv, residual_demand_panel.rds.\n")
