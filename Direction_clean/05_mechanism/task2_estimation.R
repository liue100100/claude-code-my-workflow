#!/usr/bin/env Rscript
# task2_estimation.R -- Task 2 Steps 2-4: RQ1, RQ2 (registered), mechanical-break backstop.
# All definitions fixed in task2_preregistration.md (committed 405ef65) before estimation.
# Runs ONLY if the Step-1 frequency gate passed (checked at the top).
#
# Outcomes: composite (raw + within-unit rank), Component A (withdrawal, LPM), Component B
# (pricing, conditional on availability >= floor). Unit-day grain, test units TORRB2/3/4+PPCCGT.
# Inference: analytic cluster-month + wild cluster bootstrap (sandwich::vcovBS, Rademacher/Webb,
# R=999) on the headline coefficients.
#
# Run from my-project root.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
JUNE_COMP_PRICE <- 241.38; APC_IMPUTE <- 300; WCB_R <- 999L

UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
UD <- UD[DUID %in% TEST_UNITS]

# gate check (re-derived, hard stop)
n_gate <- UD[comp_A==TRUE & essential_day==TRUE, .N]
stopifnot("FREQUENCY GATE FAILED -- do not estimate" = n_gate >= 30)
cat(sprintf("Gate re-check: %d Component-A events among essential days (>=30). Proceeding.\n", n_gate))

# ---------------------------------------------------------------------------
# Controls at day grain (from the Stage-3 regression panel, all true market time)
# ---------------------------------------------------------------------------
RP <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
RP[, cal_day := dt10(interval_dt - 1)]
CTL <- RP[, .(n_iv_ctl = .N, srmc = srmc[1], dem = mean(TOTALDEMAND), ns = mean(nonsync_mw),
              rrp = mean(RRP), slope_mean = mean(slope_kernel, na.rm=TRUE),
              sat_share = mean(saturated, na.rm=TRUE)), by=.(DUID, cal_day)]
D <- merge(UD, CTL, by=c("DUID","cal_day"), all.x=TRUE)
n_thin <- D[is.na(n_iv_ctl) | n_iv_ctl < 240, .N]
cat(sprintf("Unit-days: %d; dropped for thin/absent control coverage (<240 intervals): %d\n", nrow(D), n_thin))
D <- D[!is.na(n_iv_ctl) & n_iv_ctl >= 240 & !is.na(composite)]
D[, yyyymm := as.integer(format(cal_day, "%Y%m"))]

# expected-running-loss control: previous trading day's realised SA1 RRP profile vs today's SRMC
day_rrp <- unique(RP[, .(cal_day, interval_dt, RRP)], by=c("cal_day","interval_dt"))
prev_mean <- day_rrp[, .(rrp_prev_mean = mean(RRP)), by=cal_day][, cal_day := cal_day + 1L]
D <- merge(D, prev_mean, by="cal_day", all.x=TRUE)
prev_iv <- day_rrp[, .(cal_day = cal_day + 1L, RRP)]
setkey(prev_iv, cal_day)
D[, exp_loss := srmc - rrp_prev_mean]
sh <- prev_iv[D[, .(cal_day, srmc)], on="cal_day", allow.cartesian=TRUE][, .(share_below = mean(RRP < srmc)), by=.(cal_day, srmc)]
D <- merge(D, unique(sh, by=c("cal_day","srmc")), by=c("cal_day","srmc"), all.x=TRUE)
n_noprev <- D[is.na(exp_loss), .N]
cat(sprintf("Days without a previous-day price profile (sample edges): %d (kept for RQ1, dropped from loss-control rows)\n", n_noprev))

# compensation price + June-2022 segments (day level, AEMO MARKETSUSPENDEDFLAG)
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- rbind(g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)],
            data.table(yyyymm=202206L, comp_price=JUNE_COMP_PRICE))
D <- merge(D, cp, by="yyyymm", all.x=TRUE); stopifnot(D[, sum(is.na(comp_price))]==0)
D[, comp_price_100 := comp_price/100]
prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID=="SA1" & as.numeric(INTERVENTION)==0]
prc[, idt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(dt10(idt - 1))]
D[, segment := fifelse(yyyymm != 202206L, "outside_june2022",
              fifelse(cal_day < susp[1], "pre_suspension",
               fifelse(cal_day <= susp[2], "suspension_window", "post_suspension")))]
