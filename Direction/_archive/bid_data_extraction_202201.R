#!/usr/bin/env Rscript
# =====================================================================
# ONE-MONTH EXTRACT + GATE 3 — 202201
#
# A0 (DISCOVER): get the SA-region generator DUID list from DUDETAILSUMMARY.
# A  (EXTRACT) : stream + CACHE the FULL bid slice for ALL SA generators --
#                all columns, all bid versions, all bid types, typed, with a
#                true 5-min INTERVAL_DATETIME. Decompression cost is identical
#                whether you keep 4 units or 40, so keep the whole region once.
# B  (ANALYSE) : read cache, compute out-of-merit MW for TORRB (Gate 3).
#
# Bid tables have NO region column, so SA units are selected by DUID list.
# =====================================================================
suppressMessages(library(data.table))
source("sa_directions_feasibility.R")            # download helpers (guarded; no auto-run)

REGION <- "SA1"; M <- "202201"
TORRB  <- c("TORRB1","TORRB2","TORRB3","TORRB4")   # Gate-3 subset
CACHE  <- "./bid_cache"; dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
WRITE_CSV <- FALSE                                 # set TRUE for portable .csv copies (large for full SA)
aemo_dt <- function(x) as.POSIXct(x, format="%Y/%m/%d %H:%M:%S", tz="Australia/Brisbane")

## ---- streaming reader (Windows-safe; never extracts the raw file) ----
# `bidtype`, when supplied, is folded directly into the line-match regex (DUID
# immediately precedes BIDTYPE in both BIDOFFERPERIOD and BIDDAYOFFER), so FCAS
# rows are never retained in `keep` at all -- not just dropped after the fact.
# This is the fix for the 100+min / 18GB run that never finished: that run's
# regex matched DUID only, so it buffered ~4x more text (all ~9 bid types) than
# needed before the final fread(). A fread()-the-whole-extracted-file approach
# was also tried and rejected -- Windows fread() can't mmap a 52GB file ("not
# enough contiguous virtual memory"), so the connection-based scan stays, just
# filtered tighter.
read_zip_streaming <- function(zip, keys, chunk = 2e5L, bidtype = NULL) {
  inner <- utils::unzip(zip, list = TRUE)$Name[1]
  con <- unz(zip, inner); open(con, "rt"); on.exit(close(con))
  pat <- if (is.null(bidtype)) paste0(",(", paste(keys, collapse = "|"), "),")
         else paste0(",(", paste(keys, collapse = "|"), "),", bidtype, ",")
  cols <- NULL; keep <- list()
  repeat {
    ln <- readLines(con, n = chunk, warn = FALSE)
    if (!length(ln)) break
    if (is.null(cols)) { ih <- ln[startsWith(ln, "I,")]
      if (length(ih)) cols <- trimws(strsplit(ih[1], ",")[[1]])[-(1:4)] }
    m <- ln[grepl(pat, ln)]
    if (length(m)) keep[[length(keep)+1L]] <- m
  }
  if (!length(keep)) return(list(cols = cols, d = data.table()))
  d <- fread(text = paste(unlist(keep), collapse = "\n"),
             header = FALSE, sep = ",", fill = TRUE, colClasses = "character", showProgress = FALSE)
  list(cols = cols, d = d)
}
fetch_zip_paths <- function(table, yyyymm, cache = RAW_CACHE) {
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)
  dest <- file.path(cache, sprintf("PUBLIC_DVD_%s_%s010000.zip", table, yyyymm))
  if (download_try(url_dvd(table, yyyymm), dest)) dest else character(0)
}
stream_named <- function(dvd_name, yyyymm, keys, bidtype = NULL) {
  z <- fetch_zip_paths(dvd_name, yyyymm); stopifnot(length(z) > 0)
  fr <- read_zip_streaming(z[1], keys, bidtype = bidtype); stopifnot(!is.null(fr$cols))
  d <- fr$d; if (!nrow(d)) return(d)
  d <- d[V1 == "D"][, 5:(4 + length(fr$cols)), with = FALSE]; setnames(d, fr$cols); d[]
}
type_table <- function(d) {
  numc <- intersect(c(paste0("BANDAVAIL",1:10), paste0("PRICEBAND",1:10),
                      "MAXAVAIL","FIXEDLOAD","RAMPUPRATE","RAMPDOWNRATE","ENABLEMENTMIN",
                      "ENABLEMENTMAX","LOWBREAKPOINT","HIGHBREAKPOINT","PASAAVAILABILITY",
                      "PERIODID","VERSIONNO","DAILYENERGYCONSTRAINT","MINIMUMLOAD",
                      "T1","T2","T3","T4","RRP","INTERVENTION","RUNNO"), names(d))
  if (length(numc)) d[, (numc) := lapply(.SD, as.numeric), .SDcols = numc]
  dtc <- intersect(c("TRADINGDATE","SETTLEMENTDATE","OFFERDATETIME","OFFERDATE","LASTCHANGED",
                     "REBID_EVENT_TIME","REBID_AWARE_TIME","REBID_DECISION_TIME"), names(d))
  for (cc in dtc) set(d, j = cc, value = aemo_dt(d[[cc]]))
  d[]
}

