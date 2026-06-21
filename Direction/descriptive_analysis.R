#!/usr/bin/env Rscript
# descriptive_analysis.R
# Go/no-go descriptive diagnostic for the SA strategic-bidding hypothesis.
# Run from the Direction/ working directory.
#
# Gate 0: reconstruct d_t (trailing 365-day 90th-pct SA spot) and validate
#         against realised DCP/DQ. Halts loudly on validation failure.
# Cuts 1-5: raw conditional means, shares, bins. No regressions.
# Outputs -> Direction/outputs/descriptives/

suppressMessages({
  library(data.table)
  library(ggplot2)
})

setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT_DIR   <- "outputs/descriptives"
CACHE_DIR <- "bid_cache"
PARSE_DIR <- "direction_data/parsed"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

HIGH_BAND_THR <- 5000L    # $/MWh: "near-cap" withholding proxy
SKIP_MONTHS   <- "202206" # June 2022 APC / administrative period
DT_EXIT_YM    <- "202307" # updated once Gate 0 is computed

ym_seq <- function(start, end) {
  si <- as.integer(substr(start,1,4))*12L + as.integer(substr(start,5,6)) - 1L
  ei <- as.integer(substr(end,  1,4))*12L + as.integer(substr(end,  5,6)) - 1L
  sprintf("%d%02d", seq(si,ei) %/% 12L, seq(si,ei) %% 12L + 1L)
}
ALL_MONTHS <- setdiff(ym_seq("202201","202412"), SKIP_MONTHS)
cat(sprintf("Months: %d  (%s to %s, excl. %s)\n",
            length(ALL_MONTHS), ALL_MONTHS[1], tail(ALL_MONTHS,1), SKIP_MONTHS))

# ================================================================
# SCHEMA VALIDATION  (halt loudly on missing columns)
# ================================================================
cat("\n--- Schema validation ---\n")
check_schema <- function(path, need) {
  d <- readRDS(path)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(sprintf("SCHEMA HALT [%s] missing: %s",
                                  basename(path), paste(miss, collapse=", ")))
  invisible(d)
}
check_schema(file.path(CACHE_DIR,"DISPATCHPRICE_202203.rds"),
             c("SETTLEMENTDATE","RRP","INTERVENTION","REGIONID"))
check_schema(file.path(CACHE_DIR,"BIDOFFERPERIOD_202203.rds"),
             c("DUID","TRADINGDATE","PERIODID","OFFERDATETIME","MAXAVAIL",
               paste0("BANDAVAIL",1:10),"INTERVAL_DATETIME"))
check_schema(file.path(CACHE_DIR,"BIDDAYOFFER_202203.rds"),
             c("DUID","SETTLEMENTDATE","OFFERDATE","VERSIONNO",
               paste0("PRICEBAND",1:10)))
cat("Schemas OK.\n")

# ================================================================
# GATE 0: reconstruct d_t from DISPATCHPRICE
# ================================================================
cat("\n--- Gate 0: d_t reconstruction ---\n")

GATE0_RDS <- file.path(OUT_DIR,"gate0_dt_series.rds")
if (!file.exists(GATE0_RDS)) {
  dp_paths <- file.path(CACHE_DIR, sprintf("DISPATCHPRICE_%s.rds", ALL_MONTHS))
  dp_paths <- dp_paths[file.exists(dp_paths)]
  all_dp <- rbindlist(lapply(dp_paths, readRDS), use.names=TRUE, fill=TRUE)
  all_dp <- all_dp[REGIONID=="SA1" & INTERVENTION==0L, .(SETTLEMENTDATE, RRP)]
  all_dp[, date := as.IDate(SETTLEMENTDATE)]
  setkey(all_dp, date)
  cat(sprintf("  %d 5-min SA1 intervals loaded\n", nrow(all_dp)))

  # Trailing 365-day 90th-pct evaluated at mid-month for each ALL_MONTHS entry
  target_dates <- as.IDate(paste0(ALL_MONTHS,"15"), format="%Y%m%d")
  dt_series <- rbindlist(lapply(seq_along(target_dates), function(i) {
    d    <- target_dates[i]
    rrps <- all_dp[date > (d - 365L) & date <= d, RRP]
    data.table(yyyymm=ALL_MONTHS[i], mid_date=d,
               dt_recon=quantile(rrps, 0.9, na.rm=TRUE),
               n_intv=length(rrps))
  }))
  dt_series[, window_complete := (n_intv >= 0.9 * 365 * 288)]
  saveRDS(dt_series, GATE0_RDS)
  rm(all_dp); gc()
} else {
  cat("  Loaded cached Gate 0 series.\n")
  dt_series <- readRDS(GATE0_RDS)
}

