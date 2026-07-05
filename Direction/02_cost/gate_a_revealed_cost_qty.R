#!/usr/bin/env Rscript
# gate_a_revealed_cost_qty.R
# Gate A, revealed-cost anchor -- QUANTITY margin (companion to gate_a_revealed_cost.R).
#
# Motivation: units rebid QUANTITIES on a near-static price ladder [F16], so the
# price-band test (gate_a_revealed_cost.R) tests the lever they don't use to
# express cost. This tests the quantity margin directly: on COMPETITIVE intervals
# (undirected, non-pivotal, system not short), does the capacity a unit offers at
# low / cost-reflective prices respond to the gas price the way marginal cost would?
#   - Cost-bidding prediction: as gas (hence SRMC) rises, the price to clear the low
#     tranche rises at ~the heat rate (7-11 GJ/MWh), and the share of capacity offered
#     below a fixed cost-relevant threshold falls.
# Circularity guard (Section 7): identify on competitive intervals only. Quantity-below
# a threshold on ALL intervals is just withheld_share (the study outcome) inverted.
#
# Run from Direction/ working directory. Outputs to outputs/descriptives_v3/.

suppressMessages({ library(data.table); library(ggplot2); library(fixest) })
setwd("C:/Users/ericl/Documents/my-project/Direction")

OUT   <- "outputs/descriptives_v3"
CACHE <- "bid_cache"
TREATED <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
             "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
duid2piv <- c(
  TORRB1="piv_torrens_island_b", TORRB2="piv_torrens_island_b",
  TORRB3="piv_torrens_island_b", TORRB4="piv_torrens_island_b",
  PPCCGT="piv_pelican_point_gt", `OSB-AG`="piv_osborne_gt_st",
  QPS5="piv_quarantine_5", MINTARO="piv_mintaro", BARKIPS1="piv_bips",
  DRYCGT1="piv_dry_creek", DRYCGT2="piv_dry_creek", DRYCGT3="piv_dry_creek")

# ---- competitive flag per unit-interval ----
piv <- readRDS(file.path(OUT, "pivotality_panel.rds"))
piv[, interval_dt := SETTLEMENTDATE]
tp <- readRDS("direction_data/parsed/treatment_panel.rds")[
  , .(duid, interval_dt = interval_datetime, directed)]
comp <- rbindlist(lapply(TREATED, function(u){
  d <- piv[, .(interval_dt, pivotal = get(duid2piv[[u]]), short)]; d[, duid := u]; d}))
comp <- merge(comp, tp, by = c("duid","interval_dt"), all.x = TRUE)
comp[is.na(directed), directed := 0L]
comp[, competitive := directed == 0L & pivotal == FALSE & short == FALSE]
comp <- comp[competitive == TRUE, .(duid, interval_dt)]   # keep only competitive keys

gas <- unique(fread(file.path(OUT, "GateA_srmc_params.csv"))[,
        .(yyyymm = as.character(yyyymm), gas_gj)])

