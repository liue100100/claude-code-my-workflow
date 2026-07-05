#!/usr/bin/env Rscript
# stage2_gate_report.R -- the explicit Stage-2 gate (decision point). Per the approved plan, this
# script does NOT proceed to any regression. It reports the correlation between the competition
# measure and the essentiality flag, per unit and pooled, and the competition measure's
# distribution inside vs. outside essential intervals -- the number that determines how much
# independent variation Stage 3's essentiality coefficient will have. If Torrens looks
# near-collinear, that is surfaced plainly, not smoothed past.
#
# Run from Direction_clean/, after build_residual_demand.R.

suppressMessages({ library(data.table); library(ggplot2) })
ROOT      <- "C:/Users/ericl/Documents/my-project"
DIRECTION <- file.path(ROOT, "Direction")
OUT       <- file.path(ROOT, "Direction_clean/outputs/02_competition_control")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

# station -> essentiality-flag column, and the DUIDs that read that station's competition measure
STATION_PEX <- c(torrens_island_b="pex_torrens_island_b",
                  pelican_point_gt="pex_pelican_point_gt",
                  osborne_gt_st="pex_osborne_gt_st")
STATION_DUIDS <- list(torrens_island_b=c("TORRB2","TORRB3","TORRB4"),
                       pelican_point_gt="PPCCGT", osborne_gt_st="OSB-AG")

P <- readRDS(file.path(OUT, "residual_demand_panel.rds"))
pivotality <- readRDS(file.path(DIRECTION, "outputs/descriptives_v3/pivotality_panel.rds"))
pivotality[, interval_dt := force10(SETTLEMENTDATE)]

ess_l <- rbindlist(lapply(names(STATION_PEX), function(s) data.table(
  grp = s, interval_dt = pivotality$interval_dt, essential = pivotality[[STATION_PEX[[s]]]])))
P <- merge(P, ess_l, by=c("grp","interval_dt"), all.x=TRUE)
n_no_ess <- P[, sum(is.na(essential))]

# ---- (1) correlation between the competition measure and essentiality, per station and pooled ----
# competition measure = slope_kernel (primary; direct-20 as a robustness cross-check), and its
# reciprocal-style markup_kernel_noimport as the more directly interpretable "how much power" scale.
# markup is undefined (Inf) wherever slope_kernel==0 (rivals saturated in the local window, ~7-10%
# of intervals). Worse: checked directly -- even where FINITE, markup explodes numerically wherever
# slope is close to (but not exactly) zero, up to |markup|~1e22; 37.5% of finite values exceed 100
# in magnitude, economically meaningless for a Lerner-index-style quantity. A Pearson correlation
# on the raw values is degenerate (dominated by a handful of astronomical outliers) -- confirmed
# this produced a suspicious exact corr=0.000 for every group before this fix. Trimmed to a
# generous, documented, economically-plausible band (|markup|<=10) rather than silently averaging
# over numerical artifacts; the exclusion rate itself is reported as a finding, not hidden.
MARKUP_TRIM <- 10
corr_one <- function(d) d[!is.na(essential) & !is.na(slope_kernel), .(
  n = .N,
  corr_slope_kernel_essential  = round(cor(slope_kernel,  as.integer(essential)), 3),
  corr_slope_direct20_essential = round(cor(slope_direct_20, as.integer(essential)), 3),
  corr_markup_kernel_essential = round(cor(markup_kernel_noimport[abs(markup_kernel_noimport) <= MARKUP_TRIM],
                                            as.integer(essential)[abs(markup_kernel_noimport) <= MARKUP_TRIM]), 3),
  n_markup_trimmed = sum(abs(markup_kernel_noimport) <= MARKUP_TRIM, na.rm=TRUE),
  markup_trim_exclusion_pct = round(100*(1 - mean(abs(markup_kernel_noimport) <= MARKUP_TRIM, na.rm=TRUE)), 1)
)]
per_station <- P[, corr_one(.SD), by=grp]
pooled <- cbind(grp="POOLED (all 3 stations)", corr_one(P))
corr_tbl <- rbind(per_station, pooled)
fwrite(corr_tbl, file.path(OUT, "essentiality_competition_correlation.csv"))
cat("\n=== Correlation: competition measure vs. essentiality flag ===\n"); print(corr_tbl)

