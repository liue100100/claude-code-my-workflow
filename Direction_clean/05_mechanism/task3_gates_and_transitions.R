#!/usr/bin/env Rscript
# task3_gates_and_transitions.R -- Within-bid analysis Part 1 (the two gates, amended) and
# Part 4 (transition event study, split state definitions + Torrens partial-day table).
#
# Amendments in force: Gate 1 formal (Torrens recorded failed at 172 < 200; PPCCGT proceeds);
# Gate 2 reports pooled correlation PLUS the count/character of decoupled days (essential hours
# outside PPCCGT's 05:00-11:00 morning-ramp absence window), with infeasibility-with-reason
# pre-committed as a reportable finding. Part 4: Torrens state = daily exit posture (horizon-job
# definition); PPCCGT state = whole-day absence (>=23h below floor -- the intraday-pattern-
# adjusted state, since partial-absence mornings are its NORMAL duty cycle); stated deviation:
# transitions identified on ALL days (clean-pair restriction would censor direction-adjacent
# switches), contamination class carried as a descriptor column instead.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")

IVP <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))
DC  <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
AH_all <- IVP[DUID %in% TEST_UNITS, .(absent_h = sum(avail_below_floor)/12, n_iv=.N), by=.(DUID, cal_day)]
AH <- merge(AH_all, DC[, .(DUID, cal_day, contam, clean)], by=c("DUID","cal_day"), all.x=TRUE)

# ---------------------------------------------------------------------------
# PART 1, GATE 1 -- variation (formal): clean days with BOTH committed and absent hours
# ---------------------------------------------------------------------------
cat("================ PART 1, GATE 1: variation ================\n")
AH[, partial := absent_h >= 1 & absent_h <= 23]
g1 <- AH[clean==TRUE, .(clean_days=.N, partial_days=sum(partial)), by=.(DUID, yr=year(cal_day))][order(DUID, yr)]
print(g1)
g1p <- g1[, .(partial_days=sum(partial_days)), by=.(group=fifelse(DUID=="PPCCGT","PPCCGT","Torrens pooled"))]
print(g1p)
cat(sprintf("GATE 1: Torrens pooled %d < 200 -> FAILED (recorded). PPCCGT %d >= 200 -> PASSES.\n",
            g1p[group=="Torrens pooled", partial_days], g1p[group=="PPCCGT", partial_days]))
fwrite(g1, file.path(OUT, "task3_gate1_variation.csv"))

# ---------------------------------------------------------------------------
# PART 1, GATE 2 -- separability (amended), PPCCGT only
# ---------------------------------------------------------------------------
cat("\n================ PART 1, GATE 2: separability (PPCCGT) ================\n")
piv <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(piv)
piv[, idt := force10(SETTLEMENTDATE)]
piv[, `:=`(cal_day = dt10(idt - 1), hh = as.integer(format(idt - 1, "%H", tz="Etc/GMT-10")))]
pexh <- piv[, .(ess_iv = sum(pex_pelican_point_gt, na.rm=TRUE)), by=.(cal_day, hh)]
pexh[, ess_hour := ess_iv >= 6L]   # essential hour = >=30 min of the hour flagged (half-hour rule)
RP <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
# expected hourly price = previous day's realised hourly RRP profile (proxy; no forecast archive)
rp_iv <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds"))
rp_iv <- unique(rp_iv[, .(interval_dt, RRP)], by="interval_dt")
rp_iv[, `:=`(cal_day = dt10(interval_dt - 1), hh = as.integer(format(interval_dt - 1, "%H", tz="Etc/GMT-10")))]
hp <- rp_iv[, .(rrp_h = mean(RRP)), by=.(cal_day, hh)]
hp_prev <- copy(hp)[, cal_day := cal_day + 1L]; setnames(hp_prev, "rrp_h", "exp_price")
G2 <- merge(pexh, hp_prev, by=c("cal_day","hh"))
ppc_clean <- DC[DUID=="PPCCGT" & clean==TRUE, cal_day]
G2 <- G2[cal_day %in% ppc_clean]
ess_days <- G2[, .(n_ess_hours = sum(ess_hour)), by=cal_day][n_ess_hours > 0]
cat(sprintf("PPCCGT clean days: %d | clean days with >=1 essential hour: %d | essential hours total: %d\n",
            uniqueN(G2$cal_day), nrow(ess_days), G2[, sum(ess_hour)]))
