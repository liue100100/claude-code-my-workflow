#!/usr/bin/env Rscript
# cut5_spot_controlled.R
# Adds the daily/interval SPOT PRICE as a third confounder control to Cut 5.
#
# Rationale: spot (SA1 RRP) is a common cause of BOTH d_t and withholding.
#   - d_t is mechanically the trailing-365d 90th pctile of spot, so high-spot
#     regimes (2022) produce high d_t.
#   - spot independently drives withholding: high spot -> stronger incentive to
#     be dispatched via the market (offer low, withhold less); low spot ->
#     incentive to sit out and wait for a paid direction.
#   Since spot up pushes d_t up but withholding down, omitting spot biases the
#   d_t coefficient DOWNWARD -- same direction as the SRMC omission (Cut 5).
#
# Primary spec: INTERVAL-LEVEL (5-min) regression, spot at native resolution,
#   unit FE, clustered by month. No aggregation of spot -> within-day volatility
#   fully preserved.
#
# Figure: unit-month partial-residual scatter (FE / +SRMC / +SRMC+spot), using a
#   HIERARCHICALLY-aggregated monthly spot (5min -> 30min -> day -> month) so
#   each day contributes equally instead of a flat mean dominated by cap spikes.
#
# NB: 5-minute settlement began 1 Oct 2021; for 2022-2024 the 5-min interval IS
#   the settlement interval (30-min trading intervals are legacy).

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(fixest)
})

setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"

SPIKE_THRESH <- 300   # $/MWh; share of intervals above this = within-day volatility proxy

# ---------------------------------------------------------------------------
# Load panel (already carries 5-min spot, withheld_share, d_t, srmc per row)
# ---------------------------------------------------------------------------
panel <- readRDS(file.path(OUT, "panel_v3.rds"))
if (!inherits(panel$interval_dt, "POSIXct"))
  panel[, interval_dt := as.POSIXct(interval_dt, tz = "UTC")]

cat(sprintf("Panel: %d rows. interval_dt class: %s\n",
            nrow(panel), paste(class(panel$interval_dt), collapse="/")))

# ---------------------------------------------------------------------------
# Build the SPOT series properly (region-wide: one RRP per interval, not per unit)
# ---------------------------------------------------------------------------
spot_int <- unique(panel[!is.na(spot), .(interval_dt, spot)])
setorder(spot_int, interval_dt)
spot_int[, yyyymm   := format(interval_dt, "%Y%m")]
spot_int[, date     := as.IDate(interval_dt)]
spot_int[, halfhour := as.integer(as.numeric(interval_dt) %/% 1800L)]  # 30-min bucket id

cat(sprintf("Unique SA1 spot intervals: %d (%s to %s)\n",
            nrow(spot_int),
            format(min(spot_int$interval_dt)), format(max(spot_int$interval_dt))))

# --- Hierarchical aggregation: 5-min -> 30-min -> daily -> monthly ---
hh30  <- spot_int[, .(spot30 = mean(spot)),       by = .(yyyymm, date, halfhour)]
daily <- hh30[,     .(spot_day = mean(spot30)),    by = .(yyyymm, date)]
mspot_hier <- daily[, .(spot_hier = mean(spot_day)), by = yyyymm]

# --- Flat monthly mean (for contrast) + volatility/spike measures ---
mspot_flat <- spot_int[, .(spot_flat  = mean(spot),
                           spot_p50   = median(spot),
                           spot_spike = mean(spot > SPIKE_THRESH)),  # within-day volatility proxy
                       by = yyyymm]

mspot <- merge(mspot_hier, mspot_flat, by = "yyyymm")
cat("\nMonthly spot (hierarchical vs flat) -- note where flat >> hierarchical (spiky months):\n")
print(mspot[, .(yyyymm,
                spot_hier = round(spot_hier,1),
                spot_flat = round(spot_flat,1),
                spike_pct = round(spot_spike*100,1))])

# --- Daily spot + 1-day lag (for the interval-level simultaneity robustness) ---
daily[, spot_day_lag1 := shift(spot_day, 1L)]   # daily is time-ordered within month groups
setorder(daily, date)
daily[, spot_day_lag1 := shift(spot_day, 1L)]    # re-lag on full date order

# ---------------------------------------------------------------------------
# INTERVAL-LEVEL regression panel (5-min). Spot at native resolution.
# ---------------------------------------------------------------------------
ipanel <- panel[!is.na(withheld_share) & !is.na(dt) & !is.na(spot) &
                !is.na(srmc_marginal) & MAXAVAIL > 1,
                .(duid, yyyymm, interval_dt, withheld_share,
                  dt, srmc_marginal, spot)]
ipanel[, date := as.IDate(interval_dt)]
ipanel <- merge(ipanel, daily[, .(date, spot_day_lag1)], by = "date", all.x = TRUE)

# standardize d_t (so coefficient = per-SD; comparable to Cut 5)
dt_mu <- mean(ipanel$dt); dt_sd <- sd(ipanel$dt)
ipanel[, dt_std := (dt - dt_mu) / dt_sd]

cat(sprintf("\nInterval panel for regression: %d rows, %d months, %d units\n",
            nrow(ipanel), uniqueN(ipanel$yyyymm), uniqueN(ipanel$duid)))

# Progressive controls, clustered by month (d_t/srmc vary at month level)
m1 <- feols(withheld_share ~ dt_std                               | duid, ipanel, vcov = ~yyyymm)
m2 <- feols(withheld_share ~ dt_std + srmc_marginal              | duid, ipanel, vcov = ~yyyymm)
m3 <- feols(withheld_share ~ dt_std + srmc_marginal + spot        | duid, ipanel, vcov = ~yyyymm)
m4 <- feols(withheld_share ~ dt_std + srmc_marginal + spot_day_lag1 | duid,
            ipanel[!is.na(spot_day_lag1)], vcov = ~yyyymm)  # lagged spot: simultaneity robustness

