#!/usr/bin/env Rscript
# gate_a_revealed_cost.R
# Gate A, revealed-cost anchor (srmc_inputs_heatrate_vom.md Section 7).
# Tests whether treated units' low (cost-reflective) offer band tracks the STTM
# gas price over COMPETITIVE intervals -- i.e. whether offers reveal a
# gas-indexed heat rate that could override / validate the engineering SRMC.
#
# Design (Section 7): regress the marginal (low) offer price on contemporaneous
# gas over competitive intervals only (undirected, non-pivotal, system not short),
# per unit. Slope = implied incremental heat rate; intercept = implied VOM.
# Estimate on the competitive subsample; never on the tested (withholding) periods.
#
# Run from Direction/ working directory. Outputs to outputs/descriptives_v3/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")

OUT   <- "outputs/descriptives_v3"
CACHE <- "bid_cache"

TREATED <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
             "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")

# DUID -> pivotality-panel station column
duid2piv <- c(
  TORRB1="piv_torrens_island_b", TORRB2="piv_torrens_island_b",
  TORRB3="piv_torrens_island_b", TORRB4="piv_torrens_island_b",
  PPCCGT="piv_pelican_point_gt", `OSB-AG`="piv_osborne_gt_st",
  QPS5="piv_quarantine_5", MINTARO="piv_mintaro", BARKIPS1="piv_bips",
  DRYCGT1="piv_dry_creek", DRYCGT2="piv_dry_creek", DRYCGT3="piv_dry_creek")

# ---------------------------------------------------------------------------
# 1. Competitive-interval flag per unit-interval
#    competitive = undirected AND non-pivotal AND system not short
# ---------------------------------------------------------------------------
piv <- readRDS(file.path(OUT, "pivotality_panel.rds"))
piv[, interval_dt := SETTLEMENTDATE]
piv_keep <- c("interval_dt", "short", unique(unlist(duid2piv)))
piv <- piv[, ..piv_keep]

tp <- readRDS("direction_data/parsed/treatment_panel.rds")
tp <- tp[duid %in% TREATED, .(duid, interval_dt = interval_datetime, directed)]

comp_list <- lapply(TREATED, function(u) {
  pcol <- duid2piv[[u]]
  d <- piv[, .(interval_dt, pivotal = get(pcol), short)]
  d[, duid := u]
  d
})
comp <- rbindlist(comp_list)
comp <- merge(comp, tp, by = c("duid","interval_dt"), all.x = TRUE)
comp[is.na(directed), directed := 0L]
comp[, competitive := (directed == 0L) & (pivotal == FALSE) & (short == FALSE)]
comp[, trade_date := as.Date(interval_dt)]

# Aggregate to unit-day: share of competitive intervals
ud_comp <- comp[, .(comp_share = mean(competitive, na.rm = TRUE),
                    n_int = .N), by = .(duid, trade_date)]
cat(sprintf("Unit-days: %d | mean competitive share: %.2f\n",
            nrow(ud_comp), mean(ud_comp$comp_share)))

