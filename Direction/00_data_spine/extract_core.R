#!/usr/bin/env Rscript
# extract_core.R -- parameterised one-month NEM bid extraction (DuckDB path).
# Source this file (do NOT run directly); it defines functions only.
#
# Big tables (BIDOFFERPERIOD, BIDDAYOFFER):
#   download -> utils::unzip() to extract_tmp/ -> DuckDB filter -> unlink CSV -> cache .rds
#   Disk is no longer the binding constraint (~205 GB free); DuckDB does the
#   heavy scan so R only receives the small ENERGY-only SA slice.
#
# Small tables (DUDETAILSUMMARY, DISPATCHPRICE):
#   original unz()-streaming path (unchanged; never were the bottleneck).
#
# Requires: data.table, duckdb, DBI
#           sa_directions_feasibility.R sourced first (provides RAW_CACHE,
#           url_dvd, download_try).

suppressMessages({ library(data.table); library(duckdb); library(DBI) })

REGION      <- "SA1"
CACHE       <- "./bid_cache"
EXTRACT_DIR <- "./extract_tmp"

aemo_dt <- function(x) as.POSIXct(x, format = "%Y/%m/%d %H:%M:%S", tz = "Australia/Brisbane")

# ---- unz()-streaming helpers (small tables only) ----
read_zip_streaming <- function(zip, keys, chunk = 2e5L, bidtype = NULL) {
  inner <- utils::unzip(zip, list = TRUE)$Name[1]
  con <- unz(zip, inner); open(con, "rt"); on.exit(close(con))
  pat <- if (is.null(bidtype)) paste0(",(", paste(keys, collapse = "|"), "),")
         else paste0(",(", paste(keys, collapse = "|"), "),", bidtype, ",")
  cols <- NULL; keep <- list()
  repeat {
    ln <- readLines(con, n = chunk, warn = FALSE)
    if (!length(ln)) break
    if (is.null(cols)) {
      ih <- ln[startsWith(ln, "I,")]
      if (length(ih)) cols <- trimws(strsplit(ih[1], ",")[[1]])[-(1:4)]
    }
    m <- ln[grepl(pat, ln)]
    if (length(m)) keep[[length(keep) + 1L]] <- m
  }
  if (!length(keep)) return(list(cols = cols, d = data.table()))
  d <- fread(text = paste(unlist(keep), collapse = "\n"),
             header = FALSE, sep = ",", fill = TRUE,
             colClasses = "character", showProgress = FALSE)
  list(cols = cols, d = d)
}

fetch_zip_paths <- function(table, yyyymm, cache = RAW_CACHE, archive_table = table) {
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)

  try_dvd_name <- function(tbl, retries = 3L) {
    dest <- file.path(cache, sprintf("PUBLIC_DVD_%s_%s010000.zip", tbl, yyyymm))
    if (download_try(url_dvd(tbl, yyyymm), dest, retries = retries)) dest else character(0)
  }

  # 1. Plain DVD name (works for most tables and BIDPEROFFER through ~202205)
  z <- try_dvd_name(table)
  if (length(z)) return(z)

  # 2. Numbered DVD parts: BIDPEROFFER1, BIDPEROFFER2, ... (AEMO split from ~202206-202407)
  parts <- character(0)
  for (n in seq_len(50L)) {
    z_n <- try_dvd_name(paste0(table, n), retries = 1L)
    if (!length(z_n)) break
    parts <- c(parts, z_n)
  }
  if (length(parts)) return(parts)

  # 3. ARCHIVE naming (202408+; archive_table may differ, e.g. BIDOFFERPERIOD for BIDPEROFFER)
  #    202408 BIDOFFERPERIOD has 34 parts; allow up to 50.
  arc_parts <- character(0)
  for (n in seq_len(50L)) {
    dest <- file.path(cache, sprintf("ARCHIVE_%s_%s_FILE%02d.zip", archive_table, yyyymm, n))
    if (!download_try(url_archive(archive_table, yyyymm, n), dest, retries = 1L)) break
    arc_parts <- c(arc_parts, dest)
  }
  arc_parts
}

stream_named <- function(dvd_name, yyyymm, keys, bidtype = NULL) {
  z <- fetch_zip_paths(dvd_name, yyyymm); stopifnot(length(z) > 0)
  fr <- read_zip_streaming(z[1], keys, bidtype = bidtype); stopifnot(!is.null(fr$cols))
  d <- fr$d; if (!nrow(d)) return(data.table())
  d <- d[V1 == "D"][, 5:(4 + length(fr$cols)), with = FALSE]; setnames(d, fr$cols); d[]
}

