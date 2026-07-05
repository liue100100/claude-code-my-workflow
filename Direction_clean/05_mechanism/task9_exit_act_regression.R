#!/usr/bin/env Rscript
# task9_exit_act_regression.R -- the registered exit-act regression (task9_preregistration.md,
# committed before this ran). LPM of evening cancellation on pex_n1 essentiality, clean Torrens
# evening-on-offer days, loss control in/out, unit+month FE, cluster month + WCB.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
WCB_R <- 999L

POP <- readRDS(file.path(OUT, "task6_population.rds"))
G <- fread(file.path(OUT, "task7_label_census.csv")); G[, cal_day := as.Date(cal_day)]
P <- merge(POP, G[, .(DUID, cal_day, ess_n1, ess_pex)], by=c("DUID","cal_day"))
P <- P[segment != "suspension_window"]
P[, `:=`(cancelN = as.integer(cancel), n1only = ess_n1 & !ess_pex)]
cat(sprintf("Estimation sample: %d clean Torrens evening-on-offer days | essential_n1 %d (N-1-only %d, N-0 %d) | cancellations %d\n",
            nrow(P), P[ess_n1==TRUE, .N], P[n1only==TRUE, .N], P[ess_pex==TRUE, .N], P[, sum(cancel)]))
n_noloss <- P[is.na(exp_loss), .N]
cat(sprintf("Days without loss-control coverage (dropped from loss rows): %d\n", n_noloss))

rhs0 <- "ess_n1 + dem + ns + rrp + slope_mean + sat_share"
rhs1 <- "ess_n1*exp_loss + dem + ns + rrp + slope_mean + sat_share"
rhs2 <- "n1only + ess_pex + dem + ns + rrp + slope_mean + sat_share"
tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  ex <- list(...); for (nm in names(ex)) set(ct, j=nm, value=ex[[nm]]); ct[] }
res <- list()
f0 <- feols(as.formula(paste("cancelN ~", rhs0, "| DUID + yyyymm")), P, vcov=~yyyymm)
res$m0 <- tidy(f0, model="no loss control")
f1 <- feols(as.formula(paste("cancelN ~", rhs1, "| DUID + yyyymm")), P[!is.na(exp_loss)], vcov=~yyyymm)
res$m1 <- tidy(f1, model="with loss control")
f2 <- feols(as.formula(paste("cancelN ~", rhs2, "| DUID + yyyymm")), P, vcov=~yyyymm)
res$m2 <- tidy(f2, model="three-tier (N-0 context only)")
RES <- rbindlist(res); fwrite(RES, file.path(OUT, "task9_results.csv"))
cat("\n=== Registered coefficients (analytic, cluster month) ===\n")
print(RES[term %in% c("ess_n1TRUE","n1onlyTRUE","ess_pexTRUE","exp_loss","ess_n1TRUE:exp_loss"),
          .(model, term, estimate=round(estimate,4), se=round(std.error,4), p=round(p.value,4), nobs)])

cat("\n=== WCB on the essential coefficient (Rademacher/Webb, R=999, month clusters) ===\n")
for (mm in c("no loss","with loss")) {
  d <- if (mm=="with loss") P[!is.na(exp_loss)] else P
  r <- if (mm=="with loss") rhs1 else rhs0
  lmf <- lm(as.formula(paste("cancelN ~", r, "+ factor(DUID) + factor(yyyymm)")), d)
  b <- coef(lmf)[["ess_n1TRUE"]]
  for (tp in c(rademacher="wild", webb="wild-webb")) {
    set.seed(20260705); v <- vcovBS(lmf, cluster=~yyyymm, R=WCB_R, type=tp)
    se <- sqrt(v["ess_n1TRUE","ess_n1TRUE"]); df <- uniqueN(d$yyyymm)-1L
    cat(sprintf("  [%s | %s] b=%.4f  wcb_p=%.4f\n", mm, tp, b, 2*pt(-abs(b/se), df)))
  }
}
cat("\nFindings written after inspection against the committed readings.\n")
