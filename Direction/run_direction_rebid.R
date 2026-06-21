#!/usr/bin/env Rscript
# run_direction_rebid.R
# Driver for the direction-rebid analyses. Runs, in order:
#   00_episodes.R         -> outputs/direction_rebid/episodes.rds
#   A_depth_eventstudy.R  -> ex-ante depth onset/tail/matched (Analysis A)
#   B_rebid_runup.R       -> pre-issue rebid run-up, Delta-indexed (Analysis B)
#
# Run from the Direction/ directory:  Rscript run_direction_rebid.R

setwd("C:/Users/ericl/Documents/my-project/Direction")
steps <- c("00_episodes.R", "A_depth_eventstudy.R", "B_rebid_runup.R")
for (s in steps) {
  cat(sprintf("\n========== %s ==========\n", s))
  t0 <- Sys.time()
  ok <- tryCatch({ source(s, local = new.env()); TRUE }, error = function(e) {
    cat(sprintf("FAIL %s: %s\n", s, conditionMessage(e))); FALSE })
  cat(sprintf("%s %s (%.0fs)\n", if (ok) "PASS" else "FAIL", s,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (!ok) quit(status = 1L)
}
cat("\nAll stages PASS. Outputs in outputs/direction_rebid/\n")
