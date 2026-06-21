#!/usr/bin/env Rscript
# 00_episodes.R
# Shared episode builder for the direction-rebid analyses (A and B).
#
# One row per direction EPISODE, per DUID, with the three timestamps the design
# turns on:
#   tau = issue_time        (when AEMO issued the direction)
#   s   = effective_time    (start of the directed window)
#   c   = cancellation_time (end of the directed window)
#   lead = s - tau
# plus the instruction (Synchronise / Remain) and the focal station.
#
# Output: outputs/direction_rebid/episodes.rds
#
# Scope note: every directed SA-panel DUID maps to one of the 8 focal stations
# that already carry an ex-ante depth measure in pivotality_panel.rds, so no
# depth rebuild is needed downstream.

suppressMessages(library(data.table))
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/direction_rebid"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# DUID -> focal station (same map as build_treatment_panel.R / depth_by_directed.R)
STAT <- c(TORRB1 = "torrens_island_b", TORRB2 = "torrens_island_b",
          TORRB3 = "torrens_island_b", TORRB4 = "torrens_island_b",
          PPCCGT = "pelican_point_gt", `OSB-AG` = "osborne_gt_st",
          QPS5 = "quarantine_5", MINTARO = "mintaro",
          DRYCGT1 = "dry_creek", DRYCGT2 = "dry_creek", DRYCGT3 = "dry_creek",
          BARKIPS1 = "bips")
# concatenation-artefact recodes confirmed in build_treatment_panel.R
DUID_FIX <- c(TORRB35 = "TORRB3", TORRB46 = "TORRB4", MINTARO1 = "MINTARO")

# ---- load + clean events ----
ev <- as.data.table(readRDS("direction_data/parsed/direction_events.rds"))
ev <- ev[!is.na(duid)]
for (b in names(DUID_FIX)) ev[duid == b, duid := DUID_FIX[[b]]]
ev <- ev[direction_instruction %in% c("Synchronise", "Remain")]
ev[, station := STAT[as.character(duid)]]
ev <- ev[!is.na(station)]                       # keep directed SA focal DUIDs only

# normalise timestamp tzone for display (all are UTC+10; relabel, do not shift)
for (col in c("issue_time", "effective_time", "cancellation_time"))
  setattr(ev[[col]], "tzone", "Australia/Brisbane")

ev[, dur_h  := as.numeric(difftime(cancellation_time, effective_time, units = "hours"))]
ev <- ev[dur_h > 0]                             # drop pre-effective cancellations

ep <- ev[, .(
  duid, station,
  tau = issue_time, s = effective_time, c = cancellation_time,
  instruction = direction_instruction,
  reason,
  dur_h
)]
ep[, lead_h := as.numeric(difftime(s, tau, units = "hours"))]
setorder(ep, duid, s)
ep[, episode_id := .I]
setcolorder(ep, c("episode_id", "duid", "station", "instruction",
                  "tau", "s", "c", "lead_h", "dur_h", "reason"))

# ---- summary ----
cat(sprintf("Episodes: %d  (Synchronise %d / Remain %d)\n",
            nrow(ep), sum(ep$instruction == "Synchronise"),
            sum(ep$instruction == "Remain")))
cat(sprintf("DUIDs: %d | stations: %d\n", uniqueN(ep$duid), uniqueN(ep$station)))
cat(sprintf("lead<=0 (no pre-issue window): %d\n", sum(ep$lead_h <= 0)))
cat("\nEpisodes per DUID:\n"); print(ep[, .N, by = .(duid, station)][order(-N)])

saveRDS(ep, file.path(OUT, "episodes.rds"))
cat(sprintf("\nSaved: %s\n", file.path(OUT, "episodes.rds")))
