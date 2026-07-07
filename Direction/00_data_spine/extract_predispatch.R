#!/usr/bin/env Rscript
# extract_predispatch.R
# Extract PREDISPATCHREGIONSUM (SA1) + PREDISPATCHLOAD (SA synchronous fleet) for the
# direction-propensity workstream (Direction_clean/08_propensity/registration.md, Stage 0
# repair approved by author 2026-07-07).
#
# Reuses the proven download + DuckDB-scan machinery verbatim from extract_dispatchload.R:
#   - sa_directions_feasibility.R: RAW_CACHE, url_dvd/url_archive, download_try, aemo_dt
#   - extract_core.R: fetch_zip_paths, EXTRACT_DIR
# Output: bid_cache/PREDISPATCH_RS_<M>.rds  (regional, SA1)
#         bid_cache/PREDISPATCH_LOAD_<M>.rds (unit, SA sync fleet incl. focal — focal kept for
#         validation/audits ONLY; the propensity model never consumes focal inputs)
# Sentinels .done_pdrs_<M> / .done_pdl_<M>; atomic renames; resume-safe (cache hit skips).
#
# PREDISPATCH grain: 30-min runs (PREDISPATCHSEQNO = YYYYMMDDPP), each run forecasts 30-min
# intervals (DATETIME) to the end of the next trading day. Horizon = DATETIME - run time,
# computed downstream in Stage 1, not here.

suppressMessages({ library(data.table); library(duckdb); library(DBI) })

# Run from Direction/ (INV-10: no absolute paths; the sourced helpers assume this wd)
if (!file.exists("00_data_spine/extract_core.R"))
  stop("Run this script from the Direction/ directory")
source("00_data_spine/sa_directions_feasibility.R")
source("00_data_spine/extract_core.R")

CACHE <- "./bid_cache"

SYNC_DUIDS <- c("TORRB1","TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG","QPS5",
                "DRYCGT1","DRYCGT2","DRYCGT3","MINTARO","BARKIPS1","SNAPPER1")

# ---------------------------------------------------------------------------
# Generic one-table extractor following extract_dispatchload.R step-for-step
# ---------------------------------------------------------------------------
extract_pd_table <- function(M, dvd_table, out_prefix, done_prefix,
                             keep_req, keep_opt, where_col, where_vals,
                             cache = CACHE, extract_dir = EXTRACT_DIR,
                             archive_table = sub("_D$", "", dvd_table)) {
  # ARCHIVE months (202408+) name the PREDISPATCH tables WITHOUT the _D suffix
  # (verified on nemweb MMSDM_2024_08); PDPASA_REGIONSOLUTION is unchanged.
  rds     <- file.path(cache, sprintf("%s_%s.rds", out_prefix, M))
  rds_tmp <- paste0(rds, ".tmp")
  if (file.exists(rds)) { message("cache hit: ", rds); return(invisible(nrow(readRDS(rds)))) }
  dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)

  zips <- fetch_zip_paths(dvd_table, M, cache = RAW_CACHE, archive_table = archive_table)
  stopifnot(length(zips) > 0)
  message(sprintf("[%s %s] %d zip part(s)", dvd_table, M, length(zips)))

  # Schema guard from the first part's I-row
  inner1 <- utils::unzip(zips[1L], list = TRUE)$Name[1L]
  con1   <- unz(zips[1L], inner1); open(con1, "rt")
  hdr    <- readLines(con1, n = 8L, warn = FALSE); close(con1)
  ih     <- hdr[startsWith(hdr, "I,")]
  if (!length(ih)) stop(sprintf("SCHEMA GUARD [%s %s]: no 'I' row in first 8 lines", dvd_table, M))
  cols   <- trimws(strsplit(ih[1L], ",")[[1L]])[-(1:4)]
  missing <- setdiff(keep_req, cols)
  if (length(missing))
    stop(sprintf("SCHEMA GUARD [%s %s]: missing cols: %s", dvd_table, M, paste(missing, collapse = ", ")))
  keep_cols <- c(keep_req, intersect(keep_opt, cols))

  ncols   <- length(cols) + 4L
  cn      <- paste0("c", 0L:(ncols - 1L))
  col_map <- paste0("{", paste(sprintf("'%s':'VARCHAR'", cn), collapse = ", "), "}")
  filt_cn <- cn[match(where_col, cols) + 4L]
  sel_cn  <- cn[match(keep_cols, cols) + 4L]
  sel_sql <- paste(sprintf("%s AS %s", sel_cn, keep_cols), collapse = ", ")
  vals_sql <- paste(sprintf("'%s'", where_vals), collapse = ", ")

  parts <- vector("list", length(zips))
  for (.i in seq_along(zips)) {
    inner <- utils::unzip(zips[.i], list = TRUE)$Name[1L]
    tmp   <- file.path(extract_dir, inner)
    message(sprintf("[%s %s] decompress %s (%d/%d)...", dvd_table, M, inner, .i, length(zips)))
    utils::unzip(zips[.i], files = inner, exdir = extract_dir, overwrite = TRUE)
    path_sql <- gsub("\\\\", "/", normalizePath(tmp))
    q <- sprintf(
      "SELECT %s FROM read_csv('%s',
         header=false, delim=',', quote='\"', escape='\"',
         all_varchar=true, null_padding=true, auto_detect=false, strict_mode=false,
         parallel=false, columns=%s)
       WHERE c0='D' AND %s IN (%s)",
      sel_sql, path_sql, col_map, filt_cn, vals_sql)
    con <- dbConnect(duckdb::duckdb())
    part <- tryCatch(as.data.table(dbGetQuery(con, q)),
                     error = function(e){ dbDisconnect(con, shutdown = TRUE); unlink(tmp); stop(e) })
    dbDisconnect(con, shutdown = TRUE)
    unlink(tmp)
    message(sprintf("[%s %s]   part %d: %d rows", dvd_table, M, .i, nrow(part)))
    parts[[.i]] <- part; rm(part); gc()
  }
  d <- rbindlist(parts, fill = TRUE); rm(parts); gc()
  stopifnot(nrow(d) > 0)

  # Type conversions: any *DATETIME* column + LASTCHANGED -> POSIXct; rest numeric except ids
  dtc <- union(grep("DATETIME", names(d), value = TRUE), intersect("LASTCHANGED", names(d)))
  for (cc in dtc) d[, (cc) := aemo_dt(get(cc))]
  numc <- setdiff(names(d), c("PREDISPATCHSEQNO","DUID","REGIONID","RUNTYPE", dtc))
  if (length(numc)) d[, (numc) := lapply(.SD, as.numeric), .SDcols = numc]

  saveRDS(d, rds_tmp)
  if (!file.rename(rds_tmp, rds)) stop(sprintf("atomic rename failed: %s", rds))
  writeLines(format(Sys.time()), file.path(cache, paste0(".", done_prefix, "_", M)))
  message(sprintf("[%s %s] cached %d rows -> %s", dvd_table, M, nrow(d), rds))
  invisible(nrow(d))
}

