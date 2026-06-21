#!/usr/bin/env Rscript
# descriptive_analysis_v3.R
# Cuts 2-6 of the descriptive diagnostic v3.
# Prerequisite: gate_a_srmc.R must have run (produces GateA_srmc_params.csv).
# Run from Direction/ working directory.

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(fixest)
})
setwd("C:/Users/ericl/Documents/my-project/Direction")

OUT   <- "outputs/descriptives_v3"
CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TREATED <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
             "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
DT_EXIT_YM   <- "202307"
DT_EXIT_DATE <- as.Date("2023-07-01")

# Market Price Cap by financial year (for near-cap offer detection in Cut 4)
# FY = July to June; interval falls in FY ending June YEAR if month >= 7 of YEAR-1
mpc_by_yyyymm <- function(ym) {
  yr <- as.integer(substr(ym, 1, 4))
  mo <- as.integer(substr(ym, 5, 6))
  fy <- ifelse(mo >= 7L, yr + 1L, yr)   # FY ending June
  ifelse(fy <= 2023L, 15500,
         ifelse(fy == 2024L, 16600, 17500))
}

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
dt_s <- readRDS("outputs/descriptives/gate0_dt_series.rds")[,
  .(yyyymm, dt = dt_recon)]

srmc_ref <- fread(file.path(OUT, "GateA_srmc_params.csv"))[,
  .(duid, yyyymm = as.character(yyyymm), srmc_marginal, srmc_allin)]

tp <- readRDS("direction_data/parsed/treatment_panel.rds")
tp[, yyyymm := sprintf("%d%02d",
     as.integer(format(interval_datetime, "%Y")),
     as.integer(format(interval_datetime, "%m")))]
setkey(tp, duid, interval_datetime)

cat("Reference data loaded.\n")
cat(sprintf("  d_t months: %d  SRMC rows: %d  Directed intervals: %d\n",
            nrow(dt_s), nrow(srmc_ref), nrow(tp)))

# ---------------------------------------------------------------------------
# PASS 1: build 5-min panel for SA units (month-by-month)
# ---------------------------------------------------------------------------
# For each month load BIDOFFERPERIOD + BIDDAYOFFER + DISPATCHPRICE.
# Filter to TREATED DUIDs, keep latest rebid per unit-interval.
# Join direction flags, d_t, SRMC. Compute withheld_share.
# ---------------------------------------------------------------------------
months_all <- sort(intersect(
  dt_s$yyyymm,
  sprintf("%d%02d",
          rep(2022:2024, each = 12),
          rep(1:12, times = 3))
))
# Restrict to months where bid data exists (202201-202412, skip 202206 if absent)
months_all <- months_all[file.exists(file.path(CACHE,
                            sprintf("BIDOFFERPERIOD_%s.rds", months_all)))]
cat(sprintf("Building panel for %d months...\n", length(months_all)))