type_table <- function(d) {
  numc <- intersect(c(paste0("BANDAVAIL", 1:10), paste0("PRICEBAND", 1:10),
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

# ---- SA DUID discovery (unz()-streaming; small table) ----
get_sa_duids <- function(yyyymm, cache = CACHE) {
  rds <- file.path(cache, sprintf("SA_DUIDS_%s.rds", yyyymm))
  if (file.exists(rds)) return(readRDS(rds))
  dud <- stream_named("DUDETAILSUMMARY", yyyymm, REGION)
  stopifnot(nrow(dud) > 0, "DISPATCHTYPE" %in% names(dud))
  sa  <- sort(unique(dud[REGIONID == REGION & DISPATCHTYPE == "GENERATOR", DUID]))
  saveRDS(sa, rds); sa
}

# ---- DuckDB extraction for BIDOFFERPERIOD and BIDDAYOFFER ----
# Flow: download zip -> unzip to EXTRACT_DIR -> DuckDB filter -> unlink CSV -> cache .rds
# The extracted CSV is held on disk only while DuckDB reads it; it is unlinked immediately
# after, so never more than one month's raw CSV is on disk at a time.
extract_bids <- function(dvd_name, label, keys, yyyymm,
                         cache = CACHE, extract_dir = EXTRACT_DIR) {
  rds     <- file.path(cache, sprintf("%s_%s.rds",     label, yyyymm))
  rds_tmp <- file.path(cache, sprintf("%s_%s.rds.tmp", label, yyyymm))
  if (file.exists(rds)) { message("cache hit: ", rds); return(readRDS(rds)) }

  dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)

  # 1. Download all zip parts to nem_cache.
  #    archive_table maps BIDPEROFFER → BIDOFFERPERIOD for 202408+ ARCHIVE naming.
  zips <- fetch_zip_paths(dvd_name, yyyymm, cache = RAW_CACHE, archive_table = label)
  stopifnot(length(zips) > 0)
  message(sprintf("%s %s: %d zip part(s) found", label, yyyymm, length(zips)))

  # 2. Schema guard: peek at I-row from the first part without extracting.
  .schema_inner <- utils::unzip(zips[1L], list = TRUE)$Name[1L]
  .schema_con   <- unz(zips[1L], .schema_inner); open(.schema_con, "rt")
  .schema_hdr   <- readLines(.schema_con, n = 8L, warn = FALSE); close(.schema_con)
  ih <- .schema_hdr[startsWith(.schema_hdr, "I,")]
  if (!length(ih))
    stop(sprintf("SCHEMA GUARD [%s %s]: no 'I' header row in first 8 lines.", label, yyyymm))
  cols <- trimws(strsplit(ih[1L], ",")[[1L]])[-(1:4)]

  required <- switch(label,
    BIDOFFERPERIOD = c("DUID","BIDTYPE","TRADINGDATE","PERIODID"),
    BIDDAYOFFER    = c("DUID","BIDTYPE","SETTLEMENTDATE","OFFERDATE","VERSIONNO"),
    character(0)
  )
  missing <- setdiff(required, cols)
  if (length(missing))
    stop(sprintf("SCHEMA GUARD [%s %s]: missing columns: %s\n  Header had: %s",
                 label, yyyymm, paste(missing, collapse = ", "), paste(cols, collapse = ", ")))

  # Build DuckDB query template (reused across all parts)
  ncols    <- length(cols) + 4L
  cn       <- paste0("c", 0L:(ncols - 1L))
  col_map  <- paste0("{", paste(sprintf("'%s':'VARCHAR'", cn), collapse = ", "), "}")
  duid_cn  <- cn[match("DUID",    cols) + 4L]
  bt_cn    <- cn[match("BIDTYPE", cols) + 4L]
  keys_sql <- paste(sprintf("'%s'", keys), collapse = ", ")

  # 3. Extract one part at a time → DuckDB → unlink immediately.
  #    Avoids holding multiple large CSVs simultaneously (202408 has 34 parts × ~8 GB each).
  all_parts <- vector("list", length(zips))
  for (.i in seq_along(zips)) {
    .inner <- utils::unzip(zips[.i], list = TRUE)$Name[1L]
    .tmp   <- file.path(extract_dir, .inner)
    message(sprintf("decompressing %s (%d/%d)...", .inner, .i, length(zips)))
    utils::unzip(zips[.i], files = .inner, exdir = extract_dir, overwrite = TRUE)
    message(sprintf("  decompressed %.2f GB", file.info(.tmp)$size / 1024^3))

    .path_sql <- gsub("\\\\", "/", normalizePath(.tmp))
    .query <- sprintf(
      "SELECT * FROM read_csv('%s',
         header=false, delim=',', quote='\"', escape='\"',
         all_varchar=true, null_padding=true, auto_detect=false, strict_mode=false, parallel=false, columns=%s)
       WHERE c0 = 'D' AND %s IN (%s) AND %s = 'ENERGY'",
      .path_sql, col_map, duid_cn, keys_sql, bt_cn)

    message(sprintf("DuckDB scan: %s %s part %d...", label, yyyymm, .i))
    con <- dbConnect(duckdb::duckdb())
    .part <- tryCatch(
      as.data.table(dbGetQuery(con, .query)),
      error = function(e) { dbDisconnect(con, shutdown = TRUE); unlink(.tmp); stop(e) }
    )
    dbDisconnect(con, shutdown = TRUE)
    unlink(.tmp)   # free disk immediately
    message(sprintf("  part %d: %d rows", .i, nrow(.part)))
    all_parts[[.i]] <- .part
    rm(.part); gc()
  }

  d <- rbindlist(all_parts, fill = TRUE); rm(all_parts); gc()
  stopifnot(nrow(d) > 0)

  # 5. drop 4 leading metadata columns; rename to actual field names
  d <- d[, 5L:ncols, with = FALSE]; setnames(d, cols)
  d <- type_table(d)

  # 6. schema guard on data: PERIODID range (BIDOFFERPERIOD only)
  if (label == "BIDOFFERPERIOD") {
    mx <- max(d$PERIODID, na.rm = TRUE)
    if (!(mx %in% c(48L, 288L)))
      stop(sprintf("SCHEMA GUARD [%s %s]: max(PERIODID) = %d, expected 48 or 288.", label, yyyymm, mx))
    if (mx == 48L)
      stop(sprintf("SCHEMA GUARD [%s %s]: max(PERIODID) = 48 (30-min legacy layout). 5MS predates 202202; this month needs separate handling.", label, yyyymm))
    if ("INTERVAL_DATETIME" %in% names(d)) {
      message("INTERVAL_DATETIME already present — skipping reconstruction")
    } else {
      d[, td := as.IDate(TRADINGDATE)]
      d[, INTERVAL_DATETIME := aemo_dt(paste(format(td, "%Y/%m/%d"), "00:00:00")) + PERIODID * 300L]
    }
  }
  if (label == "BIDDAYOFFER") d[, td := as.IDate(SETTLEMENTDATE)]

  # 7. atomic write
  saveRDS(d, rds_tmp)
  if (!file.rename(rds_tmp, rds))
    stop(sprintf("atomic rename failed: %s -> %s", rds_tmp, rds))
  message(sprintf("cached %d rows -> %s", nrow(d), rds))
  d
}

# ---- main parameterised extraction function ----
# Returns list(n_bidofferperiod, n_biddayoffer, n_dispatchprice).
# Writes bid_cache/.done_<M> only after all three .rds files are confirmed.
# Each big table is rm()+gc()-ed immediately after its row count is saved.
extract_month <- function(M, cache = CACHE, extract_dir = EXTRACT_DIR) {
  dir.create(cache,       showWarnings = FALSE, recursive = TRUE)
  dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)

  # A0: SA generator DUIDs (unz()-streaming; small)
  sa_duids <- get_sa_duids(M, cache)
  message("SA DUIDs [", M, "]: ", length(sa_duids))

  # A1: BIDOFFERPERIOD (DuckDB path)
  per   <- extract_bids("BIDPEROFFER", "BIDOFFERPERIOD", sa_duids, M, cache, extract_dir)
  n_per <- nrow(per); rm(per); gc()

  # A2: BIDDAYOFFER (DuckDB path)
  day   <- extract_bids("BIDDAYOFFER", "BIDDAYOFFER", sa_duids, M, cache, extract_dir)
  n_day <- nrow(day); rm(day); gc()

  # A3: DISPATCHPRICE (unz()-streaming; small table; original path unchanged)
  prc_rds <- file.path(cache, sprintf("DISPATCHPRICE_%s.rds", M))
  prc_tmp <- file.path(cache, sprintf("DISPATCHPRICE_%s.rds.tmp", M))
  if (file.exists(prc_rds)) {
    message("cache hit: ", prc_rds)
    n_prc <- nrow(readRDS(prc_rds))
  } else {
    message("streaming DISPATCHPRICE ", M, " ...")
    prc <- type_table(stream_named("DISPATCHPRICE", M, REGION))
    stopifnot(nrow(prc) > 0)
    saveRDS(prc, prc_tmp)
    if (!file.rename(prc_tmp, prc_rds))
      stop(sprintf("atomic rename failed: %s -> %s", prc_tmp, prc_rds))
    message(sprintf("cached %d rows -> %s", nrow(prc), prc_rds))
    n_prc <- nrow(prc); rm(prc); gc()
  }

  # done sentinel — written only after all three renames have succeeded
  writeLines(format(Sys.time()), file.path(cache, paste0(".done_", M)))

  list(n_bidofferperiod = n_per, n_biddayoffer = n_day, n_dispatchprice = n_prc)
}