## ---- timing/memory instrumentation helper ----
TIMING <- list()
peak_mb <- function(g) sum(g[, ncol(g)])     # "max used (Mb)" column, both Ncells+Vcells
rds_size_mb <- function(path) if (file.exists(path)) file.info(path)$size / 1024^2 else NA_real_
stage <- function(name, dl_expr, run_expr) {
  gc(reset = TRUE)
  t_dl  <- system.time(dl_val <- eval.parent(substitute(dl_expr)))
  t_run <- system.time(run_val <- eval.parent(substitute(run_expr)))
  g <- gc()
  TIMING[[name]] <<- list(download_s = t_dl["elapsed"], stream_s = t_run["elapsed"],
                          total_s = t_dl["elapsed"] + t_run["elapsed"], peak_mb = peak_mb(g))
  cat(sprintf("\n[TIME] %-22s download=%6.1fs  stream/parse/cache=%6.1fs  peak_mem=%6.1f MB\n",
              name, t_dl["elapsed"], t_run["elapsed"], peak_mb(g)))
  run_val
}

## =====================================================================
## A0 — discover SA-region generator DUIDs (cached)
## =====================================================================
get_sa_duids <- function(yyyymm) {
  rds <- file.path(CACHE, sprintf("SA_DUIDS_%s.rds", yyyymm))
  if (file.exists(rds)) return(readRDS(rds))
  dud <- stream_named("DUDETAILSUMMARY", yyyymm, REGION)      # has REGIONID; grep keeps ,SA1, rows
  stopifnot(nrow(dud) > 0, "DISPATCHTYPE" %in% names(dud))
  sa <- sort(unique(dud[REGIONID == REGION & DISPATCHTYPE == "GENERATOR", DUID]))
  saveRDS(sa, rds); sa
}
SA_DUIDS <- stage("DUDETAILSUMMARY (discover)",
                  fetch_zip_paths("DUDETAILSUMMARY", M),
                  get_sa_duids(M))
cat("SA generator DUIDs found:", length(SA_DUIDS), "\n"); print(SA_DUIDS)
stopifnot(all(TORRB %in% SA_DUIDS))     # sanity: Torrens B must be in the SA set

## =====================================================================
## A — EXTRACT + CACHE full bid slice for ALL SA generators (costly; once)
## =====================================================================
extract_bids <- function(dvd_name, label, keys) {
  rds <- file.path(CACHE, sprintf("%s_%s.rds", label, M))
  if (file.exists(rds)) { message("cache hit: ", rds); return(readRDS(rds)) }
  bt <- if (label %in% c("BIDOFFERPERIOD", "BIDDAYOFFER")) "ENERGY" else NULL
  message("streaming ", label, " ", M, " for ", length(keys), " SA DUIDs",
          if (!is.null(bt)) paste0(" (BIDTYPE=", bt, " filtered at the line-match stage)"), " ...")
  d <- stream_named(dvd_name, M, keys, bidtype = bt); stopifnot(nrow(d) > 0)
  d <- type_table(d)
  if ("BIDTYPE" %in% names(d)) d <- d[BIDTYPE == "ENERGY"]   # defensive; regex above already guarantees this
  if (label == "BIDOFFERPERIOD") {                 # reconstruct true 5-min interval-ending time
    d[, td := as.IDate(TRADINGDATE)]
    d[, INTERVAL_DATETIME := aemo_dt(paste(format(td, "%Y/%m/%d"), "00:00:00")) + PERIODID*300L]
  }
  if (label == "BIDDAYOFFER") d[, td := as.IDate(SETTLEMENTDATE)]
  saveRDS(d, rds)
  if (WRITE_CSV) fwrite(d, sub("\\.rds$", ".csv", rds))
  message("cached ", nrow(d), " rows -> ", rds)
  d
}

