#!/usr/bin/env Rscript
# =============================================================================
# SA directions / directed-price project -- week-one feasibility checks (R).
#
# Confirms, on PUBLIC NEMWEB data, that the project is executable before
# committing. Three checks:
#
#   CHECK 1  Does an SA system-strength direction publish a "what-if"
#            (intervention pricing) run, so directed VOLUME is reconstructable?
#            directed_mw = TOTALCLEARED(physical run) - TOTALCLEARED(pricing run)
#   CHECK 2  Is the directed-MWh record unit-level (not just a regional total)?
#   CHECK 3  Build the rolling 90th-percentile directed price d_t and show the
#            2022 spike entering/leaving the trailing 12-month window.
#
# Data layer pulls MMSDM monthly archive files directly:
#   https://nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/{YYYY}/
#     MMSDM_{YYYY}_{MM}/MMSDM_Historical_Data_SQLLoader/DATA/
#     PUBLIC_DVD_{TABLE}_{YYYYMM}010000.zip
# and parses AEMO's C/I/D CSV format off the 'I' (info) row column names.
#
# Analysis functions are PURE (operate on data.tables) and validated offline:
#   Rscript sa_directions_feasibility.R --selftest
# Run with no flag for the live checks (needs internet to nemweb.com.au).
#
# [VERIFY] items below affect sign/convention correctness, not feasibility.
#
# Requires: data.table  (install.packages("data.table"))
# =============================================================================

suppressWarnings(suppressMessages(library(data.table)))
options(timeout = 600)  # MMSDM files / slow links

# YYYYMM integer sequence (inclusive). Defined before CONFIG (used by DT_MONTHS).
seq_yyyymm <- function(from, to) {
  fy <- from %/% 100; fm <- from %% 100
  ty <- to %/% 100;   tm <- to %% 100
  months <- seq((fy*12 + (fm-1)), (ty*12 + (tm-1)))
  as.integer((months %/% 12) * 100 + (months %% 12) + 1)
}

# ----------------------------------------------------------------------------- #
# CONFIG
# ----------------------------------------------------------------------------- #
RAW_CACHE <- "./nem_cache"
POLITE_DELAY <- 1.5                 # seconds between downloads; raise if throttled
REGION    <- "SA1"
TZ        <- "Australia/Brisbane"   # AEST, no DST -- matches NEM market time

# Months (YYYYMM) to pull for each check.
EVENT_MONTHS <- c(202401L)                 # CHECK 1: a month dense with SA directions
GRAN_MONTHS  <- c(202310L, 202401L)        # CHECK 2: two quarters' representative months
DT_MONTHS    <- seq_yyyymm(202101L, 202412L) # CHECK 3: long window for d_t (defined below)

# Candidate SA synchronous units in the system-strength combinations (paper Fig 1 /
# AEMO Transfer Limit Advice). [VERIFY] against the NEM Registration & Exemption
# List and the combination-table version applying in each period.
SA_SYNC_DUIDS <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
                   "QPS1","QPS2","QPS3","QPS4","QPS5","DRYCGT1","DRYCGT2",
                   "DRYCGT3","LADBROK1","LADBROK2","MINTARO")

# SRMC proxy inputs for the withholding demo. [VERIFY]/calibrate.
HEAT_RATES <- setNames(
  ifelse(SA_SYNC_DUIDS == "PPCCGT", 7.0,
         ifelse(grepl("^TORRB", SA_SYNC_DUIDS), 10.5, 11.5)), SA_SYNC_DUIDS)
GAS_PRICE_GJ <- 12.0   # Adelaide STTM proxy; pull GASBBSTTM for the real series
VOM <- 5.0

# [VERIFY] which INTERVENTION value is the PHYSICAL (outturn) run that includes
# the direction. AEMO convention: intervention/physical run = 1, pricing/what-if
# run = 0. reconstruct_directed_volume() self-checks the sign.
PHYSICAL_RUN_INTERVENTION <- 1L
PRICING_RUN_INTERVENTION  <- 0L