cat(sprintf("Suspension-day window: %s -> %s (%d unit-days)\n", susp[1], susp[2], D[segment=="suspension_window", .N]))
saveRDS(D, file.path(OUT, "task2_regression_panel.rds"))

outcomes <- c(composite="composite", rank="comp_rank", A_withdrawal="comp_A", B_pricing="comp_B")
tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  extra <- list(...); for (nm in names(extra)) set(ct, j=nm, value=extra[[nm]]); ct[] }
wcb_fun <- function(d, fml_rhs, lhs, coefname, seed=20260705) {
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", lhs, fml_rhs))
  lmf <- lm(fml, d); b <- coef(lmf)[[coefname]]
  out <- lapply(c(rademacher="wild", webb="wild-webb"), function(tp) {
    set.seed(seed); v <- vcovBS(lmf, cluster=~yyyymm, R=WCB_R, type=tp)
    se <- sqrt(v[coefname, coefname]); df <- uniqueN(d$yyyymm)-1L
    data.table(estimate=b, wcb_se=se, wcb_t=b/se, wcb_p=2*pt(-abs(b/se), df), df=df) })
  rbindlist(out, idcol="weights")
}

# ---------------------------------------------------------------------------
# STEP 2 -- RQ1: outcome ~ essential_day, M1 (no competition) / M3 (+competition)
# ---------------------------------------------------------------------------
cat("\n================ STEP 2: RQ1 ================\n")
rhs1 <- c(M1 = "essential_day + srmc + dem + ns + rrp",
          M3 = "essential_day + srmc + dem + ns + rrp + slope_mean + sat_share")
rq1 <- list(); rq1_wcb <- list()
for (o in names(outcomes)) for (m in names(rhs1)) {
  d <- if (o=="B_pricing") D[comp_A==FALSE & !is.na(comp_B)] else D
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs1[[m]])), d, vcov=~yyyymm)
  rq1[[paste(o,m)]] <- tidy(f, outcome=o, model=m)
  if (m=="M3") rq1_wcb[[o]] <- cbind(outcome=o, wcb_fun(d, rhs1[[m]], outcomes[[o]], "essential_dayTRUE"))
}
rq1 <- rbindlist(rq1); fwrite(rq1, file.path(OUT, "task2_rq1_results.csv"))
rq1_wcb <- rbindlist(rq1_wcb); fwrite(rq1_wcb, file.path(OUT, "task2_rq1_wcb.csv"))
cat("RQ1 essential-day coefficient (analytic, cluster month):\n")
print(rq1[term=="essential_dayTRUE", .(outcome, model, estimate=round(estimate,3), se=round(std.error,3), p=round(p.value,4), nobs)])
cat("RQ1 WCB (M3):\n"); print(rq1_wcb[, .(outcome, weights, estimate=round(estimate,3), wcb_p=round(wcb_p,4))])
rob <- rbindlist(lapply(c("Torrens only","drop June 2022"), function(lbl) {
  d0 <- if (lbl=="Torrens only") D[DUID!="PPCCGT"] else D[yyyymm!=202206L]
  rbindlist(lapply(names(outcomes), function(o) {
    d <- if (o=="B_pricing") d0[comp_A==FALSE & !is.na(comp_B)] else d0
    tidy(feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs1[["M3"]])), d, vcov=~yyyymm),
         outcome=o, model="M3")[term=="essential_dayTRUE"][, row := lbl][] })) }))
fwrite(rob, file.path(OUT, "task2_rq1_robustness.csv"))
cat("RQ1 robustness:\n"); print(rob[, .(row, outcome, estimate=round(estimate,3), p=round(p.value,4), nobs)])

# ---------------------------------------------------------------------------
# STEP 3 -- RQ2: essential x comp_price on the CEM-matched day sample
# ---------------------------------------------------------------------------
cat("\n================ STEP 3: RQ2 (registered) ================\n")
D[, nsq := cut(ns, quantile(ns, seq(0,1,.2), na.rm=TRUE), include.lowest=TRUE, labels=1:5)]
sl_terc <- quantile(D[sat_share < .5, slope_mean], c(1/3,2/3), na.rm=TRUE)
D[, comp_bin := fifelse(sat_share >= .5, "saturated_day",
               fifelse(slope_mean <= sl_terc[1], "t1", fifelse(slope_mean <= sl_terc[2], "t2", "t3")))]