# Realised d_t from direction_costs (old-format, 2021-2023)
dc <- readRDS(file.path(PARSE_DIR,"direction_costs.rds"))
dc[, dt_real := compensation_payment / directed_mwh]
dc[, yyyymm  := format(direction_start, "%Y%m")]
dc_m <- dc[!is.na(dt_real) & directed_mwh > 0,
           .(dt_real=weighted.mean(dt_real, directed_mwh),
             mwh=sum(directed_mwh)), by=yyyymm]

# Realised d_t from new-format per-DUID events (2023H2+)
ev <- readRDS(file.path(PARSE_DIR,"direction_events.rds"))
ev_nw <- ev[source_format=="new" & !is.na(compensation_payment) &
              !is.na(directed_mwh) & directed_mwh>0]
ev_nw[, dt_real := compensation_payment / directed_mwh]
ev_nw[, yyyymm  := format(issue_time, "%Y%m")]
ev_m  <- ev_nw[, .(dt_real=weighted.mean(dt_real,directed_mwh),
                    mwh=sum(directed_mwh)), by=yyyymm]

dt_real_all <- rbindlist(list(dc_m, ev_m), fill=TRUE)
dt_real_all <- dt_real_all[, .(dt_real=weighted.mean(dt_real,mwh)), by=yyyymm]

# Merge reconstructed & realised
dt_all <- merge(dt_series[, .(yyyymm, dt_recon, window_complete)],
                dt_real_all, by="yyyymm", all=TRUE)
dt_all[, dt := fifelse(!is.na(dt_real), dt_real, dt_recon)]  # prefer realised

# Gate 0 validation: correlation on complete-window months with both series
overlap <- dt_all[!is.na(dt_recon) & !is.na(dt_real) & window_complete==TRUE]
gate0_corr <- if (nrow(overlap) >= 3) cor(overlap$dt_recon, overlap$dt_real) else NA_real_
cat(sprintf("  Gate 0 corr (realised vs reconstructed, n=%d months): %.3f\n",
            nrow(overlap), if(is.na(gate0_corr)) NaN else gate0_corr))

if (!is.na(gate0_corr) && gate0_corr < 0.80) {
  cat("\n  LIKELY CAUSES OF MISALIGNMENT:\n")
  cat("  1. AEMO may use 30-min trading prices, not 5-min dispatch prices.\n")
  cat("  2. APC capping in Jun-Jul 2022 suppresses measured 5-min prices below market value.\n")
  cat("  3. The window may be strict calendar years rather than a rolling 365-day count.\n")
  stop(sprintf("GATE 0 FAILED (corr=%.3f). Inspect Gate0_dt_validation.png. Halting.",
               gate0_corr))
}

# Gate 0 figure
dt_plot <- dt_all[, .(yyyymm, dt_recon, dt_real)][order(yyyymm)]
dt_plot[, period := as.Date(paste0(yyyymm,"01"),"%Y%m%d")]

p_g0 <- ggplot(dt_plot, aes(x=period)) +
  geom_line(aes(y=dt_recon, colour="Reconstructed (5-min trailing 365d 90th pct)"),
            linewidth=0.9, na.rm=TRUE) +
  geom_point(aes(y=dt_real, colour="Realised (DCP/DQ)"),
             size=2.5, shape=16, na.rm=TRUE) +
  geom_vline(xintercept=as.Date(paste0(DT_EXIT_YM,"01"),"%Y%m%d"),
             linetype="dashed", colour="grey40") +
  scale_colour_manual(values=c("Reconstructed (5-min trailing 365d 90th pct)"="#1f77b4",
                                "Realised (DCP/DQ)"="#d62728")) +
  scale_y_continuous(labels=scales::dollar_format(suffix="/MWh")) +
  scale_x_date(date_breaks="6 months", date_labels="%b %Y") +
  labs(title="Gate 0: Directed price d_t — reconstructed vs realised",
       subtitle=sprintf("Corr = %.2f on %d overlap months | Dashed = d_t exit month",
                        if(is.na(gate0_corr)) NA else gate0_corr, nrow(overlap)),
       x=NULL, y="d_t ($/MWh)", colour=NULL) +
  theme_minimal(base_size=11) + theme(legend.position="bottom")

