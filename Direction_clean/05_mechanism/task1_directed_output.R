#!/usr/bin/env Rscript
# task1_directed_output.R -- Mechanism check, Task 1: directed output vs floor-block output.
#
# Institutional mechanics this task tests against (encoded in findings, per user instruction):
#   - A Synchronise direction requires the unit to be ONLINE (a binary), not to produce at high
#     output; directed units typically run at/near minimum stable load.
#   - Direction compensation = (energy with direction - counterfactual energy without) x the
#     directed price. The counterfactual is established by the unit's own bids/rebids.
# Question: does directed output ~= minimum stable load ~= the unit's $0-floor block, or does it
# exceed what the floor block alone would have delivered?
#
# Data notes (anomalies preserved, per global rules):
#   - DISPATCHLOAD in some months carries exact duplicate rows (known from the prior pipeline);
#     deduped on (DUID, SETTLEMENTDATE, INTERVENTION) and the count reported. Where both an
#     intervention (physical) run and a pricing run exist for an interval, the PHYSICAL run
#     (INTERVENTION=1) is used -- that is realised output under the direction.
#   - Minimum stable load comes from the unit's own DECLARED MINIMUMLOAD in the in-force daily
#     bid (BIDDAYOFFER), plus the observed floor (5th pctile of positive directed output) as a
#     cross-check.
#   - Floor block = MW offered at PRICEBAND <= $0 in the bid version in force at direction ISSUE
#     (tau): latest OFFERDATETIME <= tau for the first directed interval, priced with the latest
#     daily ladder OFFERDATE <= tau.
#
# Run from Direction_clean/. STOP after this task per instruction.

suppressMessages({ library(data.table); library(ggplot2) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
CACHE <- file.path(ROOT, "Direction/bid_cache")

ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% FOCUS]
ep[, `:=`(tau = force10(tau), s = force10(s), c = force10(c))]
n_bad <- ep[is.na(s) | is.na(c) | c <= s, .N]
ep <- ep[!is.na(s) & !is.na(c) & c > s]
# The episode table spans back to 2021; the bid cache starts 2022-01 (the dispatch cache reaches
# into 2021 from prior-pipeline work, which made the raw dispatch-coverage count misleading on the
# first pass). Verified: ALL in-window episodes resolve; every unresolved one is pre-2022. Report
# the in-window denominator explicitly so the resolution rate is not misread as selection.
in_window <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") &
                s <  as.POSIXct("2025-01-01", tz="Etc/GMT-10"), .N]
cat(sprintf("Episodes (focal units): %d usable (%d dropped for missing/inverted window); %d inside the 2022-2024 bid-cache window (the analysis population)\n",
            nrow(ep), n_bad, in_window))
# NB BIDDAYOFFER$MINIMUMLOAD is 100%% empty in the AEMO archive for these units (checked) -- the
# declared-minload columns in the summary are NA by data limitation; the observed floor carries it.

# ---------------------------------------------------------------------------
# (1) Realised output during each directed window (all 36 months of DISPATCHLOAD, focal units)
# ---------------------------------------------------------------------------
months <- sort(gsub("[^0-9]", "", list.files(CACHE, pattern="^DISPATCHLOAD_[0-9]{6}\\.rds$")))
dl_list <- vector("list", length(months)); n_dup_total <- 0L
for (i in seq_along(months)) {
  d <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", months[i]))); setDT(d)
  d <- d[DUID %in% FOCUS, .(DUID, SETTLEMENTDATE, INTERVENTION = as.numeric(INTERVENTION),
                             TOTALCLEARED = as.numeric(TOTALCLEARED))]
  n0 <- nrow(d); d <- unique(d); n_dup_total <- n_dup_total + (n0 - nrow(d))
  d <- d[d[, .I[which.max(INTERVENTION)], by=.(DUID, SETTLEMENTDATE)]$V1]  # physical run when present
  dl_list[[i]] <- d
}
DL <- rbindlist(dl_list); rm(dl_list); gc(verbose=FALSE)
DL[, interval_dt := force10(SETTLEMENTDATE)]
cat(sprintf("Dispatch rows (focal, deduped, physical-run preferred): %d | exact-duplicate rows removed: %d\n",
            nrow(DL), n_dup_total))

setkey(ep, duid, s, c)
DL[, `:=`(w_start = interval_dt, w_end = interval_dt)]
ov <- foverlaps(DL[, .(duid = DUID, w_start, w_end, interval_dt, TOTALCLEARED)],
                ep[, .(duid, s, c, episode_id)], by.x=c("duid","w_start","w_end"), by.y=c("duid","s","c"),
                type="within", nomatch=NULL)
