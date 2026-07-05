#!/usr/bin/env Rscript
# wo_stage1_baseline.R  --  Stage 1 of the withhold-to-be-directed design.
# Counterfactual "normal" bid per focus unit, from its UNDIRECTED, NON-PIVOTAL behaviour.
#
# Baseline regime: directed==0 & realised piv_*==FALSE & MAXAVAIL>1 (available & competitive).
#   Realised pivotality is used ONLY to select the unit's competitive reference behaviour here;
#   it does NOT enter the Stage-2 opportunity set. (Hybrid decision: realised-state proxy, look-ahead
#   in state variables acknowledged; own-offer leakage is what Stage 2 guards + audits.)
#
# Per unit outputs:
#   - baseline offer curve: median cumulative available MW offered at <= each price grid point (+ IQR)
#   - "normal cheap capacity" = effective MW offered at <= threshold (default $300); median + IQR
#   - n undirected-non-pivotal intervals defining the baseline; availability rate; stability (IQR)
# Raw $/MWh throughout. Thresholds tunable. Caches per-interval UN table for Stage 2.
#
# Run from Direction/. Outputs to outputs/withhold_opportunity/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/withhold_opportunity"; CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG","BARKIPS1")
duid2piv <- c(TORRB2="piv_torrens_island_b", TORRB3="piv_torrens_island_b",
              TORRB4="piv_torrens_island_b", PPCCGT="piv_pelican_point_gt",
              `OSB-AG`="piv_osborne_gt_st", BARKIPS1="piv_bips")
THRESH     <- c(200, 300, 500)                    # cheap-capacity price cutoffs ($/MWh); 300 = default
PGRID      <- c(0,50,100,150,200,250,300,400,500,1000,5000,16000)   # baseline offer-curve price grid
MIN_BASE_N <- 500L                                 # below this -> flag/exclude from Stage 2
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
force10 <- function(x){ x <- as.POSIXct(x); attr(x,"tzone") <- "Etc/GMT-10"; x }

# ---- regime inputs (realised) ----
tp <- readRDS("direction_data/parsed/treatment_panel.rds")[
  duid %in% FOCUS, .(duid, interval_dt = force10(interval_datetime), directed)]
piv <- readRDS("outputs/descriptives_v3/pivotality_panel.rds")
piv[, interval_dt := force10(SETTLEMENTDATE)]
pv <- rbindlist(lapply(FOCUS, function(u)
  data.table(duid = u, interval_dt = piv$interval_dt, pivotal = piv[[duid2piv[[u]]]])))
srmc <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  duid %in% FOCUS, .(duid, yyyymm = as.integer(yyyymm), srmc = srmc_marginal)]

# tz assertion on a known directed interval
stopifnot(nrow(tp[directed==1]) > 0)
cat("tz check: treatment interval sample", format(tp$interval_dt[1]),
    "| pivotality sample", format(piv$interval_dt[1]), "(both must read as UTC+10)\n")

months <- sprintf("%d%02d", rep(2022:2024, each=12), rep(1:12,3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]

per_int <- vector("list", length(months))
join_report <- vector("list", length(months))
for (i in seq_along(months)) {
  M <- months[i]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  n_raw <- nrow(bop)
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by=.(DUID, INTERVAL_DATETIME)]$V1]  # in-force version
  n_inforce <- nrow(bop)
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with=FALSE]
  bop[, interval_dt := force10(INTERVAL_DATETIME)]; bop[, td := as.Date(TRADINGDATE)]

  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID, SETTLEMENTDATE)]$V1]   # latest daily ladder
  bdo[, td := as.Date(SETTLEMENTDATE)]
  # ASSERT one ladder per (DUID, day)
  dup <- bdo[, .N, by=.(DUID, td)][N>1]; if (nrow(dup)) stop("dup ladder per DUID-day")

  m <- merge(bop, bdo[, c("DUID","td", pb_cols), with=FALSE], by=c("DUID","td"), all.x=TRUE)
  m <- merge(m, tp,  by.x=c("DUID","interval_dt"), by.y=c("duid","interval_dt"), all.x=TRUE)
  m <- merge(m, pv,  by.x=c("DUID","interval_dt"), by.y=c("duid","interval_dt"), all.x=TRUE)
  m[is.na(directed), directed := 0L]; m[is.na(pivotal), pivotal := FALSE]
  m[, yyyymm := as.integer(M)]
  m <- merge(m, srmc, by.x=c("DUID","yyyymm"), by.y=c("duid","yyyymm"), all.x=TRUE)

  join_report[[i]] <- data.table(month=M, raw=n_raw, inforce=n_inforce,
                                 merged=nrow(m), no_ladder=sum(is.na(m$PRICEBAND1)),
                                 no_srmc=sum(is.na(m$srmc)))

  # UNDIRECTED, NON-PIVOTAL, AVAILABLE
  un <- m[directed==0L & pivotal==FALSE & MAXAVAIL>1 & is.finite(srmc)]
  if (!nrow(un)) next
  BA <- as.matrix(un[, ..ba_cols]); BA[is.na(BA)] <- 0
  PB <- as.matrix(un[, ..pb_cols]); MA <- un$MAXAVAIL
  cumBA <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1]+BA[,j]
  cumBA_eff <- pmin(cumBA, MA)
  effBA <- cumBA_eff; effBA[,2:10] <- cumBA_eff[,2:10]-cumBA_eff[,1:9]
  out <- data.table(DUID=un$DUID, yyyymm=un$yyyymm, MAXAVAIL=MA, srmc=un$srmc)
  for (th in THRESH) out[[paste0("cheap",th)]] <- rowSums(effBA * (PB <= th))
  for (p in PGRID)   out[[paste0("cum_",p)]]   <- rowSums(effBA * (PB <= p))
  per_int[[i]] <- out
  cat(sprintf("  [%s] focus rows %d | UN-available %d\n", M, nrow(m), nrow(un)))
}