ggsave(file.path(OUT_DIR,"Gate0_dt_validation.png"), p_g0, width=9, height=4.5, dpi=150)
fwrite(dt_all, file.path(OUT_DIR,"Gate0_dt_table.csv"))

# Update DT_EXIT_YM: first month reconstructed d_t drops below 67% of its peak
dt_peak <- max(dt_series$dt_recon, na.rm=TRUE)
exit_cand <- dt_series[window_complete==TRUE & dt_recon < dt_peak * 0.67]
if (nrow(exit_cand)) {
  DT_EXIT_YM <- exit_cand[which.min(mid_date), yyyymm]
  cat(sprintf("  d_t exit month: %s  (peak $%.0f → drops below $%.0f)\n",
              DT_EXIT_YM, dt_peak, dt_peak*0.67))
}
cat(">>> Gate 0 PASSED. <<<\n")

# Helper: attach d_t to any table with yyyymm column
add_dt <- function(dt) merge(dt, dt_all[, .(yyyymm, dt)], by="yyyymm", all.x=TRUE)

# ================================================================
# TREATMENT PANEL & DUID CLASSIFICATION
# ================================================================
cat("\n--- Treatment panel ---\n")
tp <- readRDS(file.path(PARSE_DIR,"treatment_panel.rds"))
# Filter to SA1 DUIDs only
sa1_duids <- ev[region=="SA1", unique(duid)]
tp <- tp[duid %in% sa1_duids]
tp[, yyyymm := format(interval_datetime, "%Y%m")]
setkey(tp, duid, interval_datetime)
TREATED <- tp[, unique(duid)]
cat(sprintf("  Treated SA1 DUIDs (%d): %s\n", length(TREATED), paste(sort(TREATED),collapse=", ")))

duid_files <- list.files(CACHE_DIR, pattern="^SA_DUIDS_", full.names=TRUE)
ALL_SA     <- unique(unlist(lapply(duid_files, readRDS)))
NEVER_DIR  <- setdiff(ALL_SA, TREATED)
cat(sprintf("  Never-directed SA DUIDs: %d\n", length(NEVER_DIR)))

# ================================================================
# MONTHLY BID AGGREGATION LOOP
# ================================================================
cat("\n--- Monthly bid aggregation ---\n")
MONTHLY_RDS <- file.path(OUT_DIR,"monthly_bid_agg.rds")

