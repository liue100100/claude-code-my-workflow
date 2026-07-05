#!/usr/bin/env Rscript
# task2_build_outcome.R -- Task 2: build the price-of-the-marginal-committed-MW outcome.
# All definitions FIXED in 05_mechanism/task2_preregistration.md (committed 405ef65) BEFORE this
# script was run. Grain: unit x trading day, day-ahead stance (bid in force at 00:00), Task-1c
# trading-date fix applied (BOP keyed by its intervals' calendar day; BDO label +1).
#
# Outputs (outputs/05_mechanism/):
#   task2_interval_stance.rds   -- per (unit, day, 5-min interval): MAXAVAIL, bands, p_floor
#   task2_unit_day_panel.rds    -- per unit-day: composite (raw + within-unit rank), A, B,
#                                  config, floor, imputation counts, essential-day flag
#   task2_gate_*.csv            -- Step-1 frequency-gate tables
#   task2_lever_table.csv       -- lever decomposition of composite jumps
#
# Run from my-project root. The frequency-gate verdict prints at the end; estimation only
# proceeds if the gate passes (>=30 Component-A events among essential days, pooled test units).

suppressMessages({ library(data.table) })
ROOT  <- "C:/Users/ericl/Documents/my-project"
OUT   <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")   # OSB-AG descriptive only
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
STATION <- c(TORRB2="torrens_island_b", TORRB3="torrens_island_b", TORRB4="torrens_island_b",
             PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")
# MPC schedule per pre-registration (financial year ending): cross-checked vs observed max RRP below
MPC <- c(`2022`=15100, `2023`=15500, `2024`=16600, `2025`=17500)
fy_end <- function(d) year(d) + (month(d) >= 7L)

# ---------------------------------------------------------------------------
# 1. Day-ahead stance, per unit x day x interval (cached; one heavy pass)
# ---------------------------------------------------------------------------
IV_CACHE <- file.path(OUT, "task2_interval_stance.rds")
if (file.exists(IV_CACHE)) {
  cat("Loading cached interval stance table\n"); IV <- readRDS(IV_CACHE)
} else {
  iv_list <- vector("list", length(MONTHS))
  for (k in seq_along(MONTHS)) {
    M <- MONTHS[k]
    b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
    b <- b[DUID %in% FOCUS & BIDTYPE=="ENERGY",
           c("DUID","OFFERDATETIME","MAXAVAIL","INTERVAL_DATETIME", ba_cols), with=FALSE]
    b[, `:=`(odt = force10(OFFERDATETIME), idt = force10(INTERVAL_DATETIME))]
    b[, cal_day := dt10(idt - 1)]
    b[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
    b <- b[odt <= day_start]                                     # day-ahead versions only
    b <- b[b[, .I[odt == max(odt)], by=.(DUID, cal_day)]$V1]     # latest such version
    d <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(d)
    d <- d[DUID %in% FOCUS & BIDTYPE=="ENERGY",
           c("DUID","SETTLEMENTDATE","OFFERDATE", pb_cols), with=FALSE]
    d[, `:=`(od = force10(OFFERDATE), cal_day = as.Date(SETTLEMENTDATE) + 1L)]  # 1c label fix
    d[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
    d <- d[od <= day_start]
    d <- d[d[, .I[od == max(od)], by=.(DUID, cal_day)]$V1]
    d <- d[, c("DUID","cal_day", pb_cols), with=FALSE]
    b <- merge(b[, c("DUID","cal_day","idt","MAXAVAIL", ba_cols), with=FALSE], d,
               by=c("DUID","cal_day"), all.x=TRUE)
    iv_list[[k]] <- b
    cat(sprintf("  %s: %s stance rows\n", M, format(nrow(b), big.mark=",")))
    rm(b, d); gc(verbose=FALSE)
  }
  IV <- rbindlist(iv_list); rm(iv_list); gc(verbose=FALSE)
  saveRDS(IV, IV_CACHE)
}
cat(sprintf("Interval stance rows: %s (expect ~ 5 units x 1096 days x 288 = 1.58M)\n",
            format(nrow(IV), big.mark=",")))
n_noladder <- IV[is.na(PRICEBAND1), .N]
cat(sprintf("Rows without a daily ladder at day start: %d (%.3f%%)\n", n_noladder, 100*n_noladder/nrow(IV)))

# ---------------------------------------------------------------------------
# 2. Floors: TORRB fixed 40; PPCCGT by configuration; OSB-AG observed P5
# ---------------------------------------------------------------------------
# PPCCGT configuration per unit-day from day-ahead max MAXAVAIL (<=239 = one-turbine)
cfgd <- IV[DUID=="PPCCGT", .(max_ma = max(MAXAVAIL, na.rm=TRUE)), by=cal_day]
cfgd[, config := fifelse(max_ma == 0, NA_character_, fifelse(max_ma <= 239, "oneGT", "twoGT"))]
n_carry <- cfgd[is.na(config), .N]
setorder(cfgd, cal_day)
cfgd[, config := {v <- config; for (i in seq_along(v)) if (is.na(v[i]) && i>1) v[i] <- v[i-1]; v}]
cfgd[is.na(config), config := "twoGT"]   # leading NA fallback (counted below)
cat(sprintf("PPCCGT config days: %s | zero-availability days carried forward: %d\n",
            paste(capture.output(print(cfgd[, .N, by=config])), collapse=" "), n_carry))

DLPP <- rbindlist(lapply(MONTHS, function(M) {
  d <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(d)
  d <- d[DUID %in% c("PPCCGT","OSB-AG"), .(DUID, SETTLEMENTDATE, INTERVENTION=as.numeric(INTERVENTION),
                                           TOTALCLEARED=as.numeric(TOTALCLEARED))]
  d <- unique(d); d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1]
}))
DLPP[, cal_day := dt10(force10(SETTLEMENTDATE) - 1)]
DLPP <- merge(DLPP, cfgd[, .(cal_day, config)], by="cal_day", all.x=TRUE)
fl_pp <- DLPP[DUID=="PPCCGT" & TOTALCLEARED > 0, .(floor_mw = round(quantile(TOTALCLEARED, .05),0), n_pos=.N), by=config]
fl_osb <- DLPP[DUID=="OSB-AG" & TOTALCLEARED > 0, .(floor_mw = round(quantile(TOTALCLEARED, .05),0), n_pos=.N)]
cat("PPCCGT configuration floors (P5 of positive output, frozen here):\n"); print(fl_pp)
cat(sprintf("OSB-AG floor (P5 positive output): %.0f MW\n", fl_osb$floor_mw))
fwrite(rbind(fl_pp[, .(unit="PPCCGT", config, floor_mw, n_pos)],
             data.table(unit="OSB-AG", config="single", floor_mw=fl_osb$floor_mw, n_pos=fl_osb$n_pos),
             data.table(unit=c("TORRB2","TORRB3","TORRB4"), config="single", floor_mw=40, n_pos=NA)),
       file.path(OUT, "task2_floors.csv"))

IV <- merge(IV, cfgd[, .(cal_day, config_pp = config)], by="cal_day", all.x=TRUE)
IV[, floor_mw := fcase(DUID %chin% c("TORRB2","TORRB3","TORRB4"), 40,
                       DUID == "PPCCGT" & config_pp == "oneGT", as.numeric(fl_pp[config=="oneGT", floor_mw]),
                       DUID == "PPCCGT", as.numeric(fl_pp[config=="twoGT", floor_mw]),
                       DUID == "OSB-AG", as.numeric(fl_osb$floor_mw))]

# ---------------------------------------------------------------------------
# 3. p_floor per interval; MPC cross-check
# ---------------------------------------------------------------------------
rd <- readRDS(file.path(ROOT, "Direction_clean/outputs/02_competition_control/residual_demand_panel.rds"))
mpc_chk <- rd[grp=="torrens_island_b", .(max_rrp = max(RRP, na.rm=TRUE)), by=.(fy = fy_end(dt10(interval_dt)))]
cat("MPC cross-check (max observed SA1 RRP by FY vs schedule):\n")
print(merge(mpc_chk, data.table(fy=as.integer(names(MPC)), mpc_schedule=MPC), by="fy", all.x=TRUE))

n_na_ma <- IV[is.na(MAXAVAIL), .N]
if (n_na_ma) { cat(sprintf("NA MAXAVAIL rows set to 0 (treated as not offered): %d\n", n_na_ma)); IV[is.na(MAXAVAIL), MAXAVAIL := 0] }
bam <- as.matrix(IV[, ..ba_cols]); bam[is.na(bam)] <- 0
pbm <- as.matrix(IV[, ..pb_cols])
cum <- bam; for (j in 2:10) cum[,j] <- cum[,j-1] + bam[,j]
cum <- pmin(cum, IV$MAXAVAIL)                       # effective ladder: capped at MAXAVAIL
offered <- cum[,10]                                 # total effectively offered MW
band_ix <- 11L - rowSums(cum >= IV$floor_mw)        # first band where cumulative >= floor (11 = never)
p_from_band <- pbm[cbind(seq_len(nrow(pbm)), pmin(band_ix, 10L))]
IV[, mpc := MPC[as.character(fy_end(cal_day))]]
IV[, imputed := offered < floor_mw | band_ix == 11L | is.na(PRICEBAND1)]
IV[, p_floor := fifelse(imputed, mpc, p_from_band)]
IV[, avail_below_floor := MAXAVAIL < floor_mw]
n_edge <- IV[MAXAVAIL >= floor_mw & imputed==TRUE & !is.na(PRICEBAND1), .N]
cat(sprintf("Imputed intervals: %s (%.1f%%); edge case (MAXAVAIL >= floor but bands sum short): %d (%.4f%%)\n",
            format(IV[, sum(imputed)], big.mark=","), 100*IV[, mean(imputed)], n_edge, 100*n_edge/nrow(IV)))
saveRDS(IV[, .(DUID, cal_day, idt, MAXAVAIL, floor_mw, p_floor, imputed, avail_below_floor)],
        file.path(OUT, "task2_interval_pfloor.rds"))

# ---------------------------------------------------------------------------
# 4. Unit-day panel: composite (12th-highest p_floor), A, B, rank
# ---------------------------------------------------------------------------
nth_high <- function(x, n=12L) { x <- sort(x, decreasing=TRUE); if (length(x) >= n) x[n] else NA_real_ }
UD <- IV[, .(
  n_iv = .N,
  composite = nth_high(p_floor, 12L),
  comp_A = sum(avail_below_floor) >= 12L,
  comp_B = { nb <- p_floor[!imputed]; if (sum(avail_below_floor) < 12L && length(nb) >= 12L) nth_high(nb, 12L) else NA_real_ },
  n_imputed = sum(imputed), n_below_floor = sum(avail_below_floor),
  day_max_ma = max(MAXAVAIL), floor_mw = floor_mw[1], mpc = mpc[1]
), by=.(DUID, cal_day)]
n_short <- UD[n_iv < 240, .N]
cat(sprintf("Unit-days: %d | with <240 of 288 intervals (set NA, reported): %d\n", nrow(UD), n_short))
UD[n_iv < 240, `:=`(composite=NA_real_, comp_A=NA, comp_B=NA_real_)]
UD[, comp_rank := frank(composite, ties.method="average", na.last="keep")/sum(!is.na(composite)), by=DUID]

# essential-day flag (pex_<station>, >= 12 intervals)
piv <- readRDS(file.path(ROOT, "Direction/outputs/descriptives_v3/pivotality_panel.rds")); setDT(piv)
piv[, idt := force10(SETTLEMENTDATE)]
piv[, cal_day := dt10(idt - 1)]
pex_day <- rbindlist(lapply(names(STATION), function(u)
  piv[, .(DUID = u, ess_iv = sum(get(paste0("pex_", STATION[[u]])), na.rm=TRUE)), by=cal_day]))
UD <- merge(UD, pex_day, by=c("DUID","cal_day"), all.x=TRUE)
UD[, essential_day := !is.na(ess_iv) & ess_iv >= 12L]
saveRDS(UD, file.path(OUT, "task2_unit_day_panel.rds"))

# ---------------------------------------------------------------------------
# 5. Lever decomposition of composite jumps (per pre-registration)
# ---------------------------------------------------------------------------
setorder(IV, DUID, cal_day, idt)
setorder(UD, DUID, cal_day)
UD[, `:=`(comp_prev = shift(composite), A_prev = shift(comp_A), day_prev = shift(cal_day)), by=DUID]
UD[, jump := !is.na(comp_prev) & day_prev == cal_day - 1 &
             (abs(composite - comp_prev) > 100 | comp_A != A_prev)]
# counterfactual: today's quantities at yesterday's band prices
PB <- unique(IV[, c("DUID","cal_day", pb_cols), with=FALSE], by=c("DUID","cal_day"))
setorder(PB, DUID, cal_day)
PBprev <- copy(PB)[, cal_day := cal_day + 1L]
setnames(PBprev, pb_cols, paste0("prev_", pb_cols))
J <- UD[jump==TRUE, .(DUID, cal_day)]
IVJ <- merge(IV[J, on=c("DUID","cal_day")], PBprev, by=c("DUID","cal_day"), all.x=TRUE)
bamJ <- as.matrix(IVJ[, ..ba_cols]); bamJ[is.na(bamJ)] <- 0
ppmJ <- as.matrix(IVJ[, paste0("prev_", pb_cols), with=FALSE])
cumJ <- bamJ; for (j in 2:10) cumJ[,j] <- cumJ[,j-1] + bamJ[,j]
cumJ <- pmin(cumJ, IVJ$MAXAVAIL)
bixJ <- 11L - rowSums(cumJ >= IVJ$floor_mw)
IVJ[, p_floor_prevprice := fifelse(cumJ[,10] < floor_mw | bixJ==11L | is.na(prev_PRICEBAND1),
                                    mpc, ppmJ[cbind(seq_len(nrow(ppmJ)), pmin(bixJ,10L))])]
cf <- IVJ[, .(composite_qty_at_prev_prices = nth_high(p_floor_prevprice, 12L)), by=.(DUID, cal_day)]
UD <- merge(UD, cf, by=c("DUID","cal_day"), all.x=TRUE)
UD[, lever := fcase(
  jump==TRUE & comp_A==TRUE & A_prev==FALSE, "availability cut",
  jump==TRUE & abs(composite_qty_at_prev_prices - composite) <= 1, "quantity reallocation",
  jump==TRUE, "band-price change",
  default = NA_character_)]
lever_tbl <- UD[jump==TRUE, .N, by=.(DUID, direction = fifelse(composite > comp_prev, "up", "down"), lever)][order(DUID, direction, -N)]
fwrite(lever_tbl, file.path(OUT, "task2_lever_table.csv"))
saveRDS(UD, file.path(OUT, "task2_unit_day_panel.rds"))

# ---------------------------------------------------------------------------
# 6. STEP-1 FREQUENCY GATE (per pre-registration; verdict printed, tables saved)
# ---------------------------------------------------------------------------
cat("\n================ STEP 1: FREQUENCY GATE ================\n")
UD[, yr := year(cal_day)]
gate_comp <- UD[!is.na(composite), .(
  n_days = .N,
  pct_at_neg1000 = round(100*mean(composite <= -999),1),
  pct_cheap_le0 = round(100*mean(composite <= 0),1),
  pct_mid = round(100*mean(composite > 0 & composite < mpc),1),
  pct_at_cap = round(100*mean(composite >= mpc),1),
  median = round(median(composite),1)
), by=.(DUID, yr)][order(DUID, yr)]
fwrite(gate_comp, file.path(OUT, "task2_gate_composite.csv"))
cat("(a) Composite distribution by unit-year:\n"); print(gate_comp)

gate_A <- UD[!is.na(comp_A), .(n_days=.N, A_events=sum(comp_A),
                                A_events_essential=sum(comp_A & essential_day),
                                essential_days=sum(essential_day)), by=.(DUID, yr)][order(DUID, yr)]
fwrite(gate_A, file.path(OUT, "task2_gate_componentA.csv"))
cat("\n(b) Component A (withdrawal) events by unit-year:\n"); print(gate_A)

gate_B <- UD[!is.na(comp_B), .(n_days=.N, p25=round(quantile(comp_B,.25),1), median=round(median(comp_B),1),
                                p75=round(quantile(comp_B,.75),1), pct_le0=round(100*mean(comp_B<=0),1),
                                pct_gt300=round(100*mean(comp_B>300),1)), by=.(DUID, yr)][order(DUID, yr)]
fwrite(gate_B, file.path(OUT, "task2_gate_componentB.csv"))
cat("\n(c) Component B (pricing, conditional) distribution by unit-year:\n"); print(gate_B)
cat("\n(d) Lever table (composite jumps):\n"); print(lever_tbl)

# THE STOP RULE (pooled test units)
gA_ess <- UD[DUID %in% TEST_UNITS & comp_A==TRUE & essential_day==TRUE]
n_gate <- nrow(gA_ess)
mo_conc <- gA_ess[, .N, by=.(yyyymm = format(cal_day, "%Y%m"))][order(-N)]
top3 <- if (nrow(mo_conc)) round(100*sum(head(mo_conc$N,3))/n_gate,1) else 0
cat(sprintf("\nGATE VERDICT: Component-A events among essential days, pooled test units = %d (rule: stop if < 30).\n", n_gate))
cat(sprintf("Month concentration: top-3 months hold %.1f%% (flag if > 60%%). Months: %s\n",
            top3, paste(head(mo_conc$yyyymm,5), collapse=", ")))
cat(sprintf("Essential days (test units): %d of %d unit-days; Component-A days overall: %d\n",
            UD[DUID %in% TEST_UNITS, sum(essential_day, na.rm=TRUE)],
            UD[DUID %in% TEST_UNITS & !is.na(comp_A), .N],
            UD[DUID %in% TEST_UNITS, sum(comp_A, na.rm=TRUE)]))
cat(if (n_gate >= 30) "GATE PASSES -- estimation may proceed.\n" else "GATE FAILS -- STOP AND REPORT (no regression).\n")