# ---- (2) distribution of the competition measure inside vs. outside essential intervals ----
dist_tbl <- P[!is.na(essential) & !is.na(slope_kernel), .(
  n = .N,
  mean_slope_kernel = round(mean(slope_kernel), 2),
  median_slope_kernel = round(median(slope_kernel), 2),
  p10_slope_kernel = round(quantile(slope_kernel, .10), 2),
  p90_slope_kernel = round(quantile(slope_kernel, .90), 2)
), by=.(grp, essential)][order(grp, -essential)]
fwrite(dist_tbl, file.path(OUT, "distribution_by_essentiality.csv"))
cat("\n=== Competition-measure (slope_kernel) distribution, essential vs. non-essential ===\n"); print(dist_tbl)

Pp <- P[!is.na(essential) & !is.na(slope_kernel) & grp %in% names(STATION_PEX)]
Pp[, grp_f := factor(grp, levels=names(STATION_PEX),
                      labels=c("Torrens Island B","Pelican Point","Osborne"))]
Pp[, essential_f := factor(essential, levels=c(FALSE,TRUE), labels=c("Non-essential","Essential"))]
# SIGN CONVENTION (corrected 2026-07-04 -- the first cut of this figure had it inverted): the
# slope is d(residual demand)/d(price) in MW per $/MWh, always <= 0. MORE NEGATIVE = rivals add
# lots of supply for a small price rise = the focal generator faces MORE competition. NEAR ZERO =
# rivals saturated within the local window = the focal generator faces the LEAST competition
# (consistent with the implied markup diverging exactly there).
p <- ggplot(Pp, aes(slope_kernel, fill=essential_f)) +
  geom_density(alpha=0.5) +
  facet_wrap(~grp_f, ncol=1, scales="free_y") +
  coord_cartesian(xlim = quantile(Pp$slope_kernel, c(.01,.99))) +
  labs(title="Stage 2 gate: competition measure inside vs. outside essential intervals",
       subtitle="Residual-demand slope near the realised spot price (MW per $/MWh). More negative = rivals more responsive = MORE competition; near zero = rivals saturated = most market power.",
       x="Competition measure (residual-demand slope, MW per $/MWh)", y="Density", fill="") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "distribution_by_essentiality.png"), p, width=9, height=9, dpi=150)

# ---- gate report (plain language) ----
torrens_corr <- corr_tbl[grp=="torrens_island_b", corr_slope_kernel_essential]
collinearity_flag <- abs(torrens_corr) > 0.7   # threshold documented, tunable
torrens_mean_ess <- dist_tbl[grp=="torrens_island_b" & essential==TRUE, mean_slope_kernel]
torrens_mean_non <- dist_tbl[grp=="torrens_island_b" & essential==FALSE, mean_slope_kernel]
zero_mass_note <- P[grp=="torrens_island_b" & !is.na(slope_kernel),
                     round(100*mean(slope_kernel==0),1)]