if (!file.exists(MONTHLY_RDS)) {
  band_cols  <- paste0("BANDAVAIL", 1:10)
  price_cols <- paste0("PRICEBAND",  1:10)

  monthly_list <- vector("list", length(ALL_MONTHS))
  for (mi in seq_along(ALL_MONTHS)) {
    M  <- ALL_MONTHS[mi]
    bp_path <- file.path(CACHE_DIR, sprintf("BIDOFFERPERIOD_%s.rds", M))
    bd_path <- file.path(CACHE_DIR, sprintf("BIDDAYOFFER_%s.rds",    M))
    if (!file.exists(bp_path) || !file.exists(bd_path)) {
      cat(sprintf("  [%s] missing — skip\n", M)); next
    }
    cat(sprintf("  [%s] ...", M))

    # --- BIDOFFERPERIOD: keep needed columns, binding collapse ---
    bp <- readRDS(bp_path)
    bp <- bp[, .SD, .SDcols = intersect(c("DUID","TRADINGDATE","PERIODID",
                                            "OFFERDATETIME","MAXAVAIL",
                                            band_cols,"INTERVAL_DATETIME"), names(bp))]
    # Fill any missing band columns with 0
    for (cc in band_cols) if (!cc %in% names(bp)) set(bp, j=cc, value=0)
    # Binding = latest OFFERDATETIME per DUID-TRADINGDATE-PERIODID
    setorder(bp, DUID, TRADINGDATE, PERIODID, OFFERDATETIME)
    bp <- bp[, .SD[.N], by=.(DUID, TRADINGDATE, PERIODID)]
    bp[, td := as.IDate(TRADINGDATE)]

    # --- BIDDAYOFFER: binding daily price (latest OFFERDATE, max VERSIONNO) ---
    bd <- readRDS(bd_path)
    bd <- bd[, .SD, .SDcols = intersect(c("DUID","SETTLEMENTDATE","OFFERDATE",
                                            "VERSIONNO", price_cols), names(bd))]
    bd[, td := as.IDate(SETTLEMENTDATE)]
    # Latest offer date per DUID-trading day
    setorder(bd, DUID, td, -OFFERDATE, -VERSIONNO)
    bd <- bd[, .SD[1L], by=.(DUID, td)]

    # --- Join on DUID × td ---
    joined <- merge(bp, bd[, c("DUID","td",price_cols), with=FALSE],
                    by=c("DUID","td"), all.x=TRUE)
    rm(bp, bd); gc()

    # Total capacity offered
    joined[, total_offered := rowSums(.SD, na.rm=TRUE), .SDcols=band_cols]

    # High-band capacity: bands where PRICEBAND_k >= HIGH_BAND_THR
    for (k in 1:10) {
      pb_col <- paste0("PRICEBAND",  k)
      ba_col <- paste0("BANDAVAIL",  k)
      hk_col <- paste0("h", k)
      joined[, (hk_col) := fifelse(!is.na(get(pb_col)) & get(pb_col) >= HIGH_BAND_THR,
                                    get(ba_col), 0)]
    }
    joined[, high_offered := rowSums(.SD, na.rm=TRUE), .SDcols=paste0("h",1:10)]

    joined[, share_high  := high_offered / pmax(MAXAVAIL, 1)]
    joined[, withheld_mw := pmax(MAXAVAIL - total_offered, 0)]
    joined[, yyyymm := M]  # add as column before by= (scalar in by= causes length mismatch)

    # Monthly aggregate per DUID
    agg <- joined[, .(
      n_intervals     = .N,
      mean_maxavail   = mean(MAXAVAIL,      na.rm=TRUE),
      mean_offered    = mean(total_offered, na.rm=TRUE),
      mean_share_high = mean(share_high,    na.rm=TRUE),
      mean_withheld   = mean(withheld_mw,   na.rm=TRUE)
    ), by=.(DUID, yyyymm)]

    monthly_list[[mi]] <- agg
    rm(joined, agg); gc()
    cat(sprintf(" done\n"))
  }

  monthly_agg <- rbindlist(monthly_list, fill=TRUE)
  saveRDS(monthly_agg, MONTHLY_RDS)
  cat(sprintf("  Saved: %d rows\n", nrow(monthly_agg)))
} else {
  cat("  Loaded cached monthly aggregates.\n")
  monthly_agg <- readRDS(MONTHLY_RDS)
}

monthly_agg[, treated := DUID %in% TREATED]
monthly_agg[, period  := as.Date(paste0(yyyymm,"01"),"%Y%m%d")]
monthly_agg <- add_dt(monthly_agg)

exit_date <- as.Date(paste0(DT_EXIT_YM,"01"),"%Y%m%d")

# ================================================================
# CUT 1: Treatment variation
# ================================================================
cat("\n--- Cut 1: Treatment variation ---\n")

tp_m <- tp[yyyymm %in% ALL_MONTHS, .(
  n_dir   = sum(directed),
  n_sync  = sum(synchronise),
  n_rem   = sum(directed) - sum(synchronise)
), by=.(duid, yyyymm)]
tp_m[, period := as.Date(paste0(yyyymm,"01"),"%Y%m%d")]
tp_m <- add_dt(tp_m)

# Direction frequency vs d_t
tp_sum <- tp_m[, .(total_dir=sum(n_dir)), by=.(yyyymm, period, dt=dt)]
cat(sprintf("  Direction freq vs d_t corr: %.3f\n",
            cor(tp_sum$total_dir, tp_sum$dt, use="complete.obs")))

tp_long <- melt(tp_m, id.vars=c("duid","yyyymm","period","dt"),
                measure.vars=c("n_sync","n_rem"), variable.name="type", value.name="n")
tp_long[, type_label := ifelse(type=="n_sync","Synchronise","Remain")]

p_c1 <- ggplot(tp_long, aes(x=period, y=n, fill=type_label)) +
  geom_col(width=28) +
  geom_vline(xintercept=exit_date, linetype="dashed", colour="grey30") +
  scale_fill_manual(values=c(Synchronise="#d62728", Remain="#1f77b4")) +
  scale_x_date(date_breaks="6 months", date_labels="%b %y") +
  facet_wrap(~duid, scales="free_y") +
  labs(title="Cut 1: Directed 5-min intervals per SA treated DUID per month",
       subtitle="Dashed = d_t exit. Synchronise = unit directed from offline state (the key margin).",
       x=NULL, y="Directed intervals", fill=NULL) +
  theme_minimal(base_size=9) +
  theme(legend.position="bottom", axis.text.x=element_text(angle=45,hjust=1))
