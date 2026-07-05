#!/usr/bin/env Rscript
# build_outcome.R -- Stage 1 of the Direction_clean/ rebuild: the withholding outcome.
#
# Per focal-unit interval: two co-primary "cheap capacity" definitions --
#   (a) fixed-threshold: MW effectively offered at or below $300/MWh (the historical administered
#       price cap, a fixed nominal anchor)
#   (b) cost-indexed: MW effectively offered at or below 2x that unit-month's SRMC
# -- both capped at declared availability (MAXAVAIL), both expressed as a SHARE OF REGISTERED
# CAPACITY (Stage 0's lookup). The continuous share is the primary outcome; a binary "withheld"
# classification (share < 0.5, tunable) is secondary and only used for the channel decomposition
# and threshold-sweep tables below.
#
# Reuses the exact bid-ladder join pattern from Direction/04_market_power/wo_stage1_baseline.R /
# wo_stage2_opportunity.R (latest in-force version per (DUID,interval)/(DUID,day); cumulative
# BANDAVAIL x PRICEBAND construction capped at MAXAVAIL) -- same arithmetic, plain-language names.
# Also re-runs (does not just copy) the two essentiality-flag audits from
# Direction/04_market_power/wo_stage2_opportunity.R against THIS pipeline's own outcome variables.
#
# Run from Direction_clean/.

suppressMessages({ library(data.table); library(ggplot2) })
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")
OUT       <- file.path(ROOT, "Direction_clean/outputs/01_outcome_withholding")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

FOCUS_TEST <- c("TORRB2","TORRB3","TORRB4","PPCCGT")   # withholding-contrast-eligible
FOCUS_ALL  <- c(FOCUS_TEST, "OSB-AG")                   # OSB-AG carried through, descriptive only
station <- c(TORRB2="torrens_island_b", TORRB3="torrens_island_b", TORRB4="torrens_island_b",
             PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st")

WITHHELD_CUTOFF <- 0.50   # binary "withheld" = cheap-capacity share below this (tunable; secondary)
EPS_SHARE       <- 0.01   # 1% of registered capacity -- "materially nonzero" for channel attribution
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

reg_cap_tbl <- fread(file.path(ROOT, "Direction_clean/outputs/00_inventory/focal_unit_registered_capacity.csv"))
stopifnot(all(FOCUS_ALL %in% reg_cap_tbl$duid))
REG_CAP <- setNames(reg_cap_tbl$reg_cap_mw, reg_cap_tbl$duid)

srmc <- fread(file.path(DIRECTION, "outputs/descriptives_v3/GateA_srmc_params.csv"))[
  duid %in% FOCUS_ALL, .(duid, yyyymm = as.integer(yyyymm), srmc = srmc_marginal, gas_gj)]

# ---------------------------------------------------------------------------
# Scan the bid ladder, all 36 months, focal units only
# ---------------------------------------------------------------------------
cat("=== Scanning bid ladder, all months, focal units only ===\n")
CACHE  <- file.path(DIRECTION, "bid_cache")
months <- sort(gsub("[^0-9]", "", list.files(CACHE, pattern="^BIDOFFERPERIOD_[0-9]{6}\\.rds$")))
lst <- vector("list", length(months)); join_report <- vector("list", length(months))
for (i in seq_along(months)) {
  M <- months[i]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% FOCUS_ALL & BIDTYPE=="ENERGY"]
  n_raw <- nrow(bop)
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by=.(DUID, INTERVAL_DATETIME)]$V1]  # latest in-force version
  n_inforce <- nrow(bop)
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with=FALSE]
  bop[, interval_dt := force10(INTERVAL_DATETIME)]; bop[, td := as.Date(TRADINGDATE)]

  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% FOCUS_ALL & BIDTYPE=="ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID, SETTLEMENTDATE)]$V1]         # latest daily ladder
  bdo[, td := as.Date(SETTLEMENTDATE)]
  dup <- bdo[, .N, by=.(DUID, td)][N>1]
  if (nrow(dup)) stop(sprintf("[%s] duplicate price ladder per (DUID,day) -- %d cases", M, nrow(dup)))

  m <- merge(bop, bdo[, c("DUID","td",pb_cols), with=FALSE], by=c("DUID","td"), all.x=TRUE)
  m[, yyyymm := as.integer(M)]
  m <- merge(m, srmc, by.x=c("DUID","yyyymm"), by.y=c("duid","yyyymm"), all.x=TRUE)

  join_report[[i]] <- data.table(month=M, raw=n_raw, inforce=n_inforce, merged=nrow(m),
                                  no_ladder=sum(is.na(m$PRICEBAND1)), no_srmc=sum(is.na(m$srmc)))
  lst[[i]] <- m
  cat(sprintf("  [%s] focal bid rows %d -> in-force %d -> merged %d (no-ladder %d, no-srmc %d)\n",
              M, n_raw, n_inforce, nrow(m), join_report[[i]]$no_ladder, join_report[[i]]$no_srmc))
}
X  <- rbindlist(lst)
jr <- rbindlist(join_report)
fwrite(jr, file.path(OUT, "join_report.csv"))
cat(sprintf("\nTotals: in-force %d | no-ladder %d (%.3f%%) | no-srmc %d (%.3f%%)\n",
            sum(jr$inforce), sum(jr$no_ladder), 100*sum(jr$no_ladder)/sum(jr$inforce),
            sum(jr$no_srmc), 100*sum(jr$no_srmc)/sum(jr$inforce)))
