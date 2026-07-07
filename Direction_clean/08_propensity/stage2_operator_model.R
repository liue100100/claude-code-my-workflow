#!/usr/bin/env Rscript
# stage2_operator_model.R -- Stage 2 of the direction-propensity registration:
# discrete-time hazard (logit) on independent direction onsets, month-out CV, lead-time
# distribution, five-bucket decomposition of directed time, and the propensity pi(t).
#
# Registered specification (fixed; no additional regressors):
#   min forecast slack over the commitment lead window (workhorse), current slack (commitment
#   margin, per the Stage-1 handoff), forecast demand trough depth, forecast non-synchronous
#   share, log time-since-last-direction, 3 hour-of-day block dummies. ~9-10 parameters.
# Risk set: half-hours with no direction active AND >= 8h since the last spell ended (chained
# re-issue time is excluded; it feeds the decomposition). Outcome: independent onset (N = 8h
# rule; 386 onsets from Stage 0) in the half-hour.
# Run from Direction_clean/.

suppressMessages({ library(data.table) })
set.seed(20260707)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")
GAP_H <- 8

S <- readRDS(file.path(OUT, "stage1_panel.rds")); setDT(S); setkey(S, t30)
SP <- fread(file.path(OUT, "stage0_spells.csv"))
SP[, `:=`(spell_start = force10(spell_start), spell_end = force10(spell_end))]
setorder(SP, spell_start)
SP[, gap_h := as.numeric(spell_start - shift(spell_end), units = "hours")]
SP[, independent := is.na(gap_h) | gap_h > GAP_H]
SP[, chain_id := cumsum(independent)]
cat(sprintf("spells: %d | chains (independent onsets): %d\n", nrow(SP), SP[, uniqueN(chain_id)]))

# ---------------------------------------------------------------------------
# Forecast demand at horizons (PDPASA DEMAND50, latest run <= t-h), for trough + ns share
# ---------------------------------------------------------------------------
PD <- rbindlist(lapply(MONTHS, function(M) readRDS(file.path(CACHE, sprintf("PDPASA_RS_%s.rds", M)))), fill = TRUE)
PD <- PD[is.na(RUNTYPE) | RUNTYPE == "OUTAGE_LRC"]
PD[, `:=`(RUN_DATETIME = force10(RUN_DATETIME), INTERVAL_DATETIME = force10(INTERVAL_DATETIME))]
PDD <- PD[!is.na(DEMAND50), .(RUN_DATETIME, INTERVAL_DATETIME, DEMAND50)]
setkey(PDD, INTERVAL_DATETIME, RUN_DATETIME)
for (h in c(1, 4, 8)) {
  q <- data.table(INTERVAL_DATETIME = S$t30, RUN_DATETIME = S$t30 - h * 3600)
  d <- PDD[q, roll = Inf, on = .(INTERVAL_DATETIME, RUN_DATETIME), mult = "last"]
  S[, (sprintf("dem_fc_%dh", h)) := d$DEMAND50]
}
rm(PD, PDD); gc()

# ---------------------------------------------------------------------------
# Covariates AS SEEN AT tau = t30 (decision time): lead the target-indexed forecasts
# slack_fc_h is indexed by TARGET time (forecast made at target - h). As seen at tau, the
# forecast for target tau + h is slack_fc_h shifted back by h. 30-min grid -> lead by 2h steps.
# ---------------------------------------------------------------------------
setorder(S, t30)
lead_by <- function(x, k) shift(x, n = k, type = "lead")
S[, `:=`(
  fc_slack_1h = lead_by(slack_fc_1h, 2),   # target tau+1h
  fc_slack_4h = lead_by(slack_fc_4h, 8),   # target tau+4h
  fc_slack_8h = lead_by(slack_fc_8h, 16),  # target tau+8h
  fc_dem_1h   = lead_by(dem_fc_1h, 2),
  fc_dem_4h   = lead_by(dem_fc_4h, 8),
  fc_dem_8h   = lead_by(dem_fc_8h, 16),
  fc_ns_8h    = lead_by(ns_fc_8h, 16)
)]
S[, min_fc_slack := pmin(fc_slack_1h, fc_slack_4h, fc_slack_8h)]
S[, dem_trough   := pmin(fc_dem_1h, fc_dem_4h, fc_dem_8h) / 1000]      # GW, forecast window min
S[, ns_share_fc  := fc_ns_8h / pmax(fc_dem_8h, 1)]                     # forecast non-sync share
S[, hour_block := cut(as.integer(format(t30 - 1, "%H")), c(-1, 6, 12, 18, 24),
                      labels = c("h0_6", "h6_12", "h12_18", "h18_24"))]