ggsave(file.path(OUT_DIR,"Cut1_treatment_variation.png"), p_c1, width=14, height=10, dpi=150)
cat("  Cut 1 saved.\n")

# ================================================================
# CUT 2: Directed-price rent distribution
# ================================================================
cat("\n--- Cut 2: Rent distribution ---\n")

dp_paths <- file.path(CACHE_DIR, sprintf("DISPATCHPRICE_%s.rds", ALL_MONTHS))
dp_paths <- dp_paths[file.exists(dp_paths)]
all_dp <- rbindlist(lapply(dp_paths, readRDS), use.names=TRUE, fill=TRUE)
all_dp <- all_dp[REGIONID=="SA1" & INTERVENTION==0L, .(interval_datetime=SETTLEMENTDATE, RRP)]
setkey(all_dp, interval_datetime)

rent_dt <- merge(tp[directed==1, .(duid, interval_datetime, synchronise)],
                 all_dp, by="interval_datetime", all.x=TRUE)
rent_dt[, yyyymm := format(interval_datetime, "%Y%m")]
rent_dt <- add_dt(rent_dt)
rent_dt[, net_rent := dt - RRP]
rent_dt[, period_label := fifelse(yyyymm < DT_EXIT_YM,
                                   "Pre-exit (high d_t)", "Post-exit (low d_t)")]

rent_summary <- rent_dt[!is.na(net_rent), .(
  mean_rent    = mean(net_rent),
  med_rent     = median(net_rent),
  pct_positive = mean(net_rent > 0) * 100,
  n_intv       = .N
), by=.(period_label, synchronise)]
cat("  Rent summary:\n"); print(rent_summary)

p_c2 <- ggplot(rent_dt[!is.na(net_rent)],
               aes(x=pmin(pmax(net_rent,-5000),5000), colour=period_label)) +
  geom_density(adjust=0.6, linewidth=0.9) +
  geom_vline(xintercept=0, linetype="dashed") +
  scale_colour_manual(values=c("Pre-exit (high d_t)"="#d62728","Post-exit (low d_t)"="#1f77b4")) +
  facet_wrap(~ifelse(synchronise==1L,"Synchronise","Remain")) +
  scale_x_continuous(labels=scales::dollar_format(suffix="/MWh"), limits=c(-5000,5000)) +
  labs(title="Cut 2: Net directed-price rent  (d_t − spot)  per 5-min directed interval",
       subtitle="Positive = direction paid above spot. Truncated at ±$5,000 for display.",
       x="d_t − spot price ($/MWh)", y="Density", colour=NULL) +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(OUT_DIR,"Cut2_rent_distribution.png"), p_c2, width=9, height=4.5, dpi=150)
rm(all_dp); gc()
cat("  Cut 2 saved.\n")

# ================================================================
# CUT 3: Offer behaviour vs d_t
# ================================================================
cat("\n--- Cut 3: Offer behaviour ---\n")

# Control: never-directed SA DUIDs with MAXAVAIL > 50 MW (dispatchable floor)
ctrl_candidates <- monthly_agg[!treated & mean_maxavail > 50, unique(DUID)]
cat(sprintf("  Control DUIDs (never-directed, MAXAVAIL>50): %d  — %s\n",
            length(ctrl_candidates), paste(sort(ctrl_candidates), collapse=", ")))

panel_agg <- function(dt_sub, grp) {
  dt_sub[, .(mean_share_high=mean(mean_share_high, na.rm=TRUE),
              mean_withheld  =mean(mean_withheld,   na.rm=TRUE),
              mean_maxavail  =mean(mean_maxavail,    na.rm=TRUE),
              n_duids        =uniqueN(DUID),
              group=grp), by=.(yyyymm, period, dt)]
}
offer_panel <- rbindlist(list(
  panel_agg(monthly_agg[treated==TRUE], "Treated (ever-directed)"),
  panel_agg(monthly_agg[DUID %in% ctrl_candidates], "Control (never-directed, MAXAVAIL>50)")
))

dt_scale <- max(offer_panel$mean_share_high, na.rm=TRUE) /
            max(offer_panel$dt, na.rm=TRUE)

