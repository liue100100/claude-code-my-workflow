#!/usr/bin/env Rscript
# task11_supply_curve_history.R -- descriptive examination of the generators' supply curves:
# how the effective ladder changes across the sample period, across hours of the day, when it
# changes, and what the changes co-move with. NO tests; the adjudication boundary applies.
#
# Supply-curve summaries per interval (effective ladder = band quantities cumulated, capped at
# MAXAVAIL): MW offered <= $0, <= $300, <= $1,000, total availability, share in top-2 bands.
# Overlays: monthly d_t (compensation price), gas price, direction-episode counts (corrected
# clock), essential days (N-0 and N-1 labels).

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TEST_UNITS]
bam <- as.matrix(IV[, ..ba_cols]); bam[is.na(bam)] <- 0
pbm <- as.matrix(IV[, ..pb_cols])
cum <- bam; for (j in 2:10) cum[,j] <- cum[,j-1] + bam[,j]
cum <- pmin(cum, IV$MAXAVAIL)
eff <- cum; eff[,2:10] <- cum[,2:10] - cum[,1:9]
IV[, `:=`(mw_le0 = rowSums(eff*(pbm <= 0), na.rm=TRUE), mw_le300 = rowSums(eff*(pbm <= 300), na.rm=TRUE),
          mw_le1000 = rowSums(eff*(pbm <= 1000), na.rm=TRUE),
          mw_top2 = eff[,9] + eff[,10],
          hh = as.integer(format(idt - 1, "%H", tz="Etc/GMT-10")),
          yyyymm = as.integer(format(cal_day, "%Y%m")), yr = year(cal_day))]

# ---------------------------------------------------------------------------
# (a) The monthly history of the curve
# ---------------------------------------------------------------------------
MO <- IV[, .(mw_le0 = mean(mw_le0), mw_le300 = mean(mw_le300), mw_le1000 = mean(mw_le1000),
             avail = mean(MAXAVAIL), top2 = mean(mw_top2),
             pct_iv_zero_cheap = round(100*mean(mw_le300 < 5),1),
             pct_iv_full_cheap = round(100*mean(mw_le300 >= 150),1)), by=.(DUID, yyyymm)]
g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- g0[, .(yyyymm = as.integer(yyyymm), d_t = round(dt_recon))]
srmc <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
srmc <- srmc[duid %in% c("TORRB2","PPCCGT"), .(DUIDg = fifelse(duid=="PPCCGT","PPCCGT","TORR"),
                                               yyyymm = as.integer(yyyymm), gas_gj, srmc = srmc_marginal)]
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% TEST_UNITS]; ep[, s := force10(s)]
dm <- ep[, .(n_dir = .N), by=.(DUID = duid, yyyymm = as.integer(format(s, "%Y%m")))]
G <- fread(file.path(OUT, "task7_label_census.csv")); G[, cal_day := as.Date(cal_day)]
em <- G[, .(ess_n0 = sum(ess_pex), ess_n1 = sum(ess_n1)), by=.(DUID, yyyymm = as.integer(format(cal_day,"%Y%m")))]
MO <- Reduce(function(a,b) merge(a,b,by=intersect(names(a),names(b)),all.x=TRUE),
             list(MO, cp, dm, em))
MO[is.na(n_dir), n_dir := 0L]
MO[, DUIDg := fifelse(DUID=="PPCCGT","PPCCGT","TORR")]
MO <- merge(MO, srmc, by=c("DUIDg","yyyymm"), all.x=TRUE)
fwrite(MO, file.path(OUT, "task11_monthly_curve.csv"))
cat("=== (a) Monthly curve history (TORRB2 shown; full table in task11_monthly_curve.csv) ===\n")
print(MO[DUID=="TORRB2", .(yyyymm, mw_le300=round(mw_le300), avail=round(avail), top2=round(top2),
                           pct_zero=pct_iv_zero_cheap, pct_full=pct_iv_full_cheap, d_t, gas=round(gas_gj,1), n_dir, ess_n1)],
      nrows=36)

