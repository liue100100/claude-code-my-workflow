#!/usr/bin/env Rscript
# pivotality_analysis.R
# Bidding behaviour: pivotal vs non-pivotal, REALISED and EX-ANTE pivotality.
#   realised piv_*  : uses the unit's own online status (endogenous: withhold->direct->online->pivotal)
#   ex-ante  pex_*  : essential given RIVALS' availability only (exogenous to own withholding)
# Test of the withholding-to-be-directed channel; report directed/undirected split.

suppressMessages({ library(data.table); library(fixest); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"

piv   <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
panel <- as.data.table(readRDS(file.path(OUT, "panel_v3.rds")))

STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips")

# long pivotality keyed by (SETTLEMENTDATE, station) carrying realised + ex-ante + tightness
stations <- unique(STAT)
piv_long <- rbindlist(lapply(stations, function(s)
  data.table(SETTLEMENTDATE = piv$SETTLEMENTDATE, station = s,
             pivotal  = as.integer(piv[[paste0("piv_", s)]]),
             pivotal_ex = as.integer(piv[[paste0("pex_", s)]]),
             nonsync_mw = piv$nonsync_mw, short = piv$short)))

panel[, station := STAT[as.character(duid)]]
panel[, SETTLEMENTDATE := interval_dt]
m <- merge(panel[!is.na(station)], piv_long, by = c("SETTLEMENTDATE","station"))
m <- m[!is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1]
m[, dt_std := (dt - mean(dt)) / sd(dt)]
m[, nonsync_100 := nonsync_mw / 100]

cat(sprintf("Panel: %d rows, %d months, %d units | pivotal(realised) %.1f%%  pivotal(ex-ante) %.1f%%\n",
            nrow(m), uniqueN(m$yyyymm), uniqueN(m$duid),
            100*mean(m$pivotal), 100*mean(m$pivotal_ex)))

# ---------------------------------------------------------------------------
# 1. Level effect: realised vs ex-ante, all vs undirected
# ---------------------------------------------------------------------------
L <- function(var, sub) {
  d <- if (sub=="undirected") m[directed==0] else m
  f <- feols(as.formula(sprintf("withheld_share ~ %s + srmc_marginal + spot | duid", var)),
             d, vcov = ~yyyymm)
  data.table(treatment=var, sample=sub,
             coef=round(coef(f)[[var]],4), se=round(se(f)[[var]],4),
             t=round(coef(f)[[var]]/se(f)[[var]],1), n=f$nobs)
}
lvl <- rbindlist(list(
  L("pivotal","all"), L("pivotal","undirected"),
  L("pivotal_ex","all"), L("pivotal_ex","undirected")))
cat("\n=== Level effect on withheld_share (unit FE, +SRMC+spot, cluster month) ===\n"); print(lvl)
fwrite(lvl, file.path(OUT, "Pivotality_level_effects.csv"))

# ---------------------------------------------------------------------------
# 2. Continuous exogenous driver: non-sync penetration (fleet tightness)
#    Higher non-sync -> more units pivotal. Exogenous (weather/demand-driven).
# ---------------------------------------------------------------------------
f_ns <- feols(withheld_share ~ nonsync_100 + srmc_marginal + spot | duid, m[directed==0], vcov=~yyyymm)
cat(sprintf("\nNon-sync penetration (undirected): per +100MW non-sync, withheld_share %+.4f (t %.1f)\n",
            coef(f_ns)[["nonsync_100"]], coef(f_ns)[["nonsync_100"]]/se(f_ns)[["nonsync_100"]]))

# ---------------------------------------------------------------------------
# 3. d_t x pivotal interaction (realised + ex-ante), undirected
# ---------------------------------------------------------------------------
f_re <- feols(withheld_share ~ dt_std*pivotal    + srmc_marginal + spot | duid, m[directed==0], vcov=~yyyymm)
f_ex <- feols(withheld_share ~ dt_std*pivotal_ex + srmc_marginal + spot | duid, m[directed==0], vcov=~yyyymm)
cat("\n=== d_t x pivotal interaction (undirected) ===\n")
etable(f_re, f_ex, headers=c("realised","ex-ante"), digits=4, fitstat=~n+r2)

# ---------------------------------------------------------------------------
# 4. Figure: within pivotal-capable units, withheld_share by pivotal state
# ---------------------------------------------------------------------------
cap_units <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","MINTARO","QPS5")
cells <- m[duid %in% cap_units & directed==0,
           .(mean_ws = mean(withheld_share), n=.N), by=.(duid, pivotal)]
cells[, Pivotal := fifelse(pivotal==1L,"Pivotal","Not pivotal")]
p <- ggplot(cells, aes(factor(duid, levels=cap_units), mean_ws, fill=Pivotal)) +
  geom_col(position="dodge") +
  scale_fill_manual(values=c("Pivotal"="#d7191c","Not pivotal"="#2c7bb6"), name=NULL) +
  scale_y_continuous(labels=scales::percent_format(accuracy=1)) +
  labs(title="Withholding when pivotal vs not — undirected, market-facing intervals",
       subtitle="Within-unit comparison; realised pivotality. TIB/Pelican withhold sharply more when pivotal.",
       x=NULL, y="Mean withheld_share") +
  theme_bw(base_size=11) + theme(legend.position="bottom",
       plot.subtitle=element_text(size=8,colour="grey30"))
ggsave(file.path(OUT,"Pivotality_withholding_bars.png"), p, width=9, height=5.5, dpi=150)
cat("\nSaved Pivotality_withholding_bars.png\n")

saveRDS(m[, .(duid, yyyymm, SETTLEMENTDATE, td=as.IDate(SETTLEMENTDATE),
              withheld_share, dt, dt_std, srmc_marginal, spot, directed,
              pivotal, pivotal_ex, nonsync_mw, short)],
        file.path(OUT, "pivotality_analysis_panel.rds"))
cat("Saved pivotality_analysis_panel.rds\n")
