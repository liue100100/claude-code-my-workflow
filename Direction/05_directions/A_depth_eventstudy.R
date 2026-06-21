#!/usr/bin/env Rscript
# A_depth_eventstudy.R  -- Analysis A
# Ex-ante depth (own-status-invariant: number of AVAILABLE rivals; lower = more
# pivotal) in event time centred on the directed-episode start s.
#
#   * profile of depth_ex over e in [-12, +24] five-minute intervals, centred on
#     the first directed interval, split Synchronise vs Remain;
#   * onset (first hour directed) vs tail (last hour before c) vs a matched
#     non-directed counterfactual (same station x hour x month x weekend);
#   * paired tests onset-vs-matched and onset-vs-tail.
#
# Depth source: outputs/descriptives_v3/pivotality_panel.rds, column
# depth_ex_<station>. Higher depth = more redundant; lower = more pivotal.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/direction_rebid"

E_LO <- -12L; E_HI <- 24L          # event-time window (5-min intervals) centred on s
ONSET_N <- 12L; TAIL_N <- 12L      # first / last hour of the episode

ep <- as.data.table(readRDS(file.path(OUT, "episodes.rds")))
piv <- as.data.table(readRDS("outputs/descriptives_v3/pivotality_panel.rds"))

# ---- long ex-ante depth panel: (station, secs, depth_ex) ----
dcols <- grep("^depth_ex_", names(piv), value = TRUE)
dl <- melt(piv[, c("SETTLEMENTDATE", dcols), with = FALSE],
           id.vars = "SETTLEMENTDATE", variable.name = "station",
           value.name = "depth_ex")
dl[, station := sub("^depth_ex_", "", station)]
dl[, secs := as.numeric(SETTLEMENTDATE)]        # tz-safe join key (instant)
setkey(dl, station, secs)

# ---- station-directed interval set (any DUID in the station directed) ----
STAT <- c(TORRB1 = "torrens_island_b", TORRB2 = "torrens_island_b",
          TORRB3 = "torrens_island_b", TORRB4 = "torrens_island_b",
          PPCCGT = "pelican_point_gt", `OSB-AG` = "osborne_gt_st",
          QPS5 = "quarantine_5", MINTARO = "mintaro",
          DRYCGT1 = "dry_creek", DRYCGT2 = "dry_creek", DRYCGT3 = "dry_creek",
          BARKIPS1 = "bips")
tp <- as.data.table(readRDS("direction_data/parsed/treatment_panel.rds"))
tp[, station := STAT[as.character(duid)]]
tp <- tp[!is.na(station) & directed == 1]
dir_si <- unique(tp[, .(station, secs = as.numeric(interval_datetime))])
dir_si[, is_dir := TRUE]

# ---- matched non-directed counterfactual cells ----
# cell = station x hour x month x weekend, mean depth over NON-directed intervals
dlc <- merge(dl, dir_si, by = c("station", "secs"), all.x = TRUE)
dlc[is.na(is_dir), is_dir := FALSE]
dlc[, `:=`(hour = as.integer(format(SETTLEMENTDATE, "%H")),
           ym   = format(SETTLEMENTDATE, "%Y%m"),
           wknd = as.integer(format(SETTLEMENTDATE, "%u")) >= 6L)]
cells <- dlc[is_dir == FALSE & !is.na(depth_ex),
             .(matched_depth = mean(depth_ex), n_cell = .N),
             by = .(station, hour, ym, wknd)]
setkey(cells, station, hour, ym, wknd)

# ---- event-time grid per episode ----
# snap s,c to the 5-min interval grid (end-labelled), matching build_treatment_panel
ep[, s_grid := (floor(as.numeric(s) / 300) + 1) * 300]   # first directed interval
ep[, c_grid :=  floor(as.numeric(c) / 300) * 300]         # last directed interval

grid <- ep[, .(e = E_LO:E_HI), by = episode_id]
grid <- merge(grid, ep[, .(episode_id, station, instruction, s_grid, c_grid)],
              by = "episode_id")
grid[, secs := s_grid + e * 300]
grid <- merge(grid, dl[, .(station, secs, depth_ex)],
              by = c("station", "secs"), all.x = TRUE)

# ---- (1) event-time profile, by instruction ----
prof <- grid[!is.na(depth_ex),
             .(mean_depth = mean(depth_ex), sd = sd(depth_ex), n = .N),
             by = .(instruction, e)]