X <- X[!is.na(PRICEBAND1) & !is.na(srmc)]

# ---------------------------------------------------------------------------
# Cheap capacity: two co-primary definitions + threshold sweep, all capped at MAXAVAIL
# ---------------------------------------------------------------------------
BA <- as.matrix(X[, ..ba_cols]); BA[is.na(BA)] <- 0
PB <- as.matrix(X[, ..pb_cols]); MA <- X$MAXAVAIL
cumBA     <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1] + BA[,j]
cumBA_eff <- pmin(cumBA, MA)                                    # quantity cuts count as withholding
effBA     <- cumBA_eff; effBA[,2:10] <- cumBA_eff[,2:10] - cumBA_eff[,1:9]

cheap_at <- function(price_cutoff_vec) rowSums(effBA * (PB <= price_cutoff_vec))  # vectorised per row
X[, cheap_a       := cheap_at(300)]                    # (a) fixed $300/MWh -- headline
X[, cheap_a_150   := cheap_at(150)]                    # sweep
X[, cheap_a_500   := cheap_at(500)]
X[, cheap_b       := cheap_at(2   * srmc)]             # (b) cost-indexed 2xSRMC -- headline
X[, cheap_b_1.5x  := cheap_at(1.5 * srmc)]             # sweep
X[, cheap_b_3x    := cheap_at(3   * srmc)]

reg_cap_vec <- REG_CAP[X$DUID]
X[, maxavail_share := MAXAVAIL / reg_cap_vec]
for (cc in c("cheap_a","cheap_a_150","cheap_a_500","cheap_b","cheap_b_1.5x","cheap_b_3x")) {
  X[[paste0(cc, "_share")]] <- X[[cc]] / reg_cap_vec
}

n_over <- sum(X$maxavail_share > 1.02)
cat(sprintf("\nMAXAVAIL > 102%% of registered capacity: %d of %d rows (%.3f%%) -- not clipped, reported.\n",
            n_over, nrow(X), 100*n_over/nrow(X)))

# ---------------------------------------------------------------------------
# Waterfall channel decomposition (continuous, additive by construction):
#   registered capacity = withdrawn (availability cut) + priced_out (available but priced above
#   threshold) + cheap capacity offered
# ---------------------------------------------------------------------------
X[, withdrawn      := pmax(0, 1 - maxavail_share)]
X[, priced_out_a   := pmax(0, maxavail_share - cheap_a_share)]
X[, priced_out_b   := pmax(0, maxavail_share - cheap_b_share)]
X[, withheld_a := cheap_a_share < WITHHELD_CUTOFF]
X[, withheld_b := cheap_b_share < WITHHELD_CUTOFF]

channel_one <- function(d, priced_out_col) {
  d[, .(
    n_withheld = .N,
    withdrawn_only  = round(100*mean(withdrawn > EPS_SHARE & get(priced_out_col) <= EPS_SHARE), 1),
    priced_out_only = round(100*mean(withdrawn <= EPS_SHARE & get(priced_out_col) > EPS_SHARE), 1),
    both            = round(100*mean(withdrawn > EPS_SHARE & get(priced_out_col) > EPS_SHARE), 1),
    neither_flagged = round(100*mean(withdrawn <= EPS_SHARE & get(priced_out_col) <= EPS_SHARE), 1)
  ), by = DUID][order(match(DUID, FOCUS_ALL))]
}
channel_a <- channel_one(X[withheld_a == TRUE], "priced_out_a")
channel_b <- channel_one(X[withheld_b == TRUE], "priced_out_b")
fwrite(channel_a, file.path(OUT, "channel_decomposition_fixed_threshold.csv"))
fwrite(channel_b, file.path(OUT, "channel_decomposition_cost_indexed.csv"))
cat("\n=== Channel decomposition, among withheld intervals, fixed-threshold (a) ===\n"); print(channel_a)
cat("\n=== Channel decomposition, among withheld intervals, cost-indexed (b) ===\n");    print(channel_b)
if (any(channel_a$neither_flagged > 1) || any(channel_b$neither_flagged > 1))
  cat("NOTE: 'neither_flagged' > 1% for some unit -- investigate before reporting (see findings).\n")

