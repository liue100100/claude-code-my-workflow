#!/usr/bin/env Rscript
# test4_payoff_dose.R -- Round 3, Test 4: the make-whole payoff dose (NER 3.15.7B).
#
# Registered FIRST: 07_round3/test4_preregistration.md (plan of record:
# quality_reports/plans/encapsulated-coalescing-hammock.md, approved 2026-07-07; prereg written
# to disk before this script). ROBUSTNESS CHECK: the d_t headline is not re-opened. The only
# change to the Stage-4/Test-1 machinery is the interacting price variable:
#   rent_100  = pmax(d_t - srmc_allin, 0)/100   (primary: the make-whole prize)
#   gross_100 = pmax(d_t,  srmc_allin)/100      (companion: the effective payment)
#   rentm_100 = pmax(d_t - srmc_marginal, 0)/100 (robustness floor; PPCCGT-degenerate)
# plus the registered interacted-FE variant, unrestricted horse race, WCB, month-grain, and RI.
#
# Run from Direction_clean/. ROOT is relative (INV-10; deliberate deviation from the
# 06_round2 hardcoded-ROOT template).

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/07_round3")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

JUNE_COMP_PRICE <- 241.38
APC_IMPUTE      <- 300
WCB_R <- 999L
RI_R  <- 999L
TEST_UNITS <- c("TORRB2", "TORRB3", "TORRB4", "PPCCGT")

# ---------------------------------------------------------------------------
# S1: Panel assembly -- byte-identical to test1_floor_reach.R
# ---------------------------------------------------------------------------
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
setDT(D); n0 <- nrow(D)

O <- readRDS(file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
O <- O[, .(DUID, interval_dt, td, cheap_a_mw = cheap_a, cheap_b_mw = cheap_b, MAXAVAIL)]
D <- merge(D, O, by = c("DUID", "interval_dt"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(cheap_a_mw))] == 0)

D[, day_ceiling := max(MAXAVAIL), by = .(DUID, td)]
D[, floor_mw := fifelse(DUID == "PPCCGT", fifelse(day_ceiling <= 239, 42, 125), 40)]
D[, `:=`(reach_a = as.integer(cheap_a_mw >= floor_mw),
         reach_b = as.integer(cheap_b_mw >= floor_mw))]

prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID == "SA1" & as.numeric(INTERVENTION) == 0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
susp <- prc[as.numeric(MARKETSUSPENDEDFLAG) > 0, range(interval_dt)]
seg_map <- prc[, .(interval_dt, segment = fifelse(interval_dt < susp[1], "pre_suspension",
                            fifelse(interval_dt <= susp[2], "suspension_window", "post_suspension")))]
D <- merge(D, seg_map, by = "interval_dt", all.x = TRUE)
D[is.na(segment), segment := "outside_june2022"]
stopifnot(nrow(D) == n0)

g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- g0[, .(yyyymm = as.integer(yyyymm), comp_price = dt_recon)]
cp <- rbind(cp, data.table(yyyymm = 202206L, comp_price = JUNE_COMP_PRICE))
D <- merge(D, cp, by = "yyyymm", all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(comp_price))] == 0)
D[, comp_price_100 := comp_price / 100]
D[, hour_block := cut(as.integer(format(interval_dt, "%H")), c(-1, 6, 12, 18, 24),
                      labels = c("0-6", "6-12", "12-18", "18-24"))]

# ---------------------------------------------------------------------------
# S2: Dose construction (before the matched subsets are taken)
# ---------------------------------------------------------------------------
sp <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
sp <- sp[duid %chin% TEST_UNITS,
         .(DUID = duid, yyyymm = as.integer(yyyymm), srmc_marginal, srmc_allin)]
stopifnot(nrow(sp) == length(TEST_UNITS) * 36L, sp[, uniqueN(yyyymm)] == 36L,
          sp[, sum(is.na(srmc_allin) | is.na(srmc_marginal))] == 0)