per_raw <- stage("BIDOFFERPERIOD (volume)",
                 fetch_zip_paths("BIDPEROFFER", M),
                 extract_bids("BIDPEROFFER", "BIDOFFERPERIOD", SA_DUIDS))
day_raw <- stage("BIDDAYOFFER (price)",
                 fetch_zip_paths("BIDDAYOFFER", M),
                 extract_bids("BIDDAYOFFER", "BIDDAYOFFER", SA_DUIDS))
prc_rds <- file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))
prc <- stage("DISPATCHPRICE",
            fetch_zip_paths("DISPATCHPRICE", M),
            if (file.exists(prc_rds)) readRDS(prc_rds) else {
              p <- type_table(stream_named("DISPATCHPRICE", M, REGION)); saveRDS(p, prc_rds); p })

cat("\n--- cached bid slice (one month, ALL SA generators, ENERGY only) ---\n")
cat("PER rows:", nrow(per_raw), " units:", uniqueN(per_raw$DUID),
    " bidtypes:", paste(unique(per_raw$BIDTYPE), collapse=","), "\n")
cat("DAY rows:", nrow(day_raw), " units:", uniqueN(day_raw$DUID), "\n")

cat("\n--- on-disk cache sizes (.rds) ---\n")
for (lbl in c("BIDOFFERPERIOD", "BIDDAYOFFER", "DISPATCHPRICE")) {
  p <- file.path(CACHE, sprintf("%s_%s.rds", lbl, M))
  cat(sprintf("  %-16s %6.2f MB\n", lbl, rds_size_mb(p)))
}

cat("\n--- timing summary (system.time, wall-clock) ---\n")
print(rbindlist(lapply(names(TIMING), function(n) c(stage = n, TIMING[[n]])), fill = TRUE))

## =====================================================================
## B — ANALYSIS: out-of-merit MW for TORRB (reads cache; cheap)
## =====================================================================
per <- per_raw[DUID %in% TORRB & BIDTYPE == "ENERGY"]
day <- day_raw[DUID %in% TORRB & BIDTYPE == "ENERGY"]
prc <- prc[(is.na(INTERVENTION) | INTERVENTION == 0)]

per <- per[order(OFFERDATETIME)][, .SD[.N], by = .(DUID, td, INTERVAL_DATETIME, PERIODID)]
day <- day[order(OFFERDATE, VERSIONNO)][, .SD[.N], by = .(DUID, td)]

pcols <- paste0("BANDAVAIL",1:10); qcols <- paste0("PRICEBAND",1:10)
perL <- melt(per, id.vars=c("DUID","td","INTERVAL_DATETIME"), measure.vars=pcols,
             variable.name="band", value.name="avail"); perL[, band := as.integer(sub("BANDAVAIL","",band))]
dayL <- melt(day, id.vars=c("DUID","td"), measure.vars=qcols,
             variable.name="band", value.name="price"); dayL[, band := as.integer(sub("PRICEBAND","",band))]
b <- dayL[perL, on=.(DUID, td, band)]

prc[, interval := SETTLEMENTDATE]; prc <- unique(prc, by = "interval")
b <- prc[, .(interval, rrp = RRP)][b, on = .(interval = INTERVAL_DATETIME)]
cat("\nna_rrp by day (should be ~0):\n"); print(b[, .(na_rrp = round(mean(is.na(rrp)),3)), by = td][order(td)])

oom_int <- b[, .(oom_mw = sum(avail[price > rrp], na.rm=TRUE),
                 offered_mw = sum(avail, na.rm=TRUE)), by = .(DUID, td, interval)]
oom_per <- oom_int[, .(oom_mw = sum(oom_mw), offered_mw = sum(offered_mw)), by = .(interval, td)]
daily   <- oom_per[, .(oom_mw = mean(oom_mw), offered_mw = mean(offered_mw)), by = td]
setorder(daily, td)
cat("\n--- daily out-of-merit MW (TORRB1-4), Jan 2022 ---\n"); print(daily)
fwrite(daily, "gate3_oom_202201.csv")
