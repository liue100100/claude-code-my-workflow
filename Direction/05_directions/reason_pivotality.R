#!/usr/bin/env Rscript
# reason_pivotality.R
# Tests WHY non-pivotal units get directed (facts_memo [F17]). Three pieces:
#   (1) per-interval P(pivotal | directed) by direction REASON x station
#   (2) PER-DIRECTION hit rate (event-level, not interval): of each direction
#       spell, was the station pivotal at issue / at any point / what fraction
#   (3) reason x pivotality association across the WHOLE direction window
#       (uses 2021 once DISPATCHLOAD_2021xx are extracted — the only year AEMO
#        labelled "System strength"). LPM pivotal ~ reason with station FE.
#
# Reads per-month pivotality_<M>.rds caches DIRECTLY (never rewrites the headline
# pivotality_panel.rds). Combinations standard assumes 4 syncons (commissioned
# THROUGH 2021) -> 2021 pivotality understated -> conservative for the 2021 test.

suppressMessages({ library(data.table); library(fixest) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
CACHE <- "bid_cache"; OUT <- "outputs/descriptives_v3"

# ---------------------------------------------------------------------------
# 0. station map + load all available per-month pivotality caches
# ---------------------------------------------------------------------------
STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips", TORRA3="torrens_island_b")  # TORRA3 -> TIB(A); no combo col, drops

pfiles <- list.files(CACHE, pattern="^pivotality_[0-9]{6}\\.rds$", full.names=TRUE)
piv <- rbindlist(lapply(pfiles, readRDS), fill=TRUE)
setkey(piv, SETTLEMENTDATE)
cat(sprintf("pivotality months loaded: %d  (%s to %s)\n",
            uniqueN(piv$yyyymm),
            format(min(piv$SETTLEMENTDATE)), format(max(piv$SETTLEMENTDATE))))

stations <- intersect(unique(STAT), sub("piv_","", grep("^piv_", names(piv), value=TRUE)))
pl <- rbindlist(lapply(stations, function(s)
  data.table(SETTLEMENTDATE=piv$SETTLEMENTDATE, station=s,
             pivotal   =as.integer(piv[[paste0("piv_",s)]]),
             pivotal_ex=as.integer(piv[[paste0("pex_",s)]]))))
setkey(pl, SETTLEMENTDATE, station)

# ---------------------------------------------------------------------------
# 1. direction events -> reason buckets; keep event-level + expand to intervals
# ---------------------------------------------------------------------------
ev <- as.data.table(readRDS("direction_data/parsed/direction_events.rds"))
ev <- ev[!is.na(duid)]
dmap <- c(TORRB35="TORRB3", TORRB46="TORRB4", MINTARO1="MINTARO")
for (b in names(dmap)) ev[duid==b, duid := dmap[[b]]]
ev[, station := STAT[as.character(duid)]]
ev <- ev[!is.na(station) & station %in% stations]
ev[, dur_hrs := as.numeric(difftime(cancellation_time, effective_time, units="hours"))]
ev <- ev[dur_hrs > 0]
ev[, reason2 := fcase(
  grepl("strength", reason, ignore.case=TRUE), "strength",
  grepl("voltage",  reason, ignore.case=TRUE), "voltage",
  default = "security_generic")]
ev[, yr := format(as.Date(effective_time), "%Y")]
ev[, eid := .I]
cat("\ndirection events (pivotal-capable stations, dur>0):", nrow(ev), "\n")
print(ev[, .N, by=.(yr, reason2)][order(yr, reason2)])

# expand to 5-min intervals, carry eid + reason + station
ev[, first_intv := (floor(as.numeric(effective_time)/300)+1)*300]
ev[, last_intv  :=  floor(as.numeric(cancellation_time)/300)*300]
ev2 <- ev[last_intv >= first_intv]
exp <- rbindlist(lapply(seq_len(nrow(ev2)), function(i)
  data.table(eid=ev2$eid[i], station=ev2$station[i], reason2=ev2$reason2[i],
             yr=ev2$yr[i], secs=seq.int(ev2$first_intv[i], ev2$last_intv[i], by=300L))))
exp[, SETTLEMENTDATE := as.POSIXct(secs, origin="1970-01-01", tz="Etc/GMT-10")]
setkey(exp, SETTLEMENTDATE, station)

# join pivotal flag onto directed intervals (only intervals we have pivotality for)
dall <- merge(exp, pl, by=c("SETTLEMENTDATE","station"))
cat(sprintf("\ndirected intervals with pivotality coverage: %d of %d expanded (%.0f%%)\n",
            nrow(dall), nrow(exp), 100*nrow(dall)/nrow(exp)))

# Drivers (1)-(2) use the project's analysis window 2022-24 (matches [F13]/[F14],
# and excludes 2021 where pivotality is unreliable: syncons commissioned through
# 2021 + low pre-surge non-sync penetration). Part (3) reason test uses ALL years.
d <- dall[yr %in% c("2022","2023","2024")]
cat(sprintf("drivers (1)-(2) restricted to 2022-24: %d directed intervals\n", nrow(d)))

# ===========================================================================
# (1) PER-INTERVAL P(pivotal | directed) by reason x station  [2022-24]
# ===========================================================================
cat("\n================ (1) PER-INTERVAL  P(pivotal | directed)  [2022-24] ================\n")
t1 <- d[, .(n_intervals=.N, P_pivotal=round(mean(pivotal),3),
            P_pivotal_ex=round(mean(pivotal_ex),3)), by=.(station, reason2)][order(station,-n_intervals)]
print(t1)
fwrite(t1, file.path(OUT, "reason_pivotal_interval.csv"))

# ===========================================================================
# (2) PER-DIRECTION HIT RATE  (event-level)
#     hit_issue = pivotal in the first covered interval of the spell
#     hit_any   = pivotal in >=1 interval of the spell
#     frac_piv  = fraction of covered intervals pivotal
# ===========================================================================
cat("\n================ (2) PER-DIRECTION HIT RATE (event-level) ================\n")
setorder(d, eid, SETTLEMENTDATE)
evlevel <- d[, .(n_int=.N,
                 hit_issue = pivotal[1L],
                 hit_any   = as.integer(any(pivotal==1L)),
                 frac_piv  = mean(pivotal),
                 hit_any_ex= as.integer(any(pivotal_ex==1L))),
             by=.(eid, station, reason2, yr)]
# per-direction hit rate by station (across all reasons) vs the per-interval rate
hit_by_station <- evlevel[, .(n_directions=.N,
                              perdir_hit_any   = round(mean(hit_any),3),
                              perdir_hit_issue = round(mean(hit_issue),3),
                              mean_frac_piv    = round(mean(frac_piv),3)),
                          by=station][order(station)]
cat("\n-- per-direction hit rate by station (all reasons) --\n"); print(hit_by_station)

hit_by_reason <- evlevel[, .(n_directions=.N,
                             perdir_hit_any   = round(mean(hit_any),3),
                             perdir_hit_issue = round(mean(hit_issue),3),
                             mean_frac_piv    = round(mean(frac_piv),3)),
                         by=.(station, reason2)][order(station, -n_directions)]
cat("\n-- per-direction hit rate by station x reason --\n"); print(hit_by_reason)
fwrite(evlevel,       file.path(OUT, "reason_pivotal_eventlevel.csv"))
fwrite(hit_by_station,file.path(OUT, "perdirection_hitrate_station.csv"))
fwrite(hit_by_reason, file.path(OUT, "perdirection_hitrate_reason.csv"))

# contrast: per-interval vs per-direction (dilution from sticky spells)
contrast <- merge(
  d[, .(per_interval_P = round(mean(pivotal),3)), by=station],
  hit_by_station[, .(station, per_direction_hit_any=perdir_hit_any, mean_frac_piv)],
  by="station")
cat("\n-- DILUTION: per-interval P vs per-direction hit-any --\n"); print(contrast)
fwrite(contrast, file.path(OUT, "perinterval_vs_perdirection.csv"))

# ===========================================================================
# (3) REASON x PIVOTALITY across the WHOLE window (uses 2021, the only year
#     AEMO labelled "System strength"). Uses dall (all years).
#     CAVEAT: 2021 pivotality is unreliable (4-syncon assumption; syncons
#     commissioned through 2021) + 2021 had low non-sync penetration -> 2021
#     pivotality ~0, so the strength-label contrast is confounded. Reported
#     transparently; interpretation in pivotality_readout.md.
# ===========================================================================
cat("\n================ (3) REASON x PIVOTALITY (whole window, incl. 2021) ================\n")
cat(sprintf("years present: %s\n", paste(sort(unique(dall$yr)), collapse=", ")))

evall <- dall[order(eid, SETTLEMENTDATE),
              .(n_int=.N, hit_issue=pivotal[1L], hit_any=as.integer(any(pivotal==1L)),
                frac_piv=mean(pivotal)),
              by=.(eid, station, reason2, yr)]

dall[,  reason2 := relevel(factor(reason2), ref="security_generic")]
evall[, reason2 := relevel(factor(reason2), ref="security_generic")]
m_int <- feols(pivotal ~ reason2 | station, dall, vcov=~station)
cat("\n-- LPM: P(pivotal) ~ reason (station FE, cluster station), interval-level --\n")
print(coeftable(m_int))
m_ev <- feols(hit_any ~ reason2 | station, evall, vcov=~station)
cat("\n-- LPM: per-direction hit_any ~ reason (station FE), event-level --\n")
print(coeftable(m_ev))

cat("\n-- P(pivotal | directed) by year x reason (interval-level) --\n")
yrtab_int <- dall[, .(n=.N, P_pivotal=round(mean(pivotal),3)), by=.(yr, reason2)][order(yr, reason2)]
print(yrtab_int)
cat("\n-- per-direction hit_any by year x reason (event-level) --\n")
yrtab_ev <- evall[, .(n_dir=.N, hit_any=round(mean(hit_any),3)), by=.(yr, reason2)][order(yr, reason2)]
print(yrtab_ev)
fwrite(yrtab_int, file.path(OUT, "reason_pivotal_by_year.csv"))

cat("\nDONE. Outputs -> outputs/descriptives_v3/reason_pivotal_*.csv, perdirection_*.csv\n")
