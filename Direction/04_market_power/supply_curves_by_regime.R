#!/usr/bin/env Rscript
# supply_curves_by_regime.R
# Recover each treated unit's offer (supply) curve from bids and compare it across
# the 2x2 of direction x pivotality:
#   UN = undirected, non-pivotal   (competitive baseline)
#   UP = undirected, pivotal       (market power available, no direction -- exogenous, cf. [F14])
#   DN = directed,   non-pivotal
#   DP = directed,   pivotal       (directed AND system-essential)
#
# Representation: the offer curve is the inverse supply curve -- offer price at each
# cumulative-capacity quantile. Per interval we read price at a grid of capacity shares,
# normalise price by SRMC (log markup, comparable across gas regimes), and take the
# median curve (with IQR band) across intervals within each regime, per unit.
#
# Two quantity normalisations (produced side by side):
#   (a) share of MAXAVAIL      -> pure price/steepness shape of the offered stack
#   (b) share of registered cap-> shows BOTH levers; truncates when MAXAVAIL is cut,
#       with unavailable capacity treated as offered at the market price cap (withheld).
#
# Run from Direction/. Outputs to outputs/descriptives_v3/supply_curves/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")

OUT   <- "outputs/descriptives_v3/supply_curves"
CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# TORRB1 dropped: effectively offline all sample (95th-pctile MAXAVAIL = 0).
UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
           "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
duid2piv <- c(
  TORRB2="piv_torrens_island_b", TORRB3="piv_torrens_island_b", TORRB4="piv_torrens_island_b",
  PPCCGT="piv_pelican_point_gt", `OSB-AG`="piv_osborne_gt_st",
  QPS5="piv_quarantine_5", MINTARO="piv_mintaro", BARKIPS1="piv_bips",
  DRYCGT1="piv_dry_creek", DRYCGT2="piv_dry_creek", DRYCGT3="piv_dry_creek")

QGRID   <- seq(0.05, 1.00, by = 0.05)
MIN_INT <- 20L   # min intervals to compute a monthly median for a (unit,regime,month)

mpc_by_yyyymm <- function(ym) {           # market price cap by financial year
  yr <- as.integer(substr(ym,1,4)); mo <- as.integer(substr(ym,5,6))
  fy <- ifelse(mo >= 7L, yr+1L, yr)
  ifelse(fy <= 2023L, 15500, ifelse(fy == 2024L, 16600, 17500))
}

# ---- registered-capacity proxy per unit (95th pctile MAXAVAIL over all intervals) ----
panel <- readRDS("outputs/descriptives_v3/panel_v3.rds")[
  duid %in% UNITS, .(duid, interval_dt, directed, MAXAVAIL)]
cap95 <- panel[, .(cap = as.numeric(quantile(MAXAVAIL, 0.95, na.rm = TRUE))), by = duid]
cap95 <- cap95[cap > 0]

# ---- regime key per (duid, interval) ----
piv <- readRDS("outputs/descriptives_v3/pivotality_panel.rds")
piv[, interval_dt := SETTLEMENTDATE]
pv <- rbindlist(lapply(UNITS, function(u)
  data.table(duid = u, interval_dt = piv$interval_dt, pivotal = piv[[duid2piv[[u]]]])))
reg <- merge(panel[, .(duid, interval_dt, directed)], pv,
             by = c("duid","interval_dt"), all.x = TRUE)
reg[is.na(pivotal), pivotal := FALSE]
reg[, regime := fifelse(directed==0L & !pivotal, "UN",
              fifelse(directed==0L &  pivotal, "UP",
              fifelse(directed==1L & !pivotal, "DN", "DP")))]
reg <- reg[, .(duid, interval_dt, regime)]
setkey(reg, duid, interval_dt)

srmc_ref <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  , .(duid, yyyymm = as.character(yyyymm), srmc = srmc_marginal)]

# ---- inverse-supply reader: price at cumulative share q (vectorised over rows) ----
price_at <- function(cumshare, PB, q, mpc_vec) {
  hit <- cumshare >= q                       # n x 10 logical
  idx <- max.col(hit, ties.method = "first") # first band clearing q
  pr  <- PB[cbind(seq_len(nrow(PB)), idx)]
  none <- rowSums(hit) == 0                   # q beyond offered/available -> withheld at cap
  pr[none] <- mpc_vec[none]
  pr
}

