#!/usr/bin/env Rscript
# stage1_requirement_state.R -- Stage 1 (current-state half) of the direction-propensity
# registration (08_propensity/registration.md).
#
# The current-state requirement layer already exists, verified, in the pivotality panel
# (Direction/04_market_power/pivotality.R):
#   depth_ex_torrens_island_b = min rival-unit removals from AVAILABLE rivals before a Torrens
#     unit is needed  (slack, availability margin; regression-tested depth_ex==0 <=> pex at build)
#   depth_rl_torrens_island_b = same from ONLINE (committed) rivals (slack, commitment margin)
#   piv_n1_torrens_island_b   = Torrens essential after loss of the single largest online unit
# This script aggregates those to the 30-min grain, runs the two committed validations
# (slack==0 vs pex confusion matrix; slack<=1 vs the N-1 flag), and writes the current-state
# panel. Forecast slack at 1h/4h/8h is stage1b_forecast_slack.R (needs PDPASA + RIVAL_BOP).
#
# Rivals-only conformity: depth_* for station j zeroes j's own units before the search
# (pivotality.R depth_station), so no focal input enters the slack. nonsync_mw is realized
# semi-scheduled TOTALCLEARED (system state, not focal conduct).
#
# 30-min aggregation rule (stated, fixed): slack = MIN over the six 5-min intervals;
# pex/N-1 = ANY. Conservative operator view; keeps slack==0 <=> pex exact under aggregation.
# Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")

cols <- c("SETTLEMENTDATE","nonsync_mw","short","short_n1",
          "pex_torrens_island_b","piv_n1_torrens_island_b",
          "depth_ex_torrens_island_b","depth_rl_torrens_island_b",
          "on_torrens_island_b","on_pelican_point_gt","on_osborne_gt_st","on_quarantine_5",
          "on_dry_creek","on_mintaro","on_bips","on_snapper_point")
P <- rbindlist(lapply(MONTHS, function(M) {
  p <- readRDS(file.path(ROOT, sprintf("Direction/bid_cache/pivotality_%s.rds", M))); setDT(p)
  stopifnot(all(cols %in% names(p)))
  p[, ..cols]
}))
P[, SETTLEMENTDATE := force10(SETTLEMENTDATE)]
cat(sprintf("pivotality 5-min rows: %d (%s - %s)\n", nrow(P),
            format(min(P$SETTLEMENTDATE)), format(max(P$SETTLEMENTDATE))))

# 5-min sanity: the build-time regression test guarantees this, re-assert on the loaded panel
stopifnot(P[, all((depth_ex_torrens_island_b == 0L) == pex_torrens_island_b)])

# ---- 30-min aggregation (interval-ending convention, matching AEMO trading intervals) ----
P[, t30 := as.POSIXct(ceiling(as.numeric(SETTLEMENTDATE) / 1800) * 1800,
                      origin = "1970-01-01", tz = "Etc/GMT-10")]
S <- P[, .(
  slack_avail  = min(depth_ex_torrens_island_b),
  slack_commit = min(depth_rl_torrens_island_b),
  pex30        = any(pex_torrens_island_b),
  n1_30        = any(piv_n1_torrens_island_b),
  short30      = any(short),
  nonsync_mw   = mean(nonsync_mw),
  on_rivals    = min(on_pelican_point_gt + on_osborne_gt_st + on_quarantine_5 +
                     on_dry_creek + on_mintaro + on_bips + on_snapper_point),
  on_torrens   = min(on_torrens_island_b),
  n5           = .N), by = t30]
setorder(S, t30)
cat(sprintf("30-min intervals: %d | half-hours with <6 five-min obs: %d\n",
            nrow(S), S[n5 < 6, .N]))

# ---- Registered validation 1: slack == 0 reproduces pex (30-min) ----
cm1 <- S[, table(slack0 = slack_avail == 0, pex = pex30)]
cat("\nConfusion matrix: (slack_avail==0) x pex30 [30-min grain]\n"); print(cm1)
agree1 <- S[, mean((slack_avail == 0) == pex30)]
cat(sprintf("agreement: %.4f (exact by construction + min/any aggregation)\n", agree1))

# ---- Registered validation 2: slack <= 1 vs the N-1 flag ----
# Conceptual difference, stated: piv_n1 removes the single LARGEST online unit (the credible
# contingency); slack_commit <= 1 allows the ADVERSARIAL single departure. Adversarial implies
# largest-unit, not conversely, so expect slack<=1 to weakly contain piv_n1.
cm2 <- S[, table(slack_le1 = slack_commit <= 1, n1 = n1_30)]
cat("\nConfusion matrix: (slack_commit<=1) x N-1 flag [30-min grain]\n"); print(cm2)
disagree_cells <- prop.table(cm2)
cat(sprintf("off-diagonal shares: slack<=1 & !n1 = %.3f | !slack<=1 & n1 = %.3f (investigate if > 0.05)\n",
            disagree_cells["TRUE","FALSE"], disagree_cells["FALSE","TRUE"]))

# ---- Requirement-state distribution (the Stage-1 deliverables (i)-(iii)) ----
cat("\nSlack (availability margin) distribution, 30-min:\n")
print(S[, .N, by = slack_avail][order(slack_avail)][, share := round(100 * N / sum(N), 2)][])
cat("\nSlack (commitment margin) distribution, 30-min:\n")
print(S[, .N, by = slack_commit][order(slack_commit)][, share := round(100 * N / sum(N), 2)][])
cat(sprintf("\nRivals alone meet the standard (slack_avail > 0): %.2f%% of half-hours\n",
            100 * S[, mean(slack_avail > 0)]))
cat(sprintf("Focal needed on availability (slack_avail == 0): %.2f%%  | on commitment (slack_commit == 0): %.2f%%\n",
            100 * S[, mean(slack_avail == 0)], 100 * S[, mean(slack_commit == 0)]))

saveRDS(S, file.path(OUT, "stage1_panel_current.rds"))
fwrite(as.data.table(cm1), file.path(OUT, "stage1_cm_pex.csv"))
fwrite(as.data.table(cm2), file.path(OUT, "stage1_cm_n1.csv"))
cat("\nSaved stage1_panel_current.rds + confusion matrices. Forecast half: stage1b.\n")
cat("DONE stage1 (current-state half)\n")