cat("\n================ INTERVAL-LEVEL Cut 5 with spot control ================\n")
etable(m1, m2, m3, m4,
       headers = c("FE only", "+SRMC", "+SRMC+spot(5min)", "+SRMC+spot(lag1d)"),
       digits = 4, fitstat = ~ n + r2)

# Tidy coefficient table for d_t
grab <- function(m, lab) data.table(
  spec   = lab,
  dt_coef = round(coef(m)[["dt_std"]], 5),
  dt_se   = round(se(m)[["dt_std"]],   5),
  dt_t    = round(coef(m)[["dt_std"]] / se(m)[["dt_std"]], 2),
  n       = m$nobs)
coef_tab <- rbindlist(list(
  grab(m1, "FE only"),
  grab(m2, "+ SRMC"),
  grab(m3, "+ SRMC + spot (5-min, native)"),
  grab(m4, "+ SRMC + spot (1-day lag, simultaneity robust)")
))
cat("\nd_t coefficient across specifications (interval-level, clustered by month):\n")
print(coef_tab)
fwrite(coef_tab, file.path(OUT, "Cut5_spot_robustness.csv"))

# ---------------------------------------------------------------------------
# FIGURE: unit-month partial-residual scatter, three panels (FE / +SRMC / +spot)
# Uses HIERARCHICAL monthly spot (the "aggregate up, don't flat-average" series).
# ---------------------------------------------------------------------------
um <- panel[!is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1,
  .(mean_ws       = mean(withheld_share, na.rm = TRUE),
    dt            = first(dt),
    srmc_marginal = first(srmc_marginal)),
  by = .(duid, yyyymm)]
um <- merge(um, mspot[, .(yyyymm, spot_hier)], by = "yyyymm", all.x = TRUE)
um <- um[!is.na(spot_hier) & !is.na(srmc_marginal)]
um[, dt_std    := (dt - mean(dt)) / sd(dt)]
um[, post_exit := yyyymm >= "202307"]

# FWL partial residuals for each control set
res <- function(ctrl_formula_rhs) {
  fy <- as.formula(paste("mean_ws ~", ctrl_formula_rhs, "| duid"))
  fx <- as.formula(paste("dt_std  ~", ctrl_formula_rhs, "| duid"))
  list(ws = resid(feols(fy, um)), dt = resid(feols(fx, um)))
}
r_fe   <- res("1")
r_srmc <- res("srmc_marginal")
r_spot <- res("srmc_marginal + spot_hier")

# slopes from full models (unit FE) for annotation
b_fe   <- coef(feols(mean_ws ~ dt_std                               | duid, um))[["dt_std"]]
b_srmc <- coef(feols(mean_ws ~ dt_std + srmc_marginal              | duid, um))[["dt_std"]]
b_spot <- coef(feols(mean_ws ~ dt_std + srmc_marginal + spot_hier  | duid, um))[["dt_std"]]

lab_fe   <- sprintf("1. Unit FE only\nbeta = %+.4f", b_fe)
lab_srmc <- sprintf("2. + SRMC control\nbeta = %+.4f", b_srmc)
lab_spot <- sprintf("3. + SRMC + spot\nbeta = %+.4f", b_spot)

pdata <- rbindlist(list(
  data.table(e_dt = r_fe$dt,   e_ws = r_fe$ws,   post_exit = um$post_exit, panel = lab_fe),
  data.table(e_dt = r_srmc$dt, e_ws = r_srmc$ws, post_exit = um$post_exit, panel = lab_srmc),
  data.table(e_dt = r_spot$dt, e_ws = r_spot$ws, post_exit = um$post_exit, panel = lab_spot)
))
pdata[, panel := factor(panel, levels = c(lab_fe, lab_srmc, lab_spot))]

p <- ggplot(pdata, aes(x = e_dt, y = e_ws)) +
  geom_hline(yintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.3) +
  geom_point(aes(colour = post_exit), alpha = 0.5, size = 1.6) +
  geom_smooth(method = "lm", se = TRUE, colour = "black", fill = "grey80", linewidth = 0.9) +
  facet_wrap(~panel, ncol = 3, scales = "free_x") +
  scale_colour_manual(
    values = c("FALSE" = "#e41a1c", "TRUE" = "#377eb8"),
    labels = c("FALSE" = "Pre-exit (high d_t)", "TRUE" = "Post-exit (low d_t)"),
    name = NULL) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "withheld_share vs d_t: progressively removing confounders",
    subtitle = paste0(
      "Partial-regression residuals (unit-month). Adding SRMC then spot strips the 2022",
      " price-regime confound from d_t.\n",
      "Spot control = hierarchical monthly mean (5min->30min->day->month), so spiky days",
      " don't dominate. Inference: see interval-level table (clustered by month)."),
    x = "d_t residual (standardised, within-unit)",
    y = "withheld_share residual"
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text      = element_text(size = 9, face = "bold"),
        plot.subtitle   = element_text(size = 8, colour = "grey30"),
        panel.spacing   = unit(1.2, "lines"))

ggsave(file.path(OUT, "Cut5_SRMC_spot_controlled.png"), p,
       width = 14, height = 5.5, dpi = 150)
cat("\nSaved: Cut5_SRMC_spot_controlled.png\n")
cat("Saved: Cut5_spot_robustness.csv\n")
cat("\nDone.\n")