# SA system-strength constraint IDs in DISPATCHCONSTRAINT. [VERIFY] the exact
# CONSTRAINTID pattern from GENCONDATA / AEMO constraint naming for the period.
SS_CONSTRAINT_REGEX <- "S_.*(SYST|SS).*STR|S_SS|SYSTEM.?STRENGTH"

# ----------------------------------------------------------------------------- #
# small helpers
# ----------------------------------------------------------------------------- #
parse_dt <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  as.POSIXct(as.character(x), format = "%Y/%m/%d %H:%M:%S", tz = TZ)
}

# ----------------------------------------------------------------------------- #
# AEMO MMSDM reader  (download + parse the C/I/D format)
# ----------------------------------------------------------------------------- #
# Handles BOTH archive naming conventions:
#   old (<= 2024-07):  PUBLIC_DVD_{TABLE}_{YYYYMM}010000.zip            (single file)
#   new (>= 2024-08):  PUBLIC_ARCHIVE#{TABLE}#FILE{NN}#{YYYYMM}010000.zip
# Notes on the new scheme:
#   - '#' MUST be encoded as %23 in the URL, or HTTP drops everything after the
#     first '#' as a fragment (a naive rename fails silently for this reason).
#   - large tables split across FILE01, FILE02, ...; download all parts & concat.
#   - [VERIFY] same DATA/ directory and the part-count for large tables (e.g.
#     DISPATCHLOAD) against the live listing you are looking at.
mmsdm_dir <- function(yyyymm) {
  yyyy <- substr(as.character(yyyymm), 1, 4); mm <- substr(as.character(yyyymm), 5, 6)
  sprintf(paste0("https://nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/%s/",
                 "MMSDM_%s_%s/MMSDM_Historical_Data_SQLLoader/DATA/"), yyyy, yyyy, mm)
}
url_archive <- function(table, yyyymm, part)        # %23 encodes '#'; server decodes once
  sprintf("%sPUBLIC_ARCHIVE%%23%s%%23FILE%02d%%23%s010000.zip",
          mmsdm_dir(yyyymm), table, part, as.character(yyyymm))
url_dvd <- function(table, yyyymm)
  sprintf("%sPUBLIC_DVD_%s_%s010000.zip", mmsdm_dir(yyyymm), table, as.character(yyyymm))

download_try <- function(url, dest, retries = 3L, backoff = 4L) {
  if (file.exists(dest) && file.info(dest)$size > 100) return(TRUE)   # cache hit
  for (k in seq_len(retries)) {
    suppressWarnings(try(utils::download.file(url, dest, mode = "wb", quiet = TRUE),
                         silent = TRUE))
    if (file.exists(dest) && file.info(dest)$size > 100) return(TRUE)
    if (k < retries) Sys.sleep(backoff * k)   # modest: 4s, 8s
  }
  FALSE
}

# Extract a zip and read its CSV into a raw C/I/D data.table (NULL if not a zip).
read_zip_raw <- function(zip, cache) {
  csvs <- tryCatch(utils::unzip(zip, exdir = cache), error = function(e) character(0))
  csv  <- csvs[grepl("\\.csv$", csvs, ignore.case = TRUE)][1]
  if (is.na(csv)) return(NULL)
  fread(csv, header = FALSE, fill = TRUE, sep = ",",
        colClasses = "character", showProgress = FALSE)
}

# Combine raw parts: column names from the first part carrying an 'I' row, applied
# to all 'D' rows across every part. Continuation parts need not repeat the header.
# PURE -- selftested.
combine_parts <- function(raws) {
  raws <- raws[!vapply(raws, is.null, logical(1))]
  if (!length(raws)) stop("no parts to combine")
  cols <- NULL
  for (r in raws) { ir <- r[V1 == "I"][1]
  if (nrow(ir)) { cols <- as.character(unlist(ir))[-(1:4)]; break } }
  if (is.null(cols)) stop("no 'I' header row found in any part")
  cols <- cols[!is.na(cols) & cols != ""]
  d <- rbindlist(lapply(raws, function(r) r[V1 == "D", 5:(4 + length(cols)), with = FALSE]),
                 fill = TRUE)
  setnames(d, cols); d[]
}

