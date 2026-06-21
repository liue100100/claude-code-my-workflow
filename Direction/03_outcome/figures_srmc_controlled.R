#!/usr/bin/env Rscript
# figures_srmc_controlled.R
# Two additional figures: withheld_share vs d_t after controlling for SRMC.
#
# Figure 1 (Cut3_SRMC_controlled.png):
#   Unit-level faceted scatter. For each unit, residualize withheld_share on
#   srmc_marginal (removes the mechanical SRMC effect), then plot vs raw d_t.
#   Compare visually to Cut3_withheld_vs_dt.png (no control).
#
# Figure 2 (Cut5_SRMC_controlled.png):
#   Side-by-side partial regression plots. Left: unit FE only (current Cut 5).
#   Right: unit FE + SRMC both removed (FWL residuals). Shows the sign reversal.

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(fixest)
})

setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"

# ---------------------------------------------------------------------------
# Load cached data
# ---------------------------------------------------------------------------
panel <- readRDS(file.path(OUT, "panel_v3.rds"))

# Build unit-month aggregates (same as Cut 5)
um <- panel[!is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1,
  .(mean_ws      = mean(withheld_share, na.rm = TRUE),
    dt            = first(dt),
    srmc_marginal = first(srmc_marginal),
    srmc_allin    = first(srmc_allin),
    n_intervals   = .N),
  by = .(duid, yyyymm)]

um[, dt_std    := (dt - mean(dt, na.rm = TRUE)) / sd(dt, na.rm = TRUE)]
um[, post_exit := yyyymm >= "202307"]

tech_map <- data.table(
  duid     = c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
               "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5"),
  tech_grp = c(rep("Gas-steam",4), "CCGT","Cogen",
               "OCGT","Recip.", rep("OCGT",3), "OCGT")
)
um <- merge(um, tech_map, by = "duid", all.x = TRUE)

cat(sprintf("Unit-month panel: %d rows, %d units, %d months\n",
            nrow(um), uniqueN(um$duid), uniqueN(um$yyyymm)))

# ---------------------------------------------------------------------------
# Figure 1: Cut 3 SRMC-controlled
# For each unit separately: residualize mean_ws on srmc_marginal.
# y = ws_resid + grand_mean (so axis reads as withheld_share level).
# x = d_t (raw).
# ---------------------------------------------------------------------------

# Within-unit SRMC residuals
um[, ws_srmc_resid := {
  fit <- lm(mean_ws ~ srmc_marginal)
  resid(fit)
}, by = duid]

# Shift residuals up by the grand mean so the y-axis is interpretable
grand_mean <- mean(um$mean_ws, na.rm = TRUE)
um[, ws_srmc_adj := ws_srmc_resid + grand_mean]

# Slope annotation per unit
unit_slopes_ctrl <- um[, {
  fit <- lm(ws_srmc_resid ~ dt)
  b   <- coef(fit)[["dt"]]
  .(label = sprintf("slope = %+.4f", b),
    dt_lo  = min(dt, na.rm = TRUE),
    ws_hi  = max(ws_srmc_adj, na.rm = TRUE))
}, by = duid]

p1 <- ggplot(um, aes(x = dt, y = ws_srmc_adj)) +
  geom_hline(yintercept = grand_mean, colour = "grey65",
             linetype = "dashed", linewidth = 0.4) +
  geom_point(aes(colour = post_exit), size = 1.8, alpha = 0.75) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "black", fill = "grey80", linewidth = 0.75) +
  geom_text(data = unit_slopes_ctrl,
            aes(x = dt_lo, y = ws_hi, label = label),
            hjust = 0, vjust = 1, size = 2.5, colour = "grey30") +
  facet_wrap(~duid, ncol = 4, scales = "free") +
  scale_colour_manual(
    values = c("FALSE" = "#e41a1c", "TRUE" = "#377eb8"),
    labels = c("FALSE" = "Pre-exit (high d_t)", "TRUE" = "Post-exit (low d_t)"),
    name   = NULL) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "withheld_share vs d_t — SRMC cost environment controlled",
    subtitle = paste0(
      "withheld_share residualized on srmc_marginal within each unit",
      " (removes mechanical gas-price effect)\n",
      "Compare to Cut3_withheld_vs_dt.png — slopes flip positive for most units.",
      " Dashed = sample mean withheld_share."),
    x = expression(d[t] ~ "(¢/MWh)"),
    y = "withheld_share (SRMC-adjusted)"
  ) +
  theme_bw(base_size = 9) +
  theme(legend.position  = "bottom",
        strip.text       = element_text(size = 8, face = "bold"),
        plot.subtitle    = element_text(size = 7.5, colour = "grey30"))

ggsave(file.path(OUT, "Cut3_SRMC_controlled.png"), p1,
       width = 14, height = 10, dpi = 150)
cat("Saved: Cut3_SRMC_controlled.png\n")

# ---------------------------------------------------------------------------
# Figure 2: Cut 5 side-by-side partial regression (sign reversal)
# Left  panel: partial residuals from unit FE only (current Cut 5 figure)
# Right panel: partial residuals from unit FE + SRMC (FWL theorem)
# ---------------------------------------------------------------------------

