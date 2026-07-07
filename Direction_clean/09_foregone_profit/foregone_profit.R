#!/usr/bin/env Rscript
# foregone_profit.R -- the foregone-profit / revealed-preference exhibit
# (09_foregone_profit/registration.md + dated addendum, committed first).
# BINDING ORDER: occupancy report written to disk BEFORE any absence rate or dollar figure.
# Run from Direction_clean/.

suppressMessages({ library(data.table) })
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/09_foregone_profit")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
TEST_UNITS <- c("TORRB2", "TORRB3", "TORRB4", "PPCCGT")
H_MED <- 11.8; H_P25 <- 7.0; GROSS_K <- 0.95

# ---------------------------------------------------------------------------
# 1. Unit-day table (clean days only)
# ---------------------------------------------------------------------------
P <- readRDS(file.path(ROOT, "Direction_clean/outputs/05_mechanism/task2_regression_panel.rds"))
setDT(P); P <- P[DUID %chin% TEST_UNITS]
DC <- fread(file.path(ROOT, "Direction_clean/outputs/05_mechanism/task2_job2_day_classes.csv"))
DC[, cal_day := as.Date(cal_day)]
P <- merge(P, DC[, .(DUID, cal_day, clean)], by = c("DUID", "cal_day"), all.x = TRUE)
X <- P[clean == TRUE & !is.na(rrp_prev_mean) & !is.na(srmc) & !is.na(comp_price)]
cat(sprintf("clean unit-days with inputs: %d (of %d panel unit-days)\n", nrow(X), nrow(P)))

# pessimistic SRMC: all-in (GateA)
sp <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
sp <- sp[duid %chin% TEST_UNITS, .(DUID = duid, yyyymm = as.integer(yyyymm), srmc_allin)]
X <- merge(X, sp, by = c("DUID", "yyyymm"), all.x = TRUE)
stopifnot(X[, sum(is.na(srmc_allin))] == 0)

# day propensity from the day-ahead conditions-only hazard
S2 <- readRDS(file.path(ROOT, "Direction_clean/outputs/08_propensity/stage2_panel.rds")); setDT(S2)
S2[, cal_day := as.Date(t30 - 1, tz = "Etc/GMT-10")]
PD <- S2[, .(pi_day = 1 - exp(sum(log(pmax(1 - hz_da, 1e-12)))),
             n1_day = any(n1_30)), by = cal_day]
X <- merge(X, PD, by = "cal_day", all.x = TRUE)
stopifnot(X[, sum(is.na(pi_day))] == 0)

# ---------------------------------------------------------------------------
# 2. Margins, option values, regions (base / pessimistic / fixed-boundary)
# ---------------------------------------------------------------------------
X[, `:=`(M_base = 24 * floor_mw * (rrp_prev_mean - srmc),
         M_pess = 24 * floor_mw * (rrp_prev_mean - srmc_allin),
         M_real = 24 * floor_mw * (rrp - srmc))]                 # FLAGGED-ENDOGENOUS comparison
X[, `:=`(V_base = pi_day * H_MED * floor_mw * (GROSS_K * comp_price - srmc),
         V_pess = pi_day * H_P25 * floor_mw * (GROSS_K * comp_price - srmc_allin))]
dt_med <- X[, median(comp_price)]
X[, V_fix := pi_day * H_MED * floor_mw * (GROSS_K * dt_med - srmc)]
reg <- function(M, V) fifelse(M <= 0, "A", fifelse(M < V, "B", "C"))
X[, `:=`(region_base = reg(M_base, V_base),
         region_pess = reg(M_pess, V_pess),
         region_fix  = reg(M_base, V_fix),
         region_real = reg(M_real, V_base))]

# ---------------------------------------------------------------------------
# 3. Absence from the day-ahead stance (addendum item 3) -- computed but NOT summarized yet
# ---------------------------------------------------------------------------
IV <- readRDS(file.path(ROOT, "Direction_clean/outputs/05_mechanism/task2_interval_stance.rds"))
setDT(IV); IV <- IV[DUID %chin% TEST_UNITS]
ba <- as.matrix(IV[, paste0("BANDAVAIL", 1:10), with = FALSE])
pb <- as.matrix(IV[, paste0("PRICEBAND", 1:10), with = FALSE])
IV[, cheap300 := pmin(rowSums(ba * (pb <= 300), na.rm = TRUE), MAXAVAIL)]
IV <- merge(IV[, .(DUID, cal_day, idt, cheap300)],
            unique(X[, .(DUID, cal_day, floor_mw)]), by = c("DUID", "cal_day"))
AB <- IV[, .(reach_share = mean(cheap300 >= floor_mw)), by = .(DUID, cal_day)]
AB[, `:=`(absent = reach_share == 0, absent50 = reach_share < 0.5)]
X <- merge(X, AB, by = c("DUID", "cal_day"), all.x = TRUE)
X <- X[!is.na(absent)]
cat(sprintf("clean unit-days with stance outcome: %d\n", nrow(X)))
saveRDS(X, file.path(OUT, "foregone_profit_panel.rds"))

