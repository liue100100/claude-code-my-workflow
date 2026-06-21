#!/usr/bin/env Rscript
# B_rebid_runup.R  -- Analysis B (headline)
# Pre-issue rebid run-up. For each episode we collect every BIDOFFERPERIOD
# version whose TARGET interval g (INTERVAL_DATETIME) lies in the directed window
# and index it by
#       Delta = OFFERDATETIME (submission) - tau (issue time).
# Delta < 0 is the pre-issue run-up (interpretable); Delta > 0 is contaminated by
# the direction itself and is plotted but never read as "reversion".
#
# CRITICAL: OFFERDATETIME (submission) is never conflated with INTERVAL_DATETIME
# (the target interval g in [s,c]).
#
# Two target-interval definitions, run side by side:
#   whole : g in [s, c]                (entire directed window)
#   onset : g in [s, s + first hour]   (starting intervals only)
#
# Per (episode, version) metrics, averaged/pooled across the target intervals g:
#   mean_maxavail   = mean MAXAVAIL over g                (quantity offered)
#   abovesrmc_share = sum_g sum_k BANDAVAILk*1{PRICEBANDk>SRMC} / sum_g sum_k BANDAVAILk
#
# Run-up metrics per episode (Delta<0 only):
#   runup_withhold  = mean_maxavail(baseline)  - mean_maxavail(last_pre)   (>0 = withdrew)
#   runup_abovesrmc = abovesrmc_share(last_pre) - abovesrmc_share(baseline)(>0 = shifted up)
# baseline = earliest version targeting g (most negative Delta);
# last_pre = version with the largest Delta < 0.
#
# Headline = Synchronise; Remain = placebo. Run-up interacted with ex-ante depth
# at onset (from Analysis A) and with d_t = 1{date >= 2023-07-01} (post SA exit).

suppressMessages({ library(data.table); library(fixest); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/direction_rebid"; CACHE <- "bid_cache"

ONSET_N   <- 12L                       # first hour = first 12 five-minute intervals
EXIT_DATE <- as.Date("2023-07-01")     # d_t threshold (post SA thermal exit)
BANDS     <- 1:10
bcols     <- paste0("BANDAVAIL", BANDS)
pcols     <- paste0("PRICEBAND", BANDS)

ep <- as.data.table(readRDS(file.path(OUT, "episodes.rds")))
ep[, `:=`(tau_s = as.numeric(tau),
          s_grid = (floor(as.numeric(s) / 300) + 1) * 300,     # first directed interval
          c_grid =  floor(as.numeric(c) / 300) * 300)]          # last directed interval
ep <- ep[c_grid >= s_grid]                                      # drop sub-interval episodes
ep[, onset_hi := s_grid + (ONSET_N - 1) * 300]

# SRMC per duid-month
srmc <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  , .(DUID = duid, yyyymm = as.integer(yyyymm), srmc_marginal)]

# months whose bid files we must touch (intersection of episode windows and cache)
month_of <- function(secs) as.integer(format(as.POSIXct(secs, origin = "1970-01-01",
                                                        tz = "Australia/Brisbane"), "%Y%m"))
all_months <- unique(unlist(lapply(seq_len(nrow(ep)), function(i) {
  ms <- seq(as.Date(format(as.POSIXct(ep$s_grid[i], origin = "1970-01-01",
                                      tz = "Australia/Brisbane"))),
            as.Date(format(as.POSIXct(ep$c_grid[i], origin = "1970-01-01",
                                      tz = "Australia/Brisbane"))), by = "month")
  unique(as.integer(format(ms, "%Y%m")))
})))
have <- file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%d.rds", all_months))) &
        file.exists(file.path(CACHE, sprintf("BIDDAYOFFER_%d.rds",  all_months)))
months <- sort(all_months[have])
cat(sprintf("Episodes in scope: %d | months to scan: %d (%d..%d)\n",
            nrow(ep), length(months), min(months), max(months)))

DIRECTED_DUIDS <- unique(ep$duid)

# ---- per-month pass: aggregate to (scope, episode_id, OFFERDATETIME) ----
process_month <- function(M) {
  b <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%d.rds", M))))
  b <- b[BIDTYPE == "ENERGY" & DUID %in% DIRECTED_DUIDS,
         c("DUID", "TRADINGDATE", "INTERVAL_DATETIME", "OFFERDATETIME", "MAXAVAIL", bcols),
         with = FALSE]
  if (!nrow(b)) return(NULL)

  # price ladder: latest BIDDAYOFFER per (DUID, trading day)
  bdo <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%d.rds", M))))
  bdo <- bdo[BIDTYPE == "ENERGY" & DUID %in% DIRECTED_DUIDS]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by = .(DUID, SETTLEMENTDATE)]$V1]
  ladder <- bdo[, c("DUID", "SETTLEMENTDATE", pcols), with = FALSE]
  setnames(ladder, "SETTLEMENTDATE", "TRADINGDATE")

  b <- merge(b, ladder, by = c("DUID", "TRADINGDATE"), all.x = TRUE)
  b[, yyyymm := as.integer(format(TRADINGDATE, "%Y%m"))]
  b <- merge(b, srmc, by = c("DUID", "yyyymm"), all.x = TRUE)

  # per-row offered quantity total and above-SRMC quantity
  bmat <- as.matrix(b[, bcols, with = FALSE]); bmat[is.na(bmat)] <- 0
  pmat <- as.matrix(b[, pcols, with = FALSE])
  above <- pmat > b$srmc_marginal; above[is.na(above)] <- FALSE
  b[, total_offer := rowSums(bmat)]
  b[, above_offer := rowSums(bmat * above)]
  b[, isecs := as.numeric(INTERVAL_DATETIME)]
  b[, c(bcols, pcols) := NULL]

  # map each bid row (target interval g) to its episode via foverlaps
  bo <- b[, .(DUID, istart = isecs, iend = isecs,
              OFFERDATETIME, MAXAVAIL, total_offer, above_offer, isecs)]
  setkey(bo, DUID, istart, iend)
  epk <- ep[, .(duid, episode_id, instruction, tau_s, g_lo = s_grid, g_hi = c_grid, onset_hi)]
  setkey(epk, duid, g_lo, g_hi)
  m <- foverlaps(bo, epk, by.x = c("DUID", "istart", "iend"),
                 by.y = c("duid", "g_lo", "g_hi"), nomatch = 0L)
  if (!nrow(m)) return(NULL)
  m[, onset := isecs <= onset_hi]

  whole <- m[, .(scope = "whole", sum_mx = sum(MAXAVAIL), n_g = .N,
                 sum_above = sum(above_offer), sum_total = sum(total_offer)),
             by = .(episode_id, OFFERDATETIME)]
  onset <- m[onset == TRUE,
             .(scope = "onset", sum_mx = sum(MAXAVAIL), n_g = .N,
               sum_above = sum(above_offer), sum_total = sum(total_offer)),
             by = .(episode_id, OFFERDATETIME)]
  rbind(whole, onset)
}

