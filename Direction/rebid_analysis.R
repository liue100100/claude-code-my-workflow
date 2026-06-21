#!/usr/bin/env Rscript
# rebid_analysis.R
# Do units actively REBID (revise offers intraday) more when they (expect to) be
# pivotal for system strength? Rebidding is the dynamic behavioural signal:
# a unit that rebids in anticipation of being needed is actively positioning.
#
# Rebid intensity per unit-day = # distinct OFFERDATETIME versions (BIDOFFERPERIOD
# keeps all versions). Quantity-withholding direction = change in MAXAVAIL across
# the day's versions (first -> last). Tested against pivotality aggregated to the
# unit-day: realised share, ex-ante share, and non-sync penetration (exogenous).

suppressMessages({ library(data.table); library(fixest); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"; CACHE <- "bid_cache"

SYNC <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG","QPS5",
          "MINTARO","DRYCGT1","DRYCGT2","DRYCGT3","BARKIPS1")
STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips")

months <- sprintf("%d%02d", rep(2022:2024, each=12), rep(1:12, times=3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]

# SRMC per duid-month (price ladder threshold for "above-cost" withholding)
srmc <- fread(file.path(OUT, "GateA_srmc_params.csv"))[, .(DUID=duid, yyyymm=as.character(yyyymm), srmc_marginal)]

# ---- rebid intensity + quantity-withholding + price-band escalation per unit-day ----
rebid_one <- function(M) {
  b <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))))
  b <- b[BIDTYPE=="ENERGY" & DUID %in% SYNC]
  b[, td := as.IDate(INTERVAL_DATETIME)]
  # rebid intensity: distinct versions per unit-day
  cnt <- b[, .(n_versions = uniqueN(OFFERDATETIME)), by=.(DUID, td)]
  # quantity withholding: INTERVAL-FIXED first->last MAXAVAIL change, averaged over
  # the day's intervals (so we compare like-with-like, not across intervals).
  iv <- b[, .(mx_first = MAXAVAIL[which.min(OFFERDATETIME)],
              mx_last  = MAXAVAIL[which.max(OFFERDATETIME)]),
          by = .(DUID, td, INTERVAL_DATETIME)]
  qw <- iv[, .(quan_withheld = mean(mx_first - mx_last, na.rm=TRUE),   # >0 = withdrew capacity
               maxavail_mean = mean(mx_last, na.rm=TRUE)), by=.(DUID, td)]

  # ---- price-band escalation: do rebids move MW UP the price ladder? ----
  # Hold the day's price bands fixed (latest BIDDAYOFFER), compare the band-quantity
  # allocation of the FIRST vs LAST quantity version. Escalation = share of capacity
  # above SRMC in the last version minus the first.
  bdo <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))))
  bdo <- bdo[BIDTYPE=="ENERGY" & DUID %in% SYNC]
  bdo[, td := as.IDate(SETTLEMENTDATE)]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID, td)]$V1]      # latest price ladder per unit-day
  pb  <- bdo[, c("DUID","td", paste0("PRICEBAND",1:10)), with=FALSE]

  # first & last version band-quantity totals (summed over the day's intervals)
  bcols <- paste0("BANDAVAIL", 1:10)
  fv <- b[, .SD[OFFERDATETIME==min(OFFERDATETIME)], by=.(DUID, td), .SDcols=bcols][
           , lapply(.SD, sum, na.rm=TRUE), by=.(DUID, td), .SDcols=bcols]
  lv <- b[, .SD[OFFERDATETIME==max(OFFERDATETIME)], by=.(DUID, td), .SDcols=bcols][
           , lapply(.SD, sum, na.rm=TRUE), by=.(DUID, td), .SDcols=bcols]
  setnames(fv, bcols, paste0("f", 1:10)); setnames(lv, bcols, paste0("l", 1:10))
  esc <- merge(fv, lv, by=c("DUID","td"))
  esc <- merge(esc, pb, by=c("DUID","td"))
  esc[, yyyymm := M]
  esc <- merge(esc, srmc, by=c("DUID","yyyymm"), all.x=TRUE)
  # above-SRMC share for first and last versions
  fmat <- as.matrix(esc[, paste0("f",1:10), with=FALSE])
  lmat <- as.matrix(esc[, paste0("l",1:10), with=FALSE])
  pmat <- as.matrix(esc[, paste0("PRICEBAND",1:10), with=FALSE])
  above <- pmat > esc$srmc_marginal
  ws_first <- rowSums(fmat*above, na.rm=TRUE) / pmax(rowSums(fmat, na.rm=TRUE), 1)
  ws_last  <- rowSums(lmat*above, na.rm=TRUE) / pmax(rowSums(lmat, na.rm=TRUE), 1)
  esc2 <- esc[, .(DUID, td)]
  esc2[, ws_escalation := ws_last - ws_first]    # >0 = moved capacity above SRMC across the day

  agg <- Reduce(function(a,b) merge(a,b,by=c("DUID","td")), list(cnt, qw, esc2))
  agg[, yyyymm := M]
  agg
}
cat("Computing rebid intensity over", length(months), "months...\n")
rebid <- rbindlist(lapply(months, rebid_one))   # quan_withheld computed in rebid_one
cat(sprintf("rebid unit-days: %d | mean versions/day %.1f | mean MW withdrawn %.1f\n",
            nrow(rebid), mean(rebid$n_versions), mean(rebid$quan_withheld, na.rm=TRUE)))

