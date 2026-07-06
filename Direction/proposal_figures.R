#!/usr/bin/env Rscript
# proposal_figures.R
# Descriptive figures that MOTIVATE the SA-directions research proposal.
# Plain-language labelling: every axis, line and bar is explained in words so a
# first-time reader needs no jargon glossary. Assembled from already-cached panels.
# Run from the Direction/ working directory.
#
#   F1  Compensation price vs gas price (slow-moving prize -> low / high rent)
#   F2  Volume directed & total direction cost to the market (small volume can still cost a lot)
#   F3  How essential the directed units are (pivotality composition)
#   F4  Rebidding across three groups of days (whole / direction / pivotal-direction)
#
# Outputs -> Direction/outputs/proposal_figures/  (PNG @300dpi + companion CSVs + readout.md)

suppressMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
})

setwd("C:/Users/ericl/Documents/my-project/Direction")
Sys.setlocale("LC_TIME", "C")     # force English month labels (machine locale is zh)
OUT   <- "outputs/proposal_figures"
DESC  <- "outputs/descriptives"
DESC3 <- "outputs/descriptives_v3"
PARSE <- "direction_data/parsed"
CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# Shared palette + theme
COL <- c(prize = "#d62728", cost = "#1f77b4", grey = "grey45",
         t1 = "#b2182b", t2 = "#ef8a62", t3 = "#bdbdbd")
THEME <- theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.subtitle = element_text(size = 9, colour = "grey30"),
        plot.caption  = element_text(size = 8, colour = "grey35", hjust = 0),
        panel.grid.minor = element_blank())

ym_to_qdate <- function(ym) {            # "202203" -> Date of quarter start
  yr <- as.integer(substr(ym, 1, 4)); mo <- as.integer(substr(ym, 5, 6))
  qm <- (ceiling(mo / 3) - 1L) * 3L + 1L
  as.Date(sprintf("%d-%02d-01", yr, qm))
}
ym_to_mdate <- function(ym) as.Date(sprintf("%s-%s-01", substr(ym,1,4), substr(ym,5,6)))

cat("=== proposal_figures.R ===\n")

# ============================================================================
# F1 — Compensation price vs gas price: the prize moves slowly, so the margin
#      over fuel cost (the "rent") swings from low to high across the sample.
# ============================================================================
cat("\n[F1] compensation price vs gas price ...\n")

dt_tab <- fread(file.path(DESC, "Gate0_dt_table.csv"))
dt_tab[, yyyymm := sprintf("%06d", as.integer(yyyymm))]
dt_tab <- dt_tab[yyyymm >= "202201" & yyyymm <= "202412", .(yyyymm, dt)]
dt_tab[, period := ym_to_mdate(yyyymm)]

# Gas: Adelaide STTM ex-ante quarterly ($/GJ) — parser reused from 02_cost/gate_a_srmc.R
raw_gas <- fread("Quarterly_STTM_Price.CSV")
setnames(raw_gas, c("quarter_ending", "adl_gj", "bri_gj", "syd_gj"))
raw_gas[, adl_gj := suppressWarnings(as.numeric(adl_gj))]
raw_gas <- raw_gas[!is.na(adl_gj)]
MONTH_MAP <- c(Jan=1L,Feb=2L,Mar=3L,Apr=4L,May=5L,Jun=6L,
               Jul=7L,Aug=8L,Sep=9L,Oct=10L,Nov=11L,Dec=12L)
raw_gas[, qend_mon := MONTH_MAP[trimws(substring(quarter_ending, 1, 3))]]
raw_gas[, qend_yr  := as.integer(paste0("20", trimws(substring(quarter_ending, 5, 6))))]
raw_gas <- raw_gas[!is.na(qend_mon) & !is.na(qend_yr)]
months_in_quarter <- function(yr, m_end, price)
  data.table(yyyymm = sprintf("%d%02d", yr, c(m_end-2L, m_end-1L, m_end)), gas_gj = price)
gas_px <- rbindlist(mapply(months_in_quarter, raw_gas$qend_yr, raw_gas$qend_mon,
                           raw_gas$adl_gj, SIMPLIFY = FALSE))
gas_px <- gas_px[yyyymm >= "202201" & yyyymm <= "202412"]
setorder(gas_px, yyyymm)

f1 <- merge(dt_tab, gas_px[, .(yyyymm, gas_gj)], by = "yyyymm", all.x = TRUE)
f1[, period := ym_to_mdate(yyyymm)]
# approximate fuel cost in $/MWh (heat rate ~10.7 GJ/MWh + ~$2.5 variable O&M) and the rent
f1[, fuel_cost := gas_gj * 10.7 + 2.5]
f1[, rent := dt - fuel_cost]
fwrite(f1, file.path(OUT, "F1_compensation_vs_fuel.csv"))

sc <- max(f1$dt, na.rm=TRUE) / max(f1$gas_gj, na.rm=TRUE)   # right->left axis scale
peak_dt <- f1[which.max(dt)]