D[, stratum := paste(DUID, yyyymm, nsq, comp_bin, sep="|")]
ok <- D[, .(ne=sum(essential_day), nc=sum(!essential_day)), by=stratum][ne>0 & nc>0, stratum]
D[, matched := stratum %in% ok]
ms <- D[, .(n_ess=sum(essential_day), n_ess_matched=sum(essential_day & matched),
            pct=round(100*sum(essential_day & matched)/pmax(sum(essential_day),1),1),
            n_comp_matched=sum(!essential_day & matched)), by=DUID]
fwrite(ms, file.path(OUT, "task2_rq2_match_summary.csv"))
cat("CEM match summary (unit x month x nonsync-quintile x competition-bin):\n"); print(ms)
M <- D[matched==TRUE]

cat("\nPOWER DIAGNOSTICS (before any coefficient):\n")
pm <- M[essential_day==TRUE, .(ess_days=.N, comp_price=round(mean(comp_price),1)), by=yyyymm][order(yyyymm)]
fwrite(pm, file.path(OUT, "task2_rq2_power_by_month.csv"))
top3 <- round(100*sum(sort(pm$ess_days, decreasing=TRUE)[1:3])/sum(pm$ess_days),1)
cat(sprintf("Essential days matched: %d over %d months; top-3 months %.1f%%; comp price sd $%.1f, range $%d-%d\n",
            sum(pm$ess_days), nrow(pm), top3, M[essential_day==TRUE, sd(comp_price)],
            round(min(pm$comp_price)), round(max(pm$comp_price))))

rhs2  <- "essential_day*comp_price_100 + srmc + dem + ns + rrp + slope_mean + sat_share"
rhs2L <- paste(rhs2, "+ essential_day*exp_loss")
samples <- list(
  "BASE: exclude suspension days"       = quote(segment != "suspension_window"),
  "(i) exclude all June 2022"           = quote(segment == "outside_june2022"),
  "(ii) suspension days at APC $300"    = quote(rep(TRUE, .N)),
  "(iii) base minus pre-suspension June"= quote(!segment %in% c("suspension_window","pre_suspension")))
INT <- "essential_dayTRUE:comp_price_100"
rq2 <- list(); base_d <- list()
for (s in names(samples)) for (o in names(outcomes)) for (lc in c("no loss control","with loss control")) {
  d <- M[eval(samples[[s]])]
  if (s == "(ii) suspension days at APC $300") d <- copy(d)[segment=="suspension_window", comp_price_100 := APC_IMPUTE/100]
  if (o=="B_pricing") d <- d[comp_A==FALSE & !is.na(comp_B)]
  if (lc=="with loss control") d <- d[!is.na(exp_loss)]
  r <- if (lc=="with loss control") rhs2L else rhs2
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], r)), d, vcov=~yyyymm)
  rq2[[paste(s,o,lc)]] <- tidy(f, sample=s, outcome=o, loss=lc)
  if (startsWith(s,"BASE") && lc=="no loss control") base_d[[o]] <- d
}
rq2 <- rbindlist(rq2, fill=TRUE); fwrite(rq2, file.path(OUT, "task2_rq2_results.csv"))
cat("\nRQ2 interaction (essential x comp price, per $100/MWh):\n")
print(rq2[term==INT, .(sample, outcome, loss, estimate=round(estimate,4), se=round(std.error,4), p=round(p.value,4), nobs)])
cat("\nLoss-control terms (base sample):\n")
print(rq2[startsWith(sample,"BASE") & loss=="with loss control" & grepl("exp_loss", term),
          .(outcome, term, estimate=round(estimate,4), p=round(p.value,4))])
rq2_wcb <- rbindlist(lapply(names(outcomes), function(o)
  cbind(outcome=o, wcb_fun(base_d[[o]], rhs2, outcomes[[o]], INT))))