# Pick the naming scheme by month (AEMO switched at 2024-08) so the common case
# goes straight to the URL that exists -- no wasted 404 round-trips. The other
# scheme is tried only as a cheap single-attempt fallback. DVD files keep their
# original local name so any PUBLIC_DVD zips already in your cache are reused.
read_mmsdm <- function(table, yyyymm, cache = RAW_CACHE) {
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)
  
  fetch_archive <- function(first_retries) {
    raws <- list(); part <- 1L
    repeat {
      dest <- file.path(cache, sprintf("ARCHIVE_%s_%s_FILE%02d.zip", table, yyyymm, part))
      rt <- if (part == 1L) first_retries else 3L
      if (!download_try(url_archive(table, yyyymm, part), dest, retries = rt)) break
      r <- read_zip_raw(dest, cache); if (is.null(r)) break
      raws[[length(raws) + 1]] <- r; part <- part + 1L; Sys.sleep(POLITE_DELAY)
    }
    raws
  }
  fetch_dvd <- function(retries) {
    dest <- file.path(cache, sprintf("PUBLIC_DVD_%s_%s010000.zip", table, yyyymm))
    if (!download_try(url_dvd(table, yyyymm), dest, retries = retries)) return(list())
    r <- read_zip_raw(dest, cache); if (is.null(r)) return(list())
    list(r)
  }
  
  archive_first <- as.integer(yyyymm) >= 202408L
  raws <- if (archive_first) fetch_archive(3L) else fetch_dvd(3L)
  if (!length(raws))                              # cheap fallback: single attempt
    raws <- if (archive_first) fetch_dvd(1L) else fetch_archive(1L)
  if (!length(raws))
    stop(sprintf("no PUBLIC_ARCHIVE or PUBLIC_DVD file for %s %s", table, yyyymm))
  combine_parts(raws)
}

# Skip-and-warn on a bad month rather than aborting the whole pull.
read_mmsdm_many <- function(table, months, cache = RAW_CACHE) {
  out <- lapply(months, function(m)
    tryCatch(read_mmsdm(table, m, cache),
             error = function(e) {
               message(sprintf("  [skip %s %s] %s", table, m, conditionMessage(e)))
               NULL }))
  rbindlist(out[!vapply(out, is.null, logical(1))], fill = TRUE)
}

# ----------------------------------------------------------------------------- #
# PURE ANALYSIS FUNCTIONS  (validated offline)
# ----------------------------------------------------------------------------- #

# Trailing-window percentile of spot -> directed price d_t. Evaluated at `by`
# spacing (daily is plenty for feasibility). Uses findInterval on sorted times,
# so the window (t-window_days, t] is a contiguous slice -> O(n log n).
# [VERIFY] price granularity (5-min dispatch vs 30-min trading) and any weighting
# against AEMO's directions compensation methodology.
build_rolling_percentile <- function(price, value_col = "RRP",
                                     time_col = "SETTLEMENTDATE",
                                     window_days = 365, q = 0.90, by = "day") {
  p <- data.table(t = parse_dt(price[[time_col]]),
                  v = as.numeric(price[[value_col]]))
  p <- p[is.finite(v)][order(t)]
  tt  <- as.numeric(p$t)
  win <- window_days * 86400
  evald <- seq(min(p$t) + win, max(p$t), by = by)
  rbindlist(lapply(evald, function(e) {
    en <- as.numeric(e); st <- en - win
    lo <- findInterval(st, tt) + 1L      # first index with t > st
    hi <- findInterval(en, tt)           # last index with t <= en
    if (hi < lo) return(data.table(SETTLEMENTDATE = e, d_t = NA_real_, n_obs = 0L))
    data.table(SETTLEMENTDATE = e,
               d_t = as.numeric(quantile(p$v[lo:hi], q, names = FALSE, type = 7)),
               n_obs = hi - lo + 1L)
  }))
}

