#!/usr/bin/env Rscript
# stage1a_rival_bop_cache.R -- preprocessing for Stage 1 forecast slack
# (08_propensity/registration.md). Slims the monthly BIDOFFERPERIOD caches to the RIVAL
# synchronous fleet's versioned availability: (DUID, INTERVAL_DATETIME, OFFERDATETIME,
# MAXAVAIL). The focal station (TORRB*) is EXCLUDED at source per the registration's hard
# constraint -- no focal inputs anywhere in the propensity.
#
# Interval keying: INTERVAL_DATETIME (the BOP TRADINGDATE label is one day behind its
# intervals -- known pipeline bug, do not key on TRADINGDATE).
# Output: bid_cache/RIVAL_BOP_<M>.rds + .done_rbop_<M>; resume-safe. Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT  <- normalizePath("..")
CACHE <- file.path(ROOT, "Direction/bid_cache")

RIVAL_SYNC <- c("PPCCGT","OSB-AG","QPS5","DRYCGT1","DRYCGT2","DRYCGT3",
                "MINTARO","BARKIPS1","SNAPPER1")

months <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) months <- args

for (M in months) {
  out <- file.path(CACHE, sprintf("RIVAL_BOP_%s.rds", M))
  if (file.exists(out)) { cat(sprintf("[%s] cache hit\n", M)); next }
  src <- file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))
  if (!file.exists(src)) { cat(sprintf("[%s] MISSING SOURCE %s\n", M, src)); next }
  t0 <- Sys.time()
  b <- readRDS(src); setDT(b)
  b <- b[DUID %chin% RIVAL_SYNC, .(DUID, INTERVAL_DATETIME, OFFERDATETIME, MAXAVAIL)]
  b[, `:=`(INTERVAL_DATETIME = as.POSIXct(INTERVAL_DATETIME),
           OFFERDATETIME     = as.POSIXct(OFFERDATETIME),
           MAXAVAIL          = as.numeric(MAXAVAIL))]
  setkey(b, DUID, INTERVAL_DATETIME, OFFERDATETIME)
  tmp <- paste0(out, ".tmp")
  saveRDS(b, tmp); stopifnot(file.rename(tmp, out))
  writeLines(format(Sys.time()), file.path(CACHE, paste0(".done_rbop_", M)))
  cat(sprintf("[%s] %d rival rows cached (%.1f min)\n", M, nrow(b),
              as.numeric(Sys.time() - t0, units = "mins")))
  rm(b); gc()
}
cat("DONE stage1a\n")