p_c3 <- ggplot(offer_panel, aes(x=period)) +
  geom_line(aes(y=mean_share_high, colour=group), linewidth=0.9, na.rm=TRUE) +
  geom_line(aes(y=dt*dt_scale), linetype="dotted", colour="grey50",
            linewidth=0.7, na.rm=TRUE) +
  geom_vline(xintercept=exit_date, linetype="dashed", colour="grey30") +
  annotate("text", x=exit_date, y=Inf, vjust=1.5, hjust=-0.1, size=3,
           colour="grey40", label="d_t exit") +
  scale_colour_manual(values=c("Treated (ever-directed)"="#d62728",
                                "Control (never-directed, MAXAVAIL>50)"="#1f77b4")) +
  scale_y_continuous(
    name=sprintf("Share of capacity in bands ≥$%s/MWh (left)", scales::comma(HIGH_BAND_THR)),
    labels=scales::percent,
    sec.axis=sec_axis(~./dt_scale, name="d_t $/MWh (right)")
  ) +
  scale_x_date(date_breaks="6 months", date_labels="%b %y") +
  labs(title="Cut 3: High-band capacity share — Treated vs Never-directed controls",
       subtitle=sprintf("Withholding proxy: %%MAXAVAIL offered at ≥$%s/MWh. Dotted = d_t (right axis).",
                        scales::comma(HIGH_BAND_THR)),
       x=NULL, colour=NULL) +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(OUT_DIR,"Cut3_offer_behaviour.png"), p_c3, width=10, height=5, dpi=150)
cat("  Cut 3 saved.\n")

# ================================================================
# CUT 4: Mechanism — BIDDAYOFFER state the day BEFORE Synchronise direction
# ================================================================
cat("\n--- Cut 4: Mechanism ---\n")

ev_sync <- ev[region=="SA1" & direction_instruction=="Synchronise" &
                !is.na(effective_time) & !is.na(issue_time)]
ev_sync[, yyyymm     := format(issue_time, "%Y%m")]
ev_sync[, issue_date := as.IDate(issue_time)]
ev_sync[, day_before := issue_date - 1L]
ev_sync[, ym_before  := format(as.Date(day_before), "%Y%m")]
ev_sync <- ev_sync[yyyymm %in% ALL_MONTHS]

# Need BIDDAYOFFER for both the event month AND the month containing day_before
# Don't intersect with ALL_MONTHS here — need Jun 2022 BIDDAYOFFER if any
# day_before falls there; file existence check below handles truly missing months
mths_needed <- sort(union(unique(ev_sync$yyyymm), unique(ev_sync$ym_before)))
cat(sprintf("  Loading BIDDAYOFFER for %d months...\n", length(mths_needed)))

bd_all <- rbindlist(lapply(mths_needed, function(M) {
  path <- file.path(CACHE_DIR, sprintf("BIDDAYOFFER_%s.rds", M))
  if (!file.exists(path)) return(NULL)
  bd <- readRDS(path)
  bd[, td := as.IDate(SETTLEMENTDATE)]
  setorder(bd, DUID, td, -OFFERDATE, -VERSIONNO)
  bd[, .SD[1L], by=.(DUID, td)][, c("DUID","td","PRICEBAND10"), with=FALSE]
}), fill=TRUE)

# Join: get PRICEBAND10 for the DUID on the day BEFORE the direction
ev_mech <- merge(ev_sync[, .(duid, yyyymm, day_before)],
                 bd_all, by.x=c("duid","day_before"), by.y=c("DUID","td"),
                 all.x=TRUE)
ev_mech <- add_dt(ev_mech)

dt_med <- median(ev_mech$dt, na.rm=TRUE)
ev_mech[, dt_group   := fifelse(dt >= dt_med, "High d_t (≥ median)", "Low d_t (< median)")]
ev_mech[, offer_high := (!is.na(PRICEBAND10) & PRICEBAND10 >= HIGH_BAND_THR)]

mech_duid <- ev_mech[!is.na(PRICEBAND10), .(
  pct_high = mean(offer_high)*100, n=.N
), by=.(duid, dt_group)]

mech_agg <- ev_mech[!is.na(PRICEBAND10), .(
  pct_high = mean(offer_high)*100, n=.N
), by=dt_group]
cat(sprintf("  d_t median split: $%.0f/MWh\n", dt_med))
cat("  Overall mechanism summary:\n"); print(mech_agg)

