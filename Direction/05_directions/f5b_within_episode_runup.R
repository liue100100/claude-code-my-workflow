#!/usr/bin/env Rscript
# f5b_within_episode_runup.R
# Within-episode run-up trajectory (resolves the F5 composition problem).
#
# Problem with the pooled-bin plot (f5_runup_supply_curves.R): each lead-time bin is
# populated by a DIFFERENT, self-selected subset of episodes (near-issue bins hold only
# the episodes that happened to rebid then), so pooled medians can't separate
# "withdrawal within every episode" from "the near bin is high-withholding episodes".
#
# Fix: for each episode, carry its LAST-KNOWN bid version forward to every point on a
# common event-time grid (Delta = submission - issue, hours). An episode with no rebid
# in a window still has a defined offer there (its standing bid). Summarise the offer at
# each Delta, then average across a FIXED set of episodes (those with a baseline at the
# earliest grid point). Also report the within transform: metric minus the episode's own
# baseline -> immune to composition.
#
# Metrics per (episode, Delta), from the offer for the directed window g in [s,c]:
#   cheap_share  = capacity offered at/below SRMC, as share of registered cap  (the cheap tranche)
#   avail_frac   = MAXAVAIL / registered cap                                   (quantity margin)
#   above_avail  = capacity priced above SRMC, as share of MAXAVAIL            (price margin)
# Run-up prediction: cheap_share falls, avail_frac falls, above_avail rises toward issue.
#
# Reads outputs/direction_rebid/f5_ver.rds (per episode-version band profiles). No re-scan.
# Run from Direction/. Outputs to outputs/direction_rebid/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/direction_rebid"

GRID   <- c(-24,-18,-12,-9,-6,-4,-3,-2,-1,0)   # hours before issue (baseline = -24)
BASE   <- min(GRID)
MIN_EP <- 10L                                   # min fixed-set episodes to plot a unit
bcols <- paste0("BANDAVAIL",1:10); pcols <- paste0("PRICEBAND",1:10)

UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
           "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
cap95 <- readRDS("outputs/descriptives_v3/panel_v3.rds")[
  duid %in% UNITS, .(cap = as.numeric(quantile(MAXAVAIL,0.95,na.rm=TRUE))), by=duid][cap>0]

ver <- as.data.table(readRDS(file.path(OUT,"f5_ver.rds")))
ver <- merge(ver, cap95, by.x="DUID", by.y="duid")

# ---- per-version withholding metrics (cumulative offer capped at MAXAVAIL) ----
BA <- as.matrix(ver[, ..bcols]); BA[is.na(BA)] <- 0
PB <- as.matrix(ver[, ..pcols])
SR <- ver$srmc; MA <- ver$MAXAVAIL; CAP <- ver$cap
valid <- is.finite(SR) & SR>0 & is.finite(MA) & rowSums(is.na(PB))==0
cumBA <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1]+BA[,j]
cumBA_eff <- pmin(cumBA, MA)
effBA <- cumBA_eff; effBA[,2:10] <- cumBA_eff[,2:10]-cumBA_eff[,1:9]
below <- rowSums(effBA * (PB <= SR))          # MW offered at/below SRMC (of available)
above <- rowSums(effBA * (PB >  SR))          # MW offered above SRMC
ver[, cheap_share := pmin(pmax(below/CAP,0),1)]
ver[, avail_frac  := pmin(pmax(MA/CAP,0),1)]
ver[, above_avail := fifelse(MA>1, above/MA, NA_real_)]
ver <- ver[valid]
cat(sprintf("Valid versions: %d (dropped %d for NA ladder / bad SRMC-MAXAVAIL)\n",
            nrow(ver), sum(!valid)))

# ---- carry-forward: active version at each grid Delta, per episode (rolling join, LOCF) ----
vv <- ver[, .(DUID, episode_id, delta_h, cheap_share, avail_frac, above_avail)]
setkey(vv, DUID, episode_id, delta_h)
q <- unique(vv[, .(DUID, episode_id)])[, .(delta_star = GRID), by=.(DUID, episode_id)]
q[, delta_h := delta_star]; setkey(q, DUID, episode_id, delta_h)
traj <- vv[q, roll = TRUE]                     # LOCF: last version with delta_h <= delta_star
traj[, delta_star := delta_h]

# ---- fixed set: episodes with a defined (carried) offer at EVERY grid point ----
# equivalently: a baseline version at or before the earliest grid point.
defined_all <- traj[, .(ok = all(!is.na(cheap_share))), by=.(DUID, episode_id)]
fixed <- defined_all[ok == TRUE, .(DUID, episode_id)]
traj <- merge(traj, fixed, by=c("DUID","episode_id"))

cov <- merge(unique(vv[,.(DUID, episode_id)])[, .(episodes_ver=uniqueN(episode_id)), by=DUID],
             fixed[, .(fixed_set=uniqueN(episode_id)), by=DUID], by="DUID", all.x=TRUE)