ba_cols <- paste0("BANDAVAIL", 1:10); pb_cols <- paste0("PRICEBAND", 1:10)
months  <- sprintf("%d%02d", rep(2022:2024, each=12), rep(1:12,3))
months  <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]

curve_list <- vector("list", length(months))   # (unit,regime,month,q,norm) monthly medians
scal_list  <- vector("list", length(months))   # (unit,regime,month) scalar medians

for (i in seq_along(months)) {
  M <- months[i]; mpc <- mpc_by_yyyymm(M)
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% cap95$duid & BIDTYPE == "ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by = .(DUID, INTERVAL_DATETIME)]$V1]
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with = FALSE]
  bop[, td := as.Date(TRADINGDATE)]
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% cap95$duid & BIDTYPE == "ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
  bdo[, td := as.Date(SETTLEMENTDATE)]
  m <- merge(bop, bdo[, c("DUID","td", pb_cols), with = FALSE], by = c("DUID","td"))
  m <- merge(m, reg, by.x = c("DUID","INTERVAL_DATETIME"),
             by.y = c("duid","interval_dt"))
  m[, yyyymm := M]
  m <- merge(m, srmc_ref, by.x = c("DUID","yyyymm"), by.y = c("duid","yyyymm"))
  m <- merge(m, cap95, by.x = "DUID", by.y = "duid")
  m <- m[is.finite(MAXAVAIL) & MAXAVAIL > 1 & is.finite(srmc) & srmc > 0]
  if (!nrow(m)) next

  BA <- as.matrix(m[, ..ba_cols]); BA[is.na(BA)] <- 0
  PB <- as.matrix(m[, ..pb_cols])
  SR  <- m$srmc; MA <- m$MAXAVAIL; CAP <- m$cap; mpcv <- rep(mpc, nrow(m))
  cumBA  <- BA; for (j in 2:10) cumBA[, j] <- cumBA[, j-1] + BA[, j]
  # MAXAVAIL caps total dispatchable output regardless of posted band quantities:
  # capacity above MAXAVAIL is unavailable (a quantity-withholding lever), so cap the
  # cumulative offer at MAXAVAIL before normalising. effBA = per-band availability net of the cap.
  cumBA_eff <- pmin(cumBA, MA)
  effBA <- cumBA_eff
  effBA[, 2:10] <- cumBA_eff[, 2:10] - cumBA_eff[, 1:9]
  cumsh_ma  <- cumBA_eff / MA     # in [0,1]
  cumsh_reg <- cumBA_eff / CAP    # in [0, MAXAVAIL/cap] -> truncates when MAXAVAIL is cut

  # ---- curve points at each q, both normalisations: raw price ($) and price/SRMC ----
  # Each interval's inverse supply curve is monotone (NEM price bands are non-decreasing and we
  # stack cheapest-first). To keep the MEDIAN curve monotone we aggregate over a FIXED set of
  # intervals across all quantiles: drop any interval whose curve has a gap (NA), never filter
  # per-quantile. Floor tranche (price<=0) is CLAMPED to the log-axis floor, not dropped.
  RCLAMP <- 0.1
  mk_curve <- function(cumsh, norm) {
    id <- seq_len(nrow(m))
    dd <- rbindlist(lapply(QGRID, function(q) {
      pr <- price_at(cumsh, PB, q, mpcv)
      data.table(id = id, DUID = m$DUID, regime = m$regime, q = q, price = pr)
    }))
    bad <- dd[!is.finite(price), unique(id)]         # any interval with a gap -> drop entirely
    dd  <- dd[!id %in% bad]
    dd[, ratio := pmax(price / SR[id], RCLAMP)]       # clamp (monotone-preserving) for log view
    dd[, .(med = median(ratio), q25 = quantile(ratio,.25), q75 = quantile(ratio,.75),
           med_p = median(price), lo_p = quantile(price,.25), hi_p = quantile(price,.75), n = .N),
       by = .(DUID, regime, q)][n >= MIN_INT][, norm := norm][]
  }
  curve_list[[i]] <- rbind(mk_curve(cumsh_ma, "MAXAVAIL"),
                           mk_curve(cumsh_reg, "registered"))[, yyyymm := M][]

  # ---- scalar steepness metrics per interval, then monthly median by regime ----
  above <- effBA * (PB > SR)                  # SR recycled down columns (length = nrow)
  below <- effBA * (PB <= SR)
  m[, withheld_ma  := rowSums(above) / MA]                        # price margin (of MAXAVAIL)
  m[, withheld_reg := pmin(pmax((CAP - rowSums(below)) / CAP, 0), 1)]  # price + quantity (of reg cap)
  m[, markup50 := price_at(cumsh_ma, PB, 0.50, mpcv) / SR]
  m[, p10 := price_at(cumsh_ma, PB, 0.10, mpcv)]
  m[, p90 := price_at(cumsh_ma, PB, 0.90, mpcv)]
  m[, steepness := pmax(p90,1) / pmax(p10,1)]
  m[, avail_frac := MA / CAP]
  scal_list[[i]] <- m[, .(withheld_ma  = median(withheld_ma,  na.rm=TRUE),
                          withheld_reg = median(withheld_reg, na.rm=TRUE),
                          markup50     = median(markup50,     na.rm=TRUE),
                          steepness    = median(steepness,    na.rm=TRUE),
                          avail_frac   = median(avail_frac,   na.rm=TRUE),
                          n_int = .N),
                      by = .(DUID, regime)][n_int >= MIN_INT][, yyyymm := M][]
  cat(sprintf("  [%s] rows %d\n", M, nrow(m)))
}

