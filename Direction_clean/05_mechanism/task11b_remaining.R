#!/usr/bin/env Rscript
# task11b -- sections (b) and (c) of the supply-curve history (task11 crashed mid-print).
suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
MO <- fread(file.path(OUT, "task11_monthly_curve.csv"))
HH <- fread(file.path(OUT, "task11_hourly_curve.csv"))
cat("=== (b) Hour-of-day cheap MW (<=$300) by year ===\nTORRB2:\n")
w1 <- dcast(HH[DUID=="TORRB2"], hh ~ yr, value.var="mw_le300"); print(as.data.frame(w1))
cat("PPCCGT:\n"); w2 <- dcast(HH[DUID=="PPCCGT"], hh ~ yr, value.var="mw_le300"); print(as.data.frame(w2))
cat("\n=== (c) Monthly co-movements ===\n")
setorder(MO, DUID, yyyymm)
MO[, d_cheap := mw_le300 - shift(mw_le300), by=DUID]
MO[, d_dt := d_t - shift(d_t), by=DUID]
cm <- MO[!is.na(gas_gj) & !is.na(d_t), .(
  cor_cheap_dt = round(cor(mw_le300, d_t, use="complete.obs"),2),
  cor_cheap_gas = round(cor(mw_le300, gas_gj, use="complete.obs"),2),
  cor_cheap_ndir = round(cor(mw_le300, n_dir, use="complete.obs"),2),
  cor_dcheap_ddt = round(cor(d_cheap, d_dt, use="complete.obs"),2),
  cor_dt_gas = round(cor(d_t, gas_gj, use="complete.obs"),2)), by=DUID]
print(as.data.frame(cm)); fwrite(cm, file.path(OUT, "task11_comovement.csv"))
MO[, era := fifelse(yyyymm <= 202306, "A_high_dt_2201_2306", "B_postdrop_2307_2412")]
sp <- MO[, .(d_t_mean = round(mean(d_t, na.rm=TRUE)), gas_mean = round(mean(gas_gj, na.rm=TRUE),1),
             mw_le300 = round(mean(mw_le300),1), pct_zero = round(mean(pct_iv_zero_cheap),1),
             avail = round(mean(avail)), dir_per_mo = round(mean(n_dir),1),
             ess_n1_per_mo = round(mean(ess_n1, na.rm=TRUE),1)), by=.(DUID, era)][order(DUID, era)]
cat("\nPeriod split (high-d_t era vs post-drop):\n"); print(as.data.frame(sp))
fwrite(sp, file.path(OUT, "task11_era_split.csv"))
cat("\nPost-drop era only (gas ~flat):\n")
print(as.data.frame(MO[era=="B_postdrop_2307_2412" & !is.na(gas_gj) & !is.na(d_t),
      .(cor_cheap_dt = round(cor(mw_le300, d_t, use='complete.obs'),2),
        cor_dcheap_ddt = round(cor(d_cheap, d_dt, use='complete.obs'),2),
        gas_sd = round(sd(gas_gj),2), dt_sd = round(sd(d_t),1)), by=DUID]))