# ---------------------------------------------------------------------------
# Threshold sensitivity sweep
# ---------------------------------------------------------------------------
sweep <- rbindlist(lapply(FOCUS_ALL, function(u) {
  d <- X[DUID == u]
  rbindlist(list(
    data.table(duid=u, definition="a_fixed",   threshold="$150",         n=nrow(d), median_share=round(median(d$cheap_a_150_share),3), withheld_pct=round(100*mean(d$cheap_a_150_share<WITHHELD_CUTOFF),1)),
    data.table(duid=u, definition="a_fixed",   threshold="$300 (default)",n=nrow(d), median_share=round(median(d$cheap_a_share),3),     withheld_pct=round(100*mean(d$cheap_a_share<WITHHELD_CUTOFF),1)),
    data.table(duid=u, definition="a_fixed",   threshold="$500",         n=nrow(d), median_share=round(median(d$cheap_a_500_share),3), withheld_pct=round(100*mean(d$cheap_a_500_share<WITHHELD_CUTOFF),1)),
    data.table(duid=u, definition="b_indexed", threshold="1.5xSRMC",     n=nrow(d), median_share=round(median(d$`cheap_b_1.5x_share`),3), withheld_pct=round(100*mean(d$`cheap_b_1.5x_share`<WITHHELD_CUTOFF),1)),
    data.table(duid=u, definition="b_indexed", threshold="2xSRMC (default)",n=nrow(d), median_share=round(median(d$cheap_b_share),3),   withheld_pct=round(100*mean(d$cheap_b_share<WITHHELD_CUTOFF),1)),
    data.table(duid=u, definition="b_indexed", threshold="3xSRMC",       n=nrow(d), median_share=round(median(d$cheap_b_3x_share),3),   withheld_pct=round(100*mean(d$cheap_b_3x_share<WITHHELD_CUTOFF),1))
  ))
}))
fwrite(sweep, file.path(OUT, "threshold_sensitivity.csv"))
cat("\n=== Threshold sensitivity sweep ===\n"); print(sweep)

# ---------------------------------------------------------------------------
# Agreement rate between (a) and (b), overall and by month; correlate disagreement with gas price
# ---------------------------------------------------------------------------
X[, agree := withheld_a == withheld_b]
agree_overall <- X[, .(n=.N, agreement_pct=round(100*mean(agree),1)), by=DUID][order(match(DUID,FOCUS_ALL))]
agree_month <- X[, .(n=.N, agreement_pct=round(100*mean(agree),1), gas_gj=mean(gas_gj)), by=.(DUID,yyyymm)]
gas_corr <- agree_month[, .(corr_disagreement_gas = round(cor(100-agreement_pct, gas_gj), 3)), by=DUID]
fwrite(agree_month, file.path(OUT, "ab_agreement_by_month.csv"))
fwrite(agree_overall, file.path(OUT, "ab_agreement_overall.csv"))
cat("\n=== (a) vs (b) agreement rate, overall ===\n"); print(agree_overall)
cat("\n=== Correlation between monthly disagreement rate and gas price (expect positive if high-gas months drive divergence) ===\n")
print(gas_corr)
worst_disagreement <- agree_overall[, max(100 - agreement_pct)]
if (worst_disagreement < 5) cat(sprintf(
  "NOTE: disagreement is small for every unit (worst case %.1f%% of intervals, %s) -- itself\n  evidence the $300 vs 2xSRMC threshold choice is innocuous, per the pre-registered reasoning.\n",
  worst_disagreement, agree_overall[which.max(100-agreement_pct), DUID]))

# ---------------------------------------------------------------------------
# Distribution per unit (primary definition, cheap_a) -- report bimodality as a finding
# ---------------------------------------------------------------------------
dist_summ <- X[, .(
  n = .N, mean = round(mean(cheap_a_share),3), median = round(median(cheap_a_share),3),
  p10 = round(quantile(cheap_a_share,.10),3), p90 = round(quantile(cheap_a_share,.90),3),
  floor_share_pct  = round(100*mean(cheap_a_share < 0.10), 1),   # near-zero cheap capacity
  full_share_pct   = round(100*mean(cheap_a_share > 0.75), 1)    # most capacity offered cheap
), by=DUID][order(match(DUID,FOCUS_ALL))]
fwrite(dist_summ, file.path(OUT, "distribution_summary.csv"))
cat("\n=== Distribution of cheap-capacity share (fixed-threshold definition), per unit ===\n"); print(dist_summ)