# directed / post-spell state per half-hour
S[, in_spell := FALSE]
for (i in seq_len(nrow(SP))) S[t30 > SP$spell_start[i] & t30 <= SP$spell_end[i] + 1, in_spell := TRUE]
# time since last spell end (hours) at tau
idx <- findInterval(as.numeric(S$t30), as.numeric(SP$spell_end))
S[, tsl_h := as.numeric(t30 - SP$spell_end[pmax(idx, 1)], units = "hours")]
S[idx == 0, tsl_h := as.numeric(t30 - min(t30) + 1800, units = "hours")]  # pre-first-spell: time from sample start
S[, log_tsl := log(pmax(tsl_h, 0.5))]

# onset outcome: half-hour containing an independent spell start
ons <- SP[independent == TRUE, .(t30 = as.POSIXct(ceiling(as.numeric(spell_start) / 1800) * 1800,
                                                  origin = "1970-01-01", tz = "Etc/GMT-10"))]
S[, onset := t30 %in% ons$t30]

# risk set
R <- S[in_spell == FALSE & tsl_h > GAP_H & !is.na(min_fc_slack) & !is.na(dem_trough) & !is.na(ns_share_fc)]
cat(sprintf("risk set: %d half-hours | onsets in risk set: %d (of %d independent)\n",
            nrow(R), R[, sum(onset)], SP[independent == TRUE, .N]))

# ---------------------------------------------------------------------------
# Registered logit, ~10 parameters
# ---------------------------------------------------------------------------
fml <- onset ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + log_tsl + hour_block
fit <- glm(fml, family = binomial(), data = R)
cat("\n=== Registered hazard logit ===\n")
print(summary(fit)$coefficients)
cat(sprintf("params: %d | events per param: %.1f\n", length(coef(fit)), R[, sum(onset)] / length(coef(fit))))

# ---------------------------------------------------------------------------
# Month-out cross-validation: fit on 35 months, predict the held month
# ---------------------------------------------------------------------------
R[, yyyymm := format(t30 - 1, "%Y%m")]
R[, p_cv := NA_real_]
for (M in MONTHS) {
  f <- glm(fml, family = binomial(), data = R[yyyymm != M])
  R[yyyymm == M, p_cv := predict(f, .SD, type = "response")]
}
stopifnot(R[, sum(is.na(p_cv))] == 0)
# calibration by CV-predicted decile + AUC
R[, dec := cut(p_cv, quantile(p_cv, 0:10 / 10), include.lowest = TRUE, labels = 1:10)]
cal <- R[, .(n = .N, p_hat = mean(p_cv), p_obs = mean(onset)), by = dec][order(dec)]
cat("\n=== Month-out CV calibration (deciles of predicted hazard) ===\n"); print(cal)
auc <- function(y, p) { r <- rank(p); n1 <- sum(y); n0 <- length(y) - n1
  (sum(r[y]) - n1 * (n1 + 1) / 2) / (n1 * n0) }
cat(sprintf("CV AUC: %.3f | in-sample AUC: %.3f | CV deviance ratio (1 - D/D0): %.3f\n",
            auc(R$onset, R$p_cv), auc(R$onset, predict(fit, R, type = "response")),
            1 - with(R, -2 * sum(onset * log(pmax(p_cv, 1e-12)) + (1 - onset) * log(pmax(1 - p_cv, 1e-12)))) /
                  with(R, { p0 <- mean(onset); -2 * sum(onset * log(p0) + (1 - onset) * log(1 - p0)) })))
fwrite(cal, file.path(OUT, "stage2_calibration.csv"))
ct <- as.data.table(summary(fit)$coefficients, keep.rownames = "term")
fwrite(ct, file.path(OUT, "stage2_hazard_coefs.csv"))

# ---------------------------------------------------------------------------
# Lead-time distribution: independent onset -> first slack_commit == 0 at/after onset
# ---------------------------------------------------------------------------
need_times <- S[slack_commit == 0, t30]
lead <- SP[independent == TRUE][, {
  nt <- need_times[need_times >= spell_start & need_times <= spell_end + 1]
  .(lead_h = if (length(nt)) as.numeric(min(nt) - spell_start, units = "hours") else NA_real_)
}, by = spell_start]
cat(sprintf("\n=== Lead time (onset -> first commitment-need in spell) ===\nonsets with a need event: %d/%d | median %.1f h | p25 %.1f | p75 %.1f\n",
            lead[!is.na(lead_h), .N], nrow(lead),
            lead[, median(lead_h, na.rm = TRUE)], lead[, quantile(lead_h, .25, na.rm = TRUE)],
            lead[, quantile(lead_h, .75, na.rm = TRUE)]))
fwrite(lead, file.path(OUT, "stage2_leadtimes.csv"))