LOWLAB  <- "Low rent:\nthe fuel-price spike\nswallowed the prize"
HIGHLAB <- "High rent:\nthe prize stayed high\nafter fuel costs fell"
p1 <- ggplot(f1, aes(x = period)) +
  # shade and label the two rent regimes
  annotate("rect", xmin = as.Date("2022-01-01"), xmax = as.Date("2022-08-01"),
           ymin = -Inf, ymax = Inf, alpha = 0.07, fill = COL["cost"]) +
  annotate("rect", xmin = as.Date("2022-10-01"), xmax = as.Date("2023-12-31"),
           ymin = -Inf, ymax = Inf, alpha = 0.08, fill = COL["prize"]) +
  annotate("text", x = as.Date("2022-04-15"), y = 305, label = LOWLAB,
           size = 2.9, colour = "#15607a", lineheight = 0.9) +
  annotate("text", x = as.Date("2023-06-15"), y = 110, label = HIGHLAB,
           size = 2.9, colour = COL["prize"], lineheight = 0.9) +
  geom_step(aes(y = gas_gj * sc, colour = "Gas price — the units' main fuel cost (quarterly)"),
            linewidth = 0.9, direction = "hv", na.rm = TRUE) +
  geom_line(aes(y = dt, colour = "Compensation price paid per unit of energy (monthly)"),
            linewidth = 1.1, na.rm = TRUE) +
  scale_colour_manual(values = c(
    "Compensation price paid per unit of energy (monthly)" = unname(COL["prize"]),
    "Gas price — the units' main fuel cost (quarterly)"     = unname(COL["cost"]))) +
  scale_y_continuous(name = "Compensation price paid to directed\ngenerators ($ per MWh of energy)",
                     labels = dollar_format(),
                     sec.axis = sec_axis(~ . / sc, name = "South Australian wholesale\ngas price ($ per gigajoule)",
                                         labels = dollar_format())) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(title = "The compensation price keeps paying 2022 prices long after fuel costs fall",
       subtitle = "It tracks the previous 12 months of prices, so it lags fuel cost — a small rent in 2022, a large rent in 2023.",
       x = NULL, colour = NULL) +
  THEME + theme(legend.text = element_text(size = 8))
ggsave(file.path(OUT, "F1_compensation_vs_fuel.png"), p1, width = 9.8, height = 5.2, dpi = 300)
cat("  saved F1_compensation_vs_fuel.png\n")

# ============================================================================
# F2 — Volume directed (bars) and the total direction cost to the market
#      (line). Cost = the NER 3.15.8 recovery amount (`cra` column):
#      compensation + additional compensation + independent-expert fee, net of
#      the unit's retained market earnings. This is the concept AEMO plots in
#      Quarterly Energy Dynamics (grouping whole events by start quarter
#      reproduces QED Q2-2024 Fig 85's Q2-23 value to the cent; we instead
#      allocate pro-rata over each event's window, which shifts a few $m
#      between neighbouring quarters but is temporally honest).
#      The 2022Q4-2023Q1 window is the costliest per MWh: a small
#      directed volume, but each MWh paid the inflated, slow-moving
#      compensation price (F1's high-rent period).
# ============================================================================
cat("\n[F2] volume directed & direction cost ...\n")

# The event-level cost reports cover 2021-01-01 -> 2023-10-27 16:30; the
# per-DUID event records (new format) begin where they stop. Split at the
# actual coverage seam — a month-label cut at 202310 drops Oct 1-27, 2023
# (~$7m), because neither source then contributes it.
fill_cra <- function(d) d[, cra := fifelse(
  is.na(cra),
  compensation_payment + fcoalesce(additional_compensation, 0) +
    fcoalesce(ie_fee, 0) - fcoalesce(retained_trading_amount, 0),
  cra)]
dc <- fill_cra(as.data.table(readRDS(file.path(PARSE, "direction_costs.rds"))))
dc <- dc[!is.na(directed_mwh),
         .(w_start = direction_start, w_end = direction_end, directed_mwh,
           comp = compensation_payment, cra, src = "costs (event-level)")]
COSTS_END <- max(dc$w_end)
ev <- fill_cra(as.data.table(readRDS(file.path(PARSE, "direction_events.rds"))))
ev <- ev[source_format == "new" & region == "SA1" & !is.na(directed_mwh) &
           effective_time >= COSTS_END,
         .(w_start = effective_time, w_end = cancellation_time, directed_mwh,
           comp = compensation_payment, cra, src = "events (per-DUID)")]
ev[is.na(w_end) | w_end <= w_start, w_end := w_start + 1]
vc <- rbindlist(list(dc, ev))

