#!/usr/bin/env Rscript
# task2_secondary.R -- Task 2 Steps 5-6: secondary outcomes + episode reclassification.
#
# EPISODE TIMES: now corrected AT SOURCE (Job 1 fixed excel_to_posix and re-parsed;
# episodes.rds is rebuilt on true times), so SHIFT = 0. The first run of this script applied a
# -10h in-memory correction to the then-broken episodes.rds; results must reproduce identically.
# A guard below asserts the source really is corrected (episode starts peak in the morning).
#
# Run from my-project root after task2_estimation.R.

suppressMessages({ library(data.table); library(fixest) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
SHIFT <- 0   # source fixed in Job 1; was 10*3600 when episodes.rds carried the +10h bug

ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% FOCUS]
ep[, `:=`(tau = force10(tau) - SHIFT, s = force10(s) - SHIFT, c = force10(c) - SHIFT)]
ep <- ep[!is.na(s) & !is.na(c) & c > s &
         s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
ep[, `:=`(yyyymm = as.integer(format(s, "%Y%m")), dur_h = as.numeric(difftime(c, s, units="hours")))]
hh_mode <- ep[, .N, by=.(hh=as.integer(format(s, "%H")))][which.max(N), hh]
stopifnot("episodes.rds still carries the +10h bug (start-hour mode not in the morning)" = hh_mode %in% 6:10)
cat(sprintf("Episodes (focal, in-window, source-corrected times; start-hour mode %02d:00): %d\n", hh_mode, nrow(ep)))

g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
cp <- rbind(g0[, .(yyyymm=as.integer(yyyymm), comp_price=dt_recon)], data.table(yyyymm=202206L, comp_price=241.38))
ep <- merge(ep, cp, by="yyyymm", all.x=TRUE)
ep[, comp_price_100 := comp_price/100]

# ---------------------------------------------------------------------------
# STEP 5a -- direction duration vs the compensation price (supporting only)
# ---------------------------------------------------------------------------
cat("\n=== Step 5a: episode duration vs comp price ===\n")
f_dur <- feols(dur_h ~ comp_price_100 | duid, ep[yyyymm != 202206L], vcov=~yyyymm)
print(summary(f_dur)$coeftable)
cat(sprintf("Median duration %.1f h; by comp-price tercile: %s\n", ep[, median(dur_h)],
            paste(ep[, .(med=round(median(dur_h),1)), by=cut(comp_price, quantile(comp_price, 0:3/3), include.lowest=TRUE, labels=c("low","mid","high"))][order(cut)]$med, collapse=" / ")))

# ---------------------------------------------------------------------------
# STEP 5b -- online-at-floor-when-directed share, by comp-price tercile (corrected windows)
# ---------------------------------------------------------------------------
cat("\n=== Step 5b: online-at-floor share when directed ===\n")
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
DL <- rbindlist(lapply(sort(unique(format(ep$s, "%Y%m"))), function(M) {
  f <- file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M)); if (!file.exists(f)) return(NULL)
  d <- readRDS(f); setDT(d)
  d <- d[DUID %in% FOCUS, .(DUID, SETTLEMENTDATE, INTERVENTION=as.numeric(INTERVENTION),
                            TOTALCLEARED=as.numeric(TOTALCLEARED))]
  d <- unique(d); d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1]
}))
DL[, idt := force10(SETTLEMENTDATE)]
fl <- unique(UD[, .(DUID, cal_day, floor_mw)])
setkey(ep, duid, s, c)
DL[, `:=`(w0=idt, w1=idt)]
ov <- foverlaps(DL[, .(duid=DUID, w0, w1, idt, TOTALCLEARED)], ep[, .(duid, s, c, episode_id, yyyymm, comp_price)],
                by.x=c("duid","w0","w1"), by.y=c("duid","s","c"), type="within", nomatch=NULL)
ov[, cal_day := dt10(idt-1)]
ov <- merge(ov, fl, by.x=c("duid","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)
ov[, at_floor := TOTALCLEARED > 1 & abs(TOTALCLEARED - floor_mw) <= 10]
s5b <- ov[, .(n_intervals=.N, online_pct=round(100*mean(TOTALCLEARED>1),1), at_floor_pct=round(100*mean(at_floor),1)),
          by=cut(comp_price, quantile(ep$comp_price, 0:3/3), include.lowest=TRUE, labels=c("low","mid","high"))][order(cut)]
setnames(s5b, "cut", "comp_price_tercile")
fwrite(s5b, file.path(OUT, "task2_step5_secondary.csv"))
print(s5b)

# ---------------------------------------------------------------------------
# STEP 6 -- episode reclassification on the issue-day composite (corrected windows)
# ---------------------------------------------------------------------------
cat("\n=== Step 6: episode reclassification under the composite outcome ===\n")
ep[, cal_day := dt10(s)]   # calendar day of (corrected) window start
E6 <- merge(ep, UD[, .(duid=DUID, cal_day, composite, comp_A, comp_B, mpc)], by=c("duid","cal_day"), all.x=TRUE)
n_na <- E6[is.na(composite), .N]
E6[, class6 := fcase(comp_A == TRUE, "withdrawn (Component A)",
                     comp_A == FALSE & composite > 300, "priced-out (floor MW > $300)",
                     comp_A == FALSE, "committed-cheap (<= $300)",
                     default = "no outcome day")]
cat(sprintf("Episodes classified: %d (no unit-day outcome for %d)\n", E6[!is.na(composite), .N], n_na))
cls <- E6[, .N, by=class6][order(-N)][, pct := round(100*N/sum(N),1)][]
fwrite(cls, file.path(OUT, "task2_step6_reclass.csv"))
print(cls)
exit_share <- E6[!is.na(composite), mean(class6 != "committed-cheap (<= $300)")]
cat(sprintf("Exit-then-directed share under the composite (withdrawn + priced-out): %.1f%% of %d episodes (Task 1c benchmark: 91%% of 69, measured on SHIFTED windows -- see findings_task1d)\n",
            100*exit_share, E6[!is.na(composite), .N]))
# lobe movement (271 comp-matched episodes; lobes themselves were built on shifted windows -- caveat)
X <- readRDS(file.path(OUT, "task1b_panel.rds"))
lb <- merge(E6[, .(episode_id, class6)], X[, .(episode_id, lobe)], by="episode_id")
cat("\nLobe x new class (NB lobes were defined on shifted windows; reported as the movement asked for, caveated):\n")
print(dcast(lb[, .N, by=.(lobe, class6)], lobe ~ class6, value.var="N", fill=0))
fwrite(lb[, .N, by=.(lobe, class6)], file.path(OUT, "task2_step6_lobes.csv"))
cat("\nSaved task2_step5_secondary.csv, task2_step6_{reclass,lobes}.csv\n")