# If panel already built and cached, skip the expensive loop
PANEL_CACHE <- file.path(OUT, "panel_v3.rds")
if (file.exists(PANEL_CACHE)) {
  cat("Loading cached panel...\n")
  panel <- readRDS(PANEL_CACHE)
  cat(sprintf("Full panel: %d rows | %d directed | %d synchronise\n",
              nrow(panel), sum(panel$directed), sum(panel$synchronise)))
} else {

panel_list <- vector("list", length(months_all))

for (i in seq_along(months_all)) {
  M <- months_all[i]
  cat(sprintf("  [%s] ", M))

  # -- BIDOFFERPERIOD: 5-min quantities; keep latest rebid per unit-interval --
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M)))
  bop <- bop[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  # Keep latest OFFERDATETIME per unit-interval (most recent rebid)
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by = .(DUID, INTERVAL_DATETIME)]$V1]
  bop <- bop[, .(duid         = DUID,
                 interval_dt  = INTERVAL_DATETIME,
                 trade_date   = as.Date(TRADINGDATE),
                 MAXAVAIL,
                 BA1  = BANDAVAIL1,  BA2  = BANDAVAIL2,  BA3  = BANDAVAIL3,
                 BA4  = BANDAVAIL4,  BA5  = BANDAVAIL5,  BA6  = BANDAVAIL6,
                 BA7  = BANDAVAIL7,  BA8  = BANDAVAIL8,  BA9  = BANDAVAIL9,
                 BA10 = BANDAVAIL10)]

  # -- BIDDAYOFFER: daily price bands; keep latest version per unit-day --
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M)))
  bdo <- bdo[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
  bdo <- bdo[, .(duid       = DUID,
                 trade_date = as.Date(SETTLEMENTDATE),
                 PB1  = PRICEBAND1,  PB2  = PRICEBAND2,  PB3  = PRICEBAND3,
                 PB4  = PRICEBAND4,  PB5  = PRICEBAND5,  PB6  = PRICEBAND6,
                 PB7  = PRICEBAND7,  PB8  = PRICEBAND8,  PB9  = PRICEBAND9,
                 PB10 = PRICEBAND10)]

  # -- DISPATCHPRICE: SA1 spot, intervention=0 only --
  dp <- readRDS(file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M)))
  dp <- dp[REGIONID == "SA1" & INTERVENTION == 0L,
           .(interval_dt = SETTLEMENTDATE, spot = as.numeric(RRP))]

  # -- Join bop + price bands (by duid + trade_date) --
  m <- merge(bop, bdo, by = c("duid", "trade_date"), all.x = TRUE)

  # -- Join spot price --
  m <- merge(m, dp, by = "interval_dt", all.x = TRUE)

  # -- Direction flags from treatment panel --
  tp_m <- tp[yyyymm == M, .(duid, interval_datetime, directed, synchronise)]
  m <- merge(m, tp_m,
             by.x = c("duid", "interval_dt"),
             by.y = c("duid", "interval_datetime"),
             all.x = TRUE)
  m[is.na(directed),    directed    := 0L]
  m[is.na(synchronise), synchronise := 0L]

  # -- d_t and SRMC (monthly) --
  dt_m   <- dt_s[yyyymm == M, dt]
  srmc_m <- srmc_ref[yyyymm == M]
  m[, yyyymm := M]
  m[, dt     := dt_m]
  m <- merge(m, srmc_m[, .(duid, srmc_marginal, srmc_allin)],
             by = "duid", all.x = TRUE)

  # -- withheld_share: fraction of MAXAVAIL in bands priced above srmc_marginal --
  # withheld_mw = sum(BAj | PBj > srmc_marginal)
  for (j in 1:10) {
    set(m, j = paste0("_ab", j),
        value = m[[paste0("BA", j)]] * (m[[paste0("PB", j)]] > m$srmc_marginal))
  }
  ab_cols <- paste0("_ab", 1:10)
  m[, withheld_mw    := rowSums(.SD, na.rm = TRUE), .SDcols = ab_cols]
  m[, (ab_cols)      := NULL]
  m[, withheld_share := fifelse(MAXAVAIL > 1, pmin(withheld_mw / MAXAVAIL, 1.0), NA_real_)]

  # -- rent per interval ($/MWh) --
  m[, rent := dt - spot]

  # -- drop big columns no longer needed --
  drop_cols <- c(paste0("BA",1:10), paste0("PB",1:10))
  m[, (drop_cols) := NULL]

  panel_list[[i]] <- m
  cat(sprintf("OK (%d rows, %d directed)\n", nrow(m), sum(m$directed, na.rm=TRUE)))
}

panel <- rbindlist(panel_list, fill = TRUE)
rm(panel_list); gc()
cat(sprintf("Full panel: %d rows | %d directed | %d synchronise\n",
            nrow(panel),
            sum(panel$directed),
            sum(panel$synchronise)))

# Sanity check: withheld_share in [0,1]
ws_range <- panel[!is.na(withheld_share), range(withheld_share)]
cat(sprintf("withheld_share range: [%.3f, %.3f] -- should be [0,1]\n",
            ws_range[1], ws_range[2]))

saveRDS(panel, PANEL_CACHE)
cat("Panel saved.\n\n")

} # end if(!file.exists(PANEL_CACHE))

# ---------------------------------------------------------------------------
# CUT 2: Net rent by d_t terciles x Synchronise/Remain
# ---------------------------------------------------------------------------
cat("--- Cut 2: Net rent ---\n")