# Cost-report rows span up to several weeks; allocate volume and dollars to
# quarters pro-rata by time in each quarter. (AEMO groups whole events by
# quarter instead — that convention reproduces its Q2-23/Q4-22 values exactly
# — but pro-rata places cost in the quarter the direction actually ran.)
vc[, row_id := .I]
qseq <- seq(as.Date("2021-01-01"), as.Date("2025-04-01"), by = "quarter")
qcut <- as.numeric(as.POSIXct(paste(qseq, "00:00:00"), tz = "Etc/GMT-10"))
alloc <- vc[, {
  lo <- pmax(as.numeric(w_start), qcut[-length(qcut)])
  hi <- pmin(as.numeric(w_end),   qcut[-1])
  k  <- which(hi > lo)
  .(qdate = qseq[k],
    frac  = (hi[k] - lo[k]) / (as.numeric(w_end) - as.numeric(w_start)),
    directed_mwh = directed_mwh, comp = comp, cra = cra, src = src)
}, by = row_id]

f2 <- alloc[qdate <= as.Date("2024-10-01"),
            .(directed_gwh = sum(directed_mwh * frac) / 1e3,
              cost_m       = sum(cra  * frac) / 1e6,
              comp_m       = sum(comp * frac) / 1e6,
              src          = paste(sort(unique(src)), collapse = " + ")),
            by = qdate][order(qdate)]
f2[, cost_per_mwh := cost_m * 1e6 / (directed_gwh * 1e3)]

# Share of the quarter's time with at least one SA direction active (union of
# effective->cancellation windows, both report formats). Reproduces AEMO's QED
# "percentage of time of directions" series within ~0.1pp for most quarters
# (worst: Q4-22 -2.3pp; edge conventions differ). Not drawn — the chart already
# uses both axes — but kept in the CSV: time directed and cost tell different
# stories (directed time peaks in Q4-23/Q1-24 while cost per MWh peaks a year
# earlier, when the lagged compensation price was at its 2022 high).
evt <- as.data.table(readRDS(file.path(PARSE, "direction_events.rds")))
evt <- evt[region == "SA1" & !is.na(effective_time) & !is.na(cancellation_time) &
             cancellation_time > effective_time,
           .(s = as.numeric(effective_time), c = as.numeric(cancellation_time))]
setorder(evt, s, c)
evt[, cmax := cummax(shift(c, fill = first(c)))]   # max end time of all earlier windows
evt[, grp := cumsum(s > cmax)]                     # new block when this start clears every earlier end
u <- evt[, .(s = min(s), c = max(c)), by = grp]
stopifnot(all(u$s[-1] > u$c[-nrow(u)]))            # union blocks must be disjoint
qlo <- qcut[-length(qcut)]; qhi <- qcut[-1]
pctdir <- data.table(
  qdate = qseq[-length(qseq)],
  pct_time_directed = vapply(seq_along(qlo), function(i)
    sum(pmax(pmin(u$c, qhi[i]) - pmax(u$s, qlo[i]), 0)) / (qhi[i] - qlo[i]),
    numeric(1)))
f2 <- merge(f2, pctdir, by = "qdate", all.x = TRUE)
fwrite(f2, file.path(OUT, "F2_volume_cost.csv"))
cat("  quarters (low-volume high-cost = high $/MWh):\n"); print(f2)

sc2 <- max(f2$directed_gwh, na.rm=TRUE) / max(f2$cost_m, na.rm=TRUE)
p2 <- ggplot(f2, aes(x = qdate)) +
  annotate("rect", xmin = as.Date("2022-09-15"), xmax = as.Date("2023-03-15"),
           ymin = -Inf, ymax = Inf, alpha = 0.08, fill = COL["prize"]) +
  annotate("text", x = as.Date("2023-01-01"), y = 150,
           label = "Costliest per unit of energy —\na small volume, but each MWh\npaid the inflated 2022 price\n(high-rent period, chart 1)",
           size = 2.7, colour = COL["prize"], lineheight = 0.95, vjust = 0.5) +
  geom_col(aes(y = directed_gwh, fill = "Energy generated under direction (bars)"),
           width = 70, alpha = 0.85) +
  geom_line(aes(y = cost_m * sc2, colour = "Total direction cost to the market (line)"), linewidth = 1.1) +
  geom_point(aes(y = cost_m * sc2, colour = "Total direction cost to the market (line)"), size = 1.8) +
  scale_fill_manual(values = c("Energy generated under direction (bars)" = unname(COL["cost"]))) +
  scale_colour_manual(values = c("Total direction cost to the market (line)" = unname(COL["prize"]))) +
  scale_y_continuous(name = "Energy generated under direction\n(thousand MWh per quarter)",
                     sec.axis = sec_axis(~ . / sc2, name = "Total direction cost\n($ million per quarter)",
                                         labels = dollar_format())) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(title = "A small directed volume can still cost a lot — when the compensation price is high",
       subtitle = paste0("Each bar is the energy generated because units were directed on; the line is what the quarter's directions cost the market:\n",
                         "compensation plus additional claims and expert fees, net of the units' own market earnings (the amount recovered under NER 3.15.8,\n",
                         "the same cost concept AEMO reports in Quarterly Energy Dynamics)."),
       x = NULL, fill = NULL, colour = NULL) +
  THEME + theme(legend.text = element_text(size = 8))