curves <- rbindlist(curve_list)
scal   <- rbindlist(scal_list)

# ---- aggregate monthly medians -> final curve (median + IQR across months) ----
CUR <- curves[, .(ratio = median(med),
                  lo = quantile(med, .25), hi = quantile(med, .75),
                  price = median(med_p),                       # raw $/MWh
                  plo = quantile(med_p, .25), phi = quantile(med_p, .75),
                  n_mth = .N),
              by = .(DUID, regime, q, norm)]
fwrite(CUR, file.path(OUT, "supply_curves_by_regime.csv"))

# per-unit reference SRMC (median over sample) for the raw-$ view
srmc_line <- srmc_ref[duid %in% UNITS, .(srmc = median(srmc)), by = .(DUID = duid)]

SCAL <- scal[, lapply(.SD, median, na.rm = TRUE),
             by = .(DUID, regime),
             .SDcols = c("withheld_ma","withheld_reg","markup50","steepness","avail_frac")]
SCAL <- merge(SCAL, scal[, .(months = .N), by = .(DUID, regime)], by = c("DUID","regime"))
fwrite(SCAL, file.path(OUT, "supply_curve_scalars.csv"))
cat("\n=== Steepness scalars by unit x regime (median over months) ===\n")
print(SCAL[order(match(DUID,UNITS), regime)], nrow = 60)

# ---- plotting ----
reg_lab <- c(UN="Undirected, non-pivotal", UP="Undirected, PIVOTAL",
             DN="Directed, non-pivotal",   DP="Directed, PIVOTAL")
reg_col <- c(UN="#2c7bb6", UP="#7b3294", DN="#fdae61", DP="#d7191c")
REG_LVL <- c("UN","UP","DN","DP")
CUR[, regime := factor(regime, levels = REG_LVL)]
UNIT_ORDER <- UNITS[UNITS %in% unique(CUR$DUID)]
CUR[, DUID := factor(DUID, levels = UNIT_ORDER)]
srmc_line <- srmc_line[DUID %in% UNIT_ORDER][, DUID := factor(DUID, levels = UNIT_ORDER)]

