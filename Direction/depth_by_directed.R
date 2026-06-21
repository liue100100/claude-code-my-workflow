#!/usr/bin/env Rscript
# depth_by_directed.R
# Distribution of depth-of-pivotality k by station, as COUNTS and as shares of
#   (1) ALL intervals, and (2) that station's DIRECTED intervals.
# Lets us see: at what depth are units actually directed? (k=0 essential ... high k redundant)

suppressMessages(library(data.table))
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"
p <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
TOT <- nrow(p)

# ---- directed station-intervals (union of direction events; like the decomposition) ----
STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek", BARKIPS1="bips")
ev <- as.data.table(readRDS("direction_data/parsed/direction_events.rds"))
ev <- ev[!is.na(duid)]
for (b in names(c(TORRB35="TORRB3",TORRB46="TORRB4",MINTARO1="MINTARO")))
  ev[duid==b, duid := c(TORRB35="TORRB3",TORRB46="TORRB4",MINTARO1="MINTARO")[[b]]]
ev[, station := STAT[as.character(duid)]]
ev <- ev[!is.na(station)]
ev[, dur_hrs := as.numeric(difftime(cancellation_time, effective_time, units="hours"))]
ev <- ev[dur_hrs > 0]
ev[, first_intv := (floor(as.numeric(effective_time)/300)+1)*300]
ev[, last_intv  :=  floor(as.numeric(cancellation_time)/300)*300]
ev <- ev[last_intv >= first_intv]
exp <- rbindlist(lapply(seq_len(nrow(ev)), function(i)
  data.table(station=ev$station[i], secs=seq.int(ev$first_intv[i], ev$last_intv[i], by=300L))))
exp[, SETTLEMENTDATE := as.POSIXct(secs, origin="1970-01-01", tz="Etc/GMT-10")]
directed <- unique(exp[, .(SETTLEMENTDATE, station)])

FOCAL <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
           "dry_creek","mintaro","bips","snapper_point")
KCAP <- 8L                                   # bucket k >= KCAP as the tail row

dist_table <- function(prefix, label) {
  cat(sprintf("\n=================== DEPTH DISTRIBUTION (%s) ===================\n", label))
  for (s in FOCAL) {
    k_all <- pmin(p[[paste0(prefix, s)]], KCAP)
    dir_s <- directed[station==s]
    pk <- p[, .(SETTLEMENTDATE, k = pmin(get(paste0(prefix, s)), KCAP))]
    k_dir <- pk[dir_s, on="SETTLEMENTDATE", nomatch=0L]$k
    TOTDIR <- length(k_dir)
    lv <- 0:KCAP
    tab <- data.table(
      k          = ifelse(lv==KCAP, paste0(KCAP,"+"), as.character(lv)),
      n_all      = as.integer(table(factor(k_all, levels=lv))),
      n_directed = as.integer(table(factor(k_dir, levels=lv))))
    tab[, `pct_of_all(%)`      := round(100*n_all/TOT, 2)]
    tab[, `pct_of_directed(%)` := round(100*n_directed/TOTDIR, 2)]
    cat(sprintf("\n--- %s | total intervals=%d | directed intervals=%d (%.1f%% of all) ---\n",
                toupper(s), TOT, TOTDIR, 100*TOTDIR/TOT))
    print(tab[, .(k, n_all, `pct_of_all(%)`, n_directed, `pct_of_directed(%)`)])
    fwrite(tab, file.path(OUT, sprintf("depth_dist_%s_%s.csv", sub("depth_","",sub("_$","",prefix)), s)))
  }
}
dist_table("depth_ex_", "EX-ANTE — available rivals (primary)")
dist_table("depth_rl_", "REALISED — online rivals")
cat("\nDONE. CSVs: depth_dist_ex_<station>.csv, depth_dist_rl_<station>.csv\n")
