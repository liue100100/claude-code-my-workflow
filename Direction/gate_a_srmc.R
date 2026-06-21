#!/usr/bin/env Rscript
# gate_a_srmc.R
# Gate A: per-unit SRMC vs d_t
# Run from Direction/ working directory.
# Outputs to outputs/descriptives_v3/
# STOP point -- review GateA_srmc.png before proceeding to Cuts 2-6.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")

OUT_V3 <- "outputs/descriptives_v3"
dir.create(OUT_V3, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# d_t series (reconstructed in Gate 0; column = dt_recon)
# ---------------------------------------------------------------------------
dt_raw <- readRDS("outputs/descriptives/gate0_dt_series.rds")
stopifnot("dt_recon" %in% names(dt_raw), "yyyymm" %in% names(dt_raw))
dt_s <- dt_raw[, .(yyyymm, dt = dt_recon)]
cat(sprintf("d_t series: %d months  %s - %s\n",
            nrow(dt_s), min(dt_s$yyyymm), max(dt_s$yyyymm)))

# ---------------------------------------------------------------------------
# Monthly Adelaide STTM ex-ante gas price -- from AER quarterly data
# ---------------------------------------------------------------------------
# Source: AER STTM Quarterly Prices (ex-ante)
#   File: Quarterly_STTM_Price.CSV  (saved in Direction/ by user)
#   URL:  https://www.aer.gov.au/industry/registers/charts/sttm-quarterly-prices
#
# "Quarter Ending" = last month of the quarter:
#   Mar = Q1 (Jan-Mar), Jun = Q2 (Apr-Jun),
#   Sep = Q3 (Jul-Sep), Dec = Q4 (Oct-Dec)
#
# Monthly assignment: each month in the quarter receives the quarter's
# ex-ante average price. Within-quarter intra-month variation is lost;
# adequate for monthly SRMC.
# ---------------------------------------------------------------------------

raw_gas <- fread("Quarterly_STTM_Price.CSV")
setnames(raw_gas, c("quarter_ending", "adl_gj", "bri_gj", "syd_gj"))
raw_gas[, adl_gj := suppressWarnings(as.numeric(adl_gj))]
raw_gas <- raw_gas[!is.na(adl_gj)]

# Parse "Jun 22" -> (year=2022, qend_month=6) without relying on locale-sensitive %b
MONTH_MAP <- c(Jan=1L, Feb=2L, Mar=3L, Apr=4L, May=5L, Jun=6L,
               Jul=7L, Aug=8L, Sep=9L, Oct=10L, Nov=11L, Dec=12L)
raw_gas[, qend_mon := MONTH_MAP[trimws(substring(quarter_ending, 1, 3))]]
raw_gas[, qend_yr  := as.integer(paste0("20", trimws(substring(quarter_ending, 5, 6))))]
raw_gas <- raw_gas[!is.na(qend_mon) & !is.na(qend_yr)]

# Expand each quarter-end to 3 monthly yyyymm strings (step function: same price for all 3)
months_in_quarter <- function(yr, m_end, price) {
  # quarter contains months m_end-2, m_end-1, m_end (all same year for Mar/Jun/Sep/Dec)
  data.table(
    yyyymm = sprintf("%d%02d", yr, c(m_end - 2L, m_end - 1L, m_end)),
    gas_gj = price
  )
}
monthly_rows <- mapply(months_in_quarter,
                       raw_gas$qend_yr, raw_gas$qend_mon, raw_gas$adl_gj,
                       SIMPLIFY = FALSE)
gas_px <- rbindlist(monthly_rows)
gas_px <- gas_px[yyyymm >= "202201" & yyyymm <= "202412"]
setorder(gas_px, yyyymm)
stopifnot(nrow(gas_px) == 36)

ym_all <- gas_px$yyyymm

cat(sprintf("Gas price series: %d months  %s - %s\n",
            nrow(gas_px), min(gas_px$yyyymm), max(gas_px$yyyymm)))
cat("Adelaide STTM ex-ante quarterly averages used ($/GJ):\n")
print(raw_gas[qend_yr >= 2021L & qend_yr <= 2025L, .(quarter_ending, adl_gj)])

# Distillate (diesel) price series  (AUD/L ex-tax -> convert to $/GJ)
# ASSUMPTION: AIP wholesale diesel proxy; calorific value 38.0 GJ/kL (LHV)
DIESEL_GJ_PER_LITRE <- 0.038
gas_px[, diesel_ltr := c(
  1.65, 1.70, 1.75, 1.75, 1.85, 1.95,   # Jan-Jun 2022 (Russia-Ukraine supply shock)
  1.95, 1.90, 1.85, 1.80, 1.75, 1.70,   # Jul-Dec 2022
  1.65, 1.60, 1.60, 1.60, 1.60, 1.60,   # Jan-Jun 2023
  1.58, 1.58, 1.58, 1.55, 1.55, 1.55,   # Jul-Dec 2023
  1.55, 1.55, 1.55, 1.58, 1.60, 1.60,   # Jan-Jun 2024
  1.58, 1.58, 1.55, 1.55, 1.55, 1.55    # Jul-Dec 2024
)]
gas_px[, diesel_gj := diesel_ltr / DIESEL_GJ_PER_LITRE]

gas_px_assumption <- gas_px   # alias for rest of script

# ---------------------------------------------------------------------------
# Unit parameters
# ---------------------------------------------------------------------------
# Heat rates: AEMO heat-rate workbook (as-generated HHV basis).
#   Two-part fuel curve: fuel(GJ/h) = no_load_base + incremental_hr x MW
#   incremental_hr = marginal GJ per MWh dispatched above min stable gen.
#   static_hr      = average GJ/MWh at registered capacity.
#   Source: srmc_inputs_heatrate_vom.md (companion document).
#
# VOM: Aurecon 2024 Energy Technology Cost and Technical Parameter Review,
#   by technology class. New-entrant costs; treat as floor for older plant.
#   FOM excluded from SRMC formula (fixed cost, irrelevant to marginal offer).
#
# Two SRMC measures:
#   srmc_marginal = incremental_hr x gas + vom  (offer-stack / withholding test)
#   srmc_allin    = static_hr     x gas + vom  (Synchronise on/off decision)
#
# PPCCGT/OSB-AG anomaly: AEMO sheet has incremental_hr > static_hr (physically
#   backwards). static_hr is thermodynamically correct (Pelican Pt 7.35 GJ/MWh
#   ~ 49% HHV efficiency, consistent with 2x GT13E2 + 1 ST CCGT). For these two,
#   static_hr is used for BOTH srmc_marginal and srmc_allin.
#
# Gaps:
#   BARKIPS1: absent from AEMO sheet (2019 plant). Proxy: reciprocating class
#     ~7.9 GJ/MWh (full-load gas mode, Wartsila 50DF).
#   TORRB VOM: no Aurecon class for gas-steam. Proxy: $2.5/MWh (mid of $1-4
#     range for old gas-steam). Flag source = "proxy"; fill from revealed cost.
#
# Distillate capability (dual-fuel):
#   TORRB1-4, PPCCGT, OSB-AG, MINTARO: gas only.
#   BARKIPS1 (Wartsila 50DF): designed dual-fuel (gas + diesel). TRUE.
#   DRYCGT1-3 (Alstom GT11N2): originally dual-fuel; operational status uncertain.
#   QPS5 (GE Frame 9E at Quarantine): originally dual-fuel (gas + diesel). TRUE.
# ---------------------------------------------------------------------------

unit_params <- data.table(
  duid = c(
    "TORRB1","TORRB2","TORRB3","TORRB4",
    "PPCCGT","OSB-AG",
    "MINTARO","BARKIPS1",
    "DRYCGT1","DRYCGT2","DRYCGT3","QPS5"
  ),
  tech_label = c(
    rep("Gas-steam (Torrens B)", 4),
    "CCGT (Pelican Pt)", "Cogen (Osborne)",
    "OCGT (Mintaro)", "Recip. (Barker Inlet)",
    rep("OCGT (Dry Creek)", 3), "OCGT (Quarantine)"
  ),
  # Incremental heat rate (GJ/MWh) -- source: AEMO heat-rate workbook
  # For PPCCGT/OSB-AG: anomalous (incr > static); static used for both SRMC measures.
  # For BARKIPS1: proxy from reciprocating-engine class (gap in AEMO sheet).
  incr_hr = c(
     9.94,  9.94,  9.94,  9.94,   # TORRB1-4: AEMO sheet (station-level)
     7.35,  8.16,                  # PPCCGT, OSB-AG: use static (incr anomalous)
    10.00,  7.90,                  # MINTARO: AEMO; BARKIPS1: proxy ~7.9 (Wartsila 50DF)
    10.97, 10.97, 10.97,  8.00    # DRYCGT1-3: AEMO; QPS5: AEMO
  ),
  # Static (average) heat rate (GJ/MWh) -- source: AEMO heat-rate workbook
  static_hr = c(
    10.71, 10.71, 10.71, 10.71,   # TORRB1-4
     7.35,  8.16,                  # PPCCGT, OSB-AG (static is the trusted value)
    12.72,  7.90,                  # MINTARO; BARKIPS1 proxy (no static available)
    13.69, 13.69, 13.69, 10.71    # DRYCGT1-3; QPS5
  ),
  # VOM ($/MWh) -- source: Aurecon 2024 by technology class
  # TORRB: no class; proxy $2.5/MWh (mid $1-4 range); fill from revealed cost.
  # OCGT range $8.1-16.1; large-frame E-class (Dry Creek GT11N2, Quarantine Frame 9E): $8.1.
  # Mintaro (small peaker): $12.0 (mid-range).
  vom_mwh = c(
     2.5,  2.5,  2.5,  2.5,   # TORRB: proxy (gap; low sensitivity)
     4.1,  4.1,               # PPCCGT: Aurecon 2024 CCGT; OSB-AG: CCGT proxy
    12.0,  8.51,              # MINTARO: OCGT mid; BARKIPS1: Aurecon 2024 recip.
     8.1,  8.1,  8.1,  8.1   # DRYCGT1-3, QPS5: Aurecon 2024 OCGT large-frame
  ),
  distillate_capable = c(
    FALSE, FALSE, FALSE, FALSE,   # TORRB
    FALSE, FALSE,                 # PPCCGT, OSB-AG
    FALSE, TRUE,                  # MINTARO (gas only), BARKIPS1 (Wartsila 50DF)
    TRUE,  TRUE,  TRUE,  TRUE    # DRYCGT* (orig dual), QPS5 (orig dual)
  )
)

# ---------------------------------------------------------------------------
# SRMC computation
# ---------------------------------------------------------------------------
gas_px_assumption[, .dummy := 1L]
unit_params[, .dummy := 1L]
srmc_long <- merge(gas_px_assumption, unit_params, by = ".dummy", allow.cartesian = TRUE)
srmc_long[, .dummy := NULL]
gas_px_assumption[, .dummy := NULL]
unit_params[, .dummy := NULL]

# Fuel: use cheaper of gas and diesel for distillate-capable units
srmc_long[, fuel_gj   := fifelse(distillate_capable, pmin(gas_gj, diesel_gj), gas_gj)]
srmc_long[, fuel_type := fifelse(distillate_capable & diesel_gj < gas_gj, "diesel", "gas")]

# Two SRMC measures (see srmc_inputs_heatrate_vom.md §3)
#   srmc_marginal: incremental heat rate -- for offer-stack / withholding test
#   srmc_allin:    static heat rate     -- for Synchronise on/off decision
# Both use the cheaper fuel for dual-fuel capable units.
srmc_long[, srmc_marginal := fuel_gj * incr_hr   + vom_mwh]
srmc_long[, srmc_allin    := fuel_gj * static_hr + vom_mwh]
# Convenience alias: srmc_marginal is the primary measure for Gate A
srmc_long[, srmc          := srmc_marginal]

# Sanity check: is gas always cheaper than diesel for distillate-capable units?
fuel_check <- srmc_long[distillate_capable == TRUE, .N, by = fuel_type]
cat("\nFuel choice for distillate-capable units:\n")
print(fuel_check)

# ---------------------------------------------------------------------------
# Merge with d_t
# ---------------------------------------------------------------------------
srmc_dt <- merge(srmc_long, dt_s, by = "yyyymm", all.x = TRUE)
srmc_dt[, date := as.Date(paste0(yyyymm, "01"), format = "%Y%m%d")]
DT_EXIT_YM   <- "202307"
DT_EXIT_DATE <- as.Date("2023-07-01")

# ---------------------------------------------------------------------------
# Gate A summary table
# ---------------------------------------------------------------------------
gate_a_tab <- srmc_dt[!is.na(dt), .(
  n_months                  = .N,
  # Marginal SRMC (incremental heat rate -- primary for offer-stack / withholding)
  mths_dt_above_srmc_marg   = sum(dt > srmc_marginal, na.rm = TRUE),
  pre_exit_margin_marg      = round(mean((dt - srmc_marginal)[yyyymm < DT_EXIT_YM],  na.rm = TRUE), 1),
  post_exit_margin_marg     = round(mean((dt - srmc_marginal)[yyyymm >= DT_EXIT_YM], na.rm = TRUE), 1),
  # All-in SRMC (static heat rate -- for Synchronise on/off decision)
  mths_dt_above_srmc_allin  = sum(dt > srmc_allin, na.rm = TRUE),
  pre_exit_margin_allin     = round(mean((dt - srmc_allin)[yyyymm < DT_EXIT_YM],  na.rm = TRUE), 1),
  post_exit_margin_allin    = round(mean((dt - srmc_allin)[yyyymm >= DT_EXIT_YM], na.rm = TRUE), 1)
), by = .(duid, tech_label)][order(-pre_exit_margin_marg)]

cat("\n=== GATE A: d_t - SRMC margin summary ($/MWh) ===\n")
cat("Positive margin = unit has incentive to be directed at d_t rather than run in market.\n\n")
print(gate_a_tab, nrow = 20)

fwrite(gate_a_tab, file.path(OUT_V3, "GateA_srmc_margin_summary.csv"))
fwrite(srmc_long[, .(duid, tech_label, yyyymm, gas_gj, diesel_gj, fuel_type,
                     incr_hr, static_hr, vom_mwh,
                     srmc_marginal, srmc_allin)],
       file.path(OUT_V3, "GateA_srmc_params.csv"))

cat("\nMonths where marginal SRMC > d_t (direction incentive is NEGATIVE -- marginal basis):\n")
print(srmc_dt[!is.na(dt) & srmc_marginal > dt,
              .(duid, yyyymm, gas_gj,
                srmc_marg = round(srmc_marginal,0),
                srmc_alln = round(srmc_allin,0),
                dt        = round(dt,0),
                margin    = round(dt - srmc_marginal, 0))][order(duid, yyyymm)])

# ---------------------------------------------------------------------------
# Gate A decisive plot
# ---------------------------------------------------------------------------
unit_order <- unit_params[order(-incr_hr), duid]
srmc_dt[, duid_f := factor(duid, levels = unit_order)]

dt_line <- dt_s[yyyymm %in% ym_all,
                .(date = as.Date(paste0(yyyymm,"01"), format="%Y%m%d"), dt)]

p <- ggplot(srmc_dt, aes(x = date)) +
  geom_line(aes(y = srmc, colour = "SRMC (fuel + VOM)"), linewidth = 0.9) +
  geom_line(data = dt_line, aes(y = dt, colour = "d_t (reconstructed)"),
            linewidth = 1.0, linetype = "dashed") +
  geom_ribbon(aes(ymin = pmin(srmc, dt), ymax = pmax(srmc, dt),
                  fill = ifelse(srmc > dt, "SRMC > d_t (no incentive)", "d_t > SRMC (direction incentive)")),
              alpha = 0.18) +
  geom_vline(xintercept = DT_EXIT_DATE, linetype = "dotted", colour = "grey30", linewidth = 0.7) +
  facet_wrap(~duid_f, scales = "free_y", ncol = 4) +
  scale_colour_manual(
    values = c("SRMC (fuel + VOM)" = "steelblue",
               "d_t (reconstructed)" = "firebrick"),
    name = NULL
  ) +
  scale_fill_manual(
    values = c("SRMC > d_t (no incentive)" = "#d73027",
               "d_t > SRMC (direction incentive)" = "#4dac26"),
    name = NULL
  ) +
  scale_x_date(date_labels = "%m/%y", breaks = "6 months") +
  scale_y_continuous(labels = scales::dollar_format(prefix = "$", suffix = "/MWh")) +
  labs(
    title    = "Gate A: SRMC vs d_t -- direction incentive by unit and month",
    subtitle = paste(
      "SRMC = marginal (incremental heat rate x gas price + VOM). Green = d_t > SRMC. Red = SRMC > d_t.",
      "Dotted = d_t exit (Jul 2023). Gas: AER STTM Adelaide ex-ante (quarterly step). PPCCGT/OSB-AG use static HR (incremental anomalous).",
      sep = "\n"
    ),
    x = NULL, y = "$/MWh",
    caption = paste(
      "Heat rates: AEMO heat-rate workbook (unit-specific, as-generated HHV); BARKIPS1 proxy ~7.9 GJ/MWh (Wartsila 50DF, gap in sheet).",
      "VOM: Aurecon 2024 Energy Technology Cost and Technical Parameter Review, by technology class.",
      "Gas: AER Quarterly_STTM_Price.CSV (Adelaide STTM ex-ante); diesel: AIP wholesale proxy (rarely binding).",
      sep = "\n"
    )
  ) +
  theme_bw(base_size = 10) +
  theme(
    legend.position  = "bottom",
    legend.box       = "vertical",
    strip.text       = element_text(size = 8),
    plot.caption     = element_text(size = 7, colour = "grey40"),
    plot.subtitle    = element_text(size = 8)
  )

ggsave(file.path(OUT_V3, "GateA_srmc.png"), p, width = 16, height = 11, dpi = 150)
cat(sprintf("\nSaved: %s\n", file.path(OUT_V3, "GateA_srmc.png")))

# ---------------------------------------------------------------------------
# Additional diagnostic: SRMC around d_t exit month
# ---------------------------------------------------------------------------
cat("\n--- SRMC at and around d_t exit (202306 - 202309) ---\n")
exit_window <- srmc_dt[yyyymm %in% c("202306","202307","202308","202309"),
                       .(duid, yyyymm, gas_gj = round(gas_gj,2),
                         srmc = round(srmc,0), dt = round(dt,0),
                         margin = round(dt - srmc, 0))]
print(exit_window[order(duid, yyyymm)])

cat("\n=== GATE A COMPLETE ===\n")
cat("Review GateA_srmc.png before proceeding.\n")
cat("Key question: Does SRMC have a structural break at Jul 2023 (dotted line)?\n")
cat("  YES -> threatens identification (SRMC change coincides with d_t fall).\n")
cat("  NO  -> gas SRMC glides smoothly; d_t identification is clean.\n")