p_c4 <- ggplot(mech_duid[!is.na(dt_group)],
               aes(x=reorder(duid,-pct_high), y=pct_high, fill=dt_group)) +
  geom_col(position="dodge") +
  geom_text(aes(label=paste0("n=",n)), position=position_dodge(0.9), vjust=-0.3, size=2.6) +
  scale_fill_manual(values=c("High d_t (≥ median)"="#d62728",
                              "Low d_t (< median)"="#1f77b4")) +
  scale_y_continuous(labels=function(x) paste0(x,"%"), limits=c(0,105)) +
  labs(title="Cut 4: % of Synchronise events with PRICEBAND10 ≥ $5,000 the day before",
       subtitle=sprintf("Withholding day-before proxy  |  d_t split at median $%.0f/MWh", dt_med),
       x="DUID", y="% events with top-band ≥ $5,000 the day before", fill=NULL) +
  theme_minimal(base_size=11) +
  theme(legend.position="bottom", axis.text.x=element_text(angle=45,hjust=1))
ggsave(file.path(OUT_DIR,"Cut4_mechanism.png"), p_c4, width=10, height=5.5, dpi=150)
rm(bd_all); gc()
cat("  Cut 4 saved.\n")

# ================================================================
# CUT 5: Event study preview
# ================================================================
cat("\n--- Cut 5: Event study preview ---\n")

exit_idx    <- which(ALL_MONTHS == DT_EXIT_YM)
if (!length(exit_idx)) exit_idx <- which.min(abs(as.integer(ALL_MONTHS)-as.integer(DT_EXIT_YM)))
month_order <- data.table(yyyymm=ALL_MONTHS, t_rel=seq_along(ALL_MONTHS)-exit_idx)

evs <- merge(monthly_agg[, .(DUID, yyyymm, mean_share_high, mean_withheld, treated)],
             month_order, by="yyyymm")
evs <- evs[t_rel >= -18 & t_rel <= 18]

es <- function(dt_sub, grp) {
  dt_sub[, .(mean_share_high=mean(mean_share_high,na.rm=TRUE),
              mean_withheld  =mean(mean_withheld,  na.rm=TRUE),
              n_duids=uniqueN(DUID),
              group=grp), by=t_rel]
}
es_all <- rbindlist(list(
  es(evs[treated==TRUE], "Treated (ever-directed)"),
  es(evs[DUID %in% ctrl_candidates], "Control (never-directed, MAXAVAIL>50)")
))

p_c5 <- ggplot(es_all, aes(x=t_rel, y=mean_share_high, colour=group)) +
  geom_line(linewidth=0.9, na.rm=TRUE) + geom_point(size=1.8, na.rm=TRUE) +
  geom_vline(xintercept=0, linetype="dashed", colour="grey30") +
  annotate("rect", xmin=-6, xmax=0, ymin=-Inf, ymax=Inf, alpha=0.07, fill="orange") +
  annotate("text", x=-3, y=Inf, vjust=1.5, size=3, colour="grey40", label="pre-exit\nwindow") +
  scale_colour_manual(values=c("Treated (ever-directed)"="#d62728",
                                "Control (never-directed, MAXAVAIL>50)"="#1f77b4")) +
  scale_x_continuous(breaks=seq(-18,18,6), labels=function(x) paste0("t=",x)) +
  scale_y_continuous(labels=scales::percent) +
  labs(title="Cut 5: Event-study preview — high-band capacity share",
       subtitle="t=0 = d_t exit month. Flat pre-trend + differential post-shift = supports design.",
       x="Months relative to d_t exit", y=sprintf("Share of capacity in bands ≥$%s/MWh",
                                                    scales::comma(HIGH_BAND_THR)),
       colour=NULL) +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(OUT_DIR,"Cut5_eventstudy.png"), p_c5, width=10, height=5, dpi=150)
cat("  Cut 5 saved.\n")

# ================================================================
# MEMO: descriptive_readout.md
# ================================================================
cat("\n--- Writing memo ---\n")

pre_sync  <- rent_summary[period_label=="Pre-exit (high d_t)"  & synchronise==1L]
post_sync <- rent_summary[period_label=="Post-exit (low d_t)"  & synchronise==1L]
hi_dt     <- mech_agg[dt_group=="High d_t (≥ median)", pct_high]
lo_dt     <- mech_agg[dt_group=="Low d_t (< median)",  pct_high]
corr_fd   <- cor(tp_sum$total_dir, tp_sum$dt, use="complete.obs")
dt_pre_m  <- dt_all[yyyymm < DT_EXIT_YM, mean(dt, na.rm=TRUE)]
dt_post_m <- dt_all[yyyymm >= DT_EXIT_YM, mean(dt_recon, na.rm=TRUE)]