ggsave(file.path(OUT, "F2_volume_cost.png"), p2, width = 9.8, height = 5.4, dpi = 300)
cat("  saved F2_volume_cost.png\n")

# ----------------------------------------------------------------------------
# F2b — Does directed VOLUME move with directed TIME? Three stacked panels on
#       a shared clock (no dual axis): the two series, then their ratio —
#       average output while directed (MW = energy / directed hours). A flat
#       ratio means the two series carry the same information; a level break
#       means they do not.
# ----------------------------------------------------------------------------
cat("\n[F2b] volume vs share of time directed ...\n")

f2b <- copy(f2)
f2b[, q_hours := as.numeric(difftime(shift(qdate, type = "lead",
                                           fill = as.Date("2025-01-01")),
                                     qdate, units = "hours"))]
f2b[, avg_mw := directed_gwh * 1e3 / (pct_time_directed * q_hours)]
r_all  <- f2b[, cor(directed_gwh, pct_time_directed)]
r_2224 <- f2b[qdate >= as.Date("2022-01-01"), cor(directed_gwh, pct_time_directed)]
cat(sprintf("  corr(volume, share of time): full sample %.2f | 2022-24 %.2f\n", r_all, r_2224))
fwrite(f2b[, .(qdate, directed_gwh, pct_time_directed, q_hours, avg_mw)],
       file.path(OUT, "F2b_volume_vs_time.csv"))

PANELS <- c("Energy generated under direction (thousand MWh)",
            "Share of the quarter under an active direction (%)",
            "Average output while directed (MW = energy / directed hours)")
pan <- rbindlist(list(
  f2b[, .(qdate, panel = PANELS[1], value = directed_gwh)],
  f2b[, .(qdate, panel = PANELS[2], value = pct_time_directed * 100)],
  f2b[, .(qdate, panel = PANELS[3], value = avg_mw)]))
pan[, panel := factor(panel, levels = PANELS)]

p2b <- ggplot(pan, aes(x = qdate, y = value, fill = panel)) +
  geom_col(width = 70, alpha = 0.9, show.legend = FALSE) +
  facet_wrap(~ panel, ncol = 1, scales = "free_y", strip.position = "top") +
  scale_fill_manual(values = setNames(unname(COL[c("cost", "prize", "grey")]), PANELS)) +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(title = "Since 2022, directed volume is just directed time — before, it wasn't",
       subtitle = sprintf(paste0(
         "Top two panels: the two series (correlation %.2f from 2022 on; %.2f over the full sample). Bottom: their ratio.\n",
         "In 2021 a directed hour produced 115-200 MW (several units pinned on); from 2022 it produces a steady 50-75 MW\n",
         "(one or two units at minimum load) — so after the synchronous condensers entered, volume adds nothing beyond time."),
         r_2224, r_all),
       x = NULL, y = NULL) +
  THEME + theme(strip.text = element_text(size = 9, hjust = 0),
                panel.spacing.y = unit(0.8, "lines"))
ggsave(file.path(OUT, "F2b_volume_vs_time.png"), p2b, width = 9.8, height = 7.6, dpi = 300)
cat("  saved F2b_volume_vs_time.png\n")

# ============================================================================
# F3 — How ESSENTIAL the directed units are. A unit is "essential" in a 5-minute
#      interval if NO combination of the other available South Australian
#      synchronous units can meet the system-strength requirement without it.
#      Two essential tiers + not-essential (ex-ante tier dropped: invisible).
# ============================================================================
cat("\n[F3] how essential the directed units are ...\n")

STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
piv <- as.data.table(readRDS(file.path(DESC3, "pivotality_panel.rds")))
pl <- rbindlist(lapply(STATIONS, function(s) data.table(
  SETTLEMENTDATE = piv$SETTLEMENTDATE, station = s,
  short_n1 = as.integer(piv$short_n1),
  piv    = as.integer(piv[[paste0("piv_",    s)]]),
  piv_n1 = as.integer(piv[[paste0("piv_n1_", s)]]))))

STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips")
evd <- as.data.table(readRDS(file.path(PARSE, "direction_events.rds")))[!is.na(duid)]
dmap <- c(TORRB35="TORRB3", TORRB46="TORRB4", MINTARO1="MINTARO")
for (b in names(dmap)) evd[duid==b, duid := dmap[[b]]]
evd[, station := STAT[as.character(duid)]]
evd <- evd[!is.na(station)]
evd[, dur_hrs := as.numeric(difftime(cancellation_time, effective_time, units="hours"))]
evd <- evd[is.finite(dur_hrs) & dur_hrs > 0]
evd[, first_intv := (floor(as.numeric(effective_time)/300)+1)*300]
evd[, last_intv  :=  floor(as.numeric(cancellation_time)/300)*300]
evd <- evd[last_intv >= first_intv]
exp_is <- rbindlist(lapply(seq_len(nrow(evd)), function(i)
  data.table(station = evd$station[i],
             secs = seq.int(evd$first_intv[i], evd$last_intv[i], by = 300L))))