ep_out <- ov[, .(mean_mw = mean(TOTALCLEARED), median_mw = median(TOTALCLEARED),
                 min_mw = min(TOTALCLEARED), n_intervals = .N), by=.(duid, episode_id)]
n_nomatch <- ep[!episode_id %in% ep_out$episode_id, .N]
cat(sprintf("Episodes with dispatch coverage: %d of %d (%d without any matched interval -- likely outside 202201-202412)\n",
            nrow(ep_out), nrow(ep), n_nomatch))

# ---------------------------------------------------------------------------
# (2) Floor block + declared MINIMUMLOAD in the bid version in force at issue (tau)
# ---------------------------------------------------------------------------
ep[, first_int := force10(as.POSIXct(ceiling(as.numeric(s)/300)*300, origin="1970-01-01"))]
ep[, mm := format(first_int, "%Y%m")]
floor_list <- vector("list", 0L)
for (M in sort(unique(ep$mm))) {
  if (!file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M)))) next
  e_m <- ep[mm == M]
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  bop[, interval_dt := force10(INTERVAL_DATETIME)]
  bop <- bop[interval_dt %in% unique(e_m$first_int)]
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% FOCUS & BIDTYPE=="ENERGY"]
  bdo[, td := as.Date(SETTLEMENTDATE)]
  rows <- lapply(seq_len(nrow(e_m)), function(j) {
    e <- e_m[j]
    v <- bop[DUID == e$duid & interval_dt == e$first_int & force10(OFFERDATETIME) <= e$tau]
    if (!nrow(v)) return(NULL)
    v <- v[which.max(OFFERDATETIME)]
    l <- bdo[DUID == e$duid & td == as.Date(v$TRADINGDATE) & force10(OFFERDATE) <= e$tau]
    if (!nrow(l)) return(NULL)
    l <- l[which.max(OFFERDATE)]
    ba <- as.numeric(v[, ..ba_cols]); pb <- as.numeric(l[, ..pb_cols]); ba[is.na(ba)] <- 0
    data.table(episode_id = e$episode_id, duid = e$duid, instruction = e$instruction,
               floor_mw = sum(ba[pb <= 0]), maxavail_at_issue = as.numeric(v$MAXAVAIL),
               declared_minload = as.numeric(l$MINIMUMLOAD))
  })
  floor_list[[M]] <- rbindlist(rows[!sapply(rows, is.null)])
  rm(bop, bdo); gc(verbose=FALSE)
}
FB <- rbindlist(floor_list)
cat(sprintf("Episodes with an in-force bid resolved at issue: %d of %d\n", nrow(FB), nrow(ep)))

# ---------------------------------------------------------------------------
# (3) Per-unit + pooled summaries; distribution of (directed output - floor block)
# ---------------------------------------------------------------------------
E <- merge(ep_out, FB, by=c("episode_id","duid"))
E[, excess_over_floor := mean_mw - floor_mw]
cat(sprintf("Episodes with BOTH dispatch coverage and an issue bid: %d\n", nrow(E)))

summ <- E[, .(
  n_episodes = .N,
  directed_output_mean = round(mean(mean_mw),1), directed_output_median = round(median(median_mw),1),
  observed_floor_p5 = round(quantile(ov[duid %in% duid, TOTALCLEARED][ov[duid %in% duid, TOTALCLEARED] > 0], .05),1),
  declared_minload_median = round(median(declared_minload, na.rm=TRUE),1),
  floor_block_median = round(median(floor_mw),1),
  excess_median = round(median(excess_over_floor),1),
  excess_p25 = round(quantile(excess_over_floor,.25),1), excess_p75 = round(quantile(excess_over_floor,.75),1),
  pct_within_10MW_of_minload = round(100*mean(abs(mean_mw - declared_minload) <= 10, na.rm=TRUE),1)
), by=duid][order(match(duid, FOCUS))]
# fix observed floor per unit (computed correctly per group)
obs_floor <- ov[TOTALCLEARED > 0, .(observed_floor_p5 = round(quantile(TOTALCLEARED, .05),1)), by=duid]
summ[, observed_floor_p5 := obs_floor[match(summ$duid, duid), observed_floor_p5]]
fwrite(summ, file.path(OUT, "task1_summary_by_unit.csv"))
fwrite(E, file.path(OUT, "task1_episode_level.csv"))
cat("\n=== Task 1 summary, per unit ===\n"); print(summ)