directed_panel <- panel[directed == 1L & !is.na(spot) & !is.na(dt)]

# d_t terciles defined on the distribution of d_t across directed intervals
dt_breaks <- quantile(directed_panel$dt, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE)
directed_panel[, dt_tercile := cut(dt, breaks = dt_breaks, include.lowest = TRUE,
                                    labels = c("Low d_t","Mid d_t","High d_t"))]

rent_tab <- directed_panel[!is.na(dt_tercile), .(
  mean_rent    = round(mean(rent,    na.rm = TRUE), 1),
  median_rent  = round(median(rent,  na.rm = TRUE), 1),
  pct_positive = round(mean(rent > 0, na.rm = TRUE) * 100, 1),
  n_intervals  = .N
), by = .(dt_tercile, synchronise)][order(dt_tercile, synchronise)]

rent_tab[, instruction := fifelse(synchronise == 1L, "Synchronise", "Remain")]
cat("Net rent (d_t - spot) by d_t tercile x instruction type:\n")
print(rent_tab[, .(dt_tercile, instruction, mean_rent, median_rent, pct_positive, n_intervals)])

fwrite(rent_tab, file.path(OUT, "Cut2_rent_table.csv"))

# Plot: density of rent by pre/post exit
p_cut2 <- ggplot(directed_panel[abs(rent) < 2000],
                 aes(x = rent,
                     fill  = fifelse(yyyymm < DT_EXIT_YM, "Pre-exit", "Post-exit"),
                     colour= fifelse(yyyymm < DT_EXIT_YM, "Pre-exit", "Post-exit"))) +
  geom_density(alpha = 0.3, linewidth = 0.6) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey30") +
  facet_wrap(~fifelse(synchronise==1L,"Synchronise","Remain"), ncol = 2) +
  scale_fill_manual(values = c("Pre-exit"="#e41a1c","Post-exit"="#377eb8"), name=NULL) +
  scale_colour_manual(values = c("Pre-exit"="#e41a1c","Post-exit"="#377eb8"), name=NULL) +
  labs(title  = "Cut 2: Direction rent (d_t - spot) by instruction type",
       subtitle= "Pre-exit = yyyymm < 202307 | Post-exit >= 202307 | 5-min resolution",
       x = "d_t - spot ($/MWh)", y = "Density") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(file.path(OUT, "Cut2_rent_distribution.png"), p_cut2,
       width = 10, height = 5, dpi = 150)
cat("Cut 2 saved.\n\n")

# ---------------------------------------------------------------------------
# CUT 3: Binned scatter -- withheld_share vs d_t per unit
# ---------------------------------------------------------------------------
cat("--- Cut 3: withheld_share vs d_t ---\n")

# Use ALL intervals for treated units (directed and non-directed)
ws_panel <- panel[!is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1]

# Bin d_t into 20 quantile bins across full sample
dt_bins <- quantile(ws_panel$dt, probs = seq(0, 1, by = 0.05), na.rm = TRUE)
ws_panel[, dt_bin := cut(dt, breaks = unique(dt_bins), include.lowest = TRUE)]

# Aggregate: mean withheld_share per unit x d_t bin
ws_binned <- ws_panel[, .(
  mean_ws   = mean(withheld_share, na.rm = TRUE),
  dt_mid    = mean(dt, na.rm = TRUE),
  n         = .N
), by = .(duid, dt_bin)][n >= 10]

# Tech group for colour
tech_map <- data.table(
  duid      = TREATED,
  tech_grp  = c(rep("Gas-steam (TORRB)",4), "CCGT (PPCCGT)", "Cogen (OSB)",
                "OCGT (MINTARO)", "Recip. (BARKIPS1)",
                rep("OCGT (DRYCGT)",3), "OCGT (QPS5)")
)
ws_binned <- merge(ws_binned, tech_map, by = "duid", all.x = TRUE)