cat_rent <- if (nrow(pre_sync) && nrow(post_sync)) {
  sprintf("Synchronise: pre-exit mean rent = $%.0f/MWh (%d%% positive) | post-exit = $%.0f/MWh (%d%% positive)",
          pre_sync$mean_rent, round(pre_sync$pct_positive),
          post_sync$mean_rent, round(post_sync$pct_positive))
} else { "Rent data insufficient." }

mech_verdict <- if (length(hi_dt) && length(lo_dt) && !is.na(hi_dt) && !is.na(lo_dt)) {
  diff <- hi_dt - lo_dt
  v <- if (diff > 10) "SUPPORTS" else if (diff > 0) "AMBIGUOUS" else "CUTS AGAINST"
  sprintf("%s  (high-d_t: %.0f%% vs low-d_t: %.0f%%; diff = %+.0f pp)", v, hi_dt, lo_dt, diff)
} else { "INSUFFICIENT DATA" }

memo <- c(
  "# Descriptive diagnostic readout — SA directions & strategic bidding",
  "",
  paste0("**Analysis date:** ", Sys.Date()),
  paste0("**d_t exit month (identified):** ", DT_EXIT_YM),
  "",
  "---",
  "",
  "## Gate 0: d_t series",
  sprintf("- Correlation (realised DCP/DQ vs reconstructed 5-min 90th-pct): **%.2f**",
          if(is.na(gate0_corr)) NA else gate0_corr),
  sprintf("- Pre-exit mean d_t: **$%.0f/MWh** | Post-exit reconstructed: **$%.0f/MWh** (fall: %d%%)",
          dt_pre_m, dt_post_m, round((1 - dt_post_m/dt_pre_m)*100)),
  "- **Verdict:** See figure. If correlation ≥0.80 and fall is steep, SUPPORTS.",
  "",
  "## Cut 1: Treatment variation",
  sprintf("- Treated SA1 DUIDs: **%d** | Direction freq vs d_t corr: **%.3f**",
          length(TREATED), corr_fd),
  sprintf("- Synchronise total intervals: **%d** | Remain: **%d**",
          tp[synchronise==1L, .N], tp[synchronise==0L & directed==1L, .N]),
  "- **Verdict:** Inspect figure. Enough events, enough cross-unit variation?",
  "",
  "## Cut 2: Directed-price rent",
  paste0("- ", cat_rent),
  "- **Verdict:** SUPPORTS if pre-exit rent is large positive and collapses post-exit.",
  "",
  "## Cut 3: Offer behaviour vs d_t",
  sprintf("- Control DUIDs (%d): %s", length(ctrl_candidates), paste(sort(ctrl_candidates),collapse=", ")),
  "- **Verdict:** Inspect figure. Co-movement with d_t and differential vs control?",
  "",
  "## Cut 4: Mechanism (pre-direction offer state)",
  paste0("- ", mech_verdict),
  "- **Verdict:** SUPPORTS if high-d_t period shows markedly more top-band offering before direction.",
  "",
  "## Cut 5: Event-study preview",
  sprintf("- Window: ±18 months around t=0 (%s). Treated=%d, Control=%d DUIDs.",
          DT_EXIT_YM, length(TREATED), length(ctrl_candidates)),
  "- **Verdict:** Inspect figure. Flat pre-trend + differential post-shift in treated vs control.",
  "",
  "---",
  "",
  "## Overall go/no-go",
  "",
  "| Cut | Evidence | Verdict |",
  "|-----|----------|---------|",
  sprintf("| Gate 0 | Corr %.2f; fall %d%% | fill in |",
          if(is.na(gate0_corr)) NA else gate0_corr,
          round((1-dt_post_m/dt_pre_m)*100)),
  sprintf("| Cut 2 (rent) | %s | fill in |", cat_rent),
  sprintf("| Cut 4 (mechanism) | %s | fill in |", mech_verdict),
  "| Cut 3 & 5 (offer/event-study) | See figures | fill in |",
  "",
  "**Rule:** 3 of 4 cuts support → GO. 2 support + 2 ambiguous → CONDITIONAL GO.",
  "**Rent must exist (Cut 2) to proceed** — no rent, no incentive."
)

writeLines(memo, file.path(OUT_DIR,"descriptive_readout.md"))

cat("\n=== Done. Outputs in", OUT_DIR, "===\n")
for (f in sort(list.files(OUT_DIR))) cat(" ", f, "\n")