# ---- loop months: quantity distribution across the price ladder, competitive only ----
months <- sprintf("%d%02d", rep(2022:2024, each = 12), rep(1:12, 3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]
ba_cols <- paste0("BANDAVAIL", 1:10); pb_cols <- paste0("PRICEBAND", 1:10)

um_list <- vector("list", length(months))
for (i in seq_along(months)) {
  M <- months[i]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by = .(DUID, INTERVAL_DATETIME)]$V1]
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE", ba_cols), with = FALSE]
  bop[, td := as.Date(TRADINGDATE)]
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% TREATED & BIDTYPE == "ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
  bdo[, td := as.Date(SETTLEMENTDATE)]
  m <- merge(bop, bdo[, c("DUID","td", pb_cols), with = FALSE], by = c("DUID","td"), all.x = TRUE)
  m <- merge(m, comp, by.x = c("DUID","INTERVAL_DATETIME"),
             by.y = c("duid","interval_dt"))   # inner-join -> competitive only
  if (!nrow(m)) next
  BA <- as.matrix(m[, ..ba_cols]); BA[is.na(BA)] <- 0
  PB <- as.matrix(m[, ..pb_cols])
  tot <- rowSums(BA); ok <- tot > 1
  cumsh <- t(apply(BA, 1, cumsum)) / tot
  p_at <- function(q) vapply(seq_len(nrow(PB)), function(r){
    j <- which(cumsh[r, ] >= q)[1]; if (is.na(j)) NA_real_ else PB[r, j] }, numeric(1))
  m[, p_at_10 := p_at(0.10)]
  m[, p_at_25 := p_at(0.25)]
  m[, q_below_150 := rowSums(BA * (PB <= 150)) / tot]
  m[, q_below_300 := rowSums(BA * (PB <= 300)) / tot]
  m[, yyyymm := M]
  um_list[[i]] <- m[ok, .(p_at_10 = mean(p_at_10, na.rm = TRUE),
                          p_at_25 = mean(p_at_25, na.rm = TRUE),
                          q_below_150 = mean(q_below_150, na.rm = TRUE),
                          q_below_300 = mean(q_below_300, na.rm = TRUE),
                          n_int = sum(ok)),
                     by = .(duid = DUID, yyyymm)]
  cat(sprintf("  [%s] competitive unit-month rows: %d\n", M, nrow(um_list[[i]])))
}
um <- rbindlist(um_list)
um <- merge(um, gas, by = "yyyymm")

# ---- regressions (unit-month, competitive) ----
srmc_ref <- unique(fread(file.path(OUT, "GateA_srmc_params.csv"))[,
             .(duid, eng_HR = incr_hr)])

per_unit <- um[, {
  f25 <- lm(p_at_25 ~ gas_gj); fq <- lm(q_below_150 ~ gas_gj)
  .(HR_from_p25 = round(coef(f25)[["gas_gj"]], 2),
    r2_p25      = round(summary(f25)$r.squared, 3),
    q150_slope  = round(coef(fq)[["gas_gj"]], 4),
    mean_q150   = round(mean(q_below_150, na.rm = TRUE), 3),
    n = .N)
}, by = duid]
per_unit <- merge(per_unit, srmc_ref, by = "duid")
per_unit <- per_unit[order(match(duid, TREATED))]

cat("\n=== REVEALED-COST, QUANTITY MARGIN (competitive unit-months) ===\n")
cat("HR_from_p25 = slope of low-tranche price on gas (cost => ~ eng_HR 7-11).\n")
cat("q150_slope  = slope of share-below-$150 on gas (cost => negative).\n\n")
print(per_unit, nrow = 20)

pooled_p  <- feols(p_at_25 ~ gas_gj | duid, data = um, vcov = "hetero")
pooled_q  <- feols(q_below_150 ~ gas_gj | duid, data = um, vcov = "hetero")
cat("\nPooled within-unit slope, low-tranche price p_at_25 on gas (implied HR):\n")
print(summary(pooled_p))
cat("\nPooled within-unit slope, share-below-$150 on gas:\n")
print(summary(pooled_q))

fwrite(per_unit, file.path(OUT, "GateA_revealed_cost_qty.csv"))

# ---- figure: share-below-$150 vs gas, per unit, competitive months ----
p <- ggplot(um, aes(x = gas_gj, y = q_below_150)) +
  geom_point(alpha = 0.6, colour = "grey30") +
  geom_smooth(method = "lm", se = TRUE, colour = "firebrick", linewidth = 0.8) +
  facet_wrap(~factor(duid, levels = TREATED), ncol = 4, scales = "free_y") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(title = "Revealed-cost, quantity margin: share of offered capacity priced <= $150 vs gas",
       subtitle = paste("Competitive unit-months only (undirected, non-pivotal, not short).",
         "Cost bidding => share FALLS as gas (SRMC) rises. It is flat: quantity is not cost-linked either.",
         sep = "\n"),
       x = "STTM Adelaide gas price ($/GJ)", y = "Share of offered capacity <= $150/MWh") +
  theme_bw(base_size = 9)
ggsave(file.path(OUT, "GateA_revealed_cost_qty.png"), p, width = 14, height = 9, dpi = 150)

cat("\nSaved GateA_revealed_cost_qty.csv and .png\n")
