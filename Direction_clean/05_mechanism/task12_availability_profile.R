#!/usr/bin/env Rscript
# task12_availability_profile.R -- descriptive deep-dive on Torrens DECLARED availability
# (midnight day-ahead stances, corrected clock). How often withdrawn, when, and the portfolio
# structure across the three units (rotation?). No tests.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
TOR <- c("TORRB2","TORRB3","TORRB4")
IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TOR, .(DUID, cal_day, idt, MAXAVAIL)]
IV[, `:=`(hh = as.integer(format(idt - 1, "%H", tz="Etc/GMT-10")), yr = year(cal_day),
          mo = month(cal_day), dow = wday(cal_day))]

cat("=== 1. How often: interval-level declared availability (1.58M/3 intervals per unit) ===\n")
print(IV[, .(pct_zero = round(100*mean(MAXAVAIL == 0),1),
             pct_below_floor = round(100*mean(MAXAVAIL < 40),1),
             pct_40_150 = round(100*mean(MAXAVAIL >= 40 & MAXAVAIL < 150),1),
             pct_ge150 = round(100*mean(MAXAVAIL >= 150),1),
             mean_ma = round(mean(MAXAVAIL),1)), by=.(DUID)])
cat("\nBy year:\n")
print(dcast(IV[, .(pct_zero = round(100*mean(MAXAVAIL==0),1)), by=.(DUID, yr)], DUID ~ yr, value.var="pct_zero"))

cat("\n=== 2. Unit-day states ===\n")
D <- IV[, .(ma_max = max(MAXAVAIL), ma_mean = mean(MAXAVAIL),
            h_below = sum(MAXAVAIL < 40)/12), by=.(DUID, cal_day, yr, mo, dow)]
D[, state := fcase(ma_max == 0, "all-day zero",
                   ma_max < 40, "positive but sub-floor all day",
                   h_below >= 23, "sub-floor >=23h",
                   h_below >= 1, "partial (1-23h below floor)",
                   default = "at/above floor all day")]
print(dcast(D[, .N, by=.(DUID, state)], state ~ DUID, value.var="N"))

cat("\n=== 3. When: share of intervals with MAXAVAIL >= 40, by hour x year (TORRB2; others similar) ===\n")
hy <- IV[, .(pct_avail = round(100*mean(MAXAVAIL >= 40),1)), by=.(DUID, yr, hh)]
print(dcast(hy[DUID=="TORRB2"], hh ~ yr, value.var="pct_avail"), nrows=24)
fwrite(hy, file.path(OUT, "task12_hour_year.csv"))
cat("\nBy month-of-year (pooled units, % intervals available >= 40):\n")
print(dcast(IV[, .(pct = round(100*mean(MAXAVAIL >= 40),1)), by=.(yr, mo)], mo ~ yr, value.var="pct"), nrows=12)
cat("\nBy day-of-week (1=Sun): % of unit-days with ANY availability >= 40:\n")
print(D[, .(pct_day_avail = round(100*mean(ma_max >= 40),1)), by=dow][order(dow)])

cat("\n=== 4. Availability spells (consecutive days with day-max < 40 = unavailable) ===\n")
setorder(D, DUID, cal_day)
D[, unavail := ma_max < 40]
r <- D[, {x <- rle(unavail); .(len = x$lengths, val = x$values)}, by=DUID]
print(r[val==TRUE, .(n_spells=.N, med=as.numeric(median(len)), p75=as.numeric(quantile(len,.75)),
                     p90=as.numeric(quantile(len,.9)), max=as.numeric(max(len)),
                     total_days=sum(len)), by=DUID])
print(r[val==FALSE, .(n_avail_spells=.N, med=as.numeric(median(len)), max=as.numeric(max(len))), by=DUID])

cat("\n=== 5. The portfolio view: units available per station-day (rotation?) ===\n")
SD <- dcast(D[, .(DUID, cal_day, av = ma_max >= 40)], cal_day ~ DUID, value.var="av")
SD[, n_av := TORRB2 + TORRB3 + TORRB4]
cat("Days by number of Torrens units with any availability:\n")
print(SD[, .N, by=n_av][order(n_av)])
cat("\nWhich unit is the available one on 1-unit days:\n")
print(SD[n_av==1, .N, by=.(unit = fifelse(TORRB2, "TORRB2", fifelse(TORRB3, "TORRB3", "TORRB4")))])
cat("\nPairwise same-day availability agreement (phi-style raw match rates):\n")
print(SD[, .(m23 = round(mean(TORRB2==TORRB3),2), m24 = round(mean(TORRB2==TORRB4),2),
             m34 = round(mean(TORRB3==TORRB4),2))])
setorder(SD, cal_day)
SD[, cfg := paste0(as.integer(TORRB2), as.integer(TORRB3), as.integer(TORRB4))]
SD[, cfg_prev := shift(cfg)]
ch <- SD[!is.na(cfg_prev) & cfg != cfg_prev]
cat(sprintf("\nStation configuration (which units available) changes on %d of %d day-pairs (%.1f%%); configuration run length median %.0f days\n",
            nrow(ch), nrow(SD)-1, 100*nrow(ch)/(nrow(SD)-1),
            median(rle(SD$cfg)$lengths)))
cat("Most common configurations (TORRB2/3/4):\n")
print(SD[, .N, by=cfg][order(-N)][1:6])
fwrite(SD, file.path(OUT, "task12_station_config.csv"))
cat("\nYearly: units available per day, mean:\n")
print(SD[, .(mean_units = round(mean(n_av),2)), by=year(cal_day)])
