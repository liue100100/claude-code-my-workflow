#!/usr/bin/env Rscript
# parse_direction_reports.R
# Extract direction event records from all 25 AEMO System Security Energy Directions
# market event reports covering SA generators (2021-01 to 2024-12).
#
# Outputs (Direction/direction_data/parsed/):
#   direction_events.rds   — one row per DUID × direction, all formats stacked
#   direction_costs.rds    — event-level cost aggregates (old format only; new format
#                            has per-DUID costs already in direction_events.rds)
#   recovery_rates.rds     — 5-min interval recovery rates by NEM region
#
# Format detection:
#   Old (pre-2023-10):  sheet "Summary & directions assessment" + "Directions cost & directed MWh"
#   New (2023-10 onward): sheet "Directions summary" (one merged 17-col table)

suppressMessages({
  library(readxl)
  library(data.table)
})

DATA_DIR  <- "Direction/direction_data"
OUT_DIR   <- file.path(DATA_DIR, "parsed")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Excel serial (Windows origin 1899-12-30) → POSIXct in AEMO market time (UTC+10, no DST)
# FIXED 2026-07-05 (Task 1d): the previous version formatted the UTC-parsed instant in
# Etc/GMT-10, which ADDED 10 hours to every timestamp (Excel cells are already market-time
# clocks). Keep the clock as parsed and stamp the market timezone. Verification of the bug and
# of this fix: Direction_clean/outputs/05_mechanism/findings_task1d.md (three independent lines).
excel_to_posix <- function(x) {
  as.POSIXct((as.numeric(x) - 25569) * 86400,
             origin = "1970-01-01", tz = "UTC") |>
    (\(dt) format(dt, tz = "UTC") |>
       as.POSIXct(tz = "Etc/GMT-10"))()
}

# Find the first row index whose cells all contain the given marker strings.
find_header_row <- function(raw, markers) {
  for (i in seq_len(nrow(raw))) {
    cells <- as.character(unlist(raw[i, ]))
    if (all(sapply(markers, function(m) any(grepl(m, cells, fixed = TRUE)))))
      return(i)
  }
  NA_integer_
}

# Read raw sheet and return data rows below the header identified by markers.
# clean_names: vector of clean column names (replaces footnote-suffixed names).
extract_table <- function(f, sheet, markers, clean_names = NULL, skip_rows = 1L) {
  raw <- tryCatch(
    suppressMessages(read_excel(f, sheet = sheet, col_names = FALSE)),
    error = function(e) NULL
  )
  if (is.null(raw)) return(NULL)

  hrow <- find_header_row(raw, markers)
  if (is.na(hrow)) {
    warning(sprintf("Header '%s' not found in [%s] of %s",
                    paste(markers, collapse = "+"), sheet, basename(f)))
    return(NULL)
  }

  # Column names from header row
  hdrs <- as.character(unlist(raw[hrow, ]))
  last_col <- max(which(!is.na(hdrs) & hdrs != "NA"))
  hdrs <- hdrs[1:last_col]
  hdrs <- trimws(gsub("\\d+$", "", hdrs))   # strip trailing footnote numbers

  # Drop columns with NA or empty headers (Excel "holes" in the middle)
  keep_cols <- which(!is.na(hdrs) & hdrs != "NA" & nchar(hdrs) > 0)
  hdrs <- hdrs[keep_cols]

  # Data rows
  data_start <- hrow + skip_rows
  if (data_start > nrow(raw)) return(NULL)

  d <- as.data.table(raw[data_start:nrow(raw), keep_cols])
  setnames(d, hdrs)

  # Drop all-NA rows
  d <- d[rowSums(!is.na(d)) > 0]

  if (!is.null(clean_names) && length(clean_names) == ncol(d))
    setnames(d, clean_names)

  d
}

# ---------------------------------------------------------------------------
# Old-format extractors
# ---------------------------------------------------------------------------

OLD_EVENT_COLS <- c(
  "report_event", "duid", "participant", "region",
  "issue_time", "effective_time", "cancellation_time",
  "reason", "direction_instruction", "market_notice"
)
OLD_COST_COLS <- c(
  "report_year", "report_month", "report_event",
  "direction_start", "direction_end",
  "directed_mwh", "compensation_payment",
  "retained_trading_amount", "additional_compensation",
  "ie_fee", "cra"
)

read_old_events <- function(f) {
  # Use "Direction instruction" as marker — the compliance sub-table has "Issue time"
  # too (in later old-format files) but never "Direction instruction".
  d <- extract_table(f, "Summary & directions assessment",
                     markers = c("Direction instruction", "Issue time"),
                     clean_names = OLD_EVENT_COLS)
  if (is.null(d) || !nrow(d)) return(NULL)

  # Rows in compliance notification sub-table have NA for issue_time (non-numeric)
  # Direction event rows have numeric Excel serials in all date columns.
  num_cols <- c("report_event", "issue_time", "effective_time", "cancellation_time")
  for (cc in num_cols) d[, (cc) := suppressWarnings(as.numeric(get(cc)))]
  d <- d[!is.na(issue_time)]  # drop compliance rows

  date_cols <- c("report_event", "issue_time", "effective_time", "cancellation_time")
  for (cc in date_cols) d[, (cc) := excel_to_posix(get(cc))]

  d[, `:=`(directed_resource_type = NA_character_,
            directed_mwh          = NA_real_,
            compensation_payment  = NA_real_,
            retained_trading_amount = NA_real_,
            additional_compensation = NA_real_,
            ie_fee                = NA_real_,
            cra                   = NA_real_,
            source_format         = "old",
            source_file           = basename(f))]
  d[]
}

