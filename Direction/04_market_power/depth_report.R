#!/usr/bin/env Rscript
# depth_report.R
# Reports the depth-of-pivotality measure built in pivotality.R:
#   (1) regression test: depth_ex==0 reproduces the binary ex-ante pivotal flag (pex);
#   (2) station-level DISTRIBUTION of depth (k_i), exante (primary) and realised;
#   (3) crosstab of depth against the non-sync penetration tier.
# k_i = min # rival units to remove (i excluded) before the fleet satisfies no
# applicable combination. k=0 => i essential (pivotal); larger k => more redundant.

suppressMessages(library(data.table))
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"
p <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
stopifnot(any(grepl("^depth_ex_", names(p))))

STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
# focal pivotal-capable stations (others are ~never pivotal)
FOCAL <- c("torrens_island_b","pelican_point_gt","mintaro","quarantine_5")

# ---- (1) regression test: depth_ex==0 <=> pex (exact) ----------------------
cat("================ (1) REGRESSION TEST: depth_ex==0  <=>  pex ================\n")
ok <- TRUE
for (s in STATIONS) {
  mm <- p[[paste0("depth_ex_", s)]] == 0L
  pp <- as.logical(p[[paste0("pex_", s)]])
  agree <- all(mm == pp)
  ok <- ok && agree
  cat(sprintf("  %-20s identical(depth_ex==0, pex): %s  (pex share %.3f%%)\n",
              s, agree, 100*mean(pp)))
}
cat(sprintf("ALL STATIONS PASS: %s\n", ok))
# realised: depth_rl==0 is the station-level (all-of-i removed) online-pivotal flag;
# it is NOT the one-unit base piv for multi-unit stations -> report the gap, don't assert.
cat("\n[note] depth_rl==0 is station-level online pivotality (all units of i removed),\n")
cat("       distinct from the one-unit base piv for multi-unit stations (TIB, Dry Creek):\n")
for (s in c("torrens_island_b","pelican_point_gt")) {
  cat(sprintf("  %-20s depth_rl==0 share %.2f%% vs base piv share %.2f%%\n",
              s, 100*mean(p[[paste0("depth_rl_",s)]]==0L), 100*mean(p[[paste0("piv_",s)]])))
}

# ---- (2) station-level depth distribution ----------------------------------
depth_dist <- function(prefix, label) {
  cat(sprintf("\n================ (2) DEPTH DISTRIBUTION (%s) ================\n", label))
  cat("k=0 is pivotal; columns show share of intervals at each depth, by station.\n")
  rows <- lapply(FOCAL, function(s){
    k <- p[[paste0(prefix, s)]]
    kc <- pmin(k, 6L)                       # bucket tail at >=6 for display
    tb <- prop.table(table(factor(kc, levels=0:6)))
    dt <- as.data.table(as.list(round(100*as.numeric(tb),2)))
    setnames(dt, as.character(0:6)); dt[, station := s]
    dt[, `:=`(mean_k = round(mean(k),2), median_k = as.numeric(median(k)),
              p_pivotal = round(100*mean(k==0),2))]
    dt
  })
  d <- rbindlist(rows)
  setcolorder(d, c("station","p_pivotal","mean_k","median_k", as.character(0:6)))
  print(d); d
}
de <- depth_dist("depth_ex_", "EX-ANTE — available rivals (primary)")
dr <- depth_dist("depth_rl_", "REALISED — online rivals")
fwrite(de, file.path(OUT, "depth_distribution_exante.csv"))
fwrite(dr, file.path(OUT, "depth_distribution_realised.csv"))

# ---- (3) crosstab: depth vs non-sync tier ----------------------------------
# tiers = the combination non_sync_mw breakpoints; bucket nonsync_mw into them.
breaks <- c(-Inf, 1300, 1500, 1700, 1900, 2100, 2300, Inf)
labs   <- c("<1300","1300-1500","1500-1700","1700-1900","1900-2100","2100-2300",">2300")
p[, nstier := cut(nonsync_mw, breaks=breaks, labels=labs, right=FALSE)]
cat("\n================ (3) CROSSTAB: mean ex-ante depth by station x non-sync tier ================\n")
cat("(lower depth at higher non-sync = closer to pivotal when renewables crowd out synchronous room)\n")
ct <- p[, .(n=.N,
            TIB     = round(mean(depth_ex_torrens_island_b),2),
            Pelican = round(mean(depth_ex_pelican_point_gt),2),
            Mintaro = round(mean(depth_ex_mintaro),2),
            QPS5    = round(mean(depth_ex_quarantine_5),2)),
       by=nstier][order(nstier)]
print(ct)
fwrite(ct, file.path(OUT, "depth_by_nonsync_tier.csv"))

# also: share PIVOTAL (depth_ex==0) by tier, the binary view of the same crosstab
cat("\n-- share ex-ante PIVOTAL (depth_ex==0) by station x non-sync tier --\n")
ctp <- p[, .(n=.N,
             TIB     = round(100*mean(depth_ex_torrens_island_b==0),2),
             Pelican = round(100*mean(depth_ex_pelican_point_gt==0),2),
             Mintaro = round(100*mean(depth_ex_mintaro==0),2)),
        by=nstier][order(nstier)]
print(ctp)
fwrite(ctp, file.path(OUT, "depth_pivotal_share_by_tier.csv"))

cat("\nDONE -> depth_distribution_{exante,realised}.csv, depth_by_nonsync_tier.csv, depth_pivotal_share_by_tier.csv\n")