prof[, se := sd / sqrt(n)]
prof[, `:=`(lo = mean_depth - 1.96 * se, hi = mean_depth + 1.96 * se)]
setorder(prof, instruction, e)
fwrite(prof, file.path(OUT, "A_depth_profile.csv"))

# matched reference line (mean matched cell over episodes, by instruction)
epc <- copy(ep)
epc[, `:=`(hour = as.integer(format(as.POSIXct(s_grid, origin = "1970-01-01",
                                               tz = "Australia/Brisbane"), "%H")),
           ym   = format(as.POSIXct(s_grid, origin = "1970-01-01",
                                    tz = "Australia/Brisbane"), "%Y%m"),
           wknd = as.integer(format(as.POSIXct(s_grid, origin = "1970-01-01",
                                    tz = "Australia/Brisbane"), "%u")) >= 6L)]
epc <- merge(epc, cells, by = c("station", "hour", "ym", "wknd"), all.x = TRUE)
matched_ref <- epc[!is.na(matched_depth),
                   .(matched_depth = mean(matched_depth)), by = instruction]

p1 <- ggplot(prof, aes(e, mean_depth, colour = instruction, fill = instruction)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.9) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
  geom_hline(data = matched_ref, aes(yintercept = matched_depth, colour = instruction),
             linetype = "dotted", linewidth = 0.7, show.legend = FALSE) +
  labs(title = "Ex-ante depth around the directed-episode start",
       subtitle = paste("Lower = more pivotal (fewer available rivals). e=0 is the first",
                        "directed interval. Dotted = matched non-directed cell mean."),
       x = "Event time e (5-min intervals from start s)",
       y = "Mean ex-ante depth (available rivals)") +
  theme_bw(base_size = 11) +
  theme(plot.subtitle = element_text(size = 8, colour = "grey30"),
        legend.position = "bottom")
ggsave(file.path(OUT, "A_depth_profile.png"), p1, width = 8.5, height = 5.5, dpi = 150)

# ---- (2) onset / tail / matched per episode ----
onset <- grid[e >= 0 & e <= (ONSET_N - 1) & secs <= c_grid & !is.na(depth_ex),
              .(onset_depth = mean(depth_ex)), by = episode_id]
# tail = last TAIL_N intervals up to c_grid, clipped to >= s_grid
# (skip sub-interval episodes where the grid collapses to c_grid < s_grid)
tailg <- ep[c_grid >= s_grid,
            .(secs = seq.int(pmax(s_grid, c_grid - (TAIL_N - 1) * 300), c_grid, by = 300L)),
            by = .(episode_id, station)]
tailg <- merge(tailg, dl[, .(station, secs, depth_ex)],
               by = c("station", "secs"), all.x = TRUE)
tail <- tailg[!is.na(depth_ex), .(tail_depth = mean(depth_ex)), by = episode_id]

epm <- merge(ep[, .(episode_id, duid, station, instruction)],
             onset, by = "episode_id", all.x = TRUE)
epm <- merge(epm, tail, by = "episode_id", all.x = TRUE)
epm <- merge(epm, epc[, .(episode_id, matched_depth)], by = "episode_id", all.x = TRUE)
saveRDS(epm, file.path(OUT, "A_episode_depth.rds"))

# summary table + paired tests, by instruction
summ <- epm[, .(
  n             = .N,
  onset_depth   = mean(onset_depth,  na.rm = TRUE),
  tail_depth    = mean(tail_depth,   na.rm = TRUE),
  matched_depth = mean(matched_depth, na.rm = TRUE)
), by = instruction]

tests <- epm[, {
  om <- na.omit(data.table(onset_depth, matched_depth))
  ot <- na.omit(data.table(onset_depth, tail_depth))
  .(p_onset_vs_matched = if (nrow(om) > 2) t.test(om$onset_depth, om$matched_depth,
                                                  paired = TRUE)$p.value else NA_real_,
    p_onset_vs_tail    = if (nrow(ot) > 2) t.test(ot$onset_depth, ot$tail_depth,
                                                  paired = TRUE)$p.value else NA_real_)
}, by = instruction]
summ <- merge(summ, tests, by = "instruction")
fwrite(summ, file.path(OUT, "A_onset_tail_matched.csv"))

cat("=== Analysis A: ex-ante depth onset / tail / matched ===\n")
print(summ)
cat("\nInterpretation: onset_depth < matched_depth => directions land when the unit\n",
    "is more pivotal than its typical non-directed state at the same hour/month.\n")
cat(sprintf("\nSaved: A_depth_profile.{csv,png}, A_onset_tail_matched.csv, A_episode_depth.rds\n"))
