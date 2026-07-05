#!/usr/bin/env Rscript
# task10_part1_gate.R -- Final exception task, Part 1: the gate for completing the
# floor-pricing (Component B) registration with N-1 cells. COUNTS ONLY, no test.
# (i) day-level B cell: clean days with the floor MW offered (Component B sample, no
#     imputation), essential_n1 vs ordinary, per unit; N-0 16-day cell reported alongside.
# (ii) essential HOURS with the floor offered (non-imputed p_floor), per unit, + the
#     distinct days they come from. Threshold as always: essential cell < ~30 days -> counts only.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")

UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
G  <- fread(file.path(OUT, "task7_label_census.csv")); G[, cal_day := as.Date(cal_day)]
B <- merge(UD[DUID %in% TEST_UNITS, .(DUID, cal_day, comp_A, comp_B)],
           G[, .(DUID, cal_day, ess_n1, ess_pex, clean)], by=c("DUID","cal_day"))
B <- B[clean==TRUE & comp_A==FALSE & !is.na(comp_B)]      # the Component B sample, clean days
cat("=== (i) Day-level B cell (clean days, floor MW offered all-but-<1h) ===\n")
g1 <- B[, .(B_days=.N, ess_n1_days=sum(ess_n1), ess_n0_days=sum(ess_pex), ordinary=sum(!ess_n1)), by=DUID]
print(g1)
cat(sprintf("POOLED: essential_n1 B-days = %d (N-0 benchmark was 16); ordinary B-days = %d\n",
            B[ess_n1==TRUE, .N], B[ess_n1==FALSE, .N]))
cat(sprintf("GATE (i): %s\n", if (B[ess_n1==TRUE, .N] >= 30) "PASSES (>=30)" else "counts only"))

# (ii) essential hours with the floor offered
PF <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))[DUID %in% TEST_UNITS]
PX <- readRDS(file.path(OUT, "task7_pex_n1_panel.rds"))
PF <- merge(PF, PX[, .(SETTLEMENTDATE, pex_n1_torrens_island_b, pex_n1_pelican_point_gt)],
            by.x="idt", by.y="SETTLEMENTDATE")
PF[, ess_iv := fifelse(DUID=="PPCCGT", pex_n1_pelican_point_gt, pex_n1_torrens_island_b)]
PF <- merge(PF, G[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"))
E2 <- PF[clean==TRUE & ess_iv==TRUE]
g2 <- E2[, .(essential_hours = round(.N/12,1), offered_hours = round(sum(!imputed)/12,1),
             offered_days = uniqueN(cal_day[!imputed])), by=DUID]
cat("\n=== (ii) Essential hours (clean days): total vs floor-offered, + distinct days ===\n")
print(g2)
for (u in TEST_UNITS) { r <- g2[DUID==u]
  if (nrow(r)) cat(sprintf("GATE (ii) [%s]: %d offered-days -> %s\n", u, r$offered_days,
                           if (r$offered_days >= 30) "PASSES" else "counts only")) }
fwrite(g1, file.path(OUT, "task10_gate_daylevel.csv")); fwrite(g2, file.path(OUT, "task10_gate_hours.csv"))
cat("\nGATE REPORT ONLY -- no test run; stopping for review per instruction.\n")