# Flag SETTLEMENTDATEs carrying both a physical and a pricing run; return the RRP
# from each run so a what-if run's existence and the price wedge are visible.
detect_intervention_intervals <- function(dp) {
  d <- copy(dp)
  d[, SETTLEMENTDATE := parse_dt(SETTLEMENTDATE)]
  d[, INTERVENTION := as.integer(INTERVENTION)]
  d[, RRP := as.numeric(RRP)]
  nrun <- d[, .(nr = uniqueN(INTERVENTION)), by = SETTLEMENTDATE]
  iv <- nrun[nr > 1, SETTLEMENTDATE]
  if (length(iv) == 0L) return(data.table())
  w <- dcast(d[SETTLEMENTDATE %in% iv], SETTLEMENTDATE ~ INTERVENTION,
             value.var = "RRP", fun.aggregate = function(x) x[1])
  setnames(w, setdiff(names(w), "SETTLEMENTDATE"),
           paste0("RRP_run", setdiff(names(w), "SETTLEMENTDATE")))
  w[]
}

# directed_mw per DUID-interval = physical-run cleared - pricing-run cleared.
reconstruct_directed_volume <- function(dl) {
  d <- copy(dl)
  d[, SETTLEMENTDATE := parse_dt(SETTLEMENTDATE)]
  d[, INTERVENTION := as.integer(INTERVENTION)]
  d[, TOTALCLEARED := as.numeric(TOTALCLEARED)]
  phys <- d[INTERVENTION == PHYSICAL_RUN_INTERVENTION,
            .(SETTLEMENTDATE, DUID, cleared_physical = TOTALCLEARED)]
  pric <- d[INTERVENTION == PRICING_RUN_INTERVENTION,
            .(SETTLEMENTDATE, DUID, cleared_pricing = TOTALCLEARED)]
  out <- merge(phys, pric, by = c("SETTLEMENTDATE", "DUID"))
  out[, directed_mw := cleared_physical - cleared_pricing]
  if (nrow(out)) {
    pos <- mean(out$directed_mw > 0)
    if (pos < 0.4)
      message(sprintf("  [warn] only %.0f%% of directed_mw > 0 -- PHYSICAL_RUN_INTERVENTION may be backwards. [VERIFY]", 100 * pos))
  }
  out[]
}

# Share of a unit's offered MW priced above SRMC -- withholding proxy.
# Real pipeline: join BIDDAYOFFER PRICEBAND1..10 to BIDPEROFFER BANDAVAIL1..10 on
# SETTLEMENTDATE+DUID+BIDTYPE='ENERGY', using the version applied at dispatch
# (DISPATCHOFFERTRK). [VERIFY] rebid versioning.
withholding_measure <- function(bids, srmc_by_duid) {
  b <- copy(bids)
  b[, srmc  := srmc_by_duid[DUID]]
  b[, above := as.numeric(as.numeric(price) > srmc)]
  g <- b[, .(offered_mw = sum(as.numeric(bandavail)),
             offered_above = sum(as.numeric(bandavail) * above)), by = DUID]
  g[, withhold_share := offered_above / fifelse(offered_mw == 0, NA_real_, offered_mw)]
  g[]
}

# CHECK 2: collapse to DUID x quarter to confirm unit-level granularity.
quarterly_unit_directed <- function(directed) {
  d <- copy(directed)
  d[, SETTLEMENTDATE := parse_dt(SETTLEMENTDATE)]
  d[, quarter := paste0(year(SETTLEMENTDATE), "Q", quarter(SETTLEMENTDATE))]
  d[, directed_mwh := pmax(directed_mw, 0) / 12]   # 5-min MW -> MWh
  d[, .(directed_mwh = sum(directed_mwh)), by = .(quarter, DUID)][
    order(quarter, -directed_mwh)]
}

# ---- POST-2019 PATH: system-strength directions carry NO what-if run ----------
# Identify intervals where an SA system-strength constraint binds (nonzero shadow
# price) in DISPATCHCONSTRAINT.
binding_ss_intervals <- function(dispatchconstraint, ss_regex = SS_CONSTRAINT_REGEX) {
  d <- copy(dispatchconstraint)
  d[, SETTLEMENTDATE := parse_dt(SETTLEMENTDATE)]
  d[, MARGINALVALUE := as.numeric(MARGINALVALUE)]
  ss <- d[grepl(ss_regex, CONSTRAINTID, ignore.case = TRUE) & abs(MARGINALVALUE) > 0]
  unique(ss[, .(SETTLEMENTDATE, CONSTRAINTID, MARGINALVALUE)])[order(SETTLEMENTDATE)]
}

