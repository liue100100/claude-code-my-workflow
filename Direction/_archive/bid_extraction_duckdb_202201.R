#!/usr/bin/env Rscript
# =====================================================================
# DuckDB-ACCELERATED EXTRACT — 202201
#
# Replaces the unz()-streaming scan of the big bid tables (BIDOFFERPERIOD,
# BIDDAYOFFER) with: download -> decompress to disk -> DuckDB filter scan
# -> unlink the extracted CSV -> type + cache. This is now safe because
# disk is no longer the binding constraint (~205GB free) -- the
# "never extract to disk" rule in bid_extraction_handoff.md was a
# workaround for a disk limit that no longer applies. Never holds more
# than one month's extracted CSV at a time (unlinked immediately after
# DuckDB has read it).
#
# A0 (DUID discovery) and DISPATCHPRICE are small (tens of MB) and were
# never the bottleneck, so they keep using the original unz()-streaming
# helpers -- copied unchanged from gate3_202201_unz_archive.R (that file
# is NOT modified or sourced-and-executed; copying the small helper defs
# here avoids re-running its full top-to-bottom pipeline).
#
# Schema guard (still applies, per the brief): read the I-row header,
# assert PERIODID range is 48 or 288, stop with a clear message rather
# than silently mis-parsing an unrecognised month layout.
# =====================================================================
suppressMessages({ library(data.table); library(duckdb); library(DBI) })
source("sa_directions_feasibility.R")            # download helpers (guarded; no auto-run)

REGION <- "SA1"; M <- "202201"
TORRB  <- c("TORRB1","TORRB2","TORRB3","TORRB4")
CACHE  <- "./bid_cache"; dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
EXTRACT_DIR <- "./extract_tmp"; dir.create(EXTRACT_DIR, showWarnings = FALSE, recursive = TRUE)
aemo_dt <- function(x) as.POSIXct(x, format="%Y/%m/%d %H:%M:%S", tz="Australia/Brisbane")

## ---- unchanged helpers (copied from gate3_202201_unz_archive.R; used only for
## the small A0/DISPATCHPRICE tables, not the bottleneck) ----
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
get_sa_duids <- function(yyyymm) {
  rds <- file.path(CACHE, sprintf("SA_DUIDS_%s.rds", yyyymm))
  if (file.exists(rds)) return(readRDS(rds))
  dud <- stream_named("DUDETAILSUMMARY", yyyymm, REGION)
  stopifnot(nrow(dud) > 0, "DISPATCHTYPE" %in% names(dud))
  sa <- sort(unique(dud[REGIONID == REGION & DISPATCHTYPE == "GENERATOR", DUID]))
  saveRDS(sa, rds); sa
}

rds_size_mb <- function(path) if (file.exists(path)) file.info(path)$size / 1024^2 else NA_real_
TIMING <- list()

## =====================================================================
## A0 — discover SA-region generator DUIDs (cached; unz()-streaming, small)
## =====================================================================
t_a0 <- system.time(SA_DUIDS <- get_sa_duids(M))
cat(sprintf("[TIME] A0 discover SA DUIDs: %.1fs\n", t_a0["elapsed"]))
cat("SA generator DUIDs found:", length(SA_DUIDS), "\n")
stopifnot(all(TORRB %in% SA_DUIDS))