exp_is[, SETTLEMENTDATE := as.POSIXct(secs, origin="1970-01-01", tz="Etc/GMT-10")]
dir_is <- unique(exp_is[, .(SETTLEMENTDATE, station)])

d <- merge(dir_is, pl, by = c("SETTLEMENTDATE","station"))
d <- d[year(SETTLEMENTDATE) %in% 2022:2024]
cat(sprintf("  directed unit-intervals with coverage: %d\n", nrow(d)))

TIERS <- c("Pivotal now — no other units could replace it",
           "Pivotal to stay secure if the largest unit suddenly failed",
           "Not pivotal — other units could have met the requirement")
d[, tier := fcase(piv == 1L,                     TIERS[1],
                  piv_n1 == 1L & short_n1 == 0L, TIERS[2],
                  default =                      TIERS[3])]   # ex-ante folded into not-pivotal
d[, tier := factor(tier, levels = TIERS)]

f3y <- d[, .(n = .N), by = .(grp = as.character(year(SETTLEMENTDATE)), tier)]
f3a <- d[, .(grp = "All years", n = .N), by = tier]
f3 <- rbindlist(list(f3y, f3a), use.names = TRUE)
f3[, grp := factor(grp, levels = c("2022","2023","2024","All years"))]
f3[, share := n / sum(n), by = grp]
fwrite(dcast(f3, grp ~ tier, value.var = "n", fill = 0), file.path(OUT, "F3_pivotal_composition.csv"))

NOTE <- paste0(
  "How a unit is judged pivotal: in each 5-minute interval we ask whether the South Australian system-strength requirement\n",
  "could be met by some combination of the other synchronous units available at that time. If no such combination works, the\n",
  "unit is pivotal. Red counts the units actually running; orange additionally requires the grid to survive losing its single\n",
  "largest unit (the security standard AEMO operates to). Grey = a feasible combination existed without the unit.")
p3 <- ggplot(f3, aes(x = grp, y = share, fill = tier)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = ifelse(share >= 0.04, percent(share, accuracy = 1), "")),
            position = position_stack(vjust = 0.5), size = 3.4, colour = "white") +
  scale_fill_manual(values = setNames(unname(COL[c("t1","t2","t3")]), TIERS)) +
  scale_y_continuous(labels = percent) +
  guides(fill = guide_legend(ncol = 1)) +
  labs(title = "Most directed units are pivotal — there was no other way to meet the requirement",
       subtitle = paste0("Each directed unit-interval placed in the strongest sense in which it was pivotal. ",
                         "2022-2024, ", format(nrow(d), big.mark=","), " directed unit-intervals."),
       x = NULL, y = "Share of directed unit-intervals", fill = NULL, caption = NOTE) +
  THEME + theme(legend.position = "bottom", legend.text = element_text(size = 8))
ggsave(file.path(OUT, "F3_pivotal_composition.png"), p3, width = 10, height = 6, dpi = 300)
cat("  tier counts:\n"); print(d[, .N, by = tier][order(-N)])
cat("  saved F3_pivotal_composition.png\n")

# ============================================================================
# F4 — Rebidding across three groups of unit-days. Price measure is now the
#      SHARE OF CAPACITY OFFERED AT VERY HIGH PRICES (a fixed $/MWh threshold
#      far above any gas fuel cost) — a transparent, model-free "withholding"
#      proxy that needs no SRMC. Computed once from the bid cache and cached.
# ============================================================================
cat("\n[F4] rebidding across three groups of days ...\n")

SYNC <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG","QPS5",
          "MINTARO","DRYCGT1","DRYCGT2","DRYCGT3","BARKIPS1")
PRICE_CACHE <- file.path(OUT, "_price_daily.rds")
if (!file.exists(PRICE_CACHE)) {
  cat("  building per-unit-day offer-price metrics from bid cache (one-time)...\n")
  months <- sprintf("%d%02d", rep(2022:2024, each=12), rep(1:12, times=3))
  months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]
  price_one <- function(M) {
    b <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))))
    b <- b[BIDTYPE == "ENERGY" & DUID %in% SYNC]
    if (!nrow(b)) return(NULL)
    b[, td := as.IDate(INTERVAL_DATETIME)]
    setorder(b, DUID, INTERVAL_DATETIME, OFFERDATETIME)
    bb <- b[, .SD[.N], by = .(DUID, INTERVAL_DATETIME)]          # binding (final) offer per interval
    bdo <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))))
    bdo <- bdo[BIDTYPE == "ENERGY" & DUID %in% SYNC]
    bdo[, td := as.IDate(SETTLEMENTDATE)]
    bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, td)]$V1]   # binding price ladder
    pb  <- bdo[, c("DUID","td", paste0("PRICEBAND",1:10)), with = FALSE]
    bb  <- merge(bb, pb, by = c("DUID","td"))
    qmat <- as.matrix(bb[, paste0("BANDAVAIL",1:10), with = FALSE]); qmat[is.na(qmat)] <- 0
    pmat <- as.matrix(bb[, paste0("PRICEBAND",1:10), with = FALSE])
    bb[, q_tot    := rowSums(qmat)]
    bb[, q_hi300  := rowSums(qmat * (pmat >= 300))]
    bb[, q_hi5000 := rowSums(qmat * (pmat >= 5000))]
    bb[, .(share_above_300  = sum(q_hi300)  / pmax(sum(q_tot), 1),
           share_above_5000 = sum(q_hi5000) / pmax(sum(q_tot), 1)), by = .(DUID, td)]
  }
  pday <- rbindlist(lapply(months, function(M){cat("   ",M,"\n"); price_one(M)}))
  saveRDS(pday, PRICE_CACHE)
} else {
  pday <- readRDS(PRICE_CACHE)
}