# ---------------------------------------------------------------------------
# 2. Low (cost-reflective) offer price per unit-day, from BIDDAYOFFER
#    p_lowpos = lowest price band strictly above $1 (skips the -$1000/$0 floor
#    tranche that units park for guaranteed dispatch).
# ---------------------------------------------------------------------------
months <- sprintf("%d%02d", rep(2022:2024, each = 12), rep(1:12, 3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", months)))]
pb_cols <- paste0("PRICEBAND", 1:10)

price_list <- lapply(months, function(M) {
  b <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M)))
  setDT(b); b <- b[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  b <- b[b[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]  # latest version
  pb <- as.matrix(b[, ..pb_cols]); pb[pb <= 1] <- NA
  b[, p_lowpos := apply(pb, 1, function(r) if (all(is.na(r))) NA_real_ else min(r, na.rm = TRUE))]
  b[, .(duid = DUID, trade_date = as.Date(SETTLEMENTDATE), yyyymm = M, p_lowpos)]
})
prices <- rbindlist(price_list)

# ---------------------------------------------------------------------------
# 3. Monthly gas price (same source as gate_a_srmc.R)
# ---------------------------------------------------------------------------
gas <- unique(fread(file.path(OUT, "GateA_srmc_params.csv"))[,
        .(yyyymm = as.character(yyyymm), gas_gj)])

# ---------------------------------------------------------------------------
# 4. Assemble competitive unit-day sample and regress
# ---------------------------------------------------------------------------
COMP_THRESH <- 0.80   # a day is "competitive" if >=80% of its intervals are
dat <- merge(prices, ud_comp, by = c("duid","trade_date"), all.x = TRUE)
dat <- merge(dat, gas, by = "yyyymm", all.x = TRUE)
dat_comp <- dat[!is.na(p_lowpos) & !is.na(comp_share) & comp_share >= COMP_THRESH]

cat(sprintf("Competitive unit-days (comp_share >= %.2f): %d of %d\n",
            COMP_THRESH, nrow(dat_comp), nrow(dat[!is.na(p_lowpos)])))

srmc_ref <- unique(fread(file.path(OUT, "GateA_srmc_params.csv"))[,
             .(duid, eng_HR = incr_hr, eng_VOM = vom_mwh)])

# Per-unit revealed-cost regression on the competitive subsample
rev_tab <- dat_comp[, {
  f  <- lm(p_lowpos ~ gas_gj)
  ci <- tryCatch(confint(f)["gas_gj", ], error = function(e) c(NA, NA))
  .(rev_HR  = round(coef(f)[["gas_gj"]], 2),
    HR_lo   = round(ci[1], 2), HR_hi = round(ci[2], 2),
    rev_VOM = round(coef(f)[["(Intercept)"]], 1),
    r2      = round(summary(f)$r.squared, 3),
    mean_p  = round(mean(p_lowpos, na.rm = TRUE), 1),
    n_days  = .N)
}, by = duid]
rev_tab <- merge(rev_tab, srmc_ref, by = "duid")
setcolorder(rev_tab, c("duid","rev_HR","eng_HR","HR_lo","HR_hi",
                       "rev_VOM","eng_VOM","r2","mean_p","n_days"))
rev_tab <- rev_tab[order(match(duid, TREATED))]

cat("\n=== REVEALED-COST REGRESSION (competitive unit-days) ===\n")
cat("p_lowpos ~ gas : slope=implied HR (GJ/MWh), intercept=implied VOM ($/MWh)\n\n")
print(rev_tab, nrow = 20)

# Pooled test: does gas explain the low band at all, within unit?
suppressMessages(library(fixest))
pooled <- feols(p_lowpos ~ gas_gj | duid, data = dat_comp, vcov = "hetero")
cat("\nPooled within-unit slope (unit FE, HC-robust):\n")
print(summary(pooled))

fwrite(rev_tab, file.path(OUT, "GateA_revealed_cost.csv"))

# ---------------------------------------------------------------------------
# 5. Diagnostic figure: low band vs gas, per unit, competitive days
# ---------------------------------------------------------------------------
p <- ggplot(dat_comp, aes(x = gas_gj, y = p_lowpos)) +
  geom_point(alpha = 0.15, size = 0.6, colour = "grey40") +
  geom_smooth(method = "lm", se = TRUE, colour = "firebrick", linewidth = 0.8) +
  facet_wrap(~factor(duid, levels = TREATED), ncol = 4, scales = "free_y") +
  labs(title = "Revealed-cost test: low offer band vs STTM gas price (competitive unit-days)",
       subtitle = paste("p_lowpos = lowest price band > $1 (skips the -$1000/$0 dispatch-floor tranche).",
                         "A gas-indexed cost bid would slope up at the engineering heat rate; it does not.",
                         sep = "\n"),
       x = "STTM Adelaide gas price ($/GJ)", y = "Lowest positive offer band ($/MWh)") +
  theme_bw(base_size = 9)
ggsave(file.path(OUT, "GateA_revealed_cost.png"), p, width = 14, height = 9, dpi = 150)

cat("\nSaved GateA_revealed_cost.csv and .png\n")
cat("\n=== INTERPRETATION ===\n")
cat("If rev_HR ~ 0 with r2 ~ 0 across units: offers do NOT reveal a gas-indexed\n")
cat("heat rate. Units post a near-gas-invariant low ladder and exercise conduct\n")
cat("via quantity rebids + high bands. Engineering SRMC (gate_a_srmc.R) stands as\n")
cat("the cost estimate; the revealed-cost anchor cannot override it or fill gaps.\n")
