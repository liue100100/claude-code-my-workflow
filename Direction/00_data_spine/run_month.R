#!/usr/bin/env Rscript
# run_month.R -- extract and cache bid data for one month.
# Usage:  Rscript run_month.R YYYYMM
# Exit 0 = success or already-done skip; Exit 1 = error (see logs/<M>.log).

# Anchor to the Direction root (this script lives in 00_data_spine/), so the
# relative cache paths (./bid_cache, ./logs, ./extract_tmp) resolve correctly
# regardless of how the script is invoked.
{
  .args_full   <- commandArgs(trailingOnly = FALSE)
  .script_flag <- grep("^--file=", .args_full, value = TRUE)
  if (length(.script_flag))
    setwd(dirname(dirname(normalizePath(sub("^--file=", "", .script_flag)))))
}

# ---------- parse + validate M ----------
M_args <- commandArgs(trailingOnly = TRUE)
if (length(M_args) < 1L) stop("Usage: Rscript run_month.R YYYYMM")
M <- as.character(M_args[1])
if (!grepl("^[0-9]{6}$", M))
  stop(sprintf("M must be a 6-digit YYYYMM string, got: '%s'", M))
Mnum <- as.integer(M)
if (Mnum < 202202L || Mnum > 202412L)
  stop(sprintf("M = %s is outside the allowed range [202202, 202412]", M))

CACHE       <- "./bid_cache"
LOGS        <- "./logs"
EXTRACT_DIR <- "./extract_tmp"
dir.create(CACHE,       showWarnings = FALSE, recursive = TRUE)
dir.create(EXTRACT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---------- SKIP-IF-DONE (fast path; no package loading needed) ----------
.done_flag <- file.path(CACHE, paste0(".done_", M))
.rds_files <- file.path(CACHE, c(sprintf("BIDOFFERPERIOD_%s.rds", M),
                                  sprintf("BIDDAYOFFER_%s.rds",    M),
                                  sprintf("DISPATCHPRICE_%s.rds",  M)))
if (file.exists(.done_flag) && all(file.exists(.rds_files))) {
  cat(sprintf("SKIP %s already done\n", M))
  quit(status = 0L, save = "no")
}

# ---------- load dependencies ----------
source("00_data_spine/sa_directions_feasibility.R")
source("00_data_spine/extract_core.R")

# ---------- manifest helper ----------
.manifest_path <- file.path(CACHE, "manifest.csv")
.manifest_header <- "month,status,n_bidofferperiod,n_biddayoffer,n_dispatchprice,secs_total,finished_at,error"

write_manifest_row <- function(month, status, n_per = NA, n_day = NA, n_prc = NA,
                               secs = NA, err = "") {
  if (!file.exists(.manifest_path))
    cat(.manifest_header, "\n", file = .manifest_path, sep = "")
  err_safe <- sprintf('"%s"', gsub('"', "'", gsub(",", ";", as.character(err))))
  row <- paste(c(month, status,
                 ifelse(is.na(n_per),  "", n_per),
                 ifelse(is.na(n_day),  "", n_day),
                 ifelse(is.na(n_prc),  "", n_prc),
                 ifelse(is.na(secs),   "", round(secs, 1L)),
                 format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                 if (nchar(err) == 0) "" else err_safe),
               collapse = ",")
  for (.k in seq_len(5L)) {
    .ok <- tryCatch({ cat(row, "\n", file = .manifest_path, append = TRUE, sep = ""); TRUE },
                    error = function(e) FALSE)
    if (.ok) break
    Sys.sleep(0.5)
  }
}

# ---------- run with error capture ----------
.tb_lines <- NULL

result <- tryCatch({
  withCallingHandlers({
    t_total <- system.time({
      res <- extract_month(M)
    })
    res$elapsed <- as.numeric(t_total["elapsed"])
    res
  }, error = function(e) {
    .tb_lines <<- tryCatch(
      paste(vapply(sys.calls(), function(cl)
        tryCatch(deparse(cl, width.cutoff = 60L)[1L],
                 error = function(e2) "..."), character(1L)),
        collapse = "\n"),
      error = function(e2) "(traceback capture failed)"
    )
  })
}, error = function(e) {
  msg <- conditionMessage(e)
  dir.create(LOGS, showWarnings = FALSE, recursive = TRUE)
  log_path <- file.path(LOGS, sprintf("%s.log", M))
  writeLines(c(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    paste("ERROR:", msg),
    "",
    "TRACEBACK:",
    if (is.null(.tb_lines)) "(not captured)" else .tb_lines
  ), log_path)
  cat(sprintf("[FAILED] %s: %s\n  log: %s\n", M, msg, log_path))

  # delete .tmp leftovers for THIS month only -- never touch other months' files
  tmps <- list.files(CACHE, pattern = sprintf(".*_%s\\.rds\\.tmp$", M), full.names = TRUE)
  if (length(tmps)) {
    message("cleaning up ", length(tmps), " .rds.tmp file(s)")
    file.remove(tmps)
  }
  # delete any extracted CSV still in extract_tmp/ (DuckDB unlinks on success;
  # on error it may have been left behind)
  extracted <- list.files(EXTRACT_DIR, full.names = TRUE)
  if (length(extracted)) {
    message("cleaning up ", length(extracted), " extracted CSV file(s) from extract_tmp/")
    file.remove(extracted)
  }

  write_manifest_row(M, "FAILED", err = msg)
  quit(status = 1L, save = "no")
})

# ---------- success ----------
write_manifest_row(M, "done",
                   n_per  = result$n_bidofferperiod,
                   n_day  = result$n_biddayoffer,
                   n_prc  = result$n_dispatchprice,
                   secs   = result$elapsed)
cat(sprintf("DONE %s  per=%d  day=%d  prc=%d  secs=%.1f\n",
            M,
            result$n_bidofferperiod,
            result$n_biddayoffer,
            result$n_dispatchprice,
            result$elapsed))
quit(status = 0L, save = "no")
