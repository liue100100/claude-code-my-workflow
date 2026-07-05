#!/usr/bin/env Rscript
# _addendum_torrens_no202206.R -- the cross cut the findings flagged as load-bearing: the one
# significant RQ1 result is Torrens-only (cost-indexed, p=0.04), but the POOLED cost-indexed
# coefficient collapses when 2022-06 (market suspension) is dropped. Does the Torrens result
# survive dropping 2022-06? Appends the row to rq1_robustness.csv.
# Run from Direction_clean/ after run_rq1.R.

suppressMessages({ library(data.table); library(fixest) })
OUT <- "outputs/03_rq1_essentiality"
D <- readRDS(file.path(OUT, "regression_panel.rds"))
rob <- fread(file.path(OUT, "rq1_robustness.csv"))
stopifnot(!"Torrens only, drop 2022-06" %in% rob$row)   # idempotence guard

rhs <- c(M1 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP",
         M3 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated")
outcomes <- c(a_fixed300 = "cheap_a_share", b_2xSRMC = "cheap_b_share")
d <- D[DUID %in% c("TORRB2","TORRB3","TORRB4") & yyyymm != 202206]
cat(sprintf("Torrens-only, drop 2022-06: %d rows (vs %d with 2022-06)\n",
            nrow(d), nrow(D[DUID %in% c("TORRB2","TORRB3","TORRB4")])))

new_rows <- rbindlist(lapply(names(outcomes), function(o) rbindlist(lapply(names(rhs), function(m) {
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs[[m]])), d, vcov=~yyyymm)
  ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct <- ct[term=="essentialTRUE"]
  ct[, `:=`(model=m, outcome=o, nobs=nobs(f), row="Torrens only, drop 2022-06")][]
}))))
print(new_rows[, .(row, outcome, model, estimate, std.error, p.value, nobs)])
rob <- rbind(rob, new_rows)
fwrite(rob, file.path(OUT, "rq1_robustness.csv"))
cat("Appended 4 rows to rq1_robustness.csv.\n")
