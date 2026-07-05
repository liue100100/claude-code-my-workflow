#!/usr/bin/env Rscript
# wo_stage4b_torrb3_check.R -- diagnostic: is TORRB3's wrong-signed dt:opp coefficient (Stage 4)
# driven by a compositionally different opportunity/matched sample vs. its sister units, or is it
# genuine within-sample heterogeneity? TORRB2/3/4 share ONE station-level pex flag (torrens_island_b),
# so their raw opportunity-interval TIMING should be identical by construction; if the matched
# ESTIMATION sample differs (via per-DUID data completeness or per-DUID CEM stratum availability),
# that would be a legitimate reason the pooled/per-unit coefficients aren't comparable apples-to-apples.
#
# Run from Direction/.

suppressMessages({ library(data.table); library(fixest) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/withhold_opportunity"
sisters <- c("TORRB2","TORRB3","TORRB4")

X <- readRDS(file.path(OUT, "stage3_panel.rds"))

cat("=== (1) Are the OPPORTUNITY interval sets timing-identical across sisters? ===\n")
opp_sets <- lapply(sisters, function(u) X[duid==u & opp==TRUE, as.numeric(interval_dt)])
names(opp_sets) <- sisters
for (i in 1:2) for (j in (i+1):3) {
  a <- opp_sets[[i]]; b <- opp_sets[[j]]
  cat(sprintf("  %s vs %s: n_a=%d n_b=%d symdiff=%d\n", sisters[i], sisters[j], length(a), length(b),
              length(union(setdiff(a,b), setdiff(b,a)))))
}

cat("\n=== (2) srmc mean per sister (same station -- should be near-identical) ===\n")
print(X[duid %in% sisters, .(srmc_mean=round(mean(srmc,na.rm=TRUE),2), n_na=sum(is.na(srmc))), by=duid])

cat("\n=== (3) Row-count completeness per sister, per year (bid-record gaps?) ===\n")
X[, yr := substr(as.character(yyyymm),1,4)]
print(dcast(X[duid %in% sisters], yr ~ duid, value.var="duid", fun.aggregate=length))

cat("\n=== (4) MATCHED sample size + composition per sister (opp==TRUE & matched==TRUE) ===\n")
msumm <- X[duid %in% sisters & opp==TRUE, .(
  n_opp = .N, n_matched = sum(matched), matched_pct = round(100*mean(matched),1),
  nonsync_mean = round(mean(nonsync),0), short_share = round(100*mean(short),1),
  directed_share = round(100*mean(directed),1), dt_na_share = round(100*mean(is.na(dt)),1)
), by=duid]
print(msumm)

cat("\n=== (4b) Matched opportunity intervals by year, per sister (month/tightness mix) ===\n")
print(dcast(X[duid %in% sisters & opp==TRUE & matched==TRUE], yr ~ duid, value.var="duid", fun.aggregate=length))

cat("\n=== (5) Common-support check: interval_dt where ALL THREE sisters are simultaneously matched ===\n")
wide <- dcast(X[duid %in% sisters, .(interval_dt, duid, matched, opp)], interval_dt ~ duid,
              value.var=c("matched","opp"))
common <- wide[matched_TORRB2==TRUE & matched_TORRB3==TRUE & matched_TORRB4==TRUE, interval_dt]
cat(sprintf("Intervals matched for ALL three sisters simultaneously: %d (of %d total distinct intervals)\n",
            length(common), nrow(wide)))
each_matched <- sapply(sisters, function(u) sum(wide[[paste0("matched_",u)]], na.rm=TRUE))
cat("Matched count per sister (own stratum availability): "); print(setNames(each_matched, sisters))

cat("\n=== (6) Re-run dt:opp on the COMMON intersection sample only (apples-to-apples) ===\n")
Xc <- X[duid %in% sisters & interval_dt %in% common]
res <- rbindlist(lapply(sisters, function(u) {
  d <- Xc[duid==u & !is.na(dt)]
  f <- feols(withheld ~ dt*opp + srmc | nsq + hour_block, d, vcov=~yyyymm)
  ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct[grepl(":", term), .(duid=u, term, estimate, std.error, statistic, p.value, nobs=nobs(f))]
}))
print(res)

fwrite(msumm, file.path(OUT, "stage4b_torrb3_matched_composition.csv"))
fwrite(res, file.path(OUT, "stage4b_torrb3_common_sample_results.csv"))
cat("\nSaved stage4b_torrb3_matched_composition.csv, stage4b_torrb3_common_sample_results.csv.\n")