D <- merge(D, sp, by = c("DUID", "yyyymm"), all.x = TRUE)
stopifnot(nrow(D) == n0, D[, sum(is.na(srmc_allin))] == 0)

D[, `:=`(rent  = pmax(comp_price - srmc_allin, 0),
         gross = pmax(comp_price, srmc_allin),
         rentm = pmax(comp_price - srmc_marginal, 0),
         bound = srmc_allin > comp_price)]
D[, `:=`(rent_100 = rent / 100, gross_100 = gross / 100, rentm_100 = rentm / 100,
         allin_100 = srmc_allin / 100)]

# CEM matching (identical strata)
D[, nsq := cut(nonsync_mw, quantile(nonsync_mw, seq(0, 1, .2), na.rm = TRUE), include.lowest = TRUE, labels = 1:5)]
slope_terc <- quantile(D[saturated == FALSE, slope_kernel], c(1/3, 2/3), na.rm = TRUE)
D[, comp_bin := fifelse(saturated, "saturated",
                 fifelse(slope_kernel <= slope_terc[1], "t1_steepest",
                  fifelse(slope_kernel <= slope_terc[2], "t2", "t3_nearest_zero")))]
D[, stratum := paste(DUID, yyyymm, nsq, hour_block, comp_bin, sep = "|")]
strata_ok <- D[, .(ne = sum(essential), nc = sum(!essential)), by = stratum][ne > 0 & nc > 0, stratum]
D[, matched := stratum %in% strata_ok]
M <- D[matched == TRUE]
B <- M[segment != "suspension_window"]
cat(sprintf("Matched sample: %d rows (%d essential) -- must equal Stage 4's 140,259/12,513 on the base filter.\n",
            B[, .N], B[, sum(essential)]))

# ---------------------------------------------------------------------------
# S3: Dose comparison (power report BEFORE any coefficient, per the registration)
# ---------------------------------------------------------------------------
cat("\n=== S3: dose geometry and power report ===\n")
ess_by_cell <- B[essential == TRUE, .(ess_rows = .N), by = .(DUID, yyyymm)]
dose_tab <- unique(D[, .(DUID, yyyymm, comp_price, srmc_allin, srmc_marginal,
                         rent, gross, rentm, bound)])
dose_tab <- merge(dose_tab, ess_by_cell, by = c("DUID", "yyyymm"), all.x = TRUE)
dose_tab[is.na(ess_rows), ess_rows := 0L]
setorder(dose_tab, DUID, yyyymm)
fwrite(dose_tab, file.path(OUT, "test4_dose_table.csv"))

n_bound      <- dose_tab[bound == TRUE, .N]
ess_bound    <- B[essential == TRUE & bound == TRUE, .N]
ess_total    <- B[essential == TRUE, .N]
stat_row <- function(x, lab) data.table(dose = lab, sd = sd(x), iqr = IQR(x),
                                        min = min(x), max = max(x))
pw <- rbind(stat_row(B[essential == TRUE, comp_price], "d_t (old)"),
            stat_row(B[essential == TRUE, rent],       "rent"),
            stat_row(B[essential == TRUE, gross],      "gross"),
            stat_row(B[essential == TRUE, rentm],      "rent_marginal"))
cors <- data.table(
  grain = c("essential rows", "months (ess-weighted mean)"),
  cor_rent_dt  = c(B[essential == TRUE, cor(rent, comp_price)],
                   B[essential == TRUE, .(r = mean(rent), d = mean(comp_price)), by = yyyymm][, cor(r, d)]),
  cor_gross_dt = c(B[essential == TRUE, cor(gross, comp_price)],
                   B[essential == TRUE, .(g = mean(gross), d = mean(comp_price)), by = yyyymm][, cor(g, d)]))
summ <- data.table(n_bound_unit_months = n_bound, ess_rows_bound = ess_bound,
                   ess_rows_total = ess_total,
                   ess_share_bound = round(100 * ess_bound / ess_total, 1))