p_cut3 <- ggplot(ws_binned, aes(x = dt_mid, y = mean_ws, colour = tech_grp)) +
  geom_point(alpha = 0.6, size = 1.2) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.7) +
  facet_wrap(~duid, ncol = 4, scales = "free_y") +
  geom_vline(xintercept = dt_s[yyyymm == DT_EXIT_YM, dt],
             linetype = "dotted", colour = "grey40") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(title    = "Cut 3: Withheld share (SRMC-relative) vs d_t, binned by unit",
       subtitle  = "withheld_share = fraction of MAXAVAIL offered above marginal SRMC | All intervals",
       x = "d_t ($/MWh)", y = "Mean withheld share",
       colour = NULL) +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom", strip.text = element_text(size = 7))

ggsave(file.path(OUT, "Cut3_withheld_vs_dt.png"), p_cut3,
       width = 14, height = 10, dpi = 150)

# Unit-level slopes (OLS of mean_ws on dt_mid)
cut3_slopes <- ws_binned[, {
  fit <- lm(mean_ws ~ dt_mid)
  .(slope = round(coef(fit)[["dt_mid"]] * 100, 4),
    r2    = round(summary(fit)$r.squared, 3),
    n_bins = .N)
}, by = duid][order(-slope)]
cat("withheld_share vs d_t slopes (per 100 $/MWh d_t increase):\n")
print(cut3_slopes)
fwrite(cut3_slopes, file.path(OUT, "Cut3_slopes.csv"))
cat("Cut 3 saved.\n\n")

# ---------------------------------------------------------------------------
# CUT 4: Day-before mechanism for Synchronise events
# ---------------------------------------------------------------------------
cat("--- Cut 4: Day-before mechanism ---\n")

# Identify Synchronise event starts: transition synchronise 0->1 in the full
# directed panel (tp has both synchronise=0 Remain and synchronise=1 Sync rows;
# between direction events there are no rows, so fill=0 correctly marks the
# start of each new sync block after a gap or after a Remain period).
sync_events <- tp[order(duid, interval_datetime)]
sync_events[, prev_sync := shift(synchronise, 1L, fill = 0L), by = duid]
sync_starts <- sync_events[synchronise == 1L & prev_sync == 0L,
               .(duid, interval_datetime, yyyymm)]
sync_starts[, trade_date_event  := as.Date(interval_datetime)]
sync_starts[, trade_date_before := trade_date_event - 1L]
sync_starts <- merge(sync_starts, dt_s, by = "yyyymm", all.x = TRUE)

cat(sprintf("  %d Synchronise event starts identified.\n", nrow(sync_starts)))

# Load BIDDAYOFFER for each relevant prev-day
# Group start events by (prev) trade date month to minimise file loads
sync_starts[, yyyymm_before := sprintf("%d%02d",
              as.integer(format(trade_date_before, "%Y")),
              as.integer(format(trade_date_before, "%m")))]

months_needed <- sort(unique(sync_starts$yyyymm_before))
months_needed <- months_needed[file.exists(file.path(CACHE,
                   sprintf("BIDDAYOFFER_%s.rds", months_needed)))]

bdo_pre_list <- lapply(months_needed, function(M) {
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M)))
  bdo <- bdo[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
  bdo[, .(duid       = DUID,
          trade_date = as.Date(SETTLEMENTDATE),
          PB1  = PRICEBAND1, PB2 = PRICEBAND2, PB3 = PRICEBAND3,
          PB4  = PRICEBAND4, PB5 = PRICEBAND5, PB6 = PRICEBAND6,
          PB7  = PRICEBAND7, PB8 = PRICEBAND8, PB9 = PRICEBAND9,
          PB10 = PRICEBAND10)]
})
bdo_pre <- rbindlist(bdo_pre_list)

# Also need prev-day BIDOFFERPERIOD to get MAXAVAIL day-before
bop_pre_list <- lapply(months_needed, function(M) {
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M)))
  bop <- bop[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by = .(DUID, TRADINGDATE, PERIODID)]$V1]
  # Daily aggregate: mean MAXAVAIL per unit-trading-day
  bop[, .(duid       = DUID,
          trade_date = as.Date(TRADINGDATE),
          mean_maxavail = mean(MAXAVAIL, na.rm = TRUE),
          mean_ba1  = mean(BANDAVAIL1, na.rm=TRUE),
          mean_ba10 = mean(BANDAVAIL10, na.rm=TRUE))]
})
bop_pre <- rbindlist(bop_pre_list)[,
  .(mean_maxavail = mean(mean_maxavail),
    mean_ba10     = mean(mean_ba10)),
  by = .(duid, trade_date)]

