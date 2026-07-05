#!/usr/bin/env Rscript
# wo_stage2_opportunity.R  --  Stage 2 of the withhold-to-be-directed design (circularity-critical).
#
# Builds, per focus unit and 5-min interval:
#   opportunity flag = ex-ante essentiality pex_station == TRUE
#     (a) "would-be pivotal": system infeasible without the station given RIVALS' realised online
#         status + realised non-sync. The focal station is removed in pex -> its own offer/MAXAVAIL
#         NEVER enters. This is the Threat-A guard.
#     (b) direction-likely-on-security inputs RECORDED per interval (nonsync, short, depth_ex, min-combo
#         regime). NB: pex is derived from the min-combo file + realised nonsync, so (a) and (b) are not
#         fully independent with current data (no extracted pre-dispatch forecasts) -- LIMITATION, flagged.
#   + a matched NON-opportunity comparison set (CEM on unit x month x nonsync-quintile x hour-block).
#   + the mandated leakage audit: opp ~ realised MAXAVAIL and opp ~ realised cheap tranche (must be ~null).
#
# Caches a full-regime per-interval table (cheap tranche + state + realised outcome) for Stages 3-4.
# Run from Direction/. Outputs to outputs/withhold_opportunity/.

suppressMessages({ library(data.table) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/withhold_opportunity"; CACHE <- "bid_cache"

FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")   # BARKIPS1 excluded (Stage 1)
station <- c(TORRB2="torrens_island_b", TORRB3="torrens_island_b", TORRB4="torrens_island_b",
             PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st")
TROUGH <- c(TORRB2=170, TORRB3=131, TORRB4=171, PPCCGT=180, `OSB-AG`=90)  # provisional (Stage 3 sweeps)
MIN_TEST_N <- 30L
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
force10 <- function(x){ x <- as.POSIXct(x); attr(x,"tzone") <- "Etc/GMT-10"; x }

# ---- state inputs (realised-derived proxies; look-ahead acknowledged) ----
piv <- readRDS("outputs/descriptives_v3/pivotality_panel.rds"); piv[, interval_dt := force10(SETTLEMENTDATE)]
pex_l <- rbindlist(lapply(FOCUS, function(u) data.table(
  duid=u, interval_dt=piv$interval_dt,
  pex     = piv[[paste0("pex_",     station[[u]])]],
  piv_rl  = piv[[paste0("piv_",     station[[u]])]],
  depth_ex= piv[[paste0("depth_ex_",station[[u]])]],
  nonsync = piv$nonsync_mw, short = piv$short)))
tp <- readRDS("direction_data/parsed/treatment_panel.rds")[
  duid %in% FOCUS, .(duid, interval_dt=force10(interval_datetime), directed, synchronise)]
dt_s <- readRDS("outputs/descriptives/gate0_dt_series.rds")[, .(yyyymm=as.integer(yyyymm), dt=dt_recon)]
srmc <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  duid %in% FOCUS, .(duid, yyyymm=as.integer(yyyymm), srmc=srmc_marginal)]

# ---- scan bids: cheap tranche + realised MAXAVAIL per focus interval (all regimes) ----
months <- sprintf("%d%02d", rep(2022:2024,each=12), rep(1:12,3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]
lst <- vector("list", length(months))
for (i in seq_along(months)) {
  M <- months[i]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by=.(DUID, INTERVAL_DATETIME)]$V1]
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with=FALSE]
  bop[, td := as.Date(TRADINGDATE)]
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID, SETTLEMENTDATE)]$V1]; bdo[, td := as.Date(SETTLEMENTDATE)]
  m <- merge(bop, bdo[, c("DUID","td",pb_cols), with=FALSE], by=c("DUID","td"), all.x=TRUE)
  m <- m[MAXAVAIL >= 0 & !is.na(PRICEBAND1)]
  BA <- as.matrix(m[, ..ba_cols]); BA[is.na(BA)] <- 0; PB <- as.matrix(m[, ..pb_cols]); MA <- m$MAXAVAIL
  cumBA <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1]+BA[,j]
  eff <- pmin(cumBA, MA)
  cheap300 <- rowSums({e<-eff; e[,2:10]<-eff[,2:10]-eff[,1:9]; e} * (PB<=300))
  lst[[i]] <- data.table(duid=m$DUID, interval_dt=force10(m$INTERVAL_DATETIME),
                         yyyymm=as.integer(M), MAXAVAIL=MA, cheap300=cheap300)
  cat(sprintf("  [%s] %d focus intervals\n", M, nrow(m)))
}
X <- rbindlist(lst)
X <- merge(X, pex_l, by=c("duid","interval_dt"), all.x=TRUE)
X <- merge(X, tp,    by=c("duid","interval_dt"), all.x=TRUE)
X[is.na(directed), directed:=0L]; X[is.na(synchronise), synchronise:=0L]
X <- merge(X, dt_s,  by="yyyymm", all.x=TRUE)
X <- merge(X, srmc,  by=c("duid","yyyymm"), all.x=TRUE)
X[, opp := (pex==TRUE)]
X[, hour := as.integer(format(interval_dt,"%H"))]
X[, hour_block := cut(hour, c(-1,6,12,18,24), labels=c("0-6","6-12","12-18","18-24"))]
saveRDS(X, file.path(OUT, "stage2_panel.rds"))
cat(sprintf("\nFull focus panel: %d rows | opp(pex) TRUE: %d\n", nrow(X), sum(X$opp, na.rm=TRUE)))