fwrite(rq2_wcb, file.path(OUT, "task2_rq2_wcb.csv"))
cat("\nRQ2 WCB (base, no loss control):\n"); print(rq2_wcb[, .(outcome, weights, estimate=round(estimate,4), wcb_p=round(wcb_p,4))])

# ---------------------------------------------------------------------------
# STEP 4 -- mechanical-break backstop (PRE 2023-01..05, POST 2023-10..2024-02)
# ---------------------------------------------------------------------------
cat("\n================ STEP 4: mechanical break ================\n")
M[, brk := fifelse(cal_day >= as.Date("2023-01-01") & cal_day <= as.Date("2023-05-31"), "pre",
          fifelse(cal_day >= as.Date("2023-10-01") & cal_day <= as.Date("2024-02-29"), "post", NA_character_))]
B <- M[!is.na(brk)]
cat(sprintf("Break sample: %d unit-days (pre %d / post %d); essential days pre %d / post %d; comp price pre $%.0f / post $%.0f\n",
            nrow(B), B[brk=="pre",.N], B[brk=="post",.N],
            B[brk=="pre", sum(essential_day)], B[brk=="post", sum(essential_day)],
            B[brk=="pre", mean(comp_price)], B[brk=="post", mean(comp_price)]))
n_ess_pre <- B[brk=="pre", sum(essential_day)]; n_ess_post <- B[brk=="post", sum(essential_day)]
# feasibility guard (the pre-registered stop applies here too: report the bound, never force it)
if (n_ess_pre < 10 || n_ess_post < 10) {
  msg <- sprintf(paste0("MECHANICAL-BREAK CHECK INFEASIBLE AS REGISTERED: essential days in the matched sample = ",
    "%d (PRE 2023-01..05) / %d (POST 2023-10..2024-02). The essential-day mass sits in 2022 and late ",
    "2024 (2023 holds ~7 essential station-days all year), so the fixed break windows have no PRE ",
    "contrast at day grain. Reported as infeasible; no estimate forced. NB with RQ2 null on the full ",
    "sample, the backstop is moot -- it guards a POSITIVE result against conduct drift."), n_ess_pre, n_ess_post)
  cat(msg, "\n")
  # also report the UNMATCHED essential-day counts in the windows, for the findings denominator
  DD <- D[cal_day >= as.Date("2023-01-01") & cal_day <= as.Date("2023-05-31")]
  cat(sprintf("Unmatched essential days in PRE window (all test units): %d; in POST window: %d\n",
              DD[, sum(essential_day)],
              D[cal_day >= as.Date("2023-10-01") & cal_day <= as.Date("2024-02-29"), sum(essential_day)]))
  fwrite(data.table(status="infeasible", n_ess_pre=n_ess_pre, n_ess_post=n_ess_post, note=msg),
         file.path(OUT, "task2_break_results.csv"))
} else {
  brk_res <- list()
  for (o in names(outcomes)) {
    d <- if (o=="B_pricing") B[comp_A==FALSE & !is.na(comp_B)] else B
    if (d[, uniqueN(get(outcomes[[o]]))] < 2) next
    f1 <- feols(as.formula(sprintf("%s ~ essential_day*I(brk=='post') + srmc + dem + ns + rrp + slope_mean + sat_share | DUID + yyyymm",
                                   outcomes[[o]])), d, vcov=~yyyymm)
    f2 <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs2)), d, vcov=~yyyymm)
    brk_res[[paste(o,"reduced form")]] <- tidy(f1, outcome=o, spec="essential x post (reduced form)")
    brk_res[[paste(o,"dose")]]         <- tidy(f2, outcome=o, spec="essential x comp_price, break sample")
  }
  brk_res <- rbindlist(brk_res, fill=TRUE); fwrite(brk_res, file.path(OUT, "task2_break_results.csv"))
  cat("Break-identified coefficients:\n")
  print(brk_res[grepl("essential_dayTRUE:", term),
                .(outcome, spec, term, estimate=round(estimate,4), se=round(std.error,4), p=round(p.value,4), nobs)])
}

cat("\nSaved task2_{rq1_results,rq1_wcb,rq1_robustness,rq2_match_summary,rq2_power_by_month,rq2_results,rq2_wcb,break_results}.csv, task2_regression_panel.rds\n")
cat("Findings written after inspection (findings_task2.md).\n")
