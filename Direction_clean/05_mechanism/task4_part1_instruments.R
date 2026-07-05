#!/usr/bin/env Rscript
# task4_part1_instruments.R -- Bidding-behaviour instrumentation pass, Part 1: build the five
# instruments. Definitions FIXED HERE, before any event analysis (Part 2 validation gates Part 3).
# Test units TORRB2/3/4 + PPCCGT; corrected clock; day-ahead (midnight) stance for daily
# instruments; all bid versions for the rebid panel. OSB-AG excluded (descriptive-only unit,
# no clean-day classification).
#
# (a) LADDER SHAPE, per unit-day from the midnight version, per interval then day MEDIAN:
#     effective per-band quantities = increments of min(cumsum(BANDAVAIL), MAXAVAIL).
#     (i)   wmean_price  = MW-weighted mean offer price over the effective ladder
#     (ii)  q_2xsrmc     = MW offered at prices <= 2 x that unit-month's SRMC
#     (iii) q_shoulder   = MW offered at prices <= $1,000 (where cheap ends)
#     (iv)  top2_share   = effective MW in bands 9-10 / MAXAVAIL (intervals with MAXAVAIL>0)
#     (v)   steep_iqr    = price at 75th minus price at 25th percentile of offered MW
# (b) REBID PANEL, per unit-day: n rebids lodged that calendar day (BIDDAYOFFER ENTRYTYPE=REBID),
#     hour-of-day of lodgement, lever touched (MAXAVAIL >=1 MW mean future change / band
#     reallocation >=1 MW per-interval mean / both / none), availability-change size, and
#     explanation text categorised by regex, in precedence order: direction/RTS -> plant/
#     technical -> price/forecast/market -> other. COARSE text classification, flagged; 20
#     random examples per category exported for the reader.
# (c) ABSENCE TAXONOMY, per exit-posture day (established: comp_A or composite > $300):
#     full exit   = day max MAXAVAIL < 5 MW
#     partial     = not full, >=12 intervals with MAXAVAIL < floor
#     priced-out  = comp_A FALSE and composite > $300
#     Spell structure by type + within-spell type-transition matrix (UNCONDITIONAL here; the
#     direction-approach conditional is registered for Part 3, not peeked at in Part 1).
# (d) BID CHURN, per unit-day vs previous day, midnight stances aligned interval-by-interval:
#     changed = any band-MW or MAXAVAIL difference; magnitude = sum|d BANDAVAIL|/12 (MWh) +
#     sum|d MAXAVAIL|/12 (MWh), reported overall and within constant posture states.
# (e) Floor point (composite/A/B) carried as benchmark, already on file.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")

IV <- readRDS(file.path(OUT, "task2_interval_stance.rds"))
IV <- IV[DUID %in% TEST_UNITS]
RP <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
DC <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]

# ---------------------------------------------------------------------------
# (a) Ladder shape
# ---------------------------------------------------------------------------
cat("=== (a) Ladder shape ===\n")
IV <- merge(IV, RP[, .(DUID, cal_day, srmc)], by=c("DUID","cal_day"), all.x=TRUE)
bam <- as.matrix(IV[, ..ba_cols]); bam[is.na(bam)] <- 0
pbm <- as.matrix(IV[, ..pb_cols])
cum <- bam; for (j in 2:10) cum[,j] <- cum[,j-1] + bam[,j]
cum <- pmin(cum, IV$MAXAVAIL)
eff <- cum; eff[,2:10] <- cum[,2:10] - cum[,1:9]          # effective per-band MW
tot <- cum[,10]
wmean <- rowSums(eff * pbm, na.rm=TRUE) / pmax(tot, 1e-9)
q2s <- rowSums(eff * (pbm <= 2*IV$srmc), na.rm=TRUE)
qsh <- rowSums(eff * (pbm <= 1000), na.rm=TRUE)
top2 <- (eff[,9] + eff[,10]) / pmax(IV$MAXAVAIL, 1e-9)
p25v <- pbm[cbind(1:nrow(pbm), pmax(1L, 11L - rowSums(cum >= 0.25*tot)))]
p75v <- pbm[cbind(1:nrow(pbm), pmax(1L, 11L - rowSums(cum >= 0.75*tot)))]
IV[, tot_off := tot]
IV[, `:=`(wmean_price=wmean, q_2xsrmc=q2s, q_shoulder=qsh,
          top2_share=fifelse(MAXAVAIL>0, top2, NA_real_),
          steep_iqr=fifelse(tot>0, p75v - p25v, NA_real_))]
SH <- IV[, .(wmean_price=median(wmean_price[is.finite(wmean_price) & tot_off>0]),
             q_2xsrmc=median(q_2xsrmc), q_shoulder=median(q_shoulder),
             top2_share=median(top2_share, na.rm=TRUE), steep_iqr=median(steep_iqr, na.rm=TRUE),
             n_iv_offered=sum(MAXAVAIL>0)), by=.(DUID, cal_day)]
