#!/usr/bin/env Rscript
# stage3b_conditions_pi.R -- conditions-only propensity, enforcing the registration's hard
# constraint after the Stage-3 audits caught the violation in the Stage-2 pi:
# the Stage-2 hazard embeds the direction record (log_tsl regressor; hazard zeroed inside
# spells/cool-downs), and directions are focal-heavy, so pi embedded the focal station's
# directed status -- leakage R^2 = 0.088 (> 0.01 stop), nesting inverted.
# Fix (constraint enforcement, not amendment): refit the hazard WITHOUT log_tsl on the same
# risk set, predict on ALL half-hours (no direction-record zeroing), accumulate pi2. The
# Stage-2 model stands as the operator description; pi2 is the Stage-4 dose candidate.
# Re-run all three audits on pi2. Run from Direction_clean/.

suppressMessages({ library(data.table) })
set.seed(20260707)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")

S <- readRDS(file.path(OUT, "stage2_panel.rds")); setDT(S); setorder(S, t30)
S[, yyyymm := format(t30 - 1, "%Y%m")]

# risk set as in Stage 2 (estimation only; prediction is everywhere)
R <- S[in_spell == FALSE & tsl_h > 8 & !is.na(min_fc_slack) & !is.na(dem_trough) & !is.na(ns_share_fc)]
fml2 <- onset ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + hour_block
cat("=== conditions-only hazard (log_tsl dropped; 8 params) ===\n")
fit2 <- glm(fml2, family = binomial(), data = R)
print(summary(fit2)$coefficients)

# month-out CV predictions on ALL half-hours with covariates
P <- S[!is.na(min_fc_slack) & !is.na(dem_trough) & !is.na(ns_share_fc)]
P[, hz2 := NA_real_]
for (M in MONTHS) {
  f <- glm(fml2, family = binomial(), data = R[yyyymm != M])
  P[yyyymm == M, hz2 := predict(f, .SD, type = "response")]
}
auc <- function(y, p) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1
  (sum(r[y]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
rr <- merge(R[, .(t30, onset)], P[, .(t30, hz2)], by = "t30")
cat(sprintf("CV AUC on the risk set (conditions-only): %.3f\n", auc(rr$onset, rr$hz2)))

S <- merge(S, P[, .(t30, hz2)], by = "t30", all.x = TRUE)
setorder(S, t30)
S[is.na(hz2), hz2 := 0]   # covariate-edge rows only (sample boundary)
accum <- function(hz, k) 1 - exp(frollsum(log(pmax(1 - hz, 1e-12)), n = k, align = "left"))
S[, `:=`(pi2_4h = accum(hz2, 8), pi2_8h = accum(hz2, 16), pi2_24h = accum(hz2, 48))]
S[, pi2_slow := frollmean(pi2_8h, n = 48 * 30, align = "center")]
S[, pi2_fast := pi2_8h - pi2_slow]

# ---- audits on pi2 ----
fa30 <- readRDS(file.path(OUT, "focal_avail_cache.rds"))
fa30[, t30 := as.POSIXct(ceiling(as.numeric(SETTLEMENTDATE) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
fa30 <- fa30[, .(tor_avail = mean(avail)), by = t30]
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds")); setDT(D)
cs <- D[DUID %chin% c("TORRB2", "TORRB3", "TORRB4"), .(interval_dt, cheap_a_share)]
cs[, t30 := as.POSIXct(ceiling(as.numeric(interval_dt) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
cs30 <- cs[, .(tor_cheap_share = mean(cheap_a_share, na.rm = TRUE)), by = t30]
A <- Reduce(function(a, b) merge(a, b, by = "t30", all.x = TRUE),
            list(S[!is.na(pi2_8h), .(t30, pi2_8h, pi2_slow, pi2_fast, pex30, n1_30)], fa30, cs30))
A <- A[!is.na(tor_avail) & !is.na(tor_cheap_share)]

lk <- lm(pi2_8h ~ tor_avail + tor_cheap_share, A)
r2 <- summary(lk)$r.squared
cat(sprintf("\n(i) LEAKAGE on pi2: R^2 = %.5f (stop if > 0.01) -> %s\n", r2,
            if (r2 > 0.01) "FAIL" else "PASS"))
print(coef(summary(lk)))

A[, tier := fifelse(pex30, "pex = 1", fifelse(n1_30, "N-1 = 1 (not pex)", "rest"))]
nest <- A[, .(n = .N, mean_pi2 = mean(pi2_8h), p90 = quantile(pi2_8h, .9)), by = tier][order(-mean_pi2)]
cat("\n(ii) NESTING on pi2 (expect pex >= N-1 >= rest):\n"); print(nest)

vs <- A[!is.na(pi2_slow), .(v = var(pi2_8h), vs = var(pi2_slow), vf = var(pi2_fast))]
cat(sprintf("\n(iii) VARIANCE SPLIT on pi2: slow %.1f%% | fast %.1f%%\n", 100 * vs$vs / vs$v, 100 * vs$vf / vs$v))

saveRDS(S, file.path(OUT, "stage2_panel.rds"))   # extend the panel with pi2 columns
fwrite(nest, file.path(OUT, "stage3b_nesting_pi2.csv"))
fwrite(data.table(r2_leakage_pi2 = r2, cv_auc = auc(rr$onset, rr$hz2),
                  var_share_slow = vs$vs / vs$v), file.path(OUT, "stage3b_audits_pi2.csv"))
cat("\nDONE stage3b\n")