cat(sprintf("Pooled hour-level correlation (essential hour, expected price), clean days: %.3f\n",
            G2[, cor(as.numeric(ess_hour), exp_price, use="complete.obs")]))
if (nrow(ess_days)) {
  cat(sprintf("Within-day correlation on essential-bearing days (median across days): %.3f\n",
      G2[cal_day %in% ess_days$cal_day, .(r = suppressWarnings(cor(as.numeric(ess_hour), exp_price))), by=cal_day][, median(r, na.rm=TRUE)]))
  hh_dist <- G2[ess_hour==TRUE, .N, by=hh][order(hh)]
  cat("Hour-of-day distribution of PPCCGT essential hours (clean days):\n"); print(hh_dist)
  dec <- G2[ess_hour==TRUE & !hh %in% 5:11]
  dec_days <- dec[, .(dec_hours=.N, hours=paste(sort(unique(hh)), collapse=",")), by=cal_day]
  cat(sprintf("DECOUPLED: essential hours OUTSIDE the 05:00-11:00 morning-ramp window: %d hours on %d days (of %d essential-bearing clean days)\n",
              nrow(dec), nrow(dec_days), nrow(ess_days)))
  if (nrow(dec_days)) print(dec_days)
  fwrite(G2[cal_day %in% ess_days$cal_day], file.path(OUT, "task3_gate2_essential_hours.csv"))
} else cat("No essential-bearing clean days at all for PPCCGT.\n")

# ---------------------------------------------------------------------------
# PART 4 -- transition event study (descriptive; split state definitions)
# ---------------------------------------------------------------------------
cat("\n================ PART 4: transition event study ================\n")
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
ST <- merge(AH_all, UD[, .(DUID, cal_day, comp_A, composite)], by=c("DUID","cal_day"))
ST[, state := fifelse(DUID=="PPCCGT", absent_h >= 23,                      # pattern-adjusted: whole-day absence
                      comp_A==TRUE | (comp_A==FALSE & composite > 300))]   # Torrens: horizon-job exit posture
setorder(ST, DUID, cal_day)
ST[, `:=`(state_prev = shift(state), day_prev = shift(cal_day)), by=DUID]
TR <- ST[!is.na(state_prev) & day_prev == cal_day - 1 & state != state_prev]
TR[, dir := fifelse(state, "ENTER absent state", "EXIT absent state")]
cat("Transitions per unit x direction:\n"); print(dcast(TR[, .N, by=.(DUID, dir)], DUID ~ dir, value.var="N"))