# Join: sync_starts + prev-day bids
sync_m <- merge(sync_starts,
                bdo_pre, by.x = c("duid","trade_date_before"),
                         by.y = c("duid","trade_date"), all.x = TRUE)
sync_m <- merge(sync_m,
                bop_pre, by.x = c("duid","trade_date_before"),
                         by.y = c("duid","trade_date"), all.x = TRUE)

# Join SRMC for the event month
sync_m <- merge(sync_m, srmc_ref[, .(duid, yyyymm, srmc_marginal)],
                by = c("duid","yyyymm"), all.x = TRUE)

# Was the top price band (PB10) above SRMC the day before?
sync_m[, pb10_above_srmc := fifelse(!is.na(PB10) & !is.na(srmc_marginal),
                                     PB10 > srmc_marginal, NA)]
# Share of capacity in high band relative to MAXAVAIL
sync_m[, ba10_share := fifelse(mean_maxavail > 1,
                                pmin(mean_ba10 / mean_maxavail, 1.0), NA_real_)]

# MPC threshold: was pb10 near MPC?
sync_m[, mpc := mpc_by_yyyymm(yyyymm)]
sync_m[, pb10_near_mpc := fifelse(!is.na(PB10), PB10 >= (mpc * 0.95), NA)]

# d_t terciles for Synchronise events
dt_q <- quantile(sync_m$dt, probs = c(0, 1/3, 2/3, 1), na.rm = TRUE)
sync_m[, dt_tercile := cut(dt, breaks = dt_q, include.lowest = TRUE,
                            labels = c("Low d_t","Mid d_t","High d_t"))]

cut4_tab <- sync_m[!is.na(dt_tercile), .(
  pct_pb10_above_srmc = round(mean(pb10_above_srmc, na.rm=TRUE)*100, 1),
  mean_ba10_share     = round(mean(ba10_share, na.rm=TRUE)*100, 1),
  pct_near_mpc        = round(mean(pb10_near_mpc, na.rm=TRUE)*100, 1),
  n_events            = .N
), by = .(dt_tercile)][order(dt_tercile)]

cat("Pre-Synchronise offer profile by d_t tercile (day before event):\n")
print(cut4_tab)
fwrite(cut4_tab, file.path(OUT, "Cut4_mechanism.csv"))

# Bar chart: ba10_share by d_t tercile
p_cut4 <- ggplot(sync_m[!is.na(dt_tercile) & !is.na(ba10_share)],
                 aes(x = dt_tercile, y = ba10_share, fill = dt_tercile)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.5) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_manual(values = c("Low d_t"="#74c476","Mid d_t"="#fd8d3c","High d_t"="#e41a1c"),
                    guide = "none") +
  labs(title    = "Cut 4: Band-10 share day before Synchronise event, by d_t tercile",
       subtitle  = "ba10_share = BANDAVAIL10 / MAXAVAIL (day-before daily average) | n events by tercile",
       x = NULL, y = "Band-10 share of MAXAVAIL") +
  theme_bw(base_size = 11)

ggsave(file.path(OUT, "Cut4_mechanism.png"), p_cut4,
       width = 7, height = 5, dpi = 150)
cat("Cut 4 saved.\n\n")

# ---------------------------------------------------------------------------
# CUT 5: Continuous d_t design -- unit FE + SRMC control
# ---------------------------------------------------------------------------
cat("--- Cut 5: Continuous d_t regression ---\n")

# Aggregate to unit-month: mean withheld_share, d_t, srmc_marginal
# Use all intervals (directed and non-directed) for the 12 SA units
um_panel <- panel[!is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1,
  .(mean_ws      = mean(withheld_share, na.rm = TRUE),
    dt            = first(dt),
    srmc_marginal = first(srmc_marginal),
    n_intervals   = .N),
  by = .(duid, yyyymm)]