read_old_costs <- function(f) {
  d <- extract_table(f, "Directions cost & directed MWh",
                     markers = c("Year", "Directed MWh"),
                     clean_names = OLD_COST_COLS)
  if (is.null(d) || !nrow(d)) return(NULL)

  # Keep only numeric rows (skip footnote rows that creep in)
  # Use [[]] to avoid data.table::year() shadowing the column name
  d[, report_year  := suppressWarnings(as.numeric(d[["report_year"]]))]
  d[, report_month := suppressWarnings(as.numeric(d[["report_month"]]))]
  d <- d[!is.na(report_year)]

  date_cols <- c("report_event", "direction_start", "direction_end")
  for (cc in date_cols) d[, (cc) := excel_to_posix(suppressWarnings(as.numeric(d[[cc]])))]

  num_cols <- setdiff(OLD_COST_COLS, c("report_year", "report_month", "report_event", "direction_start", "direction_end"))
  for (cc in num_cols) d[, (cc) := suppressWarnings(as.numeric(d[[cc]]))]

  d[, source_file := basename(f)]
  d[]
}

# ---------------------------------------------------------------------------
# New-format extractor
# ---------------------------------------------------------------------------

NEW_EVENT_COLS <- c(
  "report_event", "duid", "participant", "region",
  "issue_time", "effective_time", "cancellation_time",
  "directed_resource_type", "reason", "direction_instruction",
  "market_notice", "directed_mwh",
  "compensation_payment", "retained_trading_amount",
  "additional_compensation", "ie_fee", "cra"
)

read_new_events <- function(f) {
  # New format has TWO sub-tables in "Directions summary":
  #   1. Compliance notifications (~row 66): no "Directed MWh" column
  #   2. Direction events (~row 82): has "Directed MWh"
  # We detect by requiring both "Directed MWh" and "Cancellation time".
  d <- extract_table(f, "Directions summary",
                     markers = c("Directed MWh", "Cancellation time"),
                     clean_names = NEW_EVENT_COLS)
  if (is.null(d) || !nrow(d)) return(NULL)

  date_cols <- c("report_event", "issue_time", "effective_time", "cancellation_time")
  for (cc in date_cols) d[, (cc) := excel_to_posix(suppressWarnings(as.numeric(get(cc))))]

  num_cols <- c("directed_mwh", "compensation_payment", "retained_trading_amount",
                "additional_compensation", "ie_fee", "cra")
  for (cc in num_cols) d[, (cc) := suppressWarnings(as.numeric(get(cc)))]

  d[, `:=`(source_format = "new", source_file = basename(f))]
  d[]
}

# ---------------------------------------------------------------------------
# Recovery rates extractor
# ---------------------------------------------------------------------------