extract_pd_regionsum <- function(M) extract_pd_table(
  M, dvd_table = "PREDISPATCHREGIONSUM_D", out_prefix = "PREDISPATCH_RS", done_prefix = "done_pdrs",
  keep_req = c("PREDISPATCHSEQNO","RUNNO","REGIONID","PERIODID","INTERVENTION",
               "TOTALDEMAND","AVAILABLEGENERATION","DATETIME"),
  keep_opt = c("LASTCHANGED","SS_SOLAR_UIGF","SS_WIND_UIGF","SS_SOLAR_CLEAREDMW","SS_WIND_CLEAREDMW",
               "SS_SOLAR_AVAILABILITY","SS_WIND_AVAILABILITY","DEMANDFORECAST","NETINTERCHANGE"),
  where_col = "REGIONID", where_vals = "SA1")

extract_pd_load <- function(M) extract_pd_table(
  M, dvd_table = "PREDISPATCHLOAD_D", out_prefix = "PREDISPATCH_LOAD", done_prefix = "done_pdl",
  keep_req = c("PREDISPATCHSEQNO","RUNNO","DUID","PERIODID","INTERVENTION",
               "AVAILABILITY","DATETIME"),
  keep_opt = c("LASTCHANGED","PASAAVAILABILITY","DISPATCHMODE","TOTALCLEARED"),
  where_col = "DUID", where_vals = SYNC_DUIDS)

# PDPASA regional solution: ALL half-hourly runs retained in MMSDM (unlike the PREDISPATCH*_D
# tables, which keep only the final run per target interval) -> this is the forecast-horizon
# source for regional demand + capacity conditions. Unit-level rival availability at horizon
# comes from the bid cache (versioned MAXAVAIL), not from here.
extract_pdpasa_region <- function(M) extract_pd_table(
  M, dvd_table = "PDPASA_REGIONSOLUTION", out_prefix = "PDPASA_RS", done_prefix = "done_pdpasa",
  keep_req = c("RUN_DATETIME","INTERVAL_DATETIME","REGIONID","DEMAND50",
               "AGGREGATECAPACITYAVAILABLE"),
  keep_opt = c("RUNTYPE","DEMAND10","DEMAND90","AGGREGATESCHEDULEDLOAD","AGGREGATEPASAAVAILABILITY",
               "SURPLUSCAPACITY","SURPLUSRESERVE","LOWRESERVECONDITION","LACKOFRESERVECONDITION",
               "SEMISCHEDULEDCAPACITY","SS_SOLAR_UIGF","SS_WIND_UIGF","LASTCHANGED"),
  where_col = "REGIONID", where_vals = "SA1")

# Final-run PREDISPATCH regional PRICE (added 2026-07-08 for the rebuilt boundary test,
# 10_boundary_test final registration): one row per target interval (final run only).
extract_pd_price <- function(M) extract_pd_table(
  M, dvd_table = "PREDISPATCHPRICE_D", out_prefix = "PREDISPATCH_PRICE", done_prefix = "done_pdp",
  keep_req = c("PREDISPATCHSEQNO", "RUNNO", "REGIONID", "PERIODID", "INTERVENTION",
               "RRP", "DATETIME"),
  keep_opt = c("LASTCHANGED", "EEP"),
  where_col = "REGIONID", where_vals = "SA1")

# ---- driver ----
months <- c("202112", sprintf("%d%02d", rep(2022:2024, each = 12), rep(1:12, times = 3)))
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) months <- args

message("=== PREDISPATCH extraction: ", length(months), " months x 2 tables ===")
res <- data.table(month = months, rs_rows = NA_integer_, load_rows = NA_integer_,
                  pdpasa_rows = NA_integer_, price_rows = NA_integer_, status = "")
for (M in months) {
  ok <- tryCatch({
    n1 <- extract_pd_regionsum(M)
    n2 <- extract_pd_load(M)
    n3 <- extract_pdpasa_region(M)
    n4 <- extract_pd_price(M)
    res[month == M, `:=`(rs_rows = n1, load_rows = n2, pdpasa_rows = n3, price_rows = n4, status = "OK")]; TRUE
  }, error = function(e) {
    res[month == M, status := paste0("ERR: ", conditionMessage(e))]
    message("[", M, "] ERROR: ", conditionMessage(e)); FALSE
  })
  fwrite(res, file.path(CACHE, "predispatch_manifest.csv"))
}
print(res)
message("=== done. OK: ", sum(res$status == "OK"), "/", length(months), " ===")