# ---------------------------------------------------------------------------
# 4. OCCUPANCY REPORT -- written to disk before any rate or dollar figure
# ---------------------------------------------------------------------------
occ <- rbindlist(lapply(c(base = "region_base", pess = "region_pess", fix = "region_fix"),
  function(rc) X[, .N, by = .(DUID, region = get(rc))][, calib := rc]), idcol = "calibration")
occ_w <- dcast(occ, calibration + DUID ~ region, value.var = "N", fill = 0)
occ_pool <- occ[, .(N = sum(N)), by = .(calibration, region)]
lines <- c("# Regions occupancy — clean unit-day counts (written before any rate or dollar figure)",
  "", sprintf("Registration: `09_foregone_profit/registration.md` + addendum. Panel: %d clean unit-days,", nrow(X)),
  sprintf("four units, 2022–2024. d_t sample median (fixed-boundary row): $%.0f.", dt_med), "",
  "## Pooled counts", "", "| calibration | A | B | C |", "|---|---|---|---|")
for (cc in c("base", "pess", "fix")) {
  r <- occ_pool[calibration == cc]
  lines <- c(lines, sprintf("| %s | %d | %d | %d |", cc,
                            sum(r[region == "A", N]), sum(r[region == "B", N]), sum(r[region == "C", N])))
}
lines <- c(lines, "", "## By unit (base calibration)", "", "| unit | A | B | C |", "|---|---|---|---|")
for (u in TEST_UNITS) {
  r <- X[DUID == u, .N, by = region_base]
  g <- function(k) if (nrow(r[region_base == k])) r[region_base == k, N] else 0L
  lines <- c(lines, sprintf("| %s | %d | %d | %d |", u, g("A"), g("B"), g("C")))
}
nB <- X[region_base == "B", .N]
lines <- c(lines, "", sprintf("**Degeneracy gate: region B holds %d clean unit-days pooled under the base calibration (threshold 30) → %s.**",
                              nB, if (nB < 30) "GATE FIRES — descriptive only, reading (c)" else "gate passes — deliverables proceed"))
writeLines(lines, file.path(OUT, "regions_occupancy.md"))
fwrite(occ_w, file.path(OUT, "regions_occupancy.csv"))
cat(sprintf("\nOCCUPANCY WRITTEN. Pooled base: A=%d B=%d C=%d | gate: %s\n",
            X[region_base == "A", .N], nB, X[region_base == "C", .N],
            if (nB < 30) "FIRES" else "passes"))

if (nB < 30) { cat("=== GATE FIRED: stopping at descriptive counts, per the registration. ===\n"); quit(save = "no", status = 0) }

# ---------------------------------------------------------------------------
# 5. Deliverables (gate passed): absence rates -> dollars -> proximity -> robustness
# ---------------------------------------------------------------------------
cat("\n=== Absence rates P(absent) by region ===\n")
rate_tab <- rbindlist(lapply(c(base = "region_base", pess = "region_pess", fix = "region_fix"), function(rc)
  X[, .(n = .N, absent_rate = round(mean(absent), 3), absent50_rate = round(mean(absent50), 3)),
    by = .(region = get(rc))][order(region)][, calib := rc]), idcol = "calibration")
print(rate_tab)
per_unit <- X[, .(n = .N, absent_rate = round(mean(absent), 3)), by = .(DUID, region = region_base)][order(DUID, region)]
print(per_unit)
fwrite(rate_tab, file.path(OUT, "absence_rates.csv"))
fwrite(per_unit, file.path(OUT, "absence_rates_by_unit.csv"))

cat("\n=== Dollar figures: absent region-B days (base) ===\n")
BB <- X[region_base == "B" & absent == TRUE]
cat(sprintf("absent region-B days: %d | sum M_d (declined spot profit): $%.2fM | sum V_absent (option value): $%.2fM\n",
            nrow(BB), BB[, sum(M_base)] / 1e6, BB[, sum(V_base)] / 1e6))
BBp <- X[region_pess == "B" & absent == TRUE]
cat(sprintf("pessimistic: %d days | sum M: $%.2fM | sum V: $%.2fM\n",
            nrow(BBp), BBp[, sum(M_pess)] / 1e6, BBp[, sum(V_pess)] / 1e6))

cat("\n=== Direction-proximity cut within absent profitable (M>0) days ===\n")
AP <- X[M_base > 0 & absent == TRUE]
cat(sprintf("absent profitable days: %d\n", nrow(AP)))
print(AP[, .(n = .N, share_regionB = round(mean(region_base == "B"), 3)), by = .(n1_day)])
pi_cut <- X[region_base == "B", median(pi_day)]
print(AP[, .(n = .N, share_regionB = round(mean(region_base == "B"), 3)), by = .(pi_above = pi_day > pi_cut)])

cat("\n=== Robustness: realized-price M_d (FLAGGED ENDOGENOUS -- comparison only) ===\n")
print(X[, .N, by = region_real][order(region_real)])
print(X[, .(n = .N, absent_rate = round(mean(absent), 3)), by = region_real][order(region_real)])

cat("\nDONE foregone_profit\n")