# ---- pivotality aggregated to station-day ----
piv <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
piv[, td := as.IDate(SETTLEMENTDATE)]
stations <- unique(STAT)
pd <- rbindlist(lapply(stations, function(s)
  piv[, .(station=s,
          piv_share = mean(get(paste0("piv_", s))),
          pex_share = mean(get(paste0("pex_", s))),
          nonsync_mean = mean(nonsync_mw)), by=td]))

rebid[, station := STAT[as.character(DUID)]]
r <- merge(rebid, pd, by=c("td","station"))
r[, nonsync_100 := nonsync_mean/100]
r[, yyyymm := format(td, "%Y%m")]

# ---- direction events for the day (to split anticipation vs already-directed) ----
tp <- as.data.table(readRDS("direction_data/parsed/treatment_panel.rds"))
tp[, td := as.IDate(interval_datetime)]
dir_day <- tp[, .(directed_day = as.integer(any(directed==1))), by=.(duid, td)]
r <- merge(r, dir_day, by.x=c("DUID","td"), by.y=c("duid","td"), all.x=TRUE)
r[is.na(directed_day), directed_day := 0L]

cat(sprintf("\nMerged rebid-pivotality unit-days: %d\n", nrow(r)))

# ---------------------------------------------------------------------------
# 1. Rebid intensity ~ pivotality (unit + month FE, cluster month)
# ---------------------------------------------------------------------------
g1 <- feols(n_versions ~ piv_share | DUID + yyyymm, r, vcov=~yyyymm)
g2 <- feols(n_versions ~ pex_share | DUID + yyyymm, r, vcov=~yyyymm)
g3 <- feols(n_versions ~ nonsync_100 | DUID + yyyymm, r, vcov=~yyyymm)
# undirected days only (anticipation, not response to own direction)
g4 <- feols(n_versions ~ piv_share | DUID + yyyymm, r[directed_day==0], vcov=~yyyymm)
cat("\n=== Rebid intensity (versions/day) ~ pivotality ===\n")
etable(g1, g2, g3, g4,
       headers=c("realised","ex-ante","nonsync","realised|undirected"),
       digits=4, fitstat=~n+r2)