# Candidate synchronous unit output during SS-binding intervals -- the directed-
# output PROXY when no what-if run exists. Refine with an out-of-merit flag (unit
# offered above RRP yet dispatched) and validate against AEMO billing reports.
directed_output_when_ss_binds <- function(dispatchload, binding, duids) {
  dl <- copy(dispatchload)
  dl[, SETTLEMENTDATE := parse_dt(SETTLEMENTDATE)]
  dl[, TOTALCLEARED := as.numeric(TOTALCLEARED)]
  dl <- dl[DUID %in% duids & TOTALCLEARED > 0 &
             SETTLEMENTDATE %in% binding$SETTLEMENTDATE]
  dl[, .(online_intervals = .N, output_mwh = sum(TOTALCLEARED) / 12),
     by = DUID][order(-output_mwh)]
}

# ----------------------------------------------------------------------------- #
# LIVE RUN
# ----------------------------------------------------------------------------- #
run_live <- function() {
  cat("CHECK 1 -- what-if run exists + directed-volume reconstruction\n")
  dp <- read_mmsdm_many("DISPATCHPRICE", EVENT_MONTHS)[REGIONID == REGION]
  iv <- detect_intervention_intervals(dp)
  cat(sprintf("  intervention intervals in month: %d\n", nrow(iv)))
  dl <- read_mmsdm_many("DISPATCHLOAD", EVENT_MONTHS)[DUID %in% SA_SYNC_DUIDS]
  dv <- reconstruct_directed_volume(dl)
  dvn <- dv[abs(directed_mw) > 0.1]
  cat(sprintf("  unit-interval rows with nonzero directed_mw: %d\n", nrow(dvn)))
  if (nrow(dvn)) {
    cat("  sample (units directed; dual-run present == what-if published):\n")
    print(head(dvn[order(-directed_mw)], 8))
    cat("  -> CHECK 1 PASSES if rows above are nonempty for SA synchronous units.\n")
  }
  
  cat("\nCHECK 2 -- unit-level granularity across two quarters\n")
  dl2 <- read_mmsdm_many("DISPATCHLOAD", GRAN_MONTHS)[DUID %in% SA_SYNC_DUIDS]
  qu  <- quarterly_unit_directed(reconstruct_directed_volume(dl2))
  print(head(qu, 20))
  cat(sprintf("  distinct DUIDs with directed energy: %d -> PASSES if > 1.\n",
              uniqueN(qu$DUID)))
  
  cat("\nCHECK 3 -- rolling 90th-percentile directed price d_t\n")
  dpl <- read_mmsdm_many("DISPATCHPRICE", DT_MONTHS)[REGIONID == REGION]
  dt  <- build_rolling_percentile(dpl, q = 0.90, window_days = 365, by = "day")
  fwrite(dt, "d_t_SA_90pct_365d.csv")
  png("d_t_plot.png", width = 1000, height = 400)
  plot(dt$SETTLEMENTDATE, dt$d_t, type = "l",
       main = "SA directed price d_t: trailing-365d 90th percentile of RRP",
       xlab = "", ylab = "$/MWh"); grid()
  dev.off()
  cat("  saved d_t_SA_90pct_365d.csv and d_t_plot.png -- inspect the 2023 step-down\n")
}

# ----------------------------------------------------------------------------- #
# SELFTEST  (synthetic data + synthetic AEMO file; offline)
# ----------------------------------------------------------------------------- #
synth_price <- function(n_days = 1100, seed = 0) {
  set.seed(seed)
  idx <- seq(as.POSIXct("2021-01-01 00:00", tz = TZ), by = "5 min",
             length.out = n_days * 288)
  i   <- seq_along(idx)
  base  <- 60 + 25 * sin(i * 2 * pi / 288)
  noise <- pmax(rnorm(length(idx), 0, 30), -50)
  rrp   <- pmin(pmax(base + noise, -1000), 16600)
  spike <- idx >= as.POSIXct("2022-05-01", tz = TZ) &
    idx <= as.POSIXct("2022-09-15", tz = TZ)
  rrp   <- rrp + spike * runif(length(idx), 200, 900)
  data.table(SETTLEMENTDATE = idx, REGIONID = "SA1", RRP = rrp, INTERVENTION = 0L)
}