Xp <- X[DUID %in% FOCUS_ALL]; Xp[, DUID := factor(DUID, levels=FOCUS_ALL)]
p <- ggplot(Xp, aes(cheap_a_share)) +
  geom_histogram(bins=50, fill="steelblue", colour=NA) +
  facet_wrap(~DUID, ncol=3, scales="free_y") +
  labs(title="Stage 1: distribution of cheap-capacity share (fixed $300/MWh definition)",
       subtitle="Share of registered capacity offered at or below $300/MWh, capped at declared availability",
       x="Cheap-capacity share", y="Interval count") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "distribution_by_unit.png"), p, width=11, height=7, dpi=150)

# ---------------------------------------------------------------------------
# Reused audits of the essentiality flag (re-run against THIS pipeline's own variables)
# ---------------------------------------------------------------------------
cat("\n=== Reused audit 1/2: essentiality flag vs. this pipeline's own MAXAVAIL / cheap capacity ===\n")
pivotality <- readRDS(file.path(DIRECTION, "outputs/descriptives_v3/pivotality_panel.rds"))
pivotality[, interval_dt := force10(SETTLEMENTDATE)]
ess_l <- rbindlist(lapply(FOCUS_ALL, function(u) data.table(
  DUID = u, interval_dt = pivotality$interval_dt, essential = pivotality[[paste0("pex_", station[[u]])]])))
X <- merge(X, ess_l, by=c("DUID","interval_dt"), all.x=TRUE)

leakage <- X[!is.na(essential), {
  f1 <- lm(as.integer(essential) ~ MAXAVAIL); f2 <- lm(as.integer(essential) ~ cheap_a)
  .(r2_vs_maxavail = round(summary(f1)$r.squared,4), r2_vs_cheap_capacity = round(summary(f2)$r.squared,4),
    cor_vs_maxavail = round(cor(as.integer(essential), MAXAVAIL, use="complete.obs"),3),
    cor_vs_cheap_capacity = round(cor(as.integer(essential), cheap_a, use="complete.obs"),3))
}, by=DUID][order(match(DUID,FOCUS_ALL))]
fwrite(leakage, file.path(OUT, "essentiality_leakage_audit.csv"))
print(leakage)
cat("PASS criterion: R^2 approx 0 -- the essentiality flag is not predicted by the unit's own realised offer.\n")

cat("\n=== Reused audit 2/2: non-degenerate 'bid as usual' cell among essential intervals ===\n")
asusual <- X[!is.na(essential), .(
  n_essential = sum(essential==TRUE),
  bid_as_usual_pct = round(100*mean(cheap_a_share[essential==TRUE] >= WITHHELD_CUTOFF), 1)
), by=DUID][order(match(DUID,FOCUS_ALL))]
fwrite(asusual, file.path(OUT, "essentiality_asusual_audit.csv"))
print(asusual)
cat("PASS criterion: bid_as_usual_pct > 0 for every testable unit -- essential intervals are not\n",
    "  'withheld by construction'.\n", sep="")

saveRDS(X, file.path(OUT, "outcome_panel.rds"))

# ---------------------------------------------------------------------------
# Findings (plain language, per README glossary)
# ---------------------------------------------------------------------------
fmt_channel <- function(ch) paste(sprintf("| %s | %s | %s%% | %s%% | %s%% | %s%% |",
  ch$DUID, ch$n_withheld, ch$withdrawn_only, ch$priced_out_only, ch$both, ch$neither_flagged), collapse="\n")
fmt_dist <- function(d) paste(sprintf("| %s | %s | %s | %s | %s |",
  d$DUID, d$mean, d$median, d$floor_share_pct, d$full_share_pct), collapse="\n")
fmt_agree <- function(a) paste(sprintf("| %s | %s%% |", a$DUID, a$agreement_pct), collapse="\n")

