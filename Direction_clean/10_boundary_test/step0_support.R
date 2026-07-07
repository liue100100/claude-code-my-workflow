#!/usr/bin/env Rscript
# step0_support.R -- Step 0 of the boundary-test registration: where the days sit.
# NO OUTCOME DATA TOUCHED: the absence columns are dropped on load. Writes
# outputs/10_boundary_test/boundary_support.md + histogram CSV. Run from Direction_clean/.

suppressMessages(library(data.table))
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/10_boundary_test")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

X <- readRDS(file.path(ROOT, "Direction_clean/outputs/09_foregone_profit/foregone_profit_panel.rds"))
setDT(X)
X[, c("absent", "absent50", "reach_share") := NULL]        # outcome quarantined for Step 0
X[, `:=`(R_base = V_base - M_base, R_pess = V_pess - M_pess)]
X[, grp := fifelse(DUID == "PPCCGT", "PPCCGT", "TORRENS")]

lines <- c("# Boundary support — where the days sit (Step 0; outcome untouched)",
           "", sprintf("Panel: %d clean unit-days (regions-task constructions unchanged).", nrow(X)), "")
hist_all <- list()
for (g in c("TORRENS", "PPCCGT")) for (cal in c("base", "pess")) {
  r <- X[grp == g, get(paste0("R_", cal))] / 1000
  h <- data.table(bin_lo = floor(r / 10) * 10)[, .N, by = bin_lo][order(bin_lo)]
  h[, `:=`(grp = g, calib = cal)]
  hist_all[[paste(g, cal)]] <- h
  lines <- c(lines, sprintf("## %s, %s calibration", g, cal),
             sprintf("R range $%.0fk to $%.0fk | median $%.0fk | share R>0: %.1f%%",
                     min(r), max(r), median(r), 100 * mean(r > 0)),
             sprintf("days within ±$20k of zero: **%d** | within ±$30k: **%d** | within ±$50k: %d",
                     sum(abs(r) <= 20), sum(abs(r) <= 30), sum(abs(r) <= 50)), "")
}
fwrite(rbindlist(hist_all), file.path(OUT, "boundary_support_hist.csv"))

# gate + month clustering of near-boundary Torrens days (base, ±$30k)
nb <- X[grp == "TORRENS" & abs(R_base) <= 30000]
n30 <- nrow(nb)
mcl <- nb[, .N, by = yyyymm][order(-N)]
lines <- c(lines, "## Gate and clustering",
           sprintf("Pooled Torrens days within ±$30k (base): **%d** (gate threshold 60) → **%s**.",
                   n30, if (n30 < 60) "GATE FIRES — descriptive only" else "gate passes"),
           sprintf("Near-boundary months: %d distinct; top-3 hold %.0f%% (%s).",
                   nrow(mcl), 100 * sum(head(mcl$N, 3)) / max(n30, 1),
                   paste(head(mcl$yyyymm, 3), collapse = ", ")), "")
writeLines(lines, file.path(OUT, "boundary_support.md"))
fwrite(mcl, file.path(OUT, "boundary_support_months.csv"))
cat(readLines(file.path(OUT, "boundary_support.md")), sep = "\n")
cat("\nDONE step0\n")