VER_FILE <- file.path(OUT, "B_versions.rds")
if (file.exists(VER_FILE) && !nzchar(Sys.getenv("REBUILD_VERSIONS"))) {
  cat("Reusing existing B_versions.rds (set REBUILD_VERSIONS=1 to rescan months).\n")
  ver <- as.data.table(readRDS(VER_FILE))
} else {
  cat("Scanning months...\n")
  agg <- rbindlist(lapply(months, function(M) {
    r <- process_month(M); cat(sprintf("  %d: %s rows\n", M, if (is.null(r)) 0 else nrow(r)))
    r
  }))
  # recombine episodes split across month files
  ver <- agg[, .(sum_mx = sum(sum_mx), n_g = sum(n_g),
                 sum_above = sum(sum_above), sum_total = sum(sum_total)),
             by = .(scope, episode_id, OFFERDATETIME)]
  ver <- merge(ver, ep[, .(episode_id, duid, instruction, tau_s, s)], by = "episode_id")
  ver[, mean_maxavail   := sum_mx / n_g]
  ver[, abovesrmc_share := fifelse(sum_total > 0, sum_above / sum_total, NA_real_)]
  ver[, delta_h := (as.numeric(OFFERDATETIME) - tau_s) / 3600]
  saveRDS(ver, VER_FILE)
}
cat(sprintf("\nVersion-level rows: %d | episodes with >=1 version: %d\n",
            nrow(ver), uniqueN(ver$episode_id)))

# ---- event-time traces (binned on Delta), by instruction x scope ----
brk <- c(-Inf, -48, -36, -24, -18, -12, -9, -6, -3, -1, 0, 1, 3, 6, 12, 24, Inf)
ver[, dbin := cut(delta_h, breaks = brk, right = FALSE)]
# baseline-relative MAXAVAIL (per episode, vs earliest version) for cross-unit comparability
ver[, base_mx := mean_maxavail[which.min(OFFERDATETIME)], by = .(scope, episode_id)]
ver[, rel_mx := mean_maxavail - base_mx]

trace <- ver[!is.na(dbin), .(
  n_obs        = .N,
  maxavail     = mean(mean_maxavail, na.rm = TRUE),
  rel_maxavail = mean(rel_mx, na.rm = TRUE),
  abovesrmc    = mean(abovesrmc_share, na.rm = TRUE)
), by = .(scope, instruction, dbin)]
trace[, dbin_lo := brk[as.integer(dbin)]]
setorder(trace, scope, instruction, dbin_lo)
fwrite(trace, file.path(OUT, "B_trace.csv"))

