#!/usr/bin/env Rscript
# task3_part0_resolution.R -- Within-bid profile analysis, Part 0: resolution check.
# Question: does the absent posture live at the day grain (world a: bimodal ~0/~24 absent
# hours) or does it have intraday shape (world b: mass in the middle + recurring hour-of-day
# structure)? Clean days only (Job 2 classification), corrected clock, day-ahead stance.
# Absence here = availability below the unit's floor (withdrawal only, not priced-out).
# Test units only; OSB-AG has no clean-day classification (descriptive-only unit) -- stated.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
IVP <- readRDS(file.path(OUT, "task2_interval_pfloor.rds"))
DC  <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
IVP <- merge(IVP, DC[clean==TRUE, .(DUID, cal_day)], by=c("DUID","cal_day"))  # clean unit-days only
cat(sprintf("Clean unit-days: %d (test units)\n", uniqueN(IVP[, .(DUID, cal_day)])))

D <- IVP[, .(absent_h = sum(avail_below_floor)/12, n_iv=.N), by=.(DUID, cal_day)]
D <- D[n_iv >= 240]
bands <- function(x) cut(x, c(-Inf, 1, 6, 12, 18, 23, Inf), labels=c("<1h","1-6h","6-12h","12-18h","18-23h",">=23h"))
tab <- dcast(D[, .N, by=.(DUID, band=bands(absent_h))], DUID ~ band, value.var="N", fill=0)
tab2 <- D[, .(n_days=.N, median_h=round(median(absent_h),1), mean_h=round(mean(absent_h),1),
              pct_lt1=round(100*mean(absent_h<1),1), pct_ge23=round(100*mean(absent_h>=23),1),
              pct_middle=round(100*mean(absent_h>=1 & absent_h<23),1)), by=DUID]
cat("\n=== Absent hours per clean day: banded counts ===\n"); print(tab)
cat("\n=== Summary (the two-worlds verdict input) ===\n"); print(tab2)
fwrite(merge(tab, tab2, by="DUID"), file.path(OUT, "task3_part0_absent_hours.csv"))

# hour-of-day profile of absence on PARTIAL days (1h <= absent < 23h)
P <- merge(IVP, D[absent_h>=1 & absent_h<23, .(DUID, cal_day)], by=c("DUID","cal_day"))
P[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]
prof <- P[, .(absent_pct = round(100*mean(avail_below_floor),1)), by=.(DUID, hh)]
pw <- dcast(prof, hh ~ DUID, value.var="absent_pct")
cat("\n=== Hour-of-day absence rate on partial days (%), by unit ===\n"); print(pw, nrows=24)
fwrite(pw, file.path(OUT, "task3_part0_hourly_profile.csv"))

# concentration: share of a partial day's absence falling in the unit's 6 most-absent hours-of-day
top6 <- prof[order(DUID, -absent_pct), .(hh_top = hh[1:6]), by=DUID]
P[, is_top := paste(DUID, hh) %in% top6[, paste(DUID, hh_top)]]
conc <- P[avail_below_floor==TRUE, .(share_in_top6 = round(mean(is_top),3), n_absent_iv=.N), by=DUID]
cat("\n=== Concentration: share of partial-day absence in the unit's 6 most-absent clock hours ===\n")
print(conc)

# day-to-day recurrence: correlation of each partial day's hourly absence vector with the unit mean profile
Ph <- P[, .(a = mean(avail_below_floor)), by=.(DUID, cal_day, hh)]
Ph <- merge(Ph, prof[, .(DUID, hh, m = absent_pct/100)], by=c("DUID","hh"))
rec <- Ph[, .(r = suppressWarnings(cor(a, m))), by=.(DUID, cal_day)][, .(median_r = round(median(r, na.rm=TRUE),2),
        pct_r_gt_.5 = round(100*mean(r > .5, na.rm=TRUE),1), n_partial_days=uniqueN(cal_day)), by=DUID]
cat("\n=== Recurrence: correlation of each partial day's profile with the unit's mean profile ===\n")
print(rec)
fwrite(rec, file.path(OUT, "task3_part0_recurrence.csv"))