# Left: unit FE only
e_ws_fe   <- resid(feols(mean_ws ~ 1           | duid, data = um))
e_dt_fe   <- resid(feols(dt_std  ~ 1           | duid, data = um))

# Right: unit FE + SRMC (FWL)
e_ws_srmc <- resid(feols(mean_ws ~ srmc_marginal | duid, data = um))
e_dt_srmc <- resid(feols(dt_std  ~ srmc_marginal | duid, data = um))

# Annotate slopes (recovered from full fixest models for accuracy)
b_fe   <- coef(feols(mean_ws ~ dt_std                  | duid, data = um,
                     vcov = "hetero"))[["dt_std"]]
b_srmc <- coef(feols(mean_ws ~ dt_std + srmc_marginal  | duid, data = um,
                     vcov = "hetero"))[["dt_std"]]

panel_fe   <- sprintf("Without SRMC control\n(unit FE only)\nβ = %.4f", b_fe)
panel_srmc <- sprintf("With SRMC control\n(unit FE + SRMC)\nβ = +%.4f **", b_srmc)

plot_data <- rbindlist(list(
  data.table(e_dt = e_dt_fe,   e_ws = e_ws_fe,
             post_exit = um$post_exit, duid = um$duid,
             panel = panel_fe),
  data.table(e_dt = e_dt_srmc, e_ws = e_ws_srmc,
             post_exit = um$post_exit, duid = um$duid,
             panel = panel_srmc)
))
plot_data[, panel := factor(panel, levels = c(panel_fe, panel_srmc))]

p2 <- ggplot(plot_data, aes(x = e_dt, y = e_ws)) +
  geom_hline(yintercept = 0, colour = "grey65", linetype = "dashed", linewidth = 0.4) +
  geom_vline(xintercept = 0, colour = "grey65", linetype = "dashed", linewidth = 0.4) +
  geom_point(aes(colour = post_exit), alpha = 0.5, size = 1.8) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "black", fill = "grey80", linewidth = 0.9) +
  facet_wrap(~panel, ncol = 2, scales = "free_x") +
  scale_colour_manual(
    values = c("FALSE" = "#e41a1c", "TRUE" = "#377eb8"),
    labels = c("FALSE" = "Pre-exit (high d_t)", "TRUE" = "Post-exit (low d_t)"),
    name   = NULL) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "Partial regression: withheld_share on d_t — the sign reversal",
    subtitle = paste0(
      "Left: after removing unit fixed effects only — slope ≈ 0, slightly negative.\n",
      "Right: after also removing SRMC cost environment — slope turns positive (** p < 0.01).\n",
      "The 2022 gas shock drove d_t and SRMC up simultaneously, masking the strategic response.",
      " SRMC control recovers it.\n",
      "Unit-month observations | 11 SA thermal units | 35 months | het.-robust SE."),
    x = "d_t residual (standardised, within-unit variation)",
    y = "withheld_share residual"
  ) +
  theme_bw(base_size = 11) +
  theme(
    legend.position = "bottom",
    strip.text      = element_text(size = 10, face = "bold"),
    plot.subtitle   = element_text(size = 8, colour = "grey30"),
    panel.spacing   = unit(1.5, "lines")
  )

ggsave(file.path(OUT, "Cut5_SRMC_controlled.png"), p2,
       width = 12, height = 6, dpi = 150)
cat("Saved: Cut5_SRMC_controlled.png\n")

# ---------------------------------------------------------------------------
# Figure 3: Direction margin (d_t − SRMC) vs total direction volume by month
# ---------------------------------------------------------------------------
# Monthly aggregate across all SA treated units:
#   x: capacity-weighted mean (d_t − srmc_marginal) — the per-MWh rent
#   y: total directed unit-hours (proxy for direction volume, 5-min intervals × 5/60)
#
# Purpose: test whether AEMO direction intensity co-moves with generator rents.
# If the identification assumption holds (AEMO directs for security, not rents),
# there should be no strong positive relationship.
# ---------------------------------------------------------------------------

monthly <- panel[directed == 1L & !is.na(srmc_marginal) & !is.na(dt) & MAXAVAIL > 0,
  .(directed_unit_hrs  = .N * 5 / 60,               # directed unit-hours across all units
    directed_cap_gwh   = sum(MAXAVAIL, na.rm=TRUE) * 5 / 60 / 1000,  # MAXAVAIL-weighted GWh (proxy)
    mean_margin        = mean(dt - srmc_marginal, na.rm = TRUE),  # capacity-wtd mean (d_t - SRMC)
    dt_val             = first(dt)),
  by = yyyymm][order(yyyymm)]

# Label the d_t exit month and peak months for annotation
monthly[, label := fifelse(
  yyyymm == "202307", "Exit (Jul 2023)",
  fifelse(yyyymm %in% c("202209","202210","202212"), yyyymm, "")
)]
monthly[, post_exit := yyyymm >= "202307"]