print(summ); print(pw); print(cors)
fwrite(summ, file.path(OUT, "test4_dose_summary.csv"))
fwrite(pw,   file.path(OUT, "test4_dose_power.csv"))
fwrite(cors, file.path(OUT, "test4_dose_correlations.csv"))
stopifnot(n_bound == 10L)   # registered geometry: TORRB2/3/4 x {202204,202205,202206} + PPCCGT x 202204

# ---------------------------------------------------------------------------
# S4: Anchor replication -- must reproduce Test-1 base reach_a before anything new is read
# ---------------------------------------------------------------------------
cat("\n=== S4: anchor replication (Test-1 base reach_a on comp_price_100) ===\n")
rhs_old <- "essential*comp_price_100 + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
f_anchor <- feols(as.formula(sprintf("reach_a ~ %s | DUID + yyyymm", rhs_old)), B, vcov = ~yyyymm)
b_anchor <- coef(f_anchor)[["essentialTRUE:comp_price_100"]]
t1 <- fread(file.path(ROOT, "Direction_clean/outputs/06_round2/test1_interaction.csv"))
b_ref <- t1[startsWith(sample, "BASE") & outcome == "reach_a", estimate]
cat(sprintf("  anchor b=%.6f  vs test1_interaction.csv BASE reach_a %.6f\n", b_anchor, b_ref))
stopifnot(length(b_ref) == 1L, abs(b_anchor - b_ref) < 1e-6)

# ---------------------------------------------------------------------------
# S5: Main grid -- {rent, gross, rent_marginal} x 4 June treatments x outcomes
# ---------------------------------------------------------------------------
cat("\n=== S5: main grid (registered) ===\n")
mk_rhs <- function(dv) sprintf("essential*%s + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated", dv)
samples <- list(
  "BASE: exclude suspension window only" = quote(segment != "suspension_window"),
  "(i) exclude all June 2022"            = quote(segment == "outside_june2022"),
  "(ii) include window at APC $300"      = quote(rep(TRUE, .N)),
  "(iii) base minus pre-suspension June" = quote(!segment %in% c("suspension_window", "pre_suspension"))
)
outcomes <- list(
  reach_a     = list(var = "reach_a",       subset = quote(rep(TRUE, .N))),
  reach_b     = list(var = "reach_b",       subset = quote(rep(TRUE, .N))),
  share_a     = list(var = "cheap_a_share", subset = quote(rep(TRUE, .N))),
  share_b     = list(var = "cheap_b_share", subset = quote(rep(TRUE, .N))),
  intensive_a = list(var = "cheap_a_share", subset = quote(reach_a == 1L)),
  intensive_b = list(var = "cheap_b_share", subset = quote(reach_b == 1L))
)
doses <- c(rent = "rent_100", gross = "gross_100", rent_marginal = "rentm_100")
outcomes_marg <- c("reach_a", "share_a", "share_b")   # registered restriction for the marginal floor

apc_replace <- function(d) {
  d[segment == "suspension_window",
    `:=`(rent_100  = pmax(APC_IMPUTE - srmc_allin, 0) / 100,
         gross_100 = pmax(APC_IMPUTE, srmc_allin) / 100,
         rentm_100 = pmax(APC_IMPUTE - srmc_marginal, 0) / 100,
         comp_price_100 = APC_IMPUTE / 100)]
  d
}
tidy_fit <- function(f, dose_lab, samp, o, spec) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  ct[, `:=`(dose = dose_lab, sample = samp, outcome = o, spec = spec, nobs = nobs(f))][]
}
res <- list(); base_fits <- list()
for (dz in names(doses)) {
  dv <- doses[[dz]]
  outs <- if (dz == "rent_marginal") outcomes[outcomes_marg] else outcomes
  for (s in names(samples)) for (o in names(outs)) {
    d <- M[eval(samples[[s]])]
    if (s == "(ii) include window at APC $300") d <- apc_replace(copy(d))
    d <- d[eval(outs[[o]]$subset)]
    f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outs[[o]]$var, mk_rhs(dv))), d, vcov = ~yyyymm)
    if (startsWith(s, "BASE")) base_fits[[paste(dz, o)]] <- list(fit = f, data = d, var = outs[[o]]$var, dv = dv)
    res[[paste(dz, s, o)]] <- tidy_fit(f, dz, s, o, "DUID+yyyymm FE")
  }
}

