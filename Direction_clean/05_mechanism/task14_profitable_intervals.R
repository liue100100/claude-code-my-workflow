#!/usr/bin/env Rscript
# task14_profitable_intervals.R -- within the corrected directed windows: how many intervals
# had spot ABOVE fuel cost (running profitable interval-by-interval), and what is their
# structure (block lengths, hour of day, year, instruction type)? Descriptive.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TOR <- c("TORRB2","TORRB3","TORRB4")
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")

ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% TOR]; ep[, `:=`(s=force10(s), c=force10(c))]
ep <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
srmc <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
sm <- unique(srmc[duid=="TORRB2", .(yyyymm=as.integer(yyyymm), srmc=srmc_marginal)])  # station-common

IC <- file.path(OUT, "_task14_iv.rds")
if (file.exists(IC)) { OV <- readRDS(IC) } else {
  dl <- rbindlist(lapply(MONTHS, function(M) {
    d <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(d)
    d <- d[DUID %in% TOR, .(DUID, SETTLEMENTDATE, INTERVENTION=as.numeric(INTERVENTION),
                            TOTALCLEARED=as.numeric(TOTALCLEARED))]
    d <- unique(d); d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1] }))
  dl[, idt := force10(SETTLEMENTDATE)]
  dp <- rbindlist(lapply(MONTHS, function(M) {
    d <- readRDS(file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))); setDT(d)
    keep <- intersect(c("SETTLEMENTDATE","RRP","INTERVENTION","REGIONID"), names(d)); d <- d[, ..keep]
    if ("REGIONID" %in% names(d)) d <- d[REGIONID=="SA1"]
    if ("INTERVENTION" %in% names(d)) d <- d[d[, .I[which.min(as.numeric(INTERVENTION))], by=SETTLEMENTDATE]$V1]
    d[, .(idt=force10(SETTLEMENTDATE), RRP=as.numeric(RRP))] }))
  dl <- merge(dl, unique(dp, by="idt"), by="idt")
  setkey(ep, duid, s, c); dl[, `:=`(w0=idt, w1=idt)]
  OV <- foverlaps(dl[, .(duid=DUID, w0, w1, idt, TOTALCLEARED, RRP)],
                  ep[, .(duid, s, c, episode_id, instruction)],
                  by.x=c("duid","w0","w1"), by.y=c("duid","s","c"), type="within", nomatch=NULL)
  saveRDS(OV, IC)
}
OV[, yyyymm := as.integer(format(idt, "%Y%m"))]
OV <- merge(OV, sm, by="yyyymm", all.x=TRUE)
n_na <- OV[is.na(srmc), .N]
cat(sprintf("Intervals without a fuel-cost month (sample-edge, dropped): %d\n", n_na))
OV <- OV[!is.na(srmc)]
OV[, `:=`(profit = RRP > srmc, hh = as.integer(format(idt - 1, "%H", tz="Etc/GMT-10")), yr = year(idt))]

cat(sprintf("Directed Torrens intervals (corrected windows): %s\n", format(nrow(OV), big.mark=",")))
cat(sprintf("\n=== Intervals with spot > fuel cost: %s of %s (%.1f%%) ===\n",
            format(OV[profit==TRUE,.N], big.mark=","), format(nrow(OV), big.mark=","), 100*OV[, mean(profit)]))
cat("By year:\n"); print(OV[, .(pct_profitable = round(100*mean(profit),1), n_iv=.N,
                                 med_margin_when_profitable = round(median(RRP[profit]-srmc[profit]))), by=yr][order(yr)])
cat("By instruction:\n"); print(OV[, .(pct_profitable = round(100*mean(profit),1), n_iv=.N), by=instruction])
cat("By hour block:\n")
print(OV[, .(pct_profitable = round(100*mean(profit),1)),
         by=.(blk=cut(hh, c(-1,5,11,17,23), labels=c("00-06","06-12","12-18","18-24")))][order(blk)])
cat("\nDistribution of the spot-minus-cost margin over ALL directed intervals ($/MWh):\n")
print(round(quantile(OV$RRP - OV$srmc, c(.10,.25,.50,.75,.90,.95,.99)),0))

cat("\n=== Structure: consecutive profitable runs WITHIN episodes ===\n")
setorder(OV, episode_id, duid, idt)
runs <- OV[, {r <- rle(profit); .(len=r$lengths, val=r$values)}, by=.(episode_id, duid)][val==TRUE]
cat(sprintf("Profitable runs: %d | length (5-min intervals): median %.0f, P75 %.0f, P90 %.0f, max %.0f | runs >= 1h: %d | runs >= 4h: %d\n",
            nrow(runs), median(runs$len), quantile(runs$len,.75), quantile(runs$len,.9), max(runs$len),
            runs[len>=12,.N], runs[len>=48,.N]))
epi <- OV[, .(pct_profit = mean(profit), n_iv=.N, mean_margin = mean(RRP - srmc)), by=.(episode_id, duid, instruction)]
cat(sprintf("\n=== Episode level: windows where MEAN spot > fuel cost: %d of %d (%.1f%%) ===\n",
            epi[mean_margin > 0, .N], nrow(epi), 100*epi[, mean(mean_margin > 0)]))
cat("Episodes by share of window profitable:\n")
print(epi[, .N, by=.(share = cut(pct_profit, c(-0.01,0.001,.25,.5,.75,1),
        labels=c("0%","0-25%","25-50%","50-75%","75-100%")))][order(share)])
fwrite(epi, file.path(OUT, "task14_episode_profitability.csv"))
cat("\nDescriptive only.\n")