r <- as.data.table(readRDS(file.path(DESC3, "rebid_pivotality_daily.rds")))
r <- merge(r, pday, by = c("DUID","td"), all.x = TRUE)

SAMP <- c("Every day\n(all units)", "Days the unit was\ndirected on",
          "Directed days when the\nunit was pivotal")
mk <- function(dt, lab) dt[, .(
  sample = lab,
  `Times the unit revised its offer during the day`              = mean(n_versions, na.rm=TRUE),
  `Capacity pulled back during the day (MW; <0 = added)`         = mean(quan_withheld, na.rm=TRUE),
  `Share of capacity offered above $300/MWh (well above fuel cost)` = mean(share_above_300, na.rm=TRUE),
  n = .N)]
f4w <- rbindlist(list(
  mk(r,                                    SAMP[1]),
  mk(r[directed_day == 1],                 SAMP[2]),
  mk(r[directed_day == 1 & piv_share > 0], SAMP[3])))
fwrite(f4w, file.path(OUT, "F4_rebidding_by_sample.csv"))
cat("  sample means:\n"); print(f4w)

f4 <- melt(f4w, id.vars = c("sample","n"), variable.name = "metric", value.name = "value")
f4[, metric := factor(metric, levels = unique(metric))]
f4[, lbl := ifelse(grepl("Share", as.character(metric)), percent(value, accuracy = 0.1),
                   sprintf("%.1f", value))]
# bake each group's size into the x-axis label (avoids on-bar n= text overlapping bars)
nlab <- setNames(sprintf("%s\nn = %s", f4w$sample, format(f4w$n, big.mark=",")), f4w$sample)
f4[, sample := factor(nlab[as.character(sample)], levels = nlab[SAMP])]

p4 <- ggplot(f4, aes(x = sample, y = value, fill = sample)) +
  geom_hline(yintercept = 0, colour = "grey80", linewidth = 0.3) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(data = f4[value >= 0], aes(label = lbl), vjust = -0.4, size = 2.9) +
  geom_text(data = f4[value <  0], aes(label = lbl), vjust =  1.3, size = 2.9) +
  facet_wrap(~ metric, scales = "free_y", labeller = label_wrap_gen(width = 32)) +
  scale_fill_manual(values = unname(COL[c("t3","t2","t1")])) +
  scale_y_continuous(expand = expansion(mult = c(0.18, 0.18))) +
  labs(title = "What units do as they become more pivotal: they offer more capacity at very high prices",
       subtitle = paste0("Averages per unit-day for pivotal-capable South Australian gas units, across three groups of days. ",
                         "Capacity 'pulled back' goes negative on direction days because directed units are required to add output."),
       x = NULL, y = NULL) +
  THEME + theme(axis.text.x = element_text(size = 8))
ggsave(file.path(OUT, "F4_rebidding_by_sample.png"), p4, width = 11.5, height = 4.8, dpi = 300)
cat("  saved F4_rebidding_by_sample.png\n")

# ============================================================================
# F5 — RUN-UP TO A DIRECTION. For each direction episode, follow the offer for
#      its directed intervals from the FIRST version submitted to the LAST
#      version submitted before the direction is issued. x = hours before issue.
#      Two scopes (the two "versions"): the full directed period vs its first
#      hour. Two metrics: capacity offered, and share offered above $300/MWh.
#      Episode-mapping logic reused from 05_directions/B_rebid_runup.R; recomputed
#      with the $300 threshold (no SRMC) and cached to _runup_versions.rds.
# ============================================================================
cat("\n[F5] run-up to a direction ...\n")

ONSET_N  <- 12L                       # "first hour" = first 12 five-minute intervals
bcols    <- paste0("BANDAVAIL", 1:10)
pcols    <- paste0("PRICEBAND",  1:10)
RUNUP_CACHE <- file.path(OUT, "_runup_versions.rds")

ep <- as.data.table(readRDS(file.path("outputs/direction_rebid", "episodes.rds")))
ep[, `:=`(tau_s  = as.numeric(tau),
          s_grid = (floor(as.numeric(s) / 300) + 1) * 300,
          c_grid =  floor(as.numeric(c) / 300) * 300)]