synth_dispatchload <- function() {
  t0 <- as.POSIXct("2024-01-15 18:00:00", tz = TZ)
  ts <- c(t0, t0 + 300)
  rows <- rbindlist(lapply(ts, function(t) rbindlist(lapply(
    list(c("TORRB1", 120, 0), c("PPCCGT", 200, 80), c("DRYCGT1", 0, 0)),
    function(r) data.table(
      SETTLEMENTDATE = rep(t, 2), DUID = r[1],
      INTERVENTION = c(PHYSICAL_RUN_INTERVENTION, PRICING_RUN_INTERVENTION),
      TOTALCLEARED = c(as.numeric(r[2]), as.numeric(r[3])))))))
  rows
}

synth_bids <- function() {
  srmc_torr <- HEAT_RATES["TORRB1"] * GAS_PRICE_GJ + VOM
  rbind(
    data.table(DUID = "TORRB1", price = c(0, srmc_torr + 200, 12000),
               bandavail = c(20, 100, 80)),
    data.table(DUID = "DRYCGT1", price = c(40, 60), bandavail = c(50, 50)))
}

# Write a synthetic AEMO C/I/D CSV to exercise the parser.
write_synth_aemo <- function(path) {
  lines <- c(
    "C,NEMP.WORLD,DISPATCHPRICE,,,2024/01/16,,,,",
    "I,DISPATCH,PRICE,4,SETTLEMENTDATE,REGIONID,RRP,INTERVENTION",
    'D,DISPATCH,PRICE,4,2024/01/15 18:00:00,SA1,300,1',
    'D,DISPATCH,PRICE,4,2024/01/15 18:00:00,SA1,95,0',
    'D,DISPATCH,PRICE,4,2024/01/15 18:05:00,SA1,300,1',
    'D,DISPATCH,PRICE,4,2024/01/15 18:05:00,SA1,95,0',
    "C,END OF REPORT,4")
  writeLines(lines, path)
}