# ---------------------------------------------------------------------------
# 2. Intraday quantity-withholding ~ pivotality (did they pull capacity?)
#    Now with undirected-only spec (anticipation, not response to own direction).
# ---------------------------------------------------------------------------
h1  <- feols(quan_withheld ~ piv_share | DUID + yyyymm, r, vcov=~yyyymm)
h1u <- feols(quan_withheld ~ piv_share | DUID + yyyymm, r[directed_day==0], vcov=~yyyymm)
h2  <- feols(quan_withheld ~ pex_share | DUID + yyyymm, r, vcov=~yyyymm)
h2u <- feols(quan_withheld ~ pex_share | DUID + yyyymm, r[directed_day==0], vcov=~yyyymm)
cat("\n=== Intraday MAXAVAIL withdrawn (first-last) ~ pivotality ===\n")
etable(h1, h1u, h2, h2u,
       headers=c("realised|all","realised|undir","ex-ante|all","ex-ante|undir"),
       digits=4, fitstat=~n+r2)

# ---------------------------------------------------------------------------
# 2b. Price-band escalation ~ pivotality (did rebids move MW above SRMC?)
# ---------------------------------------------------------------------------
e1  <- feols(ws_escalation ~ piv_share | DUID + yyyymm, r, vcov=~yyyymm)
e1u <- feols(ws_escalation ~ piv_share | DUID + yyyymm, r[directed_day==0], vcov=~yyyymm)
e2  <- feols(ws_escalation ~ pex_share | DUID + yyyymm, r, vcov=~yyyymm)
e3  <- feols(ws_escalation ~ nonsync_100 | DUID + yyyymm, r[directed_day==0], vcov=~yyyymm)
cat("\n=== Price-band escalation (above-SRMC share last-first version) ~ pivotality ===\n")
etable(e1, e1u, e2, e3,
       headers=c("realised|all","realised|undir","ex-ante|all","nonsync|undir"),
       digits=4, fitstat=~n+r2)
cat(sprintf("\nmean ws_escalation: %.4f (>0 = rebids net-move capacity above SRMC over the day)\n",
            mean(r$ws_escalation, na.rm=TRUE)))

# ---------------------------------------------------------------------------
# 3. Figure: rebid intensity by pivotal-share decile, pivotal-capable units
# ---------------------------------------------------------------------------
cap <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","MINTARO")
rc <- r[DUID %in% cap]
# bin by pivotal share into 0, and tertiles of the positive part (zeros dominate)
rc[, piv_grp := fifelse(piv_share==0, "0",
                 fifelse(piv_share<=0.33,"(0,.33]",
                  fifelse(piv_share<=0.67,"(.33,.67]",">.67")))]
rc[, piv_grp := factor(piv_grp, levels=c("0","(0,.33]","(.33,.67]",">.67"))]
gd <- rc[, .(quan_withheld=mean(quan_withheld,na.rm=TRUE),
             n_versions=mean(n_versions), n=.N), by=piv_grp][order(piv_grp)]
p <- ggplot(gd, aes(piv_grp, quan_withheld)) +
  geom_col(fill="#d7191c", alpha=0.8) +
  labs(title="Intraday capacity withdrawal rises with system-strength pivotality",
       subtitle="Pivotal-capable units. y = mean MAXAVAIL withdrawn intraday (first-version minus last, MW); x = pivotal share of day.",
       x="Pivotal share of the day", y="Mean MAXAVAIL withdrawn (MW)") +
  theme_bw(base_size=11) + theme(plot.subtitle=element_text(size=8,colour="grey30"))
ggsave(file.path(OUT,"Rebid_vs_pivotality.png"), p, width=8, height=5.5, dpi=150)
cat("\nSaved Rebid_vs_pivotality.png\n")
fwrite(r[, .(DUID, td, station, n_versions, quan_withheld, ws_escalation, piv_share,
             pex_share, nonsync_mean, directed_day)], file.path(OUT, "rebid_pivotality_daily.csv"))
saveRDS(r, file.path(OUT, "rebid_pivotality_daily.rds"))
cat("Saved rebid_pivotality_daily.{csv,rds}\n")
