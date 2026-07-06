# ==============================================================================
# 91_paper_figures.R — publication figures for the SA directions paper
#
# Reads ONLY existing verified outputs (no new estimation):
#   Direction/outputs/proposal_figures/{F1_compensation_vs_fuel,F2_volume_cost,F2b_volume_vs_time}.csv
#   Direction_clean/outputs/05_mechanism/{task11_monthly_curve,task1_episode_level}.csv
#   Direction_clean/outputs/04_rq2_compensation_price/rq2_interaction.csv
#
# Writes print-quality (greyscale-safe) PDF+PNG to output/figures/.
# Run from repo root: Rscript scripts/R/91_paper_figures.R
# ==============================================================================

suppressPackageStartupMessages(library(ggplot2))

# Month labels must be English regardless of system locale
invisible(Sys.setlocale("LC_TIME", "English"))

root <- normalizePath(".")
dirf <- file.path(root, "output", "figures")
dir.create(dirf, recursive = TRUE, showWarnings = FALSE)

pf <- file.path(root, "Direction", "outputs", "proposal_figures")
dc <- file.path(root, "Direction_clean", "outputs")

theme_paper <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(linewidth = 0.25, colour = "grey85"),
        legend.position = "bottom",
        strip.text = element_text(face = "bold"),
        plot.title = element_blank())

save_fig <- function(p, name, w = 6.5, h = 4) {
  # INV-11: transparent backgrounds for manuscript figures
  ggsave(file.path(dirf, paste0(name, ".pdf")), p, width = w, height = h,
         device = cairo_pdf, bg = "transparent")
  ggsave(file.path(dirf, paste0(name, ".png")), p, width = w, height = h,
         dpi = 300, bg = "transparent")
  cat("wrote", file.path("output/figures", name), "(.pdf/.png)\n")
}

# ------------------------------------------------------------------------------
# Fig 1 — Compensation price vs fuel cost: the mechanical rent
# ------------------------------------------------------------------------------
f1 <- read.csv(file.path(pf, "F1_compensation_vs_fuel.csv"))
f1$period <- as.Date(f1$period)

p1 <- ggplot(f1, aes(x = period)) +
  geom_ribbon(aes(ymin = pmin(dt, fuel_cost), ymax = pmax(dt, fuel_cost)),
              fill = "grey75", alpha = 0.45) +
  geom_line(aes(y = dt, linetype = "comp"), linewidth = 0.7) +
  geom_line(aes(y = fuel_cost, linetype = "fuel"), linewidth = 0.7) +
  scale_linetype_manual(NULL, values = c(comp = "solid", fuel = "22"),
                        labels = c(comp = expression("Compensation price" ~ d[t]),
                                   fuel = "Fuel cost (engineering SRMC)")) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "$/MWh") +
  theme_paper
save_fig(p1, "fig1_compensation_rent")

# ------------------------------------------------------------------------------
# Fig 2 — Directed volume, cost per MWh, average MW while directed (quarterly)
# ------------------------------------------------------------------------------
f2  <- read.csv(file.path(pf, "F2_volume_cost.csv"))
f2b <- read.csv(file.path(pf, "F2b_volume_vs_time.csv"))
f2$qdate <- as.Date(f2$qdate); f2b$qdate <- as.Date(f2b$qdate)

long2 <- rbind(
  data.frame(qdate = f2$qdate,  value = f2$directed_gwh,     panel = "Directed volume (GWh/quarter)"),
  data.frame(qdate = f2$qdate,  value = f2$cost_per_mwh,     panel = "Recovery cost per directed MWh ($/MWh)"),
  data.frame(qdate = f2b$qdate, value = f2b$avg_mw,          panel = "Average MW while directed"))
long2$panel <- factor(long2$panel, levels = unique(long2$panel))

p2 <- ggplot(long2, aes(x = qdate, y = value)) +
  geom_col(fill = "grey40", width = 70) +
  facet_wrap(~panel, ncol = 1, scales = "free_y") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL, y = NULL) +
  theme_paper
save_fig(p2, "fig2_direction_cost_anatomy", h = 5.5)

# ------------------------------------------------------------------------------
# Fig 3 — Supply-curve history: the cheap tranche vs availability, by station
# ------------------------------------------------------------------------------
t11 <- read.csv(file.path(dc, "05_mechanism", "task11_monthly_curve.csv"))
t11$period <- as.Date(paste0(substr(t11$yyyymm, 1, 4), "-", substr(t11$yyyymm, 5, 6), "-01"))