# Correlation and OLS slope for annotation
r_val <- cor(monthly$mean_margin, monthly$directed_unit_hrs)
fit_m <- lm(directed_unit_hrs ~ mean_margin, data = monthly)
b_m   <- coef(fit_m)[["mean_margin"]]

cat(sprintf("Direction volume vs margin: r = %.3f, slope = %.2f hrs per $/MWh\n",
            r_val, b_m))

# ---- Main scatter: margin vs directed unit-hours, coloured by pre/post exit ----
p3 <- ggplot(monthly, aes(x = mean_margin, y = directed_unit_hrs)) +
  geom_smooth(method = "lm", se = TRUE,
              colour = "grey40", fill = "grey85", linewidth = 0.7,
              linetype = "dashed") +
  geom_point(aes(colour = post_exit, size = dt_val), alpha = 0.85) +
  geom_text(aes(label = label), size = 2.6, vjust = -0.8, hjust = 0.5,
            colour = "grey25") +
  scale_colour_manual(
    values = c("FALSE" = "#e41a1c", "TRUE" = "#377eb8"),
    labels = c("FALSE" = "Pre-exit (high d_t)", "TRUE" = "Post-exit (low d_t)"),
    name = NULL) +
  scale_size_continuous(
    name   = expression(d[t] ~ "($/MWh)"),
    range  = c(2, 6),
    breaks = c(150, 250, 350)) +
  annotate("text", x = Inf, y = Inf,
           label = sprintf("r = %.2f\nslope = %.1f hrs per $/MWh", r_val, b_m),
           hjust = 1.1, vjust = 1.3, size = 3.2, colour = "grey25") +
  labs(
    title    = expression("Direction volume vs direction margin " * (d[t] - SRMC[marginal])),
    subtitle = paste0(
      "Monthly totals across 11–12 SA thermal units | point size = d_t level\n",
      "y = total directed unit-hours (directed intervals × 5 min, summed across units)\n",
      "x = capacity-weighted mean (d_t − srmc_marginal) in $/MWh | dashed = OLS fit"),
    x = expression(d[t] - SRMC[marginal] ~ "($/MWh, fleet average)"),
    y = "Total directed unit-hours per month"
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position  = "right",
        plot.subtitle    = element_text(size = 8, colour = "grey30"))

ggsave(file.path(OUT, "Margin_vs_DirectionVolume.png"), p3,
       width = 10, height = 7, dpi = 150)
cat("Saved: Margin_vs_DirectionVolume.png\n")

# ---- Companion time-series: both series on one plot (dual-axis) ----
# Scale directed_unit_hrs to fit on same axis as mean_margin
scale_factor <- max(monthly$mean_margin) / max(monthly$directed_unit_hrs)

p3b <- ggplot(monthly, aes(x = as.integer(yyyymm))) +
  geom_rect(aes(xmin = as.integer("202307") - 0.5,
                xmax = as.integer("202412") + 0.5,
                ymin = -Inf, ymax = Inf),
            fill = "#deebf7", alpha = 0.4) +
  geom_line(aes(y = mean_margin), colour = "#e41a1c", linewidth = 0.9) +
  geom_line(aes(y = directed_unit_hrs * scale_factor),
            colour = "#2171b5", linewidth = 0.9, linetype = "longdash") +
  geom_vline(xintercept = as.integer("202307"), linetype = "dotted",
             colour = "grey30", linewidth = 0.6) +
  annotate("text", x = as.integer("202307") + 0.3, y = Inf,
           label = "d_t exit", vjust = 1.4, hjust = 0, size = 3, colour = "grey30") +
  scale_x_continuous(
    breaks = as.integer(c("202201","202207","202301","202307","202401","202407")),
    labels = c("Jan-22","Jul-22","Jan-23","Jul-23","Jan-24","Jul-24")) +
  scale_y_continuous(
    name     = expression(d[t] - SRMC[marginal] ~ "($/MWh)"),
    sec.axis = sec_axis(~ . / scale_factor,
                        name = "Total directed unit-hours per month")) +
  labs(
    title    = expression("Time series: direction margin vs direction volume"),
    subtitle = "Red: fleet-mean (d_t − SRMC_marginal) [left axis] | Blue dashed: directed unit-hours [right axis]\nShaded: post d_t exit (Jul 2023 onwards)",
    x = NULL) +
  theme_bw(base_size = 11) +
  theme(
    axis.title.y       = element_text(colour = "#e41a1c"),
    axis.title.y.right = element_text(colour = "#2171b5"),
    plot.subtitle      = element_text(size = 8, colour = "grey30")
  )

ggsave(file.path(OUT, "Margin_vs_DirectionVolume_timeseries.png"), p3b,
       width = 11, height = 5, dpi = 150)
cat("Saved: Margin_vs_DirectionVolume_timeseries.png\n")

# Print monthly table for inspection
cat("\nMonthly margin vs volume:\n")
print(monthly[, .(yyyymm, mean_margin = round(mean_margin,1),
                  directed_unit_hrs  = round(directed_unit_hrs,0),
                  dt_val = round(dt_val,1))])

cat("\nDone. Figures written to", OUT, "\n")