ep <- ep[c_grid >= s_grid]
ep[, onset_hi := s_grid + (ONSET_N - 1) * 300]
DIRECTED_DUIDS <- unique(ep$duid)

if (!file.exists(RUNUP_CACHE)) {
  cat("  building per-version run-up table from bid cache (one-time, ~10 min)...\n")
  months <- sprintf("%d%02d", rep(2022:2024, each=12), rep(1:12, times=3))
  months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months))) &
                    file.exists(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds",  months)))]
  process_runup <- function(M) {
    b <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))))
    b <- b[BIDTYPE == "ENERGY" & DUID %in% DIRECTED_DUIDS,
           c("DUID","TRADINGDATE","INTERVAL_DATETIME","OFFERDATETIME","MAXAVAIL", bcols), with = FALSE]
    if (!nrow(b)) return(NULL)
    bdo <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))))
    bdo <- bdo[BIDTYPE == "ENERGY" & DUID %in% DIRECTED_DUIDS]
    bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
    ladder <- bdo[, c("DUID","SETTLEMENTDATE", pcols), with = FALSE]
    setnames(ladder, "SETTLEMENTDATE", "TRADINGDATE")
    b <- merge(b, ladder, by = c("DUID","TRADINGDATE"), all.x = TRUE)
    bmat <- as.matrix(b[, bcols, with = FALSE]); bmat[is.na(bmat)] <- 0
    pmat <- as.matrix(b[, pcols, with = FALSE])
    above <- pmat >= 300; above[is.na(above)] <- FALSE
    b[, total_offer := rowSums(bmat)]
    b[, above_offer := rowSums(bmat * above)]
    b[, isecs := as.numeric(INTERVAL_DATETIME)]
    b[, c(bcols, pcols) := NULL]
    bo <- b[, .(DUID, istart = isecs, iend = isecs, OFFERDATETIME, MAXAVAIL, total_offer, above_offer, isecs)]
    setkey(bo, DUID, istart, iend)
    epk <- ep[, .(duid, episode_id, instruction, tau_s, g_lo = s_grid, g_hi = c_grid, onset_hi)]
    setkey(epk, duid, g_lo, g_hi)
    m <- foverlaps(bo, epk, by.x = c("DUID","istart","iend"),
                   by.y = c("duid","g_lo","g_hi"), nomatch = 0L)
    if (!nrow(m)) return(NULL)
    m[, onset := isecs <= onset_hi]
    whole <- m[, .(scope="whole", sum_mx=sum(MAXAVAIL), n_g=.N,
                   sum_above=sum(above_offer), sum_total=sum(total_offer)), by=.(episode_id, OFFERDATETIME)]
    onset <- m[onset == TRUE, .(scope="onset", sum_mx=sum(MAXAVAIL), n_g=.N,
                   sum_above=sum(above_offer), sum_total=sum(total_offer)), by=.(episode_id, OFFERDATETIME)]
    rbind(whole, onset)
  }
  agg <- rbindlist(lapply(months, function(M){cat("   ",M,"\n"); process_runup(M)}))
  ver <- agg[, .(sum_mx=sum(sum_mx), n_g=sum(n_g), sum_above=sum(sum_above), sum_total=sum(sum_total)),
             by = .(scope, episode_id, OFFERDATETIME)]
  ver <- merge(ver, ep[, .(episode_id, duid, instruction, tau_s)], by = "episode_id")
  ver[, mean_maxavail   := sum_mx / n_g]
  ver[, share_above_300 := fifelse(sum_total > 0, sum_above / sum_total, NA_real_)]
  ver[, delta_h := (as.numeric(OFFERDATETIME) - tau_s) / 3600]
  saveRDS(ver, RUNUP_CACHE)
} else {
  ver <- as.data.table(readRDS(RUNUP_CACHE))
}

# WITHIN-EPISODE change vs each episode's first bid version. A pooled LEVEL trace is
# confounded by which episodes enter each Delta-bin (composition); the baseline-relative
# change is the correct "first version -> last version" object and is the same
# normalisation B_rebid_runup.R uses for MAXAVAIL.
RB <- c(-24,-18,-12,-9,-6,-3,0)        # coarser near issue: final 3h pooled (few versions there)
vv <- ver[delta_h >= -24 & delta_h < 0 & instruction %in% c("Synchronise","Remain")]
vv[, base_mx := mean_maxavail[which.min(OFFERDATETIME)],   by = .(scope, episode_id)]
vv[, base_sh := share_above_300[which.min(OFFERDATETIME)], by = .(scope, episode_id)]
vv[, rel_mx := mean_maxavail   - base_mx]
vv[, rel_sh := (share_above_300 - base_sh) * 100]      # percentage points
vv[, dbin := cut(delta_h, breaks = RB, right = FALSE)]
vv[, dmid := (RB[as.integer(dbin)] + RB[as.integer(dbin)+1]) / 2]
tr <- vv[!is.na(dbin), .(
  `Capacity offered (MW)`       = mean(rel_mx, na.rm = TRUE),
  `Share above $300/MWh (pts)`  = mean(rel_sh, na.rm = TRUE),
  n = .N), by = .(scope, instruction, dmid)]