UN <- rbindlist(per_int)
saveRDS(UN, file.path(OUT, "stage1_UN_intervals.rds"))
jr <- rbindlist(join_report); fwrite(jr, file.path(OUT, "stage1_join_report.csv"))
cat(sprintf("\nJoin totals: inforce %d | no_ladder %d (%.2f%%) | no_srmc %d\n",
            sum(jr$inforce), sum(jr$no_ladder), 100*sum(jr$no_ladder)/sum(jr$inforce), sum(jr$no_srmc)))

# ---- per-unit baseline summary ----
q1 <- function(x) as.numeric(quantile(x, .25, na.rm=TRUE))
q3 <- function(x) as.numeric(quantile(x, .75, na.rm=TRUE))
summ <- UN[, .(
  n_UN_intervals = .N,
  maxavail_med   = round(median(MAXAVAIL),1),
  cheap300_med   = round(median(cheap300),1),
  cheap300_iqr   = round(q3(cheap300)-q1(cheap300),1),
  cheap300_q1    = round(q1(cheap300),1), cheap300_q3 = round(q3(cheap300),1),
  cheap200_med   = round(median(cheap200),1),
  cheap500_med   = round(median(cheap500),1),
  srmc_med       = round(median(srmc),1)
), by=DUID][order(match(DUID,FOCUS))]
summ[, stable := fifelse(n_UN_intervals >= MIN_BASE_N, "OK", "TOO_FEW->EXCLUDE")]
summ[, iqr_over_med := round(cheap300_iqr/pmax(cheap300_med,1e-9),2)]
fwrite(summ, file.path(OUT, "stage1_baseline_summary.csv"))
cat("\n=== STAGE 1: baseline cheap capacity per unit (raw MW, default $300 cutoff) ===\n")
print(summ)

# ---- baseline offer curve (median cum MW at each price grid pt, + IQR) ----
curve <- UN[, {
  lst <- lapply(PGRID, function(p){ v <- get(paste0("cum_",p))
    list(price=p, med=median(v), q1=q1(v), q3=q3(v)) })
  rbindlist(lst)
}, by=DUID]
fwrite(curve, file.path(OUT, "stage1_baseline_curve.csv"))
curve[, DUID := factor(DUID, levels=FOCUS)]
p <- ggplot(curve, aes(price, med)) +
  geom_ribbon(aes(ymin=q1, ymax=q3), alpha=0.15, fill="steelblue") +
  geom_step(colour="steelblue", linewidth=0.8, direction="hv") +
  geom_point(size=1) +
  facet_wrap(~DUID, ncol=3, scales="free_y") +
  scale_x_continuous(trans="log1p", breaks=c(0,100,300,1000,5000,16000)) +
  scale_y_continuous(labels=scales::comma) +
  labs(title="Stage 1: baseline (normal) offer curve per unit -- undirected, non-pivotal, available",
       subtitle="Median cumulative AVAILABLE MW offered at <= price (raw $/MWh, log1p x). Ribbon = IQR across UN intervals. Dashed = $300 cheap cutoff.",
       x="Offer price ($/MWh)", y="Cumulative available MW offered at <= price") +
  geom_vline(xintercept=300, linetype="dashed", colour="grey40") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "stage1_baseline_curve.png"), p, width=13, height=8, dpi=150)
cat("\nSaved stage1_{UN_intervals.rds, baseline_summary.csv, baseline_curve.csv/png, join_report.csv}\n")