## =====================================================================
## NEW — download -> decompress -> DuckDB filter -> cache (the bid tables)
## =====================================================================
extract_bids_duckdb <- function(dvd_name, label, keys, bidtype = "ENERGY") {
  rds <- file.path(CACHE, sprintf("%s_%s.rds", label, M))
  if (file.exists(rds)) {
    message("cache hit: ", rds)
    d <- readRDS(rds)
    return(list(d = d, timing = list(download_s = 0, decompress_s = 0, duckdb_s = 0, total_s = 0)))
  }

  # 1. download
  t_dl <- system.time({ z <- fetch_zip_paths(dvd_name, M); stopifnot(length(z) > 0) })

  # 2. decompress the single member to disk (one month at a time; unlinked right after use)
  inner <- utils::unzip(z, list = TRUE)$Name[1]
  tmp <- file.path(EXTRACT_DIR, inner)
  t_decompress <- system.time({
    utils::unzip(z, files = inner, exdir = EXTRACT_DIR, overwrite = TRUE)
  })
  size_gb <- file.info(tmp)$size / 1024^3
  message(sprintf("decompressed %s (%.2f GB)", inner, size_gb))

  # Read the I-row header to get column names (same convention as the unz() version:
  # 4 leading metadata fields dropped). Schema guard: stop on an unrecognised layout
  # rather than silently mis-parsing.
  hdr_lines <- readLines(tmp, n = 5)
  ih <- hdr_lines[startsWith(hdr_lines, "I,")]
  if (!length(ih)) { unlink(tmp); stop(sprintf("No 'I' header row found in %s -- unrecognised file layout, stopping.", inner)) }
  cols <- trimws(strsplit(ih[1], ",")[[1]])[-(1:4)]
  required <- if (label == "BIDOFFERPERIOD") c("DUID", "BIDTYPE", "TRADINGDATE", "PERIODID")
              else c("DUID", "BIDTYPE", "SETTLEMENTDATE", "OFFERDATE", "VERSIONNO")
  missing <- setdiff(required, cols)
  if (length(missing)) {
    unlink(tmp)
    stop(sprintf("Schema guard failed for %s %s: missing expected columns [%s] -- layout has changed, stopping rather than mis-parsing. Header cols were: %s",
                 label, M, paste(missing, collapse = ", "), paste(cols, collapse = ", ")))
  }

  ncols <- length(cols) + 4
  col_names <- paste0("c", 0:(ncols - 1))
  columns_map <- paste0("{", paste0(sprintf("'%s':'VARCHAR'", col_names), collapse = ", "), "}")
  duid_col    <- col_names[match("DUID", cols) + 4]
  bidtype_col <- col_names[match("BIDTYPE", cols) + 4]

  path_sql <- gsub("\\\\", "/", normalizePath(tmp))
  keys_sql <- paste0("'", keys, "'", collapse = ", ")
  bt_clause <- if (!is.null(bidtype)) sprintf(" AND %s = '%s'", bidtype_col, bidtype) else ""

  # 3. DuckDB does the heavy scan; R only receives the small filtered result
  con <- dbConnect(duckdb::duckdb())
  query <- sprintf("
    SELECT * FROM read_csv('%s', header=false, delim=',', quote='\"', escape='\"',
                            all_varchar=true, null_padding=true, auto_detect=false, columns=%s)
    WHERE c0 = 'D' AND %s IN (%s)%s
  ", path_sql, columns_map, duid_col, keys_sql, bt_clause)
  t_duckdb <- system.time({ d <- as.data.table(dbGetQuery(con, query)) })
  dbDisconnect(con, shutdown = TRUE)
  stopifnot(nrow(d) > 0)

  # never hold more than one month's extracted CSV on disk
  unlink(tmp)

  # 4. drop the 4 leading metadata columns, name the rest (same convention as before)
  d <- d[, 5:ncols, with = FALSE]; setnames(d, cols)
  d <- type_table(d)

  if (label == "BIDOFFERPERIOD") {
    mx <- max(d$PERIODID, na.rm = TRUE)
    if (!(mx %in% c(48, 288))) {
      stop(sprintf("Schema guard failed: max(PERIODID)=%s for %s %s is neither 48 nor 288 -- unrecognised interval layout, stopping rather than mis-parsing.", mx, label, M))
    }
    if (mx != 288) {
      stop(sprintf("max(PERIODID)=%s indicates the legacy 30-min layout, not the validated 5-min BIDOFFERPERIOD schema -- stopping; this month needs separate handling.", mx))
    }
    if ("INTERVAL_DATETIME" %in% names(d)) {
      message("INTERVAL_DATETIME already present in source -- skipping reconstruction")
    } else {
      d[, td := as.IDate(TRADINGDATE)]
      d[, INTERVAL_DATETIME := aemo_dt(paste(format(td, "%Y/%m/%d"), "00:00:00")) + PERIODID * 300L]
    }
  }
  if (label == "BIDDAYOFFER") d[, td := as.IDate(SETTLEMENTDATE)]

  saveRDS(d, rds)
  message("cached ", nrow(d), " rows -> ", rds)

  list(d = d, timing = list(download_s = t_dl["elapsed"], decompress_s = t_decompress["elapsed"],
                             duckdb_s = t_duckdb["elapsed"],
                             total_s = t_dl["elapsed"] + t_decompress["elapsed"] + t_duckdb["elapsed"]))
}

res_per <- extract_bids_duckdb("BIDPEROFFER", "BIDOFFERPERIOD", SA_DUIDS)
TIMING[["BIDOFFERPERIOD (volume)"]] <- res_per$timing
per_raw <- res_per$d
cat(sprintf("[TIME] %-22s download=%6.1fs  decompress=%6.1fs  duckdb=%6.1fs  total=%6.1fs\n",
            "BIDOFFERPERIOD", res_per$timing$download_s, res_per$timing$decompress_s,
            res_per$timing$duckdb_s, res_per$timing$total_s))

res_day <- extract_bids_duckdb("BIDDAYOFFER", "BIDDAYOFFER", SA_DUIDS)
TIMING[["BIDDAYOFFER (price)"]] <- res_day$timing
day_raw <- res_day$d
cat(sprintf("[TIME] %-22s download=%6.1fs  decompress=%6.1fs  duckdb=%6.1fs  total=%6.1fs\n",
            "BIDDAYOFFER", res_day$timing$download_s, res_day$timing$decompress_s,
            res_day$timing$duckdb_s, res_day$timing$total_s))

## DISPATCHPRICE — small table, keeps the original unz()-streaming path
prc_rds <- file.path(CACHE, sprintf("DISPATCHPRICE_%s.rds", M))
t_prc <- system.time({
  prc <- if (file.exists(prc_rds)) readRDS(prc_rds) else {
    p <- type_table(stream_named("DISPATCHPRICE", M, REGION)); saveRDS(p, prc_rds); p }
})
cat(sprintf("[TIME] %-22s total=%6.1fs (unz()-streaming, unchanged)\n", "DISPATCHPRICE", t_prc["elapsed"]))

cat("\n--- cached bid slice (one month, ALL SA generators, ENERGY only) ---\n")
cat("PER rows:", nrow(per_raw), " units:", uniqueN(per_raw$DUID),
    " bidtypes:", paste(unique(per_raw$BIDTYPE), collapse=","), "\n")
cat("DAY rows:", nrow(day_raw), " units:", uniqueN(day_raw$DUID), "\n")

cat("\n--- on-disk cache sizes (.rds) ---\n")
for (lbl in c("BIDOFFERPERIOD", "BIDDAYOFFER", "DISPATCHPRICE")) {
  p <- file.path(CACHE, sprintf("%s_%s.rds", lbl, M))
  cat(sprintf("  %-16s %8.3f MB\n", lbl, rds_size_mb(p)))
}

cat("\n--- timing summary (DuckDB path) ---\n")
print(rbindlist(lapply(names(TIMING), function(n) c(stage = n, TIMING[[n]])), fill = TRUE))

## =====================================================================
## PART B — Gate-3 analysis on the NEW DuckDB-derived cache
## =====================================================================
gate3_oom <- function(per_raw, day_raw, prc_raw, units) {
  per <- per_raw[DUID %in% units & BIDTYPE == "ENERGY"]
  day <- day_raw[DUID %in% units & BIDTYPE == "ENERGY"]
  prc <- prc_raw[(is.na(INTERVENTION) | INTERVENTION == 0)]

  per <- per[order(OFFERDATETIME)][, .SD[.N], by = .(DUID, td, INTERVAL_DATETIME, PERIODID)]
  day <- day[order(OFFERDATE, VERSIONNO)][, .SD[.N], by = .(DUID, td)]

  pcols <- paste0("BANDAVAIL",1:10); qcols <- paste0("PRICEBAND",1:10)
  perL <- melt(per, id.vars=c("DUID","td","INTERVAL_DATETIME"), measure.vars=pcols,
               variable.name="band", value.name="avail"); perL[, band := as.integer(sub("BANDAVAIL","",band))]
  dayL <- melt(day, id.vars=c("DUID","td"), measure.vars=qcols,
               variable.name="band", value.name="price"); dayL[, band := as.integer(sub("PRICEBAND","",band))]
  b <- dayL[perL, on=.(DUID, td, band)]

  prc2 <- copy(prc); prc2[, interval := SETTLEMENTDATE]; prc2 <- unique(prc2, by = "interval")
  b <- prc2[, .(interval, rrp = RRP)][b, on = .(interval = INTERVAL_DATETIME)]
  na_rrp <- b[, .(na_rrp = round(mean(is.na(rrp)),3)), by = td][order(td)]

  oom_int <- b[, .(oom_mw = sum(avail[price > rrp], na.rm=TRUE),
                   offered_mw = sum(avail, na.rm=TRUE)), by = .(DUID, td, interval)]
  oom_per <- oom_int[, .(oom_mw = sum(oom_mw), offered_mw = sum(offered_mw)), by = .(interval, td)]
  daily   <- oom_per[, .(oom_mw = mean(oom_mw), offered_mw = mean(offered_mw)), by = td]
  setorder(daily, td)
  list(daily = daily, na_rrp = na_rrp)
}

new_res <- gate3_oom(per_raw, day_raw, prc, TORRB)
cat("\nna_rrp by day, NEW (DuckDB) cache (should be ~0):\n"); print(new_res$na_rrp)
cat("\n--- daily out-of-merit MW (TORRB1-4), Jan 2022 -- NEW DuckDB cache ---\n")
print(new_res$daily)
cat(sprintf("\nSummary (new): offered range = %.1f - %.1f MW; OOM range = %.1f - %.1f MW\n",
            min(new_res$daily$offered_mw), max(new_res$daily$offered_mw),
            min(new_res$daily$oom_mw), max(new_res$daily$oom_mw)))

## =====================================================================
## ACCEPTANCE TEST — compare against the trusted unz() reference
## (regenerated fresh from the pre-existing TORRB-only validated cache,
## not hardcoded numbers, so this is a true reference-implementation
## comparison)
## =====================================================================
ref_per_path <- "bid_cache/_old_torrb_only_backup/BIDOFFERPERIOD_202201.rds"
ref_day_path <- "bid_cache/_old_torrb_only_backup/BIDDAYOFFER_202201.rds"
if (file.exists(ref_per_path) && file.exists(ref_day_path)) {
  ref_per_raw <- readRDS(ref_per_path)[BIDTYPE == "ENERGY"]
  ref_day_raw <- readRDS(ref_day_path)[BIDTYPE == "ENERGY"]
  ref_res <- gate3_oom(ref_per_raw, ref_day_raw, prc, TORRB)

  cmp <- merge(ref_res$daily, new_res$daily, by = "td", suffixes = c("_ref", "_new"))
  cmp[, oom_diff := oom_mw_new - oom_mw_ref]
  cmp[, offered_diff := offered_mw_new - offered_mw_ref]
  tol <- 1e-6
  bad <- cmp[abs(oom_diff) > tol | abs(offered_diff) > tol]

  cat("\n--- ACCEPTANCE TEST: new (DuckDB) vs reference (unz(), trusted) ---\n")
  print(cmp[, .(td, offered_mw_ref, offered_mw_new, offered_diff, oom_mw_ref, oom_mw_new, oom_diff)])

  if (nrow(bad)) {
    cat("\n*** MISMATCH: the following days differ beyond tolerance", tol, "***\n")
    print(bad)
    stop("ACCEPTANCE TEST FAILED -- new DuckDB cache does not reproduce the trusted unz() output. Stopping before any further use of this cache.")
  } else {
    cat("\nACCEPTANCE TEST PASSED -- new DuckDB cache reproduces the trusted unz() output exactly (within ", tol, " MW).\n", sep = "")
  }
} else {
  cat("\n[WARN] Reference cache not found at bid_cache/_old_torrb_only_backup/ -- skipping direct comparison; relying on the printed offered/OOM/na_rrp ranges instead.\n")
}

fwrite(new_res$daily, "gate3_oom_202201_duckdb.csv")