# descriptors: surrounding week
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% TEST_UNITS]; ep[, `:=`(s=force10(s), c=force10(c))]
srmc <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))
srmc <- srmc[duid %in% c("TORRB2","PPCCGT"), .(duid_g = fifelse(duid=="PPCCGT","PPCCGT","TORR"), yyyymm=as.integer(yyyymm), gas_gj)]
srmc <- unique(srmc, by=c("duid_g","yyyymm"))
RPd <- RP[, .(DUID, cal_day, exp_loss, essential_day, contam = NA_character_)]
RPd <- merge(RPd[, !"contam"], DC[, .(DUID, cal_day, contam)], by=c("DUID","cal_day"), all.x=TRUE)
TR[, yyyymm := as.integer(format(cal_day, "%Y%m"))]
TR[, duid_g := fifelse(DUID=="PPCCGT","PPCCGT","TORR")]
TR <- merge(TR, srmc, by=c("duid_g","yyyymm"), all.x=TRUE)
desc <- rbindlist(lapply(seq_len(nrow(TR)), function(j) {
  t0 <- TR[j]
  wk <- RPd[DUID==t0$DUID & cal_day >= t0$cal_day-3 & cal_day <= t0$cal_day+3]
  dir7 <- ep[duid==t0$DUID & s < force10(as.POSIXct(paste(t0$cal_day,"00:00:00"), tz="Etc/GMT-10")) &
             s >= force10(as.POSIXct(paste(t0$cal_day-7,"00:00:00"), tz="Etc/GMT-10")), .N]
  data.table(DUID=t0$DUID, cal_day=t0$cal_day, dir=t0$dir, gas_gj=t0$gas_gj,
             exp_loss_wk = round(wk[, mean(exp_loss, na.rm=TRUE)],1),
             essential_pm3 = wk[, sum(essential_day, na.rm=TRUE)],
             directions_prior7d = dir7,
             contam_day = RPd[DUID==t0$DUID & cal_day==t0$cal_day, contam])
}))
# spell lengths + likely-maintenance proxy for ENTER transitions (spell >= 14 whole-absent days)
runs <- ST[!is.na(state), {r <- rle(state); .(len=r$lengths, val=r$values, endpos=cumsum(r$lengths))}, by=DUID]
desc2 <- desc[, .(n=.N, gas_med=round(median(gas_gj, na.rm=TRUE),1),
                  exp_loss_med=round(median(exp_loss_wk, na.rm=TRUE),1),
                  pct_exp_loss_pos=round(100*mean(exp_loss_wk>0, na.rm=TRUE),1),
                  pct_dir_prior7d=round(100*mean(directions_prior7d>0),1),
                  pct_essential_pm3=round(100*mean(essential_pm3>0),1),
                  pct_clean_day=round(100*mean(contam_day=="clean", na.rm=TRUE),1)), by=.(DUID, dir)]
cat("\nTransition descriptor table (medians/shares over transitions):\n"); print(desc2)
fwrite(desc, file.path(OUT, "task3_part4_transitions.csv"))
fwrite(desc2, file.path(OUT, "task3_part4_transition_summary.csv"))
# absent-spell length by unit (state runs, val==TRUE)
cat("\nAbsent-state spell lengths (days) by unit:\n")
print(runs[val==TRUE, .(n_spells=.N, med=as.numeric(median(len)), p75=as.numeric(quantile(len,.75)),
                        p90=as.numeric(quantile(len,.9)), max=as.numeric(max(len)),
                        spells_ge14d=sum(len>=14)), by=DUID])

# base-rate context for the directions-prior-7d descriptor (denominator for the transition shares)
base7 <- rbindlist(lapply(TEST_UNITS, function(u) {
  days <- ST[DUID==u, cal_day]
  hits <- sapply(days, function(d) ep[duid==u & s < force10(as.POSIXct(paste(d,"00:00:00"), tz="Etc/GMT-10")) &
                                      s >= force10(as.POSIXct(paste(d-7,"00:00:00"), tz="Etc/GMT-10")), .N] > 0)
  data.table(DUID=u, pct_dir_prior7d_ALL_days = round(100*mean(hits),1))
}))
cat("\nBase rate: share of ALL unit-days with a direction in the prior 7 days (context for the transition shares):\n")
print(base7)
fwrite(base7, file.path(OUT, "task3_part4_base7.csv"))

# Torrens partial-day table (amendment): are partial days transition-adjacent?
cat("\n=== Torrens partial-day table (172 clean partial days) ===\n")
TP <- AH[DUID!="PPCCGT" & clean==TRUE & partial==TRUE]
tr_days <- TR[, .(DUID, tday=cal_day)]
TP[, adj_transition := mapply(function(u,d) tr_days[DUID==u & abs(as.numeric(tday-d)) <= 1, .N] > 0, DUID, cal_day)]
tp_tbl <- TP[, .(partial_days=.N, median_absent_h=round(median(absent_h),1),
                 pct_adjacent_to_transition=round(100*mean(adj_transition),1)), by=.(DUID, yr=year(cal_day))][order(DUID, yr)]
print(tp_tbl)
cat(sprintf("Pooled: %d partial days; %.1f%% within +-1 day of a state transition (ramp days)\n",
            nrow(TP), 100*TP[, mean(adj_transition)]))
fwrite(tp_tbl, file.path(OUT, "task3_part4_torrens_partial.csv"))
cat("\nSaved task3_{gate1_variation,gate2_essential_hours,part4_transitions,part4_transition_summary,part4_torrens_partial}.csv\n")