read_recovery_rates <- function(f) {
  # Sheet "Directions recovery rates":
  #   row 3: "reporting period start | reporting period end | Recovery rate ($/MWh)"
  #   row 4: start_serial | end_serial | "date & time" | SA1 | VIC1 | NSW1 | TAS1 | QLD1
  #   row 5+: interval_serial | SA1_rate [| VIC1_rate | NSW1_rate | TAS1_rate | QLD1_rate]
  raw <- tryCatch(
    suppressMessages(read_excel(f, sheet = "Directions recovery rates", col_names = FALSE)),
    error = function(e) NULL
  )
  if (is.null(raw)) return(NULL)

  # Find row 4 sub-header (contains region names)
  hrow4 <- NA_integer_
  for (i in seq_len(min(20L, nrow(raw)))) {
    cells <- as.character(unlist(raw[i, ]))
    if (any(grepl("SA1", cells, fixed = TRUE))) { hrow4 <- i; break }
  }
  if (is.na(hrow4)) return(NULL)

  # Reporting period bounds from row 3 or 4
  bounds <- suppressWarnings(as.numeric(unlist(raw[hrow4, 1:2])))
  period_start <- if (!is.na(bounds[1])) excel_to_posix(bounds[1]) else NA
  period_end   <- if (!is.na(bounds[2])) excel_to_posix(bounds[2]) else NA

  # Column names: date_time, SA1, VIC1, NSW1, TAS1, QLD1 (may be spread over positions 3-8)
  hdrs <- as.character(unlist(raw[hrow4, ]))
  # Find region columns by label
  regions <- c("SA1", "VIC1", "NSW1", "TAS1", "QLD1")
  region_cols <- sapply(regions, function(r) {
    idx <- which(hdrs == r)
    if (length(idx)) idx[1] else NA_integer_
  })

  # Data starts at row hrow4 + 1
  data_rows <- raw[(hrow4 + 1L):nrow(raw), ]
  data_rows <- as.data.table(data_rows)

  # Datetime column: look for "date & time" label in header (e.g. col 4),
  # then fall back to first column with non-NA numeric values.
  dt_col <- NA_integer_
  dt_label_col <- which(grepl("date.*time", tolower(hdrs)))
  if (length(dt_label_col)) {
    dt_col <- dt_label_col[1]
  } else {
    for (ci in seq_len(ncol(data_rows))) {
      vals <- suppressWarnings(as.numeric(unlist(data_rows[, ci, with = FALSE])))
      if (any(!is.na(vals))) { dt_col <- ci; break }
    }
  }
  if (is.na(dt_col)) return(NULL)

  dt_vals <- suppressWarnings(as.numeric(unlist(data_rows[, dt_col, with = FALSE])))

  d <- data.table(
    interval_datetime = excel_to_posix(dt_vals),
    period_start      = period_start,
    period_end        = period_end
  )
  for (r in names(region_cols)) {
    ci <- region_cols[[r]]
    if (!is.na(ci) && ci <= ncol(data_rows)) {
      d[, (r) := suppressWarnings(as.numeric(unlist(data_rows[, ci, with = FALSE])))]
    } else {
      d[, (r) := NA_real_]
    }
  }
  d <- d[!is.na(interval_datetime)]
  d[, source_file := basename(f)]
  d[]
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

files <- list.files(DATA_DIR, pattern = "\\.xlsx$", full.names = TRUE)
cat(sprintf("Processing %d Excel files...\n", length(files)))

events_list  <- list()
costs_list   <- list()
rates_list   <- list()

for (f in files) {
  cat(sprintf("  %s\n", basename(f)))
  sheets <- excel_sheets(f)

  if ("Summary & directions assessment" %in% sheets) {
    ev <- read_old_events(f)
    if (!is.null(ev) && nrow(ev)) {
      cat(sprintf("    [old] events: %d rows\n", nrow(ev)))
      events_list[[length(events_list) + 1L]] <- ev
    }
    co <- read_old_costs(f)
    if (!is.null(co) && nrow(co)) {
      cat(sprintf("    [old] costs:  %d rows\n", nrow(co)))
      costs_list[[length(costs_list) + 1L]] <- co
    }
  } else if ("Directions summary" %in% sheets) {
    ev <- read_new_events(f)
    if (!is.null(ev) && nrow(ev)) {
      cat(sprintf("    [new] events: %d rows\n", nrow(ev)))
      events_list[[length(events_list) + 1L]] <- ev
    }
  }

  rr <- read_recovery_rates(f)
  if (!is.null(rr) && nrow(rr)) {
    cat(sprintf("    recovery rates: %d intervals\n", nrow(rr)))
    rates_list[[length(rates_list) + 1L]] <- rr
  }
}

# ---------------------------------------------------------------------------
# Stack, deduplicate, save
# ---------------------------------------------------------------------------

if (length(events_list)) {
  events <- rbindlist(events_list, fill = TRUE, use.names = TRUE)

  # Deduplicate: same duid + issue_time + effective_time may appear in overlapping reports
  events <- unique(events, by = c("duid", "issue_time", "effective_time"))
  setorder(events, issue_time, duid)

  cat(sprintf("\nTotal direction events: %d rows across %d DUIDs\n",
              nrow(events), uniqueN(events$duid)))
  cat(sprintf("Period: %s to %s\n",
              format(min(events$issue_time, na.rm = TRUE)),
              format(max(events$cancellation_time, na.rm = TRUE))))

  saveRDS(events, file.path(OUT_DIR, "direction_events.rds"))
  fwrite(events, file.path(OUT_DIR, "direction_events.csv"))
  cat(sprintf("Saved: %s\n", file.path(OUT_DIR, "direction_events.rds")))
}

if (length(costs_list)) {
  costs <- rbindlist(costs_list, fill = TRUE, use.names = TRUE)
  costs <- unique(costs, by = c("report_event", "direction_start"))
  setorder(costs, direction_start)
  saveRDS(costs, file.path(OUT_DIR, "direction_costs.rds"))
  fwrite(costs, file.path(OUT_DIR, "direction_costs.csv"))
  cat(sprintf("Saved: %s (%d rows)\n", file.path(OUT_DIR, "direction_costs.rds"), nrow(costs)))
}

if (length(rates_list)) {
  rates <- rbindlist(rates_list, fill = TRUE, use.names = TRUE)
  rates <- unique(rates, by = c("source_file", "interval_datetime"))
  setorder(rates, interval_datetime)
  saveRDS(rates, file.path(OUT_DIR, "recovery_rates.rds"))
  cat(sprintf("Saved: %s (%d interval-file rows)\n",
              file.path(OUT_DIR, "recovery_rates.rds"), nrow(rates)))
}

cat("\nDone.\n")