# ---- opportunity set size + (b) input distribution + as-usual presence ----
opp_summ <- X[, {
  o <- .SD[opp==TRUE]
  .(n_opp = nrow(o),
    n_total = .N,
    opp_rate_pct = round(100*mean(opp, na.rm=TRUE),2),
    nonsync_med_opp = round(median(o$nonsync)), depth_med_opp = round(median(o$depth_ex),1),
    short_share_opp = round(100*mean(o$short),1),
    dt_med_opp = round(median(o$dt)),
    cheap_med_opp = round(median(o$cheap300)),
    asusual_share_opp = round(100*mean(o$cheap300 >= TROUGH[[.BY$duid]]),1),  # must be >0 (else circular)
    withheld_share_opp= round(100*mean(o$cheap300 <  TROUGH[[.BY$duid]]),1),
    directed_share_opp= round(100*mean(o$directed),1))
}, by=duid][order(match(duid,FOCUS))]
opp_summ[, testable := fifelse(n_opp>=MIN_TEST_N, "TEST", "DESCRIPTIVE_ONLY")]
fwrite(opp_summ, file.path(OUT, "stage2_opportunity_summary.csv"))
cat("\n=== STAGE 2: opportunity set (pex==TRUE) per unit ===\n"); print(opp_summ)

# ---- LEAKAGE AUDIT: opp must NOT be predicted by focal realised MAXAVAIL / cheap tranche ----
cat("\n=== LEAKAGE AUDIT: opp ~ realised MAXAVAIL and opp ~ realised cheap300 (want ~null) ===\n")
aud <- X[, {
  f1 <- lm(as.integer(opp) ~ MAXAVAIL); f2 <- lm(as.integer(opp) ~ cheap300)
  .(b_MAXAVAIL = signif(coef(f1)[["MAXAVAIL"]],3), r2_MAXAVAIL = round(summary(f1)$r.squared,4),
    b_cheap300 = signif(coef(f2)[["cheap300"]],3), r2_cheap300 = round(summary(f2)$r.squared,4),
    cor_opp_MAXAVAIL = round(cor(as.integer(opp), MAXAVAIL, use="complete.obs"),3),
    cor_opp_cheap    = round(cor(as.integer(opp), cheap300, use="complete.obs"),3))
}, by=duid][order(match(duid,FOCUS))]
fwrite(aud, file.path(OUT, "stage2_leakage_audit.csv")); print(aud)
cat("PASS criterion: |cor| small and R2 ~ 0 -> realised own-offer does not determine the opportunity set.\n")

# ---- (3) MATCHED non-opportunity comparison set (CEM) ----
X[, nsq := cut(nonsync, quantile(nonsync, seq(0,1,.2), na.rm=TRUE), include.lowest=TRUE, labels=1:5)]
X[, stratum := paste(duid, yyyymm, nsq, hour_block, sep="|")]
strata_ok <- X[, .(nopp=sum(opp==TRUE), ncmp=sum(opp==FALSE)), by=stratum][nopp>0 & ncmp>0, stratum]
X[, matched := stratum %in% strata_ok]
X[, comparison := (opp==FALSE & matched)]
cmp_summ <- X[matched==TRUE, .(
  n_opp_matched = sum(opp==TRUE),
  n_comparison  = sum(comparison),
  strata = uniqueN(stratum)), by=duid][order(match(duid,FOCUS))]
opp_total <- X[, .(n_opp=sum(opp==TRUE)), by=duid]
cmp_summ <- merge(opp_total, cmp_summ, by="duid", all.x=TRUE)
cmp_summ[, opp_matched_pct := round(100*n_opp_matched/n_opp,1)]
fwrite(cmp_summ, file.path(OUT, "stage2_matched_comparison.csv"))
cat("\n=== (3) Matched non-opportunity comparison set (CEM: unit x month x nonsync-quintile x hour-block) ===\n")
print(cmp_summ)
saveRDS(X, file.path(OUT, "stage2_panel.rds"))  # re-save with matched/stratum cols
cat("\nSaved stage2_panel.rds + summaries. STOP for Stage-2 sense-check review.\n")