cov <- cov[order(match(DUID, UNITS))]
cat("\n=== Fixed-set coverage (episodes defined at ALL grid points) ===\n"); print(cov)

# ---- within transform: each episode minus its own baseline at Delta = -24 ----
base_val <- traj[delta_star == BASE, .(DUID, episode_id,
                 b_cheap=cheap_share, b_avail=avail_frac, b_above=above_avail)]
traj <- merge(traj, base_val, by=c("DUID","episode_id"))
traj[, `:=`(d_cheap = cheap_share - b_cheap,
            d_avail = avail_frac - b_avail,
            d_above = above_avail - b_above)]

# ---- aggregate across the fixed set at each Delta (mean +- SE) ----
agg <- function(v, se){ list(m=mean(v,na.rm=TRUE), s=sd(v,na.rm=TRUE)/sqrt(sum(!is.na(v)))) }
TR <- traj[, {
  c(setNames(as.list(unlist(lapply(.(cheap_share,avail_frac,above_avail,d_cheap,d_avail,d_above),
      function(v) c(mean(v,na.rm=TRUE), sd(v,na.rm=TRUE)/sqrt(sum(!is.na(v))))))),
    c("cheap_m","cheap_se","avail_m","avail_se","above_m","above_se",
      "dcheap_m","dcheap_se","davail_m","davail_se","dabove_m","dabove_se")),
    n_ep = .(uniqueN(episode_id)))
}, by=.(DUID, delta_star)]
TR <- merge(TR, cov[, .(DUID, fixed_set)], by="DUID")
TR <- TR[fixed_set >= MIN_EP]
fwrite(TR, file.path(OUT, "f5b_within_episode_runup.csv"))
UNIT_ORDER <- UNITS[UNITS %in% unique(TR$DUID)]
TR[, DUID := factor(DUID, levels=UNIT_ORDER)]

cat("\n=== Within-episode trajectory (fixed set), TORRB units ===\n")
print(TR[DUID %in% c("TORRB2","TORRB3","TORRB4"),
         .(DUID, delta_star, n_ep=unlist(n_ep),
           cheap=round(cheap_m,3), d_cheap=round(dcheap_m,3),
           avail=round(avail_m,3), d_avail=round(davail_m,3))][order(DUID,delta_star)])

# ---- plots ----
mk <- function(ycol, secol, ylab, ttl, sub, hline0=FALSE, pctfmt=TRUE){
  p <- ggplot(TR, aes(delta_star, get(ycol))) +
    geom_ribbon(aes(ymin=get(ycol)-1.96*get(secol), ymax=get(ycol)+1.96*get(secol)),
                alpha=0.15, fill="firebrick") +
    geom_line(colour="firebrick", linewidth=0.9) + geom_point(colour="firebrick", size=1.2) +
    geom_vline(xintercept=0, linetype="dashed", colour="grey40") +
    facet_wrap(~DUID, ncol=4, scales="free_y") +
    labs(title=ttl, subtitle=sub, x="Delta = submission - issue (hours; 0 = direction issued)", y=ylab) +
    theme_bw(base_size=10) + theme(strip.text=element_text(size=9))
  if (hline0) p <- p + geom_hline(yintercept=0, linetype="dotted", colour="grey50")
  if (pctfmt) p <- p + scale_y_continuous(labels=scales::percent_format(accuracy=1))
  p
}
ggsave(file.path(OUT,"f5b_cheap_share_level.png"),
       mk("cheap_m","cheap_se","Cheap tranche (offered <= SRMC, share of reg. cap)",
          "Within-episode run-up: cheap tranche vs lead time to direction issue",
          "Fixed episode set, carried-forward offers. Mean +/- 95% CI across episodes. Falling = cheap tranche withdrawn."),
       width=14, height=8, dpi=150)
ggsave(file.path(OUT,"f5b_cheap_share_change.png"),
       mk("dcheap_m","dcheap_se","Change in cheap tranche vs episode baseline (-24h)",
          "Within-episode run-up (composition-proof): change in cheap tranche from -24h baseline",
          "Each episode minus its own -24h value, then averaged. Fixed set. Negative = withdrawing the cheap tranche as issue nears.",
          hline0=TRUE),
       width=14, height=8, dpi=150)
ggsave(file.path(OUT,"f5b_avail_frac_change.png"),
       mk("davail_m","davail_se","Change in MAXAVAIL/reg.cap vs -24h baseline",
          "Within-episode run-up (composition-proof): change in available capacity from -24h baseline",
          "Quantity margin. Each episode minus its own -24h value, averaged. Fixed set. Negative = withdrawing MAXAVAIL as issue nears.",
          hline0=TRUE),
       width=14, height=8, dpi=150)
cat("\nSaved f5b_{cheap_share_level,cheap_share_change,avail_frac_change}.png and .csv\n")