plot_trace <- function(yvar, ylab, fname, ttl) {
  d <- trace[is.finite(dbin_lo)]
  p <- ggplot(d, aes(dbin_lo, get(yvar), colour = instruction)) +
    annotate("rect", xmin = 0, xmax = max(d$dbin_lo), ymin = -Inf, ymax = Inf,
             alpha = 0.08, fill = "red") +
    geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
    geom_line(linewidth = 0.9) + geom_point(size = 1.4) +
    facet_wrap(~scope, ncol = 1, scales = "free_y",
               labeller = labeller(scope = c(whole = "g in [s,c] (whole window)",
                                             onset = "g in [s, s+1h] (onset)"))) +
    labs(title = ttl,
         subtitle = "x = Delta = submission - issue (h). Shaded Delta>0 = post-issue, contaminated (not interpreted).",
         x = "Delta (hours relative to direction issue)", y = ylab, colour = NULL) +
    theme_bw(base_size = 11) +
    theme(plot.subtitle = element_text(size = 8, colour = "grey30"),
          legend.position = "bottom")
  ggsave(file.path(OUT, fname), p, width = 8.5, height = 7, dpi = 150)
}
plot_trace("rel_maxavail", "Mean MAXAVAIL minus episode baseline (MW)",
           "B_trace_maxavail.png", "Capacity offered (MAXAVAIL) around direction issue")
plot_trace("abovesrmc", "Mean above-SRMC share of offered MW",
           "B_trace_abovesrmc.png", "Above-SRMC share around direction issue")

# ---- run-up metrics per episode (Delta<0 only) ----
pre <- ver[delta_h < 0]
runup <- pre[, {
  ob <- OFFERDATETIME
  ib <- which.min(ob); il <- which.max(ob)
  .(n_pre        = .N,
    base_mx      = mean_maxavail[ib],   last_mx   = mean_maxavail[il],
    base_above   = abovesrmc_share[ib], last_above = abovesrmc_share[il])
}, by = .(scope, episode_id)]
runup[, runup_withhold  := base_mx - last_mx]
runup[, runup_abovesrmc := last_above - base_above]
runup <- merge(runup, ep[, .(episode_id, duid, instruction, s)], by = "episode_id")
runup <- merge(runup, as.data.table(readRDS(file.path(OUT, "A_episode_depth.rds")))[
                 , .(episode_id, depth_onset = onset_depth)], by = "episode_id", all.x = TRUE)
runup[, d_t  := as.integer(as.Date(s) >= EXIT_DATE)]
runup[, ym   := format(as.Date(s), "%Y%m")]
fwrite(runup, file.path(OUT, "B_runup_metrics.csv"))

cat("\n=== Run-up summary (Delta<0; >0 withhold = withdrew capacity pre-issue) ===\n")
print(runup[, .(n = .N,
                mean_n_pre        = round(mean(n_pre), 1),
                mean_withhold_MW  = round(mean(runup_withhold,  na.rm = TRUE), 2),
                mean_abovesrmc    = round(mean(runup_abovesrmc, na.rm = TRUE), 4)),
            by = .(scope, instruction)][order(scope, instruction)])

# ---- regressions: run-up x ex-ante depth x d_t ; Synchronise headline, Remain placebo ----
sink(file.path(OUT, "B_runup_regression.txt"))
for (sc in c("whole", "onset")) {
  cat(sprintf("\n############ SCOPE = %s ############\n", sc))
  for (resp in c("runup_withhold", "runup_abovesrmc")) {
    dat <- runup[scope == sc & is.finite(get(resp)) & !is.na(depth_onset)]
    fml <- as.formula(sprintf("%s ~ depth_onset * d_t | duid", resp))
    mS <- tryCatch(feols(fml, dat[instruction == "Synchronise"], vcov = ~ym), error = function(e) NULL)
    mR <- tryCatch(feols(fml, dat[instruction == "Remain"],      vcov = ~ym), error = function(e) NULL)
    cat(sprintf("\n----- %s  (%s) -----\n", resp, sc))
    mods <- Filter(Negate(is.null), list(Synchronise = mS, Remain_placebo = mR))
    if (length(mods)) print(etable(mods, digits = 4, fitstat = ~ n + r2)) else cat("  (no estimable model)\n")
  }
}
sink()
cat(readLines(file.path(OUT, "B_runup_regression.txt")), sep = "\n")
cat(sprintf("\nSaved: B_versions.rds, B_trace.{csv,png x2}, B_runup_metrics.csv, B_runup_regression.txt\n"))