# S5b: interacted-FE variant (DUID^yyyymm absorbs all unit-month levels incl. srmc control)
cat("=== S5b: interacted-FE variant (DUID^yyyymm) ===\n")
rhs_ife <- function(dv) sprintf("essential*%s + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated", dv)
for (dz in c("rent", "gross")) {
  dv <- doses[[dz]]
  for (o in c("reach_a", "share_a", "share_b")) {
    f <- feols(as.formula(sprintf("%s ~ %s | DUID^yyyymm", outcomes[[o]]$var, rhs_ife(dv))), B, vcov = ~yyyymm)
    res[[paste(dz, "ife", o)]] <- tidy_fit(f, dz, "BASE (interacted FE)", o, "DUID^yyyymm FE")
  }
}
res <- rbindlist(res)
fwrite(res, file.path(OUT, "test4_results_full.csv"))
int <- res[grepl("^essentialTRUE:(rent_100|gross_100|rentm_100)$", term)]
fwrite(int, file.path(OUT, "test4_interaction.csv"))
cat("\n=== Test 4: essential x dose interactions (per $100/MWh) ===\n")
print(int[, .(dose, spec, sample, outcome, estimate, std.error, p.value, nobs)], nrows = 100)

# S5c: unrestricted horse race + equal-and-opposite Wald
cat("\n=== S5c: unrestricted horse race (essential x d_t + essential x allin) ===\n")
rhs_hr <- "essential*comp_price_100 + essential*allin_100 + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
hr <- list()
for (o in c("reach_a", "share_a", "share_b")) {
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]]$var, rhs_hr)), B, vcov = ~yyyymm)
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term", "estimate", "std.error", "statistic", "p.value"))
  V  <- vcov(f)
  t_dt <- "essentialTRUE:comp_price_100"; t_al <- "essentialTRUE:allin_100"
  stopifnot(all(c(t_dt, t_al) %in% rownames(V)))
  cmb  <- coef(f)[[t_dt]] + coef(f)[[t_al]]          # H0 (make-whole restriction): b_dt + b_allin = 0
  vcmb <- V[t_dt, t_dt] + V[t_al, t_al] + 2 * V[t_dt, t_al]
  dfm  <- uniqueN(B$yyyymm) - 1L
  pw_t <- 2 * pt(-abs(cmb / sqrt(vcmb)), df = dfm)
  cat(sprintf("  [%s] b_dt=%.5f  b_allin=%.5f  restriction b_dt+b_allin=%.5f  p=%.4f\n",
              o, coef(f)[[t_dt]], coef(f)[[t_al]], cmb, pw_t))
  hr[[o]] <- cbind(ct[grepl("^essentialTRUE:", term)][, outcome := o],
                   data.table(restr_sum = cmb, restr_se = sqrt(vcmb), restr_p = pw_t))
}
fwrite(rbindlist(hr), file.path(OUT, "test4_horserace.csv"))

