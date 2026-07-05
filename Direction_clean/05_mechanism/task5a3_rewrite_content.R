#!/usr/bin/env Rscript
# task5a3_rewrite_content.R -- what EXACTLY changes in the pre-event rewrites?
# Three cuts, pre-direction (D-3..D-1) + pre-essential-onset (D-1) vs quiet:
#  (1) band-level: which band indices / price levels exchange quantity;
#  (2) hour-level: signed MAXAVAIL change by hour of day;
#  (3) lodgement text: finer subcategories (ambient/temperature capability, RTS/direction,
#      price/dispatch response, outage/plant, tolling/fuel, other).

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)

# target day sets: reuse Part 3b groups + essential-onset D-1
DAYD <- fread(file.path(OUT, "task4_part3b_day_decomp.csv"))    # DUID, cal_day, grp (D-1/D-2/D-3/quiet)
DAYD[, cal_day := as.Date(cal_day)]
D <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
DC <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
EO <- D[essential_day==TRUE][order(DUID, cal_day)]
EO[, prev7 := sapply(seq_len(.N), function(i) D[DUID==EO$DUID[i] & cal_day >= EO$cal_day[i]-7 &
                                                cal_day < EO$cal_day[i], sum(essential_day, na.rm=TRUE)])]
EO <- EO[prev7==0]
eo1 <- merge(EO[, .(DUID, cal_day = cal_day-1)], DC[clean==TRUE, .(DUID, cal_day)], by=c("DUID","cal_day"))
TGT <- rbind(DAYD[, .(DUID, cal_day, grp)], eo1[, .(DUID, cal_day, grp="pre-essential-onset D-1")])
TGT <- unique(TGT, by=c("DUID","cal_day","grp"))
cat("Rewrite-day groups:\n"); print(TGT[, .N, by=grp][order(grp)])

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))[DUID %in% TEST_UNITS]
need <- unique(rbind(TGT[, .(DUID, cal_day)], TGT[, .(DUID, cal_day=cal_day-1)]))
IV <- merge(IV, need, by=c("DUID","cal_day"))
setorder(IV, DUID, cal_day, idt)
IV[, ivx := seq_len(.N), by=.(DUID, cal_day)]
yd <- copy(IV)[, cal_day := cal_day + 1L]
setnames(yd, c("MAXAVAIL", ba_cols), c("y_ma", paste0("y_", ba_cols)))
X <- merge(IV, yd[, c("DUID","cal_day","ivx","y_ma", paste0("y_",ba_cols)), with=FALSE],
           by=c("DUID","cal_day","ivx"))
X <- merge(X, TGT, by=c("DUID","cal_day"), allow.cartesian=TRUE)  # a day may sit in 2 groups
X[, hh := as.integer(format(idt - 1, "%H", tz="Etc/GMT-10"))]

# (1) band-level exchange
b1 <- as.matrix(X[, ..ba_cols]); b0 <- as.matrix(X[, paste0("y_",ba_cols), with=FALSE])
p1 <- as.matrix(X[, ..pb_cols]); b1[is.na(b1)] <- 0; b0[is.na(b0)] <- 0
dB <- b1 - b0
band_tbl <- rbindlist(lapply(1:10, function(k)
  X[, .(band=k, price_med = round(median(p1[.I, k], na.rm=TRUE)),
        gross_mwh = round(sum(abs(dB[.I, k]))/12), net_mwh = round(sum(dB[.I, k])/12)), by=grp]))
band_tbl <- band_tbl[, .(grp, band, price_med, gross_mwh, net_mwh)]
cat("\n=== (1) Which bands move: gross/net MWh by band (median band price shown), per group ===\n")
n_days_grp <- TGT[, .(nd = .N), by=grp]
band_tbl <- merge(band_tbl, n_days_grp, by="grp")
band_tbl[, `:=`(gross_per_day = round(gross_mwh/nd,1), net_per_day = round(net_mwh/nd,2))]
print(dcast(band_tbl, band + grp ~ ., value.var=c("price_med","gross_per_day","net_per_day"))[order(band, grp)], nrows=50)

# (2) hour-level signed MAXAVAIL change
hr_tbl <- X[, .(net_dma = sum(MAXAVAIL - y_ma)/12, gross_dma = sum(abs(MAXAVAIL - y_ma))/12), by=.(grp, hh)]
hr_tbl <- merge(hr_tbl, n_days_grp, by="grp")
hr_tbl[, `:=`(net_per_day = round(net_dma/nd,2), gross_per_day = round(gross_dma/nd,2))]
cat("\n=== (2) Availability change by hour of day (MWh per rewrite-day) ===\n")
print(dcast(hr_tbl, hh ~ grp, value.var="net_per_day"), nrows=24)
fwrite(band_tbl, file.path(OUT, "task5a3_band_exchange.csv"))
fwrite(hr_tbl, file.path(OUT, "task5a3_hourly_ma.csv"))

# (3) finer lodgement text categories (rebids AND daily bids lodged d-1 targeting day d)
RBP <- readRDS(file.path(OUT, "task4_rebid_panel.rds")); BD <- RBP$BD
BD[, `:=`(lodge_day = dt10(od))]
sub <- function(x) fcase(
  grepl("ambient|temp|forecast ambient|weather", x, ignore.case=TRUE), "ambient/capability",
  grepl("RTS|direction|MN ?#?[0-9]", x, ignore.case=TRUE), "RTS/direction",
  grepl("price|MPD|PD |dispatch|constraint", x, ignore.case=TRUE), "price/dispatch response",
  grepl("outage|plant|unit|trip|fault|boiler|turbine|run.?up|min load", x, ignore.case=TRUE), "outage/plant",
  grepl("toll|fuel|gas|MAP", x, ignore.case=TRUE), "tolling/fuel",
  default="other")
BD[, sub := sub(REBIDEXPLANATION)]
LK <- merge(TGT, BD[, .(DUID, cal_day=td, lodge_day, sub)], by=c("DUID","cal_day"))
LK <- LK[lodge_day == cal_day - 1]
cat("\n=== (3) What the lodgements say (rebids on d-1 targeting day d), share by subcategory ===\n")
lk <- LK[, .N, by=.(grp, sub)]
lk[, share := round(100*N/sum(N),1), by=grp]
print(dcast(lk, grp ~ sub, value.var="share", fill=0))
fwrite(lk, file.path(OUT, "task5a3_lodgement_subcats.csv"))
cat("\nSaved task5a3_{band_exchange,hourly_ma,lodgement_subcats}.csv\n")