um_panel[, post_exit := as.integer(yyyymm >= DT_EXIT_YM)]
um_panel[, dt_std    := (dt - mean(dt, na.rm=TRUE)) / sd(dt, na.rm=TRUE)]

# OLS with unit FE (feols absorbs duid FE)
fit_base  <- feols(mean_ws ~ dt_std | duid, data = um_panel, vcov = "hetero")
fit_srmc  <- feols(mean_ws ~ dt_std + srmc_marginal | duid,
                   data = um_panel, vcov = "hetero")
# By instruction type: directed vs non-directed
um_dir <- panel[directed == 1L & !is.na(withheld_share) & !is.na(dt) & MAXAVAIL > 1,
  .(mean_ws      = mean(withheld_share, na.rm = TRUE),
    dt            = first(dt),
    srmc_marginal = first(srmc_marginal)),
  by = .(duid, yyyymm)]
um_dir[, dt_std := (dt - mean(dt, na.rm=TRUE)) / sd(dt, na.rm=TRUE)]
fit_dir <- feols(mean_ws ~ dt_std + srmc_marginal | duid,
                 data = um_dir, vcov = "hetero")

cat("Cut 5 regression results:\n")
cat("\n[1] Base: withheld_share ~ d_t (std) | unit FE\n")
print(summary(fit_base))
cat("\n[2] With SRMC control: withheld_share ~ d_t + srmc | unit FE\n")
print(summary(fit_srmc))
cat("\n[3] Directed intervals only:\n")
print(summary(fit_dir))

# Save coefficient table
coef_tab <- rbindlist(list(
  data.table(spec = "All intervals, no SRMC ctrl",
             coef = coef(fit_base)[["dt_std"]],
             se   = se(fit_base)[["dt_std"]],
             n    = fit_base$nobs),
  data.table(spec = "All intervals, SRMC ctrl",
             coef = coef(fit_srmc)[["dt_std"]],
             se   = se(fit_srmc)[["dt_std"]],
             n    = fit_srmc$nobs),
  data.table(spec = "Directed only, SRMC ctrl",
             coef = coef(fit_dir)[["dt_std"]],
             se   = se(fit_dir)[["dt_std"]],
             n    = fit_dir$nobs)
))
coef_tab[, t_stat := round(coef / se, 2)]
coef_tab[, coef   := round(coef, 5)]
coef_tab[, se     := round(se, 5)]
fwrite(coef_tab, file.path(OUT, "Cut5_regression.csv"))
cat("\nCut 5 coefficient table:\n"); print(coef_tab)

# Partial residual scatter (unit-month level)
um_panel[, resid_ws := resid(feols(mean_ws ~ 1 | duid, data = um_panel))]
um_panel[, resid_dt := resid(feols(dt_std ~ 1 | duid, data = um_panel))]

p_cut5 <- ggplot(um_panel, aes(x = resid_dt, y = resid_ws,
                               colour = factor(post_exit))) +
  geom_point(alpha = 0.5, size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, colour = "black", linewidth = 0.8) +
  scale_colour_manual(values = c("0" = "#e41a1c", "1" = "#377eb8"),
                      labels = c("0" = "Pre-exit", "1" = "Post-exit"),
                      name = NULL) +
  labs(title    = "Cut 5: withheld_share vs d_t (within-unit variation)",
       subtitle  = "Partial residuals after unit FE removal | unit-month level | slope = d_t coefficient",
       x = "d_t residual (within-unit, standardised)",
       y = "withheld_share residual (within-unit)") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(file.path(OUT, "Cut5_dt_regression.png"), p_cut5,
       width = 8, height = 6, dpi = 150)
cat("Cut 5 saved.\n\n")

# ---------------------------------------------------------------------------
# CUT 6: Within-day rent responsiveness
# ---------------------------------------------------------------------------
cat("--- Cut 6: Within-day rent responsiveness ---\n")

# For each unit-day cell (within same calendar day):
#   x: rent = d_t - spot (varies across intervals within day as spot varies)
#   y: withheld_share (varies within day due to rebids)
# Bin rent within each unit-day cell; compute mean withheld_share per bin.
# Object: do units offer more capacity above SRMC when instantaneous rent is higher?
# Note: d_t is fixed within month, so within-day rent variation = spot variation.