# Station grain: TORR rows are per-DUID (TORRB2/3/4) — sum to the station level
agg3 <- aggregate(cbind(avail, mw_le300) ~ DUIDg + period, data = t11, FUN = sum)
agg3$DUIDg <- factor(agg3$DUIDg,
                     levels = c("TORR", "PPCCGT"),
                     labels = c("Torrens Island B (TORRB2+3+4, station total)", "Pelican Point (PPCCGT)"))

long3 <- rbind(
  data.frame(DUIDg = agg3$DUIDg, period = agg3$period, mw = agg3$avail,    series = "Offered availability"),
  data.frame(DUIDg = agg3$DUIDg, period = agg3$period, mw = agg3$mw_le300, series = "Cheap tranche (<= $300/MWh)"))

p3 <- ggplot(long3, aes(x = period, y = mw, linetype = series)) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~DUIDg, ncol = 1, scales = "free_y") +
  scale_linetype_manual(NULL, values = c("Offered availability" = "solid",
                                         "Cheap tranche (<= $300/MWh)" = "22")) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "MW (monthly mean)") +
  theme_paper
save_fig(p3, "fig3_supply_history", h = 6)

# ------------------------------------------------------------------------------
# Fig 4 — Directed output relative to the operating floor (episode level)
# ------------------------------------------------------------------------------
t1e <- read.csv(file.path(dc, "05_mechanism", "task1_episode_level.csv"))
t1e <- t1e[is.finite(t1e$excess_over_floor), ]
share_le0 <- mean(t1e$excess_over_floor <= 0)

p4 <- ggplot(t1e, aes(x = excess_over_floor)) +
  geom_histogram(binwidth = 10, boundary = 0, fill = "grey40", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = 0, linetype = "22", linewidth = 0.5) +
  annotate("text", x = 0, y = Inf, hjust = -0.05, vjust = 1.5, size = 3,
           label = sprintf("%.1f%% of episodes deliver zero or negative\nexcess over the operating floor", 100 * share_le0)) +
  labs(x = "Mean directed output minus operating floor (MW, episode level)", y = "Episodes") +
  theme_paper
save_fig(p4, "fig4_output_vs_floor")

# ------------------------------------------------------------------------------
# Fig 5 — RQ2 interaction: stability across June-2022 treatments and outcomes
# ------------------------------------------------------------------------------
rq2i <- read.csv(file.path(dc, "04_rq2_compensation_price", "rq2_interaction.csv"))
slab <- c("BASE: exclude suspension window only"   = "Base",
          "(i) exclude all June 2022"              = "(i) Drop all\nJune 2022",
          "(ii) include window at APC $300"        = "(ii) Include window\nat APC $300",
          "(iii) base minus pre-suspension June"   = "(iii) Drop pre-suspension\nJune too")
rq2i$sample_f  <- factor(slab[rq2i$sample], levels = slab)
rq2i$outcome_f <- factor(rq2i$outcome, levels = c("a_fixed300", "b_2xSRMC"),
                         labels = c("Fixed $300 threshold", "2 x SRMC threshold"))

p5 <- ggplot(rq2i, aes(x = sample_f, y = estimate, shape = outcome_f)) +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey40") +
  geom_pointrange(aes(ymin = estimate - 1.96 * std.error, ymax = estimate + 1.96 * std.error),
                  position = position_dodge(width = 0.35), linewidth = 0.5, fatten = 2.5) +
  scale_shape_manual(NULL, values = c(16, 1)) +
  labs(x = "Treatment of June 2022",
       y = expression("Essential" %*% "compensation price (per $100/MWh)")) +
  theme_paper
save_fig(p5, "fig5_rq2_stability")

# ------------------------------------------------------------------------------
# Fig 6 — Month-grain: essential-vs-matched gap in floor-reach vs the compensation
# price (Test 3a object; data test3a_month_gaps.csv, produced under prereg 8ed73e1)
# ------------------------------------------------------------------------------
gm <- read.csv(file.path(root, "Direction_clean", "outputs", "06_round2", "test3a_month_gaps.csv"))
gm$comp_price <- gm$comp_price_100 * 100

p6 <- ggplot(gm, aes(comp_price, gap)) +
  geom_hline(yintercept = 0, linetype = "22", linewidth = 0.4, colour = "grey40") +
  geom_smooth(method = "lm", mapping = aes(weight = n_ess), se = TRUE,
              colour = "black", linewidth = 0.6, fill = "grey80") +
  geom_point(aes(size = n_ess), shape = 21, fill = "grey55", colour = "black", stroke = 0.3) +
  scale_size_continuous(name = "Essential rows", range = c(1.5, 6)) +
  labs(x = "Compensation price ($/MWh, monthly)",
       y = "Essential minus matched floor-reach rate") +
  theme_paper
save_fig(p6, "fig6_month_gap_vs_price")

cat("\nAll figures written.\n")