gate <- sprintf(
"# Stage 2 gate report -- competition measure vs. essentiality (STOP HERE for review)

This is the decision point the approved plan calls for before any regression is attempted. It
reports how much the competition measure and the essentiality flag move together -- their
collinearity determines how much INDEPENDENT variation is left for Stage 3 to attribute to
essentiality once the competition control enters.

## Correlation, per station and pooled (%d rows missing essentiality flag, excluded)
%s

## Distribution of the competition measure inside vs. outside essential intervals
See `distribution_by_essentiality.csv` and `.png`. %s

## Numerical caveat on the implied markup (found and fixed this session)
The implied-markup column (`markup_kernel_noimport = -residual_demand / (RRP * slope)`) explodes
numerically wherever the slope is close to (but not exactly) zero -- checked directly: values up to
~1e22 in magnitude, with **37.5%% of finite values exceeding |100|**, economically meaningless for a
Lerner-index-style quantity. A raw correlation against essentiality on the untrimmed markup column
produced a suspicious exact 0.000 for every station -- degenerate, not a real null, because a
handful of astronomical outliers dominate the Pearson calculation. Trimmed to |markup|<=10 (a
generous, documented band) before computing `corr_markup_kernel_essential` above;
`markup_trim_exclusion_pct` reports how much was excluded, per station, rather than hiding it.
**This is a first-order methodological flag for Stage 5's markup-benchmark appendix**, which will
need the same trim (or a better-behaved functional form) before reporting any markup summary.

## Reading
%s

## What happens next
This script does not proceed to Stage 3. Per the approved plan, Stage 3 (the RQ1 regression, run
with and without this competition control) needs its own plan and approval, informed by the
collinearity picture surfaced here.
", n_no_ess,
   paste(capture.output(print(corr_tbl)), collapse="\n"),
   sprintf("Sign convention (corrected -- an earlier draft of this report had it inverted): more NEGATIVE slope = rivals more price-responsive = MORE competition faced; near-zero slope = rivals saturated = LEAST competition. Torrens Island B: essential intervals have a mean slope of %.2f vs. %.2f non-essential. Pelican Point: %.2f vs. %.2f. Osborne: %.2f vs. %.2f.",
     dist_tbl[grp=="torrens_island_b" & essential==TRUE, mean_slope_kernel],
     dist_tbl[grp=="torrens_island_b" & essential==FALSE, mean_slope_kernel],
     dist_tbl[grp=="pelican_point_gt" & essential==TRUE, mean_slope_kernel],
     dist_tbl[grp=="pelican_point_gt" & essential==FALSE, mean_slope_kernel],
     dist_tbl[grp=="osborne_gt_st" & essential==TRUE, mean_slope_kernel],
     dist_tbl[grp=="osborne_gt_st" & essential==FALSE, mean_slope_kernel]),
   if (collinearity_flag)
     sprintf("**Torrens Island B's competition measure and essentiality flag correlate at %.2f (|r|>0.70) -- near-collinear.** This supports a specific, important reading: for the incumbent system-strength unit, being essential and facing weak competition are close to the SAME thing by construction of the grid. Stage 3's essentiality coefficient will have limited independent variation left once the competition control enters for Torrens -- that comparison (with vs. without the control) IS the headline result for this station, not a robustness footnote.", torrens_corr)
   else
     sprintf("**Not the collinearity risk the plan flagged -- and the direction of the difference is itself a finding.** Torrens Island B's linear correlation between the competition measure and essentiality is small (%.2f, pooled %.2f) -- nowhere near collinear, so Stage 3 has plenty of independent variation to work with. The conditional means differ in a direction that looks surprising until the two concepts are kept distinct: essential intervals average a slope of %.2f vs. %.2f non-essential -- i.e. essential periods show MORE-price-responsive rival supply near the clearing price (MORE energy-market competition), not less. That is economically coherent: essentiality is a system-SECURITY condition (high-renewables, low-demand periods when few synchronous units are online), not an energy-scarcity condition -- these are often cheap-energy periods with plenty of rival capacity near the (low) clearing price. Being needed for security and having energy-market power are different states, which is exactly why RQ1 needs the competition control to separate them, and why this gate found them uncorrelated. Also flagged: the competition measure has a large point mass at exactly zero (%.1f%% of Torrens intervals -- rivals saturated within the local $50 window = maximum local market power), which flattens the Pearson correlation and needs explicit handling in Stage 3 (a separate indicator), not treatment as ordinary continuous variation.",
             torrens_corr, corr_tbl[grp=="POOLED (all 3 stations)", corr_slope_kernel_essential],
             torrens_mean_ess, torrens_mean_non, zero_mass_note))
writeLines(gate, file.path(OUT, "stage2_gate_report.md"))
cat("\nSaved essentiality_competition_correlation.csv, distribution_by_essentiality.{csv,png}, stage2_gate_report.md.\n")
cat("\n=== STOP: Stage 2 gate complete. Awaiting review before any Stage 3 planning. ===\n")