trm <- melt(tr, id.vars = c("scope","instruction","dmid","n"),
            variable.name = "metric", value.name = "value")
trm[, scope := factor(fifelse(scope == "whole", "Full directed period",
                              "First hour of the directed period"),
                      levels = c("Full directed period","First hour of the directed period"))]
trm[, instruction := factor(fifelse(instruction == "Synchronise",
                                    "Directed to start up (Synchronise)",
                                    "Directed to keep running (Remain)"),
                            levels = c("Directed to start up (Synchronise)",
                                       "Directed to keep running (Remain)"))]
trm[, metric := factor(metric, levels = c("Capacity offered (MW)","Share above $300/MWh (pts)"))]
fwrite(tr[order(scope, instruction, dmid)], file.path(OUT, "F5_runup.csv"))

p5 <- ggplot(trm, aes(x = dmid, y = value, colour = instruction)) +
  geom_hline(yintercept = 0, colour = "grey80", linewidth = 0.3) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey45") +
  annotate("text", x = -0.3, y = Inf, label = "direction\nissued", size = 2.5,
           colour = "grey45", hjust = 1.05, vjust = 1.2, lineheight = 0.85) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.5) +
  facet_grid(metric ~ scope, scales = "free_y", switch = "y") +
  scale_colour_manual(values = c("Directed to start up (Synchronise)" = unname(COL["prize"]),
                                  "Directed to keep running (Remain)"   = unname(COL["cost"]))) +
  scale_x_continuous(breaks = c(-24,-18,-12,-6,0)) +
  labs(title = "In the run-up to a direction, units lift the share of their offer priced at high levels",
       subtitle = "Average change vs each episode's first bid version, up to issue (0). Above zero = raised. Both panels: y = change since the first version.",
       x = "Hours before the direction is issued", y = NULL, colour = NULL) +
  THEME + theme(strip.placement = "outside", strip.text.y = element_text(size = 8.5),
                legend.text = element_text(size = 8))
ggsave(file.path(OUT, "F5_runup.png"), p5, width = 10.5, height = 6.4, dpi = 300)
cat("  run-up trace (pre-issue, by scope x instruction):\n"); print(tr[order(scope, instruction, dmid)])
cat("  saved F5_runup.png\n")

# ============================================================================
# readout
# ============================================================================
readout <- c(
  "# Proposal descriptive figures — readout",
  paste0("Generated: ", Sys.Date()),
  "",
  "| Figure | File | Plain-language takeaway |",
  "|---|---|---|",
  "| F1 | F1_compensation_vs_fuel.png | The compensation price is fixed to the previous 12 months of electricity prices, so it keeps paying 2022 levels into 2024 — the margin over fuel cost (rent) is small in the 2022 fuel spike and large once fuel falls. |",
  "| F2 | F2_volume_cost.png | A small directed volume in late-2022/early-2023 was the costliest per MWh, because each MWh was paid the inflated compensation price (F1's high-rent period). Cost = the NER 3.15.8 recovery amount (compensation + additional compensation + expert fees, net of retained market earnings) — the same cost concept AEMO plots in QED. The CSV also holds pct_time_directed (share of the quarter under an active direction; reproduces AEMO's QED percentage-of-time series to ~0.1pp): directed time peaks in Q4-21 and Q4-23/Q1-24, not in the costliest-per-MWh window — cost tracks the lagged compensation price, not direction frequency. |",
  "| F2b | F2b_volume_vs_time.png | Directed volume vs share of the quarter under direction, plus their ratio (average MW while directed). From 2022 on the two series are interchangeable (r = 0.98; a steady 50-75 MW whenever directed); in 2021 the same directed hour carried 115-200 MW. The regime break coincides with the synchronous condensers entering service. |",
  "| F3 | F3_pivotal_composition.png | Most directed units were pivotal: no combination of the other available SA units could meet the requirement without them. |",
  "| F4 | F4_rebidding_by_sample.png | As units go from ordinary days to direction days to pivotal-direction days, they offer a rising share of capacity at very high prices. |",
  "| F5 | F5_runup.png | In the run-up to a direction (first bid version -> last version before issue), units shift more of their offered capacity above $300/MWh; shown for the full directed period and its first hour, Synchronise vs Remain. |",
  "",
  "All figures: 300 dpi PNG. Companion CSV holds the plotted data for each.",
  "Coverage: F1 and F3 use the 2022-2024 panel; F2 uses the full 2021-2024 directions cost record. F5 run-up uses the 2022-2024 bid cache.")
writeLines(readout, file.path(OUT, "readout.md"))

cat("\n=== Done. Outputs in", OUT, "===\n")
for (f in sort(list.files(OUT))) cat("  ", f, "\n")
