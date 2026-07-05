#!/usr/bin/env Rscript
# task10_part2_test.R -- Final exception task, Part 2: completing the Component B floor-pricing
# registration with N-1 cells. Committed readings fixed in the instruction before estimation.
# (i)  Day level: comp_B ~ essential_n1 + controls | unit + month, clean B-days, suspension
#      excluded, with/without the loss control (registered day-mean proxy, weakness restated),
#      cluster month + WCB. Three-tier row for the N-0 side-by-side.
# (ii) Hours level: hourly effective floor price (mean non-imputed p_floor; hour counted if
#      >= 6/12 intervals non-imputed; essential hour = >= 6/12 intervals pex_n1) with
#      UNIT x DAY fixed effects -- all day-level confounds cancel; identifies off days with
#      both essential and non-essential offered hours. Plus descriptive three-way medians.
# Realised directions never on the RHS. Corrected clock, clean days, denominators everywhere.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
WCB_R <- 999L

UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
G  <- fread(file.path(OUT, "task7_label_census.csv")); G[, cal_day := as.Date(cal_day)]
D  <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
B <- merge(UD[DUID %in% TEST_UNITS, .(DUID, cal_day, comp_A, comp_B)],
           G[, .(DUID, cal_day, ess_n1, ess_pex, clean)], by=c("DUID","cal_day"))
B <- merge(B, D[, .(DUID, cal_day, yyyymm, segment, dem, ns, rrp, slope_mean, sat_share, exp_loss)],
           by=c("DUID","cal_day"))
B <- B[clean==TRUE & comp_A==FALSE & !is.na(comp_B) & segment != "suspension_window"]
B[, n1only := ess_n1 & !ess_pex]
cat(sprintf("(i) Day sample: %d clean B-days (essential_n1 %d, N-0 %d, ordinary %d)\n",
            nrow(B), B[ess_n1==TRUE,.N], B[ess_pex==TRUE,.N], B[ess_n1==FALSE,.N]))

tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  ex <- list(...); for (nm in names(ex)) set(ct, j=nm, value=ex[[nm]]); ct[] }
rhs0 <- "ess_n1 + dem + ns + rrp + slope_mean + sat_share"
rhs1 <- "ess_n1*exp_loss + dem + ns + rrp + slope_mean + sat_share"
rhs2 <- "n1only + ess_pex + dem + ns + rrp + slope_mean + sat_share"
res <- list()
res$m0 <- tidy(feols(as.formula(paste("comp_B ~", rhs0, "| DUID + yyyymm")), B, vcov=~yyyymm), model="no loss control")
res$m1 <- tidy(feols(as.formula(paste("comp_B ~", rhs1, "| DUID + yyyymm")), B[!is.na(exp_loss)], vcov=~yyyymm), model="with loss control")
res$m2 <- tidy(feols(as.formula(paste("comp_B ~", rhs2, "| DUID + yyyymm")), B, vcov=~yyyymm), model="three-tier")
RES <- rbindlist(res); fwrite(RES, file.path(OUT, "task10_day_results.csv"))
cat("\n=== (i) Day-level coefficients (analytic, cluster month) ===\n")
print(RES[term %in% c("ess_n1TRUE","n1onlyTRUE","ess_pexTRUE","exp_loss","ess_n1TRUE:exp_loss"),
          .(model, term, estimate=round(estimate,1), se=round(std.error,1), p=round(p.value,4), nobs)])
cat("\nWCB on ess_n1 (Rademacher/Webb, R=999):\n")
for (mm in c("no loss","with loss")) {
  d <- if (mm=="with loss") B[!is.na(exp_loss)] else B
  r <- if (mm=="with loss") rhs1 else rhs0
  lmf <- lm(as.formula(paste("comp_B ~", r, "+ factor(DUID) + factor(yyyymm)")), d)
  b <- coef(lmf)[["ess_n1TRUE"]]
  for (tp in c(rademacher="wild", webb="wild-webb")) {
    set.seed(20260705); v <- vcovBS(lmf, cluster=~yyyymm, R=WCB_R, type=tp)
    se <- sqrt(v["ess_n1TRUE","ess_n1TRUE"]); df <- uniqueN(d$yyyymm)-1L
    cat(sprintf("  [%s | %s] b=%.1f  wcb_p=%.4f\n", mm, tp, b, 2*pt(-abs(b/se), df)))
  }
}

# ---------------------------------------------------------------------------
cat("\n=== (ii) Hours level ===\n")
PF <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))[DUID %in% TEST_UNITS]
PX <- readRDS(file.path(OUT, "task7_pex_n1_panel.rds"))
PF <- merge(PF, PX[, .(SETTLEMENTDATE, pex_n1_torrens_island_b, pex_n1_pelican_point_gt)],
            by.x="idt", by.y="SETTLEMENTDATE")
PF[, ess_iv := fifelse(DUID=="PPCCGT", pex_n1_pelican_point_gt, pex_n1_torrens_island_b)]
PF[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]
H <- PF[, .(p_h = mean(p_floor[!imputed]), n_off = sum(!imputed), ess_hour = sum(ess_iv) >= 6L),
        by=.(DUID, cal_day, hh)]
H <- H[n_off >= 6]
H <- merge(H, G[, .(DUID, cal_day, clean, ess_n1)], by=c("DUID","cal_day"))
H <- merge(H, D[, .(DUID, cal_day, yyyymm, segment)], by=c("DUID","cal_day"))
H <- H[clean==TRUE & segment != "suspension_window"]
idd <- H[, .(has_both = any(ess_hour) && any(!ess_hour)), by=.(DUID, cal_day)][has_both==TRUE]
cat(sprintf("Hour sample: %s offered unit-hours; identifying unit-days (both essential and non-essential offered hours): %d (PPCCGT %d, Torrens %d)\n",
            format(nrow(H), big.mark=","), nrow(idd), idd[DUID=="PPCCGT",.N], idd[DUID!="PPCCGT",.N]))
h_res <- list()
h_res$all <- tidy(feols(p_h ~ ess_hour | DUID^cal_day, H, vcov=~yyyymm), model="within-day, all units")
h_res$pp  <- tidy(feols(p_h ~ ess_hour | cal_day, H[DUID=="PPCCGT"], vcov=~yyyymm), model="within-day, PPCCGT")
h_res$tor <- tidy(feols(p_h ~ ess_hour | DUID^cal_day, H[DUID!="PPCCGT"], vcov=~yyyymm), model="within-day, Torrens")
HRES <- rbindlist(h_res); fwrite(HRES, file.path(OUT, "task10_hour_results.csv"))
print(HRES[term=="ess_hourTRUE", .(model, estimate=round(estimate,1), se=round(std.error,1), p=round(p.value,4), nobs)])
cat("\nDescriptive three-way medians of the hourly floor price ($/MWh):\n")
H[, grp3 := fcase(ess_hour==TRUE, "essential hours",
                  ess_n1==TRUE, "non-essential hours, essential days", default="ordinary-day hours")]
print(dcast(H[, .(median_p = round(median(p_h)), p75 = round(quantile(p_h,.75)), n_hours=.N), by=.(DUID, grp3)],
            DUID ~ grp3, value.var=c("median_p","n_hours")))
fwrite(H[, .N, by=.(DUID, grp3)], file.path(OUT, "task10_hour_cells.csv"))
cat("\nDone -- findings written against the committed readings.\n")
