#!/usr/bin/env Rscript
# run_all.R -- extract bid data for all months 202202-202412.
# Shells out to a fresh Rscript process per month so the ~55 GB stream's memory
# is fully released between months and a crash/OOM kills only that month.
# Re-running resumes automatically: run_month.R skips already-done months.

# Anchor to the Direction root (this script lives in 00_data_spine/).
{
  .args_full   <- commandArgs(trailingOnly = FALSE)
  .script_flag <- grep("^--file=", .args_full, value = TRUE)
  if (length(.script_flag))
    setwd(dirname(dirname(normalizePath(sub("^--file=", "", .script_flag)))))
}

# Generate month vector with Date arithmetic -- avoids YYYYMM hand-rolled arithmetic
months <- format(
  seq(as.Date("2022-02-01"), as.Date("2024-12-01"), by = "month"),
  "%Y%m"
)
cat(sprintf("Months to process: %d  (%s .. %s)\n",
            length(months), months[1L], months[length(months)]))

CACHE   <- "./bid_cache"
LOGS    <- "./logs"
rscript <- file.path(R.home("bin"), "Rscript")

dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)
dir.create(LOGS,  showWarnings = FALSE, recursive = TRUE)

status_vec <- setNames(rep(NA_character_, length(months)), months)

for (i in seq_along(months)) {
  M <- months[i]
  cat(sprintf("[%d/%d] %s ... ", i, length(months), M))
  flush.console()
  exit_code <- system2(rscript, args = c("00_data_spine/run_month.R", M))
  if (exit_code == 0L) {
    status_vec[M] <- "done"
    # run_month.R already printed DONE or SKIP; no extra cat needed
  } else {
    status_vec[M] <- "FAILED"
    cat(sprintf("[run_all] FAILED (exit %d) -- see %s/%s.log\n", exit_code, LOGS, M))
  }
}

# ---------- summary ----------
cat("\n=== run_all summary ===\n")
cat(sprintf("  Done  : %d\n", sum(status_vec == "done",   na.rm = TRUE)))
cat(sprintf("  Failed: %d\n", sum(status_vec == "FAILED", na.rm = TRUE)))

failed <- names(status_vec)[!is.na(status_vec) & status_vec == "FAILED"]
if (length(failed))
  cat(sprintf("  Failed months: %s\n  Re-run run_all.R to retry.\n",
              paste(failed, collapse = ", ")))

manifest_path <- file.path(CACHE, "manifest.csv")
if (file.exists(manifest_path)) {
  suppressMessages(library(data.table))
  m <- tryCatch(fread(manifest_path), error = function(e) NULL)
  if (!is.null(m) && nrow(m)) {
    cat("\nManifest (last 10 rows):\n")
    print(tail(m[, intersect(c("month","status","n_bidofferperiod","secs_total"), names(m)),
                with = FALSE], 10L))
  }
}