# ---------------------------------------------------------------------------
# Five-bucket decomposition of ALL directed time (chain grain, 30-min)
# Definitions (fixed here, stated in findings): need = slack_commit == 0.
#   core:        directed half-hours with need
#   buffer:      before the chain's FIRST need
#   persistence: after the last need, same spell as the last need
#   chaining:    in re-issue spells (2nd+ of the chain) after the chain's last need
#   residual:    entire chains with no need anywhere
# ---------------------------------------------------------------------------
D30 <- rbindlist(lapply(seq_len(nrow(SP)), function(i) {
  t0 <- as.POSIXct(ceiling(as.numeric(SP$spell_start[i]) / 1800) * 1800,
                   origin = "1970-01-01", tz = "Etc/GMT-10")
  t1 <- max(t0, SP$spell_end[i])   # sub-30-min spells occupy their single covering half-hour
  data.table(chain_id = SP$chain_id[i], spell_i = i, t30 = seq(t0, t1, by = 1800))
}))
D30 <- merge(D30, S[, .(t30, slack_commit, slack_avail)], by = "t30", all.x = TRUE)
D30[, need := slack_commit == 0]
D30[, first_spell := spell_i == min(spell_i), by = chain_id]
D30[, has_need := any(need, na.rm = TRUE), by = chain_id]
D30[, `:=`(t_first_need = suppressWarnings(min(t30[need], na.rm = TRUE)),
           t_last_need  = suppressWarnings(max(t30[need], na.rm = TRUE))), by = chain_id]
D30[, last_need_spell := { ln <- suppressWarnings(max(t30[need], na.rm = TRUE))
                           sp <- spell_i[which(t30 == ln)]; if (length(sp)) sp[1] else NA_integer_ }, by = chain_id]
D30[, bucket := fifelse(!has_need, "residual",
               fifelse(need, "core",
               fifelse(t30 < t_first_need, "buffer",
               fifelse(t30 > t_last_need & spell_i == last_need_spell, "persistence",
               fifelse(t30 > t_last_need & spell_i != last_need_spell, "chaining", "persistence")))))]
dec <- D30[, .(half_hours = .N, hours = .N / 2, share = round(100 * .N / nrow(D30), 1)), by = bucket][order(-half_hours)]
cat("\n=== Five-bucket decomposition of directed time (need = slack_commit==0) ===\n"); print(dec)
# sensitivity: strict availability need
D30[, need_av := slack_avail == 0]
D30[, has_need_av := any(need_av, na.rm = TRUE), by = chain_id]
cat(sprintf("sensitivity (need = slack_avail==0): chains with any availability-need: %d/%d | directed time in no-availability-need chains: %.1f%%\n",
            D30[, uniqueN(chain_id[has_need_av])], D30[, uniqueN(chain_id)],
            100 * D30[has_need_av == FALSE, .N] / nrow(D30)))
fwrite(dec, file.path(OUT, "stage2_decomposition.csv"))

# ---------------------------------------------------------------------------
# Propensity pi(t): 1 - prod(1 - h) over the horizon, from CV hazards (leak-free)
# pi defined on ALL half-hours: hazard = CV prediction on risk-set rows, 0 inside spells /
# chained cool-down (a direction cannot independently onset there).
# ---------------------------------------------------------------------------
S <- merge(S, R[, .(t30, p_cv)], by = "t30", all.x = TRUE)
S[, hz := fifelse(is.na(p_cv), 0, p_cv)]
setorder(S, t30)
accum <- function(hz, k) {         # rolling 1 - prod(1 - hz) over next k half-hours
  l1 <- frollsum(log(pmax(1 - hz, 1e-12)), n = k, align = "left")
  1 - exp(l1)
}
S[, `:=`(pi_4h = accum(hz, 8), pi_8h = accum(hz, 16), pi_24h = accum(hz, 48))]
# slow/fast split: 30-day centered moving average of pi_8h
S[, pi_slow := frollmean(pi_8h, n = 48 * 30, align = "center")]
S[, pi_fast := pi_8h - pi_slow]
cat(sprintf("\npi_8h: mean %.4f | sd %.4f | slow-component sd %.4f | fast sd %.4f | var share slow %.2f\n",
            S[, mean(pi_8h, na.rm = TRUE)], S[, sd(pi_8h, na.rm = TRUE)],
            S[, sd(pi_slow, na.rm = TRUE)], S[, sd(pi_fast, na.rm = TRUE)],
            S[, var(pi_slow, na.rm = TRUE) / var(pi_8h, na.rm = TRUE)]))

saveRDS(S, file.path(OUT, "stage2_panel.rds"))
cat("\nSaved stage2_{panel.rds,hazard_coefs,calibration,leadtimes,decomposition}.csv\n")
cat("=== STOP: adjudicate residual-bucket gate against the registration before Stage 3/4. ===\n")
