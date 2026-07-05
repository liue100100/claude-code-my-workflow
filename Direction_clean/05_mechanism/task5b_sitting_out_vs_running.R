#!/usr/bin/env Rscript
# task5b_sitting_out_vs_running.R -- Task B: did sitting out pay better than running?
# Per Torrens unit per year: (1) direction earnings = actual per-event compensation where it
# exists (2023-10 onward, corrected Task-1b panel), else the verified formula
# 0.95 x directed MWh x directed price (monthly d_t; June 2022 at the ex-ante $241.38);
# (2) counterfactual market earnings = the SAME output valued at realised SA1 spot prices over
# the same corrected direction windows. Assumption stated: a committed unit doesn't get
# directed, so it earns spot only; this compares payment rates, not a full counterfactual
# world (AEMO's behaviour could differ). Note: actual compensation excludes the retained
# market revenue (median RTA was ~-$900 in these windows), so using comp alone if anything
# UNDERSTATES the direction channel's advantage.
# This is open check (ii) of interpretation_staged_framework.md.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
TOR <- c("TORRB2","TORRB3","TORRB4")
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")

ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% TOR]; ep[, `:=`(s=force10(s), c=force10(c))]
ep <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
ep[, `:=`(yyyymm = as.integer(format(s, "%Y%m")), yr = year(s))]
cat(sprintf("Torrens episodes (corrected windows, 2022-2024): %d\n", nrow(ep)))

# spot revenue + MWh over the corrected windows (36-month DL x SA1 price join)
dl <- rbindlist(lapply(MONTHS, function(M) {
  d <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(d)
  d <- d[DUID %in% TOR, .(DUID, SETTLEMENTDATE, INTERVENTION=as.numeric(INTERVENTION),
                          TOTALCLEARED=as.numeric(TOTALCLEARED))]
  d <- unique(d); d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1]
}))
dl[, idt := force10(SETTLEMENTDATE)]
dp <- rbindlist(lapply(MONTHS, function(M) {
  d <- readRDS(file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))); setDT(d)
  keep <- intersect(c("SETTLEMENTDATE","RRP","INTERVENTION","REGIONID"), names(d)); d <- d[, ..keep]
  if ("REGIONID" %in% names(d)) d <- d[REGIONID=="SA1"]
  if ("INTERVENTION" %in% names(d)) d <- d[d[, .I[which.min(as.numeric(INTERVENTION))], by=SETTLEMENTDATE]$V1]
  d[, .(idt=force10(SETTLEMENTDATE), RRP=as.numeric(RRP))]
}))
dp <- unique(dp, by="idt")
dl <- merge(dl, dp, by="idt")
setkey(ep, duid, s, c)
dl[, `:=`(w0=idt, w1=idt)]
ov <- foverlaps(dl[, .(duid=DUID, w0, w1, idt, TOTALCLEARED, RRP)],
                ep[, .(duid, s, c, episode_id)], by.x=c("duid","w0","w1"), by.y=c("duid","s","c"),
                type="within", nomatch=NULL)
E <- ov[, .(mwh = sum(TOTALCLEARED)/12, spot_rev = sum(TOTALCLEARED*RRP)/12,
            rrp_mean_w = sum(TOTALCLEARED*RRP)/max(sum(TOTALCLEARED),1e-9)), by=.(duid, episode_id)]
ep <- merge(ep, E, by=c("duid","episode_id"), all.x=TRUE)
n_nocov <- ep[is.na(mwh), .N]
ep <- ep[!is.na(mwh)]
cat(sprintf("Episodes with dispatch+price coverage: %d (dropped %d without)\n", nrow(ep), n_nocov))

# direction earnings
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- rbind(g0[, .(yyyymm=as.integer(yyyymm), P=dt_recon)], data.table(yyyymm=202206L, P=241.38))
ep <- merge(ep, cp, by="yyyymm", all.x=TRUE); stopifnot(ep[, sum(is.na(P))]==0)
X1b <- readRDS(file.path(OUT, "task1b_panel.rds"))[duid %in% TOR, .(episode_id, comp)]
ep <- merge(ep, X1b, by="episode_id", all.x=TRUE)
ep[, dir_formula := 0.95 * mwh * P]
ep[, dir_earn := fifelse(!is.na(comp), comp, dir_formula)]
cat(sprintf("Episodes with ACTUAL compensation: %d (2023-10 onward); formula used for %d\n",
            ep[!is.na(comp), .N], ep[is.na(comp), .N]))

# the table
tab <- ep[, .(episodes=.N, mwh=round(sum(mwh)),
              direction_earnings=round(sum(dir_earn)),
              market_counterfactual=round(sum(spot_rev)),
              gap=round(sum(dir_earn) - sum(spot_rev)),
              dir_per_mwh=round(sum(dir_earn)/sum(mwh)),
              spot_per_mwh=round(sum(spot_rev)/sum(mwh))), by=.(duid, yr)][order(duid, yr)]
cat("\n=== Per unit-year: direction earnings vs the same output at spot ===\n")
print(tab)
tot <- ep[, .(episodes=.N, mwh=round(sum(mwh)), direction=round(sum(dir_earn)),
              market=round(sum(spot_rev)), gap=round(sum(dir_earn)-sum(spot_rev)),
              ratio=round(sum(dir_earn)/max(sum(spot_rev),1),1))]
cat("\nTOTALS (3 units, 3 years):\n"); print(tot)
cat("\nCross-checks: share of directed MWh with NEGATIVE spot price:",
    round(100*ov[RRP<0, sum(TOTALCLEARED)]/ov[, sum(TOTALCLEARED)],1), "%;",
    "MWh-weighted mean spot in directed windows: $", round(ov[, sum(TOTALCLEARED*RRP)/sum(TOTALCLEARED)],1), "\n")
cat("Actual-comp subset only (2023-10+): direction $", ep[!is.na(comp), round(sum(comp))],
    " vs spot $", ep[!is.na(comp), round(sum(spot_rev))], "\n")
fwrite(tab, file.path(OUT, "task5b_unit_year_table.csv"))
fwrite(ep[, .(episode_id, duid, yr, yyyymm, mwh, P, comp, dir_formula, dir_earn, spot_rev, rrp_mean_w)],
       file.path(OUT, "task5b_episode_level.csv"))
cat("\nSaved task5b_{unit_year_table,episode_level}.csv\n")