saveRDS(SH, file.path(OUT, "task4_ladder_shape.rds"))
shd <- SH[, .(n_days=.N,
              wmean_med=round(median(wmean_price, na.rm=TRUE)),
              q2s_med=round(median(q_2xsrmc),1), qsh_med=round(median(q_shoulder),1),
              top2_med=round(median(top2_share, na.rm=TRUE),2),
              steep_med=round(median(steep_iqr, na.rm=TRUE)),
              pct_alloffered_days=round(100*mean(n_iv_offered>=240),1)), by=DUID]
cat("Daily medians per unit:\n"); print(shd)
fwrite(shd, file.path(OUT, "task4_part1_shape_dist.csv"))

# ---------------------------------------------------------------------------
# (b) Rebid panel -- BDO counts/explanations + BOP lever pass (cached)
# ---------------------------------------------------------------------------
cat("\n=== (b) Rebid panel ===\n")
LCACHE <- file.path(OUT, "task4_rebid_levers.rds")
if (file.exists(LCACHE)) { LV <- readRDS(LCACHE); cat("Loaded lever cache\n") } else {
  lv <- vector("list", length(MONTHS))
  for (k in seq_along(MONTHS)) {
    M <- MONTHS[k]
    b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
    b <- b[DUID %in% TEST_UNITS & BIDTYPE=="ENERGY",
           c("DUID","OFFERDATETIME","MAXAVAIL","INTERVAL_DATETIME", ba_cols), with=FALSE]
    b[, `:=`(odt=force10(OFFERDATETIME), idt=force10(INTERVAL_DATETIME))]
    b[, td := dt10(idt - 1)]
    setorder(b, DUID, td, odt, idt)
    b[, vno := rleid(odt), by=.(DUID, td)]
    prev <- copy(b)[, vno := vno + 1L]
    setnames(prev, c("MAXAVAIL", ba_cols), c("p_ma", paste0("p_", ba_cols)))
    j <- merge(b[vno>1], prev[, c("DUID","td","vno","idt","p_ma", paste0("p_", ba_cols)), with=FALSE],
               by=c("DUID","td","vno","idt"))
    j <- j[idt > odt]                                     # future intervals only
    bm <- as.matrix(j[, ..ba_cols]); pm <- as.matrix(j[, paste0("p_", ba_cols), with=FALSE])
    bm[is.na(bm)] <- 0; pm[is.na(pm)] <- 0
    j[, `:=`(dma = abs(MAXAVAIL - p_ma), dband = rowSums(abs(bm - pm)))]
    lv[[k]] <- j[, .(mean_dma = mean(dma), mean_dband = mean(dband), n_fut=.N), by=.(DUID, td, odt)]
    rm(b, prev, j); gc(verbose=FALSE); cat(sprintf("  %s done\n", M))
  }
  LV <- rbindlist(lv); saveRDS(LV, LCACHE)
}
LV[, lever := fcase(mean_dma >= 1 & mean_dband >= 1, "both",
                    mean_dma >= 1, "MAXAVAIL",
                    mean_dband >= 1, "bands",
                    default = "none")]
BD <- rbindlist(lapply(MONTHS, function(M) {
  b <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(b)
  b[DUID %in% TEST_UNITS & BIDTYPE=="ENERGY" & ENTRYTYPE=="REBID",
    .(DUID, od=force10(OFFERDATE), td=as.Date(SETTLEMENTDATE)+1L, REBIDEXPLANATION, REBID_CATEGORY)]
}))
BD[, cat := fcase(grepl("direction|RTS|AEMO", REBIDEXPLANATION, ignore.case=TRUE), "direction/RTS",
                  grepl("plant|unit|technic|trip|fault|outage|temp|ambient|boiler|turbine|vibr|tube|leak", REBIDEXPLANATION, ignore.case=TRUE), "plant/technical",
                  grepl("price|forecast|demand|market|econ|wind|solar|interconn|constraint", REBIDEXPLANATION, ignore.case=TRUE), "price/forecast",
                  default = "other")]
BD[, `:=`(lodge_day = dt10(od), hh = as.integer(format(od, "%H")))]
RB <- BD[, .(n_rebids=.N), by=.(DUID, cal_day=lodge_day)]
base <- CJ(DUID=TEST_UNITS, cal_day=seq(as.Date("2022-01-01"), as.Date("2024-12-31"), by="day"))
RB <- merge(base, RB, by=c("DUID","cal_day"), all.x=TRUE)[is.na(n_rebids), n_rebids := 0L][]
LV[, lodge_day := dt10(odt)]
RBL <- LV[, .N, by=.(DUID, cal_day=lodge_day, lever)]
saveRDS(list(RB=RB, BD=BD, LV=LV), file.path(OUT, "task4_rebid_panel.rds"))
cat("Rebids per unit-day (distribution):\n")
print(RB[, .(mean=round(mean(n_rebids),2), median=as.numeric(median(n_rebids)), p90=as.numeric(quantile(n_rebids,.9)),
             pct_zero=round(100*mean(n_rebids==0),1), n_days=.N), by=DUID])
