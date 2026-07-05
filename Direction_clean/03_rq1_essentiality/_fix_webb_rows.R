#!/usr/bin/env Rscript
# _fix_webb_rows.R -- one-off repair, 2026-07-04. The first Stage-3 run passed `wild="webb"` to
# sandwich::vcovBS, which selects the weight family via `type` and silently swallowed the argument
# in `...` -- so the "webb" rows of rq1_wcb.csv were Rademacher duplicates (caught: bit-identical
# SEs). This recomputes ONLY the Webb rows with the correct `type="wild-webb"` and rewrites
# rq1_wcb.csv. The Rademacher rows (the primary) were always valid and are untouched.
# Run from Direction_clean/ AFTER run_rq1.R has finished.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
OUT <- "outputs/03_rq1_essentiality"
D <- readRDS(file.path(OUT, "regression_panel.rds"))
wcb <- fread(file.path(OUT, "rq1_wcb.csv"))
WCB_R <- 999L

rhs <- c(M1 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP",
         M2 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel",
         M3 = "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated")
outcomes <- c(a_fixed300 = "cheap_a_share", b_2xSRMC = "cheap_b_share")

for (o in names(outcomes)) for (m in names(rhs)) {
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", outcomes[[o]], rhs[[m]]))
  lmf <- lm(fml, D)
  b <- coef(lmf)[["essentialTRUE"]]
  set.seed(20260704)
  v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = "wild-webb")
  se <- sqrt(v["essentialTRUE","essentialTRUE"])
  tt <- b / se; df <- uniqueN(D$yyyymm) - 1L
  pv <- 2*pt(-abs(tt), df = df)
  wcb[outcome==o & model==m & weights=="webb",
      `:=`(estimate=b, wcb_se=se, wcb_t=tt, wcb_p=pv, R=WCB_R, df=df)]
  cat(sprintf("  [%s %s webb-FIXED] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", o, m, b, se, tt, pv))
  rm(lmf); gc(verbose=FALSE)
}
fwrite(wcb, file.path(OUT, "rq1_wcb.csv"))
cat("\nRewrote the 6 webb rows of rq1_wcb.csv (rademacher rows untouched).\n")
# sanity: webb and rademacher must now DIFFER (they were bit-identical under the bug)
chk <- dcast(wcb, outcome + model ~ weights, value.var="wcb_se")
stopifnot(all(chk$rademacher != chk$webb))
cat("OK: webb SEs now differ from rademacher SEs in every model (bug would have made them identical).\n")
