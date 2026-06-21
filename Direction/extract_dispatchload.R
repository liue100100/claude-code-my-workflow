#!/usr/bin/env Rscript
# extract_dispatchload.R
# Extract DISPATCHLOAD (unit-level dispatch) for all SA DUIDs, 202201-202412.
# Reuses the proven download + DuckDB-scan machinery:
#   - sa_directions_feasibility.R: RAW_CACHE, url_dvd/url_archive, download_try,
#       mmsdm_dir, aemo_dt, SA_SYNC_DUIDS  (safe to source: sys.nframe guard at L472)
#   - extract_core.R: fetch_zip_paths, get_sa_duids, aemo_dt, EXTRACT_DIR
# Output: bid_cache/DISPATCHLOAD_<M>.rds  (atomic) + .done_dl_<M> marker.
#
# DISPATCHLOAD is national (all NEM units) -> use the DuckDB path (as for bids),
# not R line-streaming. We keep only SA DUIDs and the columns pivotality needs.

suppressMessages({ library(data.table); library(duckdb); library(DBI) })

setwd("C:/Users/ericl/Documents/my-project/Direction")
source("sa_directions_feasibility.R")   # helpers + constants (guarded main block)
source("extract_core.R")                # fetch_zip_paths, get_sa_duids, EXTRACT_DIR

CACHE <- "./bid_cache"

# Required across all months; UIGF added to DISPATCHLOAD only in later years -> optional.
# Non-sync penetration is measured from TOTALCLEARED of semi-scheduled units anyway,
# so UIGF is nice-to-have, not load-bearing.
KEEP_REQ <- c("SETTLEMENTDATE","DUID","INTERVENTION","DISPATCHMODE",
              "INITIALMW","TOTALCLEARED","AVAILABILITY","SEMIDISPATCHCAP")
KEEP_OPT <- c("UIGF")