# ---------------------------------------------------------------------------
# S6: WCB, base case -- {rent, gross} x {reach_a, share_a, share_b}
# ---------------------------------------------------------------------------
cat("\n=== S6: WCB on the interaction (base case), sandwich::vcovBS, R=999 ===\n")
wt_types <- c(rademacher = "wild", webb = "wild-webb")
wcb <- list()
for (dz in c("rent", "gross")) for (o in c("reach_a", "share_a", "share_b")) {
  bf <- base_fits[[paste(dz, o)]]
  d  <- bf$data
  term_int <- paste0("essentialTRUE:", bf$dv)
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", bf$var, mk_rhs(bf$dv)))
  lmf <- lm(fml, d)
  b_lm <- coef(lmf)[[term_int]]
  b_fx <- coef(bf$fit)[[term_int]]
  stopifnot(abs(b_lm - b_fx) < 1e-6)
  for (wt in names(wt_types)) {
    set.seed(20260705)  # per-call re-seed: deliberate template-matching deviation from INV-9
    v <- vcovBS(lmf, cluster = ~yyyymm, R = WCB_R, type = wt_types[[wt]])
    se <- sqrt(v[term_int, term_int])
    df <- uniqueN(d$yyyymm) - 1L
    pv <- 2 * pt(-abs(b_lm / se), df = df)
    wcb[[paste(dz, o, wt)]] <- data.table(dose = dz, outcome = o, weights = wt, estimate = b_lm,
                                          wcb_se = se, wcb_t = b_lm / se, wcb_p = pv, R = WCB_R, df = df)
    cat(sprintf("  [%s %s %s] b=%.5f  WCB se=%.5f  t=%.2f  p=%.4f\n", dz, o, wt, b_lm, se, b_lm / se, pv))
  }
  rm(lmf); gc(verbose = FALSE)
}
wcb <- rbindlist(wcb)
fwrite(wcb, file.path(OUT, "test4_wcb.csv"))

# ---------------------------------------------------------------------------
# S7: Month-grain (Test-3a analogue; essential-row-weighted mean dose)
# ---------------------------------------------------------------------------
cat("\n=== S7: month-grain regression (gap in reach_a on ess-weighted mean dose) ===\n")
gm <- B[, .(gap = mean(reach_a[essential]) - mean(reach_a[!essential]),
            n_ess = sum(essential),
            rent_100m  = mean(rent[essential]) / 100,
            gross_100m = mean(gross[essential]) / 100), by = yyyymm][n_ess >= 30]
mg <- list()
for (dz in c(rent = "rent_100m", gross = "gross_100m")) {
  fit <- lm(as.formula(paste("gap ~", dz)), gm, weights = n_ess)
  v <- vcovHC(fit, type = "HC1")
  b <- coef(fit)[[dz]]; se <- sqrt(v[dz, dz])
  p <- 2 * pt(-abs(b / se), df = nrow(gm) - 2)
  cat(sprintf("  [%s] months=%d  slope per $100: %.4f (HC1 se %.4f, p=%.4f)\n",
              names(which(c(rent = "rent_100m", gross = "gross_100m") == dz)), nrow(gm), b, se, p))
  mg[[dz]] <- data.table(dose = dz, slope = b, se = se, p = p, n_months = nrow(gm), grain = "month")
}
# unit-month alternative (reported alongside per the registration)
gu <- B[, .(gap = mean(reach_a[essential]) - mean(reach_a[!essential]),
            n_ess = sum(essential),
            rent_100m = mean(rent[essential]) / 100,
            gross_100m = mean(gross[essential]) / 100), by = .(DUID, yyyymm)][n_ess >= 10]
for (dz in c(rent = "rent_100m", gross = "gross_100m")) {
  fit <- lm(as.formula(paste("gap ~", dz)), gu, weights = n_ess)
  v <- vcovCL(fit, cluster = gu$yyyymm, type = "HC1")
  b <- coef(fit)[[dz]]; se <- sqrt(v[dz, dz])
  p <- 2 * pt(-abs(b / se), df = uniqueN(gu$yyyymm) - 1L)
  mg[[paste0(dz, "_um")]] <- data.table(dose = dz, slope = b, se = se, p = p,
                                        n_months = nrow(gu), grain = "unit-month")
}
mg <- rbindlist(mg)
print(mg)
fwrite(gm, file.path(OUT, "test4_3a_month_gaps.csv"))
fwrite(mg, file.path(OUT, "test4_3a_result.csv"))