wd_panel <- panel[!is.na(withheld_share) & !is.na(rent) & MAXAVAIL > 1]

# Bin rent into 20 quantile bins (global, so bins are comparable)
rent_breaks <- quantile(wd_panel$rent, probs = seq(0, 1, by = 0.05), na.rm = TRUE)
wd_panel[, rent_bin := cut(rent, breaks = unique(rent_breaks), include.lowest = TRUE)]

wd_binned <- wd_panel[, .(
  mean_ws  = mean(withheld_share, na.rm = TRUE),
  rent_mid = mean(rent, na.rm = TRUE),
  n        = .N
), by = .(rent_bin)][n >= 50][order(rent_mid)]

p_cut6 <- ggplot(wd_binned, aes(x = rent_mid, y = mean_ws)) +
  geom_point(aes(size = n), alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE, colour = "steelblue", linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_size_continuous(range = c(1, 5), guide = "none") +
  labs(title    = "Cut 6: withheld_share vs instantaneous rent (d_t - spot)",
       subtitle  = "Within-day variation: d_t fixed per month, spot varies; all SA treated units",
       x = "d_t - spot ($/MWh)", y = "Mean withheld share") +
  theme_bw(base_size = 11)

ggsave(file.path(OUT, "Cut6_within_day_rent.png"), p_cut6,
       width = 8, height = 6, dpi = 150)

# Regression: withheld_share ~ rent | unit x month FE
fit_cut6 <- feols(withheld_share ~ rent | duid^yyyymm,
                  data = panel[!is.na(withheld_share) & !is.na(rent) & MAXAVAIL > 1],
                  vcov = ~duid)
cat("Cut 6 regression (rent | unit x month FE):\n")
print(summary(fit_cut6))
fwrite(data.table(coef = round(coef(fit_cut6),6),
                  se   = round(se(fit_cut6),6),
                  t    = round(coef(fit_cut6)/se(fit_cut6),2),
                  n    = fit_cut6$nobs),
       file.path(OUT, "Cut6_regression.csv"))
cat("Cut 6 saved.\n\n")

# ---------------------------------------------------------------------------
# HETEROGENEITY: slope by unit vs mean (d_t - SRMC) exposure
# ---------------------------------------------------------------------------
cat("--- Heterogeneity: slope by unit ---\n")

unit_slopes <- um_panel[, {
  fit <- lm(mean_ws ~ dt_std, data = .SD)
  .(slope = coef(fit)[["dt_std"]],
    se    = summary(fit)$coef["dt_std","Std. Error"],
    mean_margin = mean(dt - srmc_marginal, na.rm = TRUE),
    n = .N)
}, by = duid]

p_het <- ggplot(unit_slopes, aes(x = mean_margin, y = slope, label = duid)) +
  geom_point(size = 3, colour = "steelblue") +
  geom_errorbar(aes(ymin = slope - 1.96*se, ymax = slope + 1.96*se),
                width = 5, colour = "steelblue") +
  geom_text(size = 3, vjust = -0.7, hjust = 0.5) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  labs(title    = "Heterogeneity: d_t slope vs mean direction margin (d_t - SRMC)",
       subtitle  = "Units with larger direction rents should respond more to d_t variation",
       x = "Mean (d_t - SRMC_marginal) over sample ($/MWh)",
       y = "Slope of withheld_share on d_t (std)") +
  theme_bw(base_size = 11)

ggsave(file.path(OUT, "Heterogeneity_slopes.png"), p_het,
       width = 8, height = 6, dpi = 150)
cat("Unit slopes (withheld_share ~ d_t std):\n"); print(unit_slopes[order(-slope)])
fwrite(unit_slopes, file.path(OUT, "Heterogeneity_slopes.csv"))

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
cat("\n=== V3 DESCRIPTIVE COMPLETE ===\n")
cat("Outputs in", OUT, ":\n")
for (f in list.files(OUT, full.names = FALSE)) cat(" ", f, "\n")