# largest month-over-month shifts in the cheap tranche, per unit
setorder(MO, DUID, yyyymm)
MO[, d_cheap := mw_le300 - shift(mw_le300), by=DUID]
MO[, d_dt := d_t - shift(d_t), by=DUID]
cat("\nTop-5 month-over-month cheap-tranche shifts per unit (with coincident d_t and gas moves):\n")
print(MO[!is.na(d_cheap), .SD[order(-abs(d_cheap))][1:5,
        .(yyyymm, d_cheap=round(d_cheap,1), mw_le300=round(mw_le300,1), d_dt, gas=round(gas_gj,1), n_dir)], by=DUID])

# ---------------------------------------------------------------------------
# (b) The curve across hours of the day, by year
# ---------------------------------------------------------------------------
HH <- IV[, .(mw_le300 = round(mean(mw_le300),1), avail = round(mean(MAXAVAIL),1)), by=.(DUID, yr, hh)]
fwrite(HH, file.path(OUT, "task11_hourly_curve.csv"))
cat("\n=== (b) Hour-of-day cheap MW (<=$300), TORRB2 and PPCCGT by year ===\n")
print(dcast(HH[DUID=="TORRB2"], hh ~ yr, value.var="mw_le300"), nrows=24)
print(dcast(HH[DUID=="PPCCGT"], hh ~ yr, value.var="mw_le300"), nrows=24)

# ---------------------------------------------------------------------------
# (c) Period co-movement table: curve vs prize vs cost vs need (monthly, per unit group)
# ---------------------------------------------------------------------------
cat("\n=== (c) Monthly co-movements of the cheap tranche (levels and first differences) ===\n")
cm <- MO[!is.na(gas_gj), .(
  cor_cheap_dt = round(cor(mw_le300, d_t, use="complete.obs"),2),
  cor_cheap_gas = round(cor(mw_le300, gas_gj, use="complete.obs"),2),
  cor_cheap_ndir = round(cor(mw_le300, n_dir, use="complete.obs"),2),
  cor_dcheap_ddt = round(cor(d_cheap, d_dt, use="complete.obs"),2),
  cor_dt_gas = round(cor(d_t, gas_gj, use="complete.obs"),2)), by=DUID]
print(cm)
fwrite(cm, file.path(OUT, "task11_comovement.csv"))

# split-period posture summary: high-d_t era (2022-01..2023-06) vs post-drop (2023-07..2024-12)
cat("\n=== Period split: high-d_t era vs post-drop (the mechanical mid-2023 d_t fall) ===\n")
MO[, era := fifelse(yyyymm <= 202306, "high d_t (2022-01..2023-06)", "post-drop (2023-07..2024-12)")]
print(MO[, .(d_t_mean = round(mean(d_t)), gas_mean = round(mean(gas_gj, na.rm=TRUE),1),
             mw_le300 = round(mean(mw_le300),1), pct_zero = round(mean(pct_iv_zero_cheap),1),
             avail = round(mean(avail)), dir_per_mo = round(mean(n_dir),1),
             ess_n1_per_mo = round(mean(ess_n1, na.rm=TRUE),1)), by=.(DUID, era)][order(DUID, era)])

# within the post-drop era only (gas roughly flat): cheap tranche vs d_t
cat("\nWithin post-drop era only (gas ~flat -- the cleaner d_t window):\n")
print(MO[era != "high d_t (2022-01..2023-06)" & !is.na(gas_gj),
         .(cor_cheap_dt = round(cor(mw_le300, d_t, use='complete.obs'),2),
           cor_dcheap_ddt = round(cor(d_cheap, d_dt, use='complete.obs'),2),
           gas_sd = round(sd(gas_gj),2), dt_sd = round(sd(d_t),1)), by=DUID])
cat("\nDescriptive only -- no tests. Findings written after inspection.\n")