extract_dispatchload <- function(M, cache = CACHE, extract_dir = EXTRACT_DIR) {
  rds     <- file.path(cache, sprintf("DISPATCHLOAD_%s.rds", M))
  rds_tmp <- file.path(cache, sprintf("DISPATCHLOAD_%s.rds.tmp", M))
  if (file.exists(rds)) { message("cache hit: ", rds); return(invisible(nrow(readRDS(rds)))) }
  dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)

  sa_duids <- get_sa_duids(M, cache)            # ~128 SA generator DUIDs
  message(sprintf("[%s] SA DUIDs: %d", M, length(sa_duids)))

  # 1. Download zip part(s). DISPATCHLOAD is a single DVD file per month.
  zips <- fetch_zip_paths("DISPATCHLOAD", M, cache = RAW_CACHE, archive_table = "DISPATCHLOAD")
  stopifnot(length(zips) > 0)
  message(sprintf("[%s] %d zip part(s)", M, length(zips)))

  # 2. Schema guard: read I-row from first part, locate columns.
  inner1 <- utils::unzip(zips[1L], list = TRUE)$Name[1L]
  con1   <- unz(zips[1L], inner1); open(con1, "rt")
  hdr    <- readLines(con1, n = 8L, warn = FALSE); close(con1)
  ih     <- hdr[startsWith(hdr, "I,")]
  if (!length(ih)) stop(sprintf("SCHEMA GUARD [DISPATCHLOAD %s]: no 'I' row in first 8 lines", M))
  cols   <- trimws(strsplit(ih[1L], ",")[[1L]])[-(1:4)]
  missing <- setdiff(KEEP_REQ, cols)
  if (length(missing))
    stop(sprintf("SCHEMA GUARD [DISPATCHLOAD %s]: missing cols: %s", M, paste(missing, collapse=", ")))
  keep_cols <- c(KEEP_REQ, intersect(KEEP_OPT, cols))   # UIGF only where present

  ncols   <- length(cols) + 4L
  cn      <- paste0("c", 0L:(ncols - 1L))
  col_map <- paste0("{", paste(sprintf("'%s':'VARCHAR'", cn), collapse = ", "), "}")
  duid_cn <- cn[match("DUID", cols) + 4L]
  # SELECT only needed columns (positional cn for each kept field)
  sel_cn  <- cn[match(keep_cols, cols) + 4L]
  sel_sql <- paste(sprintf("%s AS %s", sel_cn, keep_cols), collapse = ", ")
  duids_sql <- paste(sprintf("'%s'", sa_duids), collapse = ", ")

  # 3. One part at a time -> unzip -> DuckDB filter -> unlink.
  parts <- vector("list", length(zips))
  for (.i in seq_along(zips)) {
    inner <- utils::unzip(zips[.i], list = TRUE)$Name[1L]
    tmp   <- file.path(extract_dir, inner)
    message(sprintf("[%s] decompress %s (%d/%d)...", M, inner, .i, length(zips)))
    utils::unzip(zips[.i], files = inner, exdir = extract_dir, overwrite = TRUE)
    path_sql <- gsub("\\\\", "/", normalizePath(tmp))
    q <- sprintf(
      "SELECT %s FROM read_csv('%s',
         header=false, delim=',', quote='\"', escape='\"',
         all_varchar=true, null_padding=true, auto_detect=false, strict_mode=false,
         parallel=false, columns=%s)
       WHERE c0='D' AND %s IN (%s)",
      sel_sql, path_sql, col_map, duid_cn, duids_sql)
    con <- dbConnect(duckdb::duckdb())
    part <- tryCatch(as.data.table(dbGetQuery(con, q)),
                     error = function(e){ dbDisconnect(con, shutdown=TRUE); unlink(tmp); stop(e) })
    dbDisconnect(con, shutdown = TRUE)
    unlink(tmp)
    message(sprintf("[%s]   part %d: %d rows", M, .i, nrow(part)))
    parts[[.i]] <- part; rm(part); gc()
  }
  d <- rbindlist(parts, fill = TRUE); rm(parts); gc()
  stopifnot(nrow(d) > 0)

  # 4. Type. SETTLEMENTDATE -> POSIXct; numerics.
  d[, SETTLEMENTDATE := aemo_dt(SETTLEMENTDATE)]
  numc <- intersect(c("INTERVENTION","DISPATCHMODE","INITIALMW","TOTALCLEARED",
                      "AVAILABILITY","SEMIDISPATCHCAP","UIGF"), names(d))
  d[, (numc) := lapply(.SD, as.numeric), .SDcols = numc]
  if (!"UIGF" %in% names(d)) d[, UIGF := NA_real_]   # uniform schema across months

  # 5. Schema guard on data: expect 5-min grid (288/day) and both intervention runs present-or-0.
  stopifnot(all(c("SETTLEMENTDATE","DUID") %in% names(d)))

  saveRDS(d, rds_tmp)
  if (!file.rename(rds_tmp, rds)) stop(sprintf("atomic rename failed: %s", rds))
  writeLines(format(Sys.time()), file.path(cache, paste0(".done_dl_", M)))
  message(sprintf("[%s] cached %d rows -> %s", M, nrow(d), rds))
  invisible(nrow(d))
}

# ---- driver ----
months <- sprintf("%d%02d", rep(2022:2024, each = 12), rep(1:12, times = 3))
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) months <- args            # allow: Rscript extract_dispatchload.R 202401 202402

message("=== DISPATCHLOAD extraction: ", length(months), " months ===")
res <- data.table(month = months, rows = NA_integer_, status = "")
for (i in seq_along(months)) {
  M <- months[i]
  ok <- tryCatch({ n <- extract_dispatchload(M); res[month==M, `:=`(rows=n, status="OK")]; TRUE },
                 error = function(e){ res[month==M, status := paste0("ERR: ", conditionMessage(e))]; message("[",M,"] ERROR: ", conditionMessage(e)); FALSE })
}
print(res)
message("=== done. OK: ", sum(res$status=="OK"), "/", length(months), " ===")