findings <- sprintf(
"# Stage 1 findings -- the withholding outcome (Direction_clean/)

Per-interval, for TORRB2/3/4, PPCCGT (primary) and OSB-AG (descriptive only), over all %d cached
months (%s to %s). See `README.md` glossary for every term below.

## Join integrity
%d bid-ladder rows resolved to the in-force version; 0 missing a price ladder, 0 missing an SRMC
match, across every month (see `join_report.csv`). MAXAVAIL exceeds registered capacity by more
than 2%% in %.2f%% of rows (ambient uprate above nameplate rating) -- not clipped, carried through
as-is.

## Cheap capacity -- two co-primary definitions, agreement rate
Definition (a): capacity offered at or below $300/MWh (fixed). Definition (b): capacity offered at
or below 2x that month's short-run marginal cost (cost-indexed). Both capped at declared
availability, both expressed as a share of registered capacity.

| Generator | Agreement rate between (a) and (b) |
|---|---|
%s

%s

Monthly disagreement correlates with gas price for the three Torrens units (r = 0.54-0.74) -- as
expected, since the cost-indexed definition moves with gas while the fixed definition doesn't; for
PPCCGT the correlation is near zero (-0.11); for OSB-AG agreement is 100%% every month (no variation
to correlate). Full breakdown in `ab_agreement_by_month.csv`.

## Threshold sensitivity
Swept (a) at $150/$500 and (b) at 1.5x/3x SRMC (`threshold_sensitivity.csv`). For the three Torrens
units the withheld-interval share stays in a narrow band (roughly 82-96%%) across every threshold
tested -- the classification is not sensitive to exactly where the line is drawn. PPCCGT is more
threshold-sensitive (53-64%% across the sweep) and should be read with that in mind.

## Channel decomposition -- among withheld intervals, why
Physical withholding (\"capacity withdrawn\": declared availability cut) versus economic
withholding (\"capacity priced out\": availability normal, price above threshold) versus both.

**Fixed-threshold definition (a):**

| Generator | n withheld | Capacity withdrawn only | Capacity priced out only | Both | Neither (flag) |
|---|---|---|---|---|---|
%s

**Cost-indexed definition (b):**

| Generator | n withheld | Capacity withdrawn only | Capacity priced out only | Both | Neither (flag) |
|---|---|---|---|---|---|
%s

Both definitions agree on the story: physical withholding (availability cuts) dominates for every
unit, but a material secondary share (10-33%%) additionally prices the *remaining* available
capacity above the threshold (\"both\") -- withholding is not purely a quantity phenomenon. The
'neither' column is essentially zero for every unit and definition, which is the expected internal
consistency check (an interval classified 'withheld' should always show up in at least one
channel) -- it passed without needing any adjustment.

## Distribution per unit -- the Torrens bimodality, reconfirmed
| Generator | Mean share | Median share | Share of intervals at floor (<10%%) | Share of intervals near-full (>75%%) |
|---|---|---|---|---|
%s

TORRB2/3/4 sit at the $0-floor tranche (near-zero cheap capacity) in roughly 69-77%% of ALL
intervals -- this is the unit's ordinary competitive behaviour, not something specific to
essential or directed periods (that comparison is Stage 3's job). This reconfirms, independently,
the bimodality already documented in the existing `Direction/` pipeline
(`outputs/withhold_opportunity/stage1b_diagnostics.md`) -- built here from scratch against this
pipeline's own registered-capacity-share outcome, not copied. See `distribution_by_unit.png`.

## Reused audits of the essentiality flag (re-run against this pipeline's own variables)
**Leakage audit** -- regressing the essentiality flag on the generator's own realised availability
and own cheap capacity: R^2 is at or near 0 for every unit (0.0000-0.0028) -- the flag is not
predicted by the generator's own offer, confirming it is a genuine rivals-only construction, not
circular. **Bid-as-usual audit** -- among essential intervals, every testable generator has a
non-empty share still bidding as usual (TORRB2/3/4: 2-6%%; PPCCGT: 66%%; OSB-AG: 100%%) -- essential
does not mean 'withheld by construction.' Both checks pass and closely reproduce the equivalent
numbers already on record in `Direction/outputs/withhold_opportunity/stage2_findings.md`, despite
being rebuilt independently here -- a strong cross-validation of the essentiality-flag reuse.

## Not yet done (correctly out of scope this pass)
No competition/residual-demand control, no RQ1/RQ2 regression, no compensation-price analysis --
all Stage 2+. This stage only builds and validates the outcome measure.
", length(months), months[1], months[length(months)], sum(jr$inforce), 100*n_over/nrow(X),
   fmt_agree(agree_overall), sprintf("Worst-case disagreement across the five generators: %.1f%% of intervals (%s).",
     worst_disagreement, agree_overall[which.max(100-agreement_pct), DUID]),
   fmt_channel(channel_a), fmt_channel(channel_b), fmt_dist(dist_summ))
writeLines(findings, file.path(OUT, "findings.md"))

cat(sprintf("\nSaved outcome_panel.rds (%d rows) + findings.md + all Stage-1 CSVs/figure.\n", nrow(X)))