plot_norm <- function(nm, subtitle_extra) {
  d <- CUR[norm == nm]
  ggplot(d, aes(x = q, y = ratio, colour = regime, fill = regime)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
    geom_line(linewidth = 0.8) +
    facet_wrap(~DUID, ncol = 4, scales = "free_x") +
    scale_y_log10(breaks = c(0.1,0.5,1,2,5,10,50,150),
                  labels = c("0.1","0.5","1 (SRMC)","2","5","10","50","150")) +
    scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    scale_colour_manual(values = reg_col, labels = reg_lab, name = NULL, drop = FALSE) +
    scale_fill_manual(values = reg_col, labels = reg_lab, name = NULL, drop = FALSE) +
    labs(title = sprintf("Offer (supply) curves by direction x pivotality regime -- x = %s", nm),
         subtitle = paste("Inverse supply curve: offer price / SRMC (log) at each cumulative-capacity quantile.",
                          "Median across months; ribbon = inter-quartile band across months.", subtitle_extra, sep="\n"),
         x = sprintf("Cumulative capacity offered (share of %s)", nm),
         y = "Offer price / SRMC  (1 = marginal cost)") +
    theme_bw(base_size = 9) +
    theme(legend.position = "bottom", strip.text = element_text(size = 8))
}

ggsave(file.path(OUT, "supply_curves_MAXAVAIL.png"),
       plot_norm("MAXAVAIL", "Isolates the price/steepness shape of the offered stack."),
       width = 15, height = 10, dpi = 150)
ggsave(file.path(OUT, "supply_curves_registered.png"),
       plot_norm("registered", "Curve truncates when MAXAVAIL is cut; unavailable capacity = withheld at the price cap."),
       width = 15, height = 10, dpi = 150)

# ---- RAW-DOLLAR view: y = offer price ($/MWh), unscaled ----
plot_raw <- function(nm, subtitle_extra) {
  d <- CUR[norm == nm]
  ggplot(d, aes(x = q, y = price, colour = regime, fill = regime)) +
    geom_hline(data = srmc_line, aes(yintercept = srmc),
               linetype = "dashed", colour = "grey35") +
    geom_ribbon(aes(ymin = plo, ymax = phi), alpha = 0.12, colour = NA) +
    geom_line(linewidth = 0.8) +
    facet_wrap(~DUID, ncol = 4, scales = "free_x") +
    scale_y_continuous(labels = scales::dollar_format()) +
    scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    scale_colour_manual(values = reg_col, labels = reg_lab, name = NULL, drop = FALSE) +
    scale_fill_manual(values = reg_col, labels = reg_lab, name = NULL, drop = FALSE) +
    labs(title = sprintf("Offer (supply) curves by direction x pivotality regime -- RAW $/MWh, x = %s", nm),
         subtitle = paste("Offer price ($/MWh, unscaled, linear) at each cumulative-capacity quantile. Median across months; ribbon = IQR.",
                          "Dashed grey = unit median SRMC (cost). Ceiling = market price cap (~$15.5-17.5k).", subtitle_extra, sep="\n"),
         x = sprintf("Cumulative capacity offered (share of %s)", nm),
         y = "Offer price ($/MWh)") +
    theme_bw(base_size = 9) +
    theme(legend.position = "bottom", strip.text = element_text(size = 8))
}
ggsave(file.path(OUT, "supply_curves_MAXAVAIL_raw.png"),
       plot_raw("MAXAVAIL", "Isolates the price shape of the offered stack."),
       width = 15, height = 10, dpi = 150)
ggsave(file.path(OUT, "supply_curves_registered_raw.png"),
       plot_raw("registered", "Truncation to the cap = quantity withheld (MAXAVAIL cut)."),
       width = 15, height = 10, dpi = 150)

# ---- scalar summary figure: withheld share (registered) by regime ----
SCAL[, regime := factor(regime, levels = REG_LVL)]
SCAL[, DUID := factor(DUID, levels = UNIT_ORDER)]
p_s <- ggplot(SCAL, aes(x = DUID, y = withheld_reg, fill = regime)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_manual(values = reg_col, labels = reg_lab, name = NULL, drop = FALSE) +
  labs(title = "Withheld share of registered capacity by regime (price + quantity margins)",
       subtitle = "Share of registered capacity NOT offered at or below SRMC (priced above SRMC or unavailable). Median over months.",
       x = NULL, y = "Withheld share of registered capacity") +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom", axis.text.x = element_text(angle = 30, hjust = 1))
ggsave(file.path(OUT, "withheld_share_by_regime.png"), p_s, width = 12, height = 6, dpi = 150)

cat("\nSaved to", OUT, ":\n"); for (f in list.files(OUT)) cat("  ", f, "\n")