cat("Lodgement hour distribution (share by 6h block):\n")
print(dcast(BD[, .N, by=.(DUID, blk=cut(hh, c(-1,5,11,17,23), labels=c("00-06","06-12","12-18","18-24")))],
            DUID ~ blk, value.var="N"))
cat("Lever mix (all rebid versions):\n")
print(dcast(LV[, .N, by=.(DUID, lever)], DUID ~ lever, value.var="N", fill=0))
cat("Explanation categories:\n")
print(dcast(BD[, .N, by=.(DUID, cat)], DUID ~ cat, value.var="N", fill=0))
set.seed(1); ex <- BD[, .SD[sample(.N, min(20,.N))], by=cat][, .(cat, DUID, example=substr(REBIDEXPLANATION,1,100))]
fwrite(ex, file.path(OUT, "task4_part1_explanation_examples.csv"))

# ---------------------------------------------------------------------------
# (c) Absence taxonomy + within-spell transitions (unconditional only in Part 1)
# ---------------------------------------------------------------------------
cat("\n=== (c) Absence taxonomy ===\n")
dm <- IV[, .(day_max_ma = max(MAXAVAIL)), by=.(DUID, cal_day)]
TX <- merge(UD[DUID %in% TEST_UNITS, .(DUID, cal_day, comp_A, composite, floor_mw)], dm, by=c("DUID","cal_day"))
TX[, exit_day := comp_A==TRUE | (comp_A==FALSE & composite > 300)]
TX[, atype := fcase(exit_day & day_max_ma < 5, "full exit",
                    exit_day & comp_A==TRUE, "partial",
                    exit_day, "priced-out", default=NA_character_)]
cat("Absence type by unit (exit-posture days only):\n")
print(dcast(TX[exit_day==TRUE, .N, by=.(DUID, atype)], DUID ~ atype, value.var="N", fill=0))
setorder(TX, DUID, cal_day)
TX[, `:=`(atype_next = shift(atype,-1), day_next = shift(cal_day,-1)), by=DUID]
tm <- TX[exit_day==TRUE & !is.na(atype_next) & day_next==cal_day+1, .N, by=.(atype, atype_next)]
cat("Within-spell type-transition matrix (consecutive exit days, all units pooled; direction-approach conditional deferred to Part 3):\n")
print(dcast(tm, atype ~ atype_next, value.var="N", fill=0))
fwrite(TX[, .(DUID, cal_day, exit_day, atype)], file.path(OUT, "task4_absence_type.csv"))

# ---------------------------------------------------------------------------
# (d) Bid churn
# ---------------------------------------------------------------------------
cat("\n=== (d) Bid churn ===\n")
setorder(IV, DUID, cal_day, idt)
IV[, ivx := seq_len(.N), by=.(DUID, cal_day)]
today <- IV[, c("DUID","cal_day","ivx","MAXAVAIL", ba_cols), with=FALSE]
yday <- copy(today)[, cal_day := cal_day + 1L]
setnames(yday, c("MAXAVAIL", ba_cols), c("y_ma", paste0("y_", ba_cols)))
CH <- merge(today, yday, by=c("DUID","cal_day","ivx"))
b1 <- as.matrix(CH[, ..ba_cols]); b0 <- as.matrix(CH[, paste0("y_", ba_cols), with=FALSE])
b1[is.na(b1)] <- 0; b0[is.na(b0)] <- 0
CH[, `:=`(dband = rowSums(abs(b1-b0)), dma = abs(MAXAVAIL - y_ma))]
CHD <- CH[, .(churn_band_mwh = sum(dband)/12, churn_ma_mwh = sum(dma)/12, n_iv=.N), by=.(DUID, cal_day)]
CHD[, `:=`(changed = churn_band_mwh + churn_ma_mwh > 1, churn_total = churn_band_mwh + churn_ma_mwh)]
CHD <- merge(CHD, TX[, .(DUID, cal_day, exit_day, atype)], by=c("DUID","cal_day"), all.x=TRUE)
setorder(CHD, DUID, cal_day)
CHD[, exit_prev := shift(exit_day), by=DUID]
saveRDS(CHD, file.path(OUT, "task4_churn.rds"))
cat("Churn base rate + distribution per unit:\n")
print(CHD[, .(n_daypairs=.N, pct_changed=round(100*mean(changed),1),
              med_churn=round(median(churn_total),0), p90=round(quantile(churn_total,.9),0)), by=DUID])
cat("Churn WITHIN constant posture (both days exit posture -- the reshuffling the state analysis cannot see):\n")
print(CHD[exit_day==TRUE & exit_prev==TRUE,
          .(n=.N, pct_changed=round(100*mean(changed),1), med_churn=round(median(churn_total),0),
            p90=round(quantile(churn_total,.9),0)), by=DUID])
cat("\nSaved task4_{ladder_shape,rebid_panel,rebid_levers,churn}.rds, task4_absence_type.csv, task4_part1_*.csv\n")