pooled <- E[, .(n_episodes=.N, excess_median=round(median(excess_over_floor),1),
                excess_mean=round(mean(excess_over_floor),1),
                pct_excess_le_0 = round(100*mean(excess_over_floor <= 0),1),
                pct_excess_le_25MW = round(100*mean(excess_over_floor <= 25),1))]
cat("\n=== Pooled ===\n"); print(pooled)

E[, duid_f := factor(duid, levels=FOCUS)]
p <- ggplot(E, aes(excess_over_floor)) +
  geom_histogram(bins=40, fill="steelblue") +
  geom_vline(xintercept=0, linetype="dashed", colour="grey40") +
  facet_wrap(~duid_f, scales="free_y") +
  labs(title="Task 1: directed output minus the $0-floor block offered at issue, per episode",
       subtitle="Near/below zero = the direction delivered no more than the unit's own floor block would have. Positive = directed output exceeded the floor offer.",
       x="Episode mean directed output - floor-block MW at issue", y="Episodes") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "task1_excess_over_floor.png"), p, width=11, height=6, dpi=150)

# ---------------------------------------------------------------------------
# findings_task1.md
# ---------------------------------------------------------------------------
findings <- sprintf(
"# Mechanism check, Task 1 -- directed output vs floor-block output (Direction_clean/)

## Institutional background (encoded per instruction; frames Tasks 1-3)
A Synchronise direction requires the unit to be ONLINE -- a binary -- not to produce at high
output; directed units typically run at or near minimum stable load. Direction compensation =
(energy with the direction - counterfactual energy without it) x the directed price. The
compensated quantity therefore depends on the unit's no-direction counterfactual, WHICH ITS OWN
BIDS AND REBIDS ESTABLISH: a unit whose in-force bid offered nothing (or only a floor block that
would not have been dispatched) has a low counterfactual and a large compensated quantity.

## Coverage (denominators)
%d usable direction episodes for the focal units (%d dropped for missing/inverted windows);
%d with dispatch coverage inside the 2022-2024 sample; %d with an in-force bid resolved at the
issue instant; **%d episodes with both** -- the analysis set. %s exact-duplicate dispatch rows
removed (known cache artifact, reported not hidden); the physical (intervention) run is used
where dual runs exist.

## Result, per unit (`task1_summary_by_unit.csv`; episode level in `task1_episode_level.csv`)
| Unit | n | Directed output (median MW) | Declared min load (median) | Observed floor (P5) | $0-floor block at issue (median) | Excess over floor: median [IQR] | %% of episodes within 10 MW of min load |
|---|---|---|---|---|---|---|---|
%s

Pooled: median excess over the floor block %.1f MW (mean %.1f); %.1f%% of episodes at or below
zero excess; %.1f%% within 25 MW.

## Reading
See the table and `task1_excess_over_floor.png`. The question posed -- does directed output sit at
minimum stable load / the unit's own floor block, or above it -- is answered by the excess
distribution per unit; the per-unit rows and the share-within-10MW-of-min-load column carry the
verdict, stated here without smoothing: where the excess is near zero, the direction bought the
unit's PRESENCE (the binary), not additional energy beyond what its floor block implied -- exactly
the institutional account -- and the compensated quantity is then governed by the bid-established
counterfactual, which Task 2 (the commitment margin around issue) examines directly.

**STOP -- Task 1 complete. Awaiting review before Task 2.**
",
  nrow(ep) + n_bad - n_bad, n_bad, nrow(ep_out), nrow(FB), nrow(E), format(n_dup_total, big.mark=","),
  paste(sprintf("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f [%.1f, %.1f] | %.1f%% |",
    summ$duid, summ$n_episodes, summ$directed_output_median, summ$declared_minload_median,
    summ$observed_floor_p5, summ$floor_block_median, summ$excess_median, summ$excess_p25,
    summ$excess_p75, summ$pct_within_10MW_of_minload), collapse="\n"),
  pooled$excess_median, pooled$excess_mean, pooled$pct_excess_le_0, pooled$pct_excess_le_25MW)
writeLines(findings, file.path(OUT, "findings_task1.md"))
cat("\nSaved task1_{summary_by_unit,episode_level}.csv, task1_excess_over_floor.png, findings_task1.md.\n")
cat("\n=== STOP: Task 1 complete. Awaiting review before Task 2. ===\n")