run_selftest <- function() {
  cat("SELFTEST (synthetic data + synthetic AEMO file, offline)\n\n")
  
  cat("[0] AEMO C/I/D parser + multi-part (PUBLIC_ARCHIVE FILE01/FILE02) combine\n")
  mk <- function(txt) fread(text = txt, header = FALSE, fill = TRUE, sep = ",",
                            colClasses = "character")
  part1 <- mk(paste("C,NEMP.WORLD,DISPATCHPRICE,,,,",
                    "I,DISPATCH,PRICE,4,SETTLEMENTDATE,REGIONID,RRP,INTERVENTION",
                    "D,DISPATCH,PRICE,4,2024/08/15 18:00:00,SA1,300,1",
                    "D,DISPATCH,PRICE,4,2024/08/15 18:00:00,SA1,95,0", sep = "\n"))
  part2 <- mk(paste("C,NEMP.WORLD,DISPATCHPRICE,,,,",   # continuation: no I header
                    "D,DISPATCH,PRICE,4,2024/08/15 18:05:00,SA1,300,1",
                    "D,DISPATCH,PRICE,4,2024/08/15 18:05:00,SA1,95,0",
                    "C,END OF REPORT,4", sep = "\n"))
  pa <- combine_parts(list(part1, part2))
  print(pa)
  stopifnot(identical(names(pa), c("SETTLEMENTDATE", "REGIONID", "RRP", "INTERVENTION")),
            nrow(pa) == 4L)
  cat("    -> PASS: names off part-1 'I' row; D rows combined across both parts\n\n")
  
  cat("[1] rolling 90th-percentile d_t with an injected 2022 spike\n")
  dt <- build_rolling_percentile(synth_price(), q = 0.90, window_days = 365)
  dt <- dt[!is.na(d_t)]
  early <- median(dt[SETTLEMENTDATE < as.POSIXct("2022-05-01", tz = TZ), d_t])
  peak  <- dt[which.max(d_t)]
  late  <- median(dt[SETTLEMENTDATE > as.POSIXct("2023-10-01", tz = TZ), d_t])
  cat(sprintf("    pre-spike median = %7.1f\n    peak             = %7.1f on %s\n    post-rolloff med = %7.1f\n",
              early, peak$d_t, as.Date(peak$SETTLEMENTDATE), late))
  stopifnot(peak$d_t > early, early > 0, late < peak$d_t)
  cat("    -> PASS: rolling window reproduces spike-in / spike-out mechanics\n\n")
  
  cat("[2] intervention detection + directed-volume reconstruction\n")
  dl <- synth_dispatchload()
  dp <- rbind(
    data.table(SETTLEMENTDATE = unique(dl$SETTLEMENTDATE), REGIONID = "SA1",
               RRP = 300, INTERVENTION = 1L),
    data.table(SETTLEMENTDATE = unique(dl$SETTLEMENTDATE), REGIONID = "SA1",
               RRP = 95,  INTERVENTION = 0L))
  iv <- detect_intervention_intervals(dp)
  dv <- reconstruct_directed_volume(dl)
  print(iv); print(dv)
  stopifnot(nrow(iv) == 2L,
            dv[DUID == "PPCCGT", directed_mw][1] == 120,
            dv[DUID == "TORRB1", directed_mw][1] == 120)
  cat("    -> PASS: dual run detected; directed_mw = physical - pricing\n\n")
  
  cat("[3] quarterly unit-level granularity (CHECK 2 logic)\n")
  qu <- quarterly_unit_directed(dv)
  print(qu)
  stopifnot(uniqueN(qu$DUID) >= 2L)
  cat("    -> PASS: directed energy resolved per DUID per quarter\n\n")
  
  cat("[4] withholding measure\n")
  srmc <- setNames(HEAT_RATES * GAS_PRICE_GJ + VOM, names(HEAT_RATES))
  wm <- withholding_measure(synth_bids(), srmc)
  print(wm)
  stopifnot(wm[DUID == "TORRB1", withhold_share] > wm[DUID == "DRYCGT1", withhold_share])
  cat(sprintf("    -> PASS: withholding unit flagged (%.0f%% vs %.0f%% above SRMC)\n\n",
              100 * wm[DUID == "TORRB1", withhold_share],
              100 * wm[DUID == "DRYCGT1", withhold_share]))
  
  cat("[5] constraint-based reconstruction (post-2019 path)\n")
  bc <- data.table(
    SETTLEMENTDATE = rep(c("2024/01/15 18:00:00", "2024/01/15 18:05:00"), each = 2),
    CONSTRAINTID   = c("S_SS_NIL_1", "S_X_THERMAL", "S_SS_NIL_1", "S_X_THERMAL"),
    MARGINALVALUE  = c(-12.5, 0, -9.0, 0))
  bi <- binding_ss_intervals(bc, ss_regex = "S_SS")
  dlc <- data.table(
    SETTLEMENTDATE = rep(c("2024/01/15 18:00:00", "2024/01/15 18:05:00"), each = 2),
    DUID = c("TORRB1", "ADPBA1G", "TORRB1", "ADPBA1G"),
    INTERVENTION = 0L, TOTALCLEARED = c(120, 5, 110, 4))
  do <- directed_output_when_ss_binds(dlc, bi, SA_SYNC_DUIDS)
  print(bi); print(do)
  stopifnot(nrow(bi) == 2L, do[DUID == "TORRB1", output_mwh] > 0,
            !("ADPBA1G" %in% do$DUID))
  cat("    -> PASS: SS-binding intervals found; candidate-unit output flagged\n\n")
  
  cat("ALL SELFTESTS PASSED -- analysis logic + AEMO parser correct.\n",
      "Run without --selftest where R can reach nemweb.com.au for the live checks.\n", sep = "")
}

# ----------------------------------------------------------------------------- #
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--selftest" %in% args) {
    run_selftest()
  } else {
    tryCatch(run_live(), error = function(e) {
      message(sprintf("[live pull failed] %s", conditionMessage(e)))
      message("If a network error, you are off-NEM-network/behind a proxy. ",
              "Run --selftest to validate logic; run live where nemweb.com.au is reachable.")
      quit(status = 1)
    })
  }
}