# ---------------------------------------------------------------------------
# S8: Randomization inference -- permute month labels of the unit-dose blocks jointly
# ---------------------------------------------------------------------------
cat("\n=== S8: randomization inference (month-block permutation of the unit-dose map) ===\n")
months <- B[, sort(unique(yyyymm))]
# Build the dose map from the source tables (sp x cp), not from panel rows -- guarantees a
# complete 4-units-per-month block even if a unit-month is absent from the matched sample.
dmap <- merge(sp, cp, by = "yyyymm")[yyyymm %in% months]
dmap[, `:=`(rent_100 = pmax(comp_price - srmc_allin, 0) / 100,
            gross_100 = pmax(comp_price, srmc_allin) / 100)]
dmap <- dmap[, .(DUID, yyyymm, rent_100, gross_100)]
stopifnot(dmap[, .N, by = yyyymm][, all(N == length(TEST_UNITS))])
ri <- list()
for (dz in c("rent", "gross")) {
  dv <- paste0(ifelse(dz == "rent", "rent", "gross"), "_100")
  f_base <- feols(as.formula(sprintf("reach_a ~ %s | DUID + yyyymm", mk_rhs(dv))), B, vcov = ~yyyymm)
  b_obs <- coef(f_base)[[paste0("essentialTRUE:", dv)]]
  Bp <- copy(B)
  # identity-permutation check: assigning the unpermuted map must reproduce b_obs exactly
  idm <- dmap[, .(DUID, yyyymm, v = get(dv))]
  Bp[idm, dose_p := i.v, on = c("DUID", "yyyymm")]
  stopifnot(Bp[, sum(is.na(dose_p))] == 0, Bp[, all(abs(dose_p - get(dv)) < 1e-12)])
  f_id <- feols(reach_a ~ essential*dose_p + srmc + TOTALDEMAND + nonsync_mw + RRP +
                  slope_kernel + saturated | DUID + yyyymm, Bp, lean = TRUE, notes = FALSE)
  stopifnot(abs(coef(f_id)[["essentialTRUE:dose_p"]] - b_obs) < 1e-10)
  cat(sprintf("  [%s] identity check OK (b_obs=%.5f); %d draws...\n", dz, b_obs, RI_R))
  set.seed(20260705)
  b_perm <- numeric(RI_R)
  for (r in seq_len(RI_R)) {
    perm <- data.table(yyyymm_to = months, yyyymm_from = sample(months))
    pm <- dmap[, .(DUID, yyyymm, v = get(dv))][perm, on = .(yyyymm = yyyymm_from)
                ][, .(DUID, yyyymm = yyyymm_to, v)]
    Bp[pm, dose_p := i.v, on = c("DUID", "yyyymm")]
    fp <- feols(reach_a ~ essential*dose_p + srmc + TOTALDEMAND + nonsync_mw + RRP +
                  slope_kernel + saturated | DUID + yyyymm, Bp, lean = TRUE, notes = FALSE)
    b_perm[r] <- coef(fp)[["essentialTRUE:dose_p"]]
    if (r %% 100 == 0) cat(sprintf("  [%s] RI draw %d/%d\n", dz, r, RI_R))
  }
  ri_p <- (1 + sum(abs(b_perm) >= abs(b_obs))) / (RI_R + 1)
  cat(sprintf("  [%s] b_obs=%.5f; two-sided RI p=%.4f (|b_perm|>=|b_obs| in %d of %d)\n",
              dz, b_obs, ri_p, sum(abs(b_perm) >= abs(b_obs)), RI_R))
  ri[[dz]] <- data.table(dose = dz, estimate = b_obs, ri_p = ri_p, draws = RI_R,
                         exceed = sum(abs(b_perm) >= abs(b_obs)))
  fwrite(data.table(b_perm = b_perm), file.path(OUT, sprintf("test4_ri_draws_%s.csv", dz)))
}
fwrite(rbindlist(ri), file.path(OUT, "test4_ri.csv"))

cat("\nSaved test4_{dose_table,dose_summary,dose_power,dose_correlations,results_full,interaction,horserace,wcb,3a_month_gaps,3a_result,ri,ri_draws_*}.csv to outputs/07_round3/.\n")
cat("=== STOP: adjudicate against test4_preregistration.md; findings file next. ===\n")
