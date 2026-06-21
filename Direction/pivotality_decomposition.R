#!/usr/bin/env Rscript
# pivotality_decomposition.R
# Decomposes the DIRECTED-but-BASE-NON-PIVOTAL interval-station mass — the
# population behind "why are non-pivotal units directed?" (facts_memo [F17],
# why_directed_nonpivotal.md) — via a successive-cut waterfall, and reports the
# residual mass after each cut. Also prints the station-level base / N-1 /
# ex-ante pivotal-share table so the shrinkage/expansion is visible.
#
# Requires pivotality.R to have been re-run with the N-1 extension (piv_n1_*,
# on_* columns in pivotality_panel.rds).

suppressMessages({ library(data.table) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3"

# --- combinations (for the combos-surviving cut) ---------------------------
combos <- fread("sa_minimum_generator_combinations.csv")
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x){x[is.na(x)]<-0L; as.integer(x)}), .SDcols=STATIONS]
combos_sn <- combos[regime == "system_normal"]
REQ    <- as.matrix(combos_sn[, ..STATIONS])
THRESH <- combos_sn$non_sync_mw
feasible_count <- function(counts, nonsync) {      # applicable combos still satisfied
  appl <- THRESH >= nonsync; if (!any(appl)) appl <- THRESH == max(THRESH)
  R <- REQ[appl,,drop=FALSE]
  sum(rowSums(sweep(R, 2, counts, FUN=function(req,have) req>have)) == 0)
}

# --- pivotality panel (wide) -> long by station ----------------------------
piv <- as.data.table(readRDS(file.path(OUT, "pivotality_panel.rds")))
stopifnot(any(grepl("^piv_n1_", names(piv))))     # guard: N-1 extension present
on_cols <- paste0("on_", STATIONS)
pl <- rbindlist(lapply(STATIONS, function(s) data.table(
  SETTLEMENTDATE = piv$SETTLEMENTDATE, station = s, nonsync_mw = piv$nonsync_mw,
  short_n1 = as.integer(piv$short_n1),
  piv    = as.integer(piv[[paste0("piv_",    s)]]),
  piv_n1 = as.integer(piv[[paste0("piv_n1_", s)]]),
  pex    = as.integer(piv[[paste0("pex_",    s)]]),
  on_self= piv[[paste0("on_", s)]])))
# CLEAN N-1 incumbency: well-defined only where the post-contingency state is
# itself feasible. Where short_n1 (system cannot survive loss of the largest unit)
# the literal piv_n1 is trivially TRUE for every station -> separate it out.
pl[, piv_n1_clean := as.integer(piv_n1 == 1L & short_n1 == 0L)]
# carry the full online vector per interval (for feasible_count after dropping i)
onmat <- as.matrix(piv[, ..on_cols]); colnames(onmat) <- STATIONS
onkey <- data.table(SETTLEMENTDATE = piv$SETTLEMENTDATE)

# ===========================================================================
# Station-level base / N-1 / ex-ante shares (shrinkage table)
# ===========================================================================
shr <- pl[, .(base_pct          = round(100*mean(piv),2),
              n1_literal_pct    = round(100*mean(piv_n1),2),
              # same-denominator comparison on N-1-secure intervals (the correct one):
              base_secure_pct   = round(100*mean(piv[short_n1==0]),2),
              n1_secure_pct     = round(100*mean(piv_n1[short_n1==0]),2),
              clean_allint_pct  = round(100*mean(piv_n1_clean),2),  # = n1_secure x P(secure); NOT comparable to base
              exante_pct        = round(100*mean(pex),2),
              n_intervals       = .N), by=station][order(-base_pct)]
cat("\n================ STATION-LEVEL PIVOTAL SHARES (2022-24) ================\n")
cat("Pivotality is MONOTONE: removing the largest unit only makes more units pivotal.\n")
cat("base            = remove unit i from the realised online fleet (all intervals)\n")
cat("n1_literal      = also remove the single largest online unit, then i (all intervals; LITERAL spec)\n")
cat("base_secure / n1_secure = base vs N-1 on N-1-SECURE intervals only (same denominator -> n1>=base)\n")
cat("clean_allint    = n1 & N-1-secure as share of ALL intervals (= n1_secure x P(secure); looks < base only by censoring)\n")
cat("exante          = i essential given rivals' AVAILABILITY only (exogenous)\n")
cat(sprintf("[context] short=%.1f%% of intervals not base-secure; short_n1=%.1f%% not N-1-secure\n",
            100*mean(as.integer(piv$short)), 100*mean(pl$short_n1[pl$station==STATIONS[1]])))
print(shr)
fwrite(shr, file.path(OUT, "pivotal_shares_base_n1_exante.csv"))

# ===========================================================================
# Directed-interval x station, with reason + instruction
# ===========================================================================
STAT <- c(TORRB1="torrens_island_b", TORRB2="torrens_island_b",
          TORRB3="torrens_island_b", TORRB4="torrens_island_b",
          PPCCGT="pelican_point_gt", `OSB-AG`="osborne_gt_st",
          QPS5="quarantine_5", MINTARO="mintaro",
          DRYCGT1="dry_creek", DRYCGT2="dry_creek", DRYCGT3="dry_creek",
          BARKIPS1="bips")
ev <- as.data.table(readRDS("direction_data/parsed/direction_events.rds"))
ev <- ev[!is.na(duid)]
dmap <- c(TORRB35="TORRB3", TORRB46="TORRB4", MINTARO1="MINTARO")
for (b in names(dmap)) ev[duid==b, duid := dmap[[b]]]
ev[, station := STAT[as.character(duid)]]
ev <- ev[!is.na(station)]
ev[, dur_hrs := as.numeric(difftime(cancellation_time, effective_time, units="hours"))]
ev <- ev[dur_hrs > 0]
ev[, reason2 := fcase(grepl("strength",reason,ignore.case=TRUE),"strength",
                      grepl("voltage", reason,ignore.case=TRUE),"voltage",
                      default="security_generic")]
ev[, is_sync := direction_instruction == "Synchronise"]
ev[, first_intv := (floor(as.numeric(effective_time)/300)+1)*300]
ev[, last_intv  :=  floor(as.numeric(cancellation_time)/300)*300]
ev <- ev[last_intv >= first_intv]
exp <- rbindlist(lapply(seq_len(nrow(ev)), function(i)
  data.table(station=ev$station[i], reason2=ev$reason2[i], is_sync=ev$is_sync[i],
             secs=seq.int(ev$first_intv[i], ev$last_intv[i], by=300L))))
exp[, SETTLEMENTDATE := as.POSIXct(secs, origin="1970-01-01", tz="Etc/GMT-10")]
# union per (interval, station): Synchronise if ANY directing event is Synchronise;
# reason = strength>voltage>security_generic precedence is irrelevant in-sample (no
# overlap) -> take the "most security-relevant" via any()
dir_is <- exp[, .(is_sync = any(is_sync),
                  voltage = any(reason2=="voltage")), by=.(SETTLEMENTDATE, station)]

# merge pivotality (base/N-1/ex-ante) onto directed interval-stations
d <- merge(dir_is, pl, by=c("SETTLEMENTDATE","station"))
d <- merge(d, data.table(SETTLEMENTDATE=piv$SETTLEMENTDATE, ridx=seq_len(nrow(piv))),
           by="SETTLEMENTDATE")          # row index into onmat for combos-surviving
cat(sprintf("\nDirected interval-stations with pivotality coverage (2022-24): %d\n", nrow(d)))

# ===========================================================================
# WATERFALL over DIRECTED & BASE-NON-PIVOTAL
# ===========================================================================
P0 <- d[piv == 0]
N0 <- nrow(P0)
report <- function(label, n) data.table(cut=label, residual=n, pct_of_P0=round(100*n/N0,1))
W <- list(report("P0: directed & base-non-pivotal", N0))

# Cut 1: keep Synchronise (Remain = already-running, not a withhold-then-direct case)
P1 <- P0[is_sync == TRUE]
W[[length(W)+1]] <- report("  - drop Remain (keep Synchronise)", nrow(P1))

# Cut 2: system-strength only (drop voltage-reason directions; different service)
P2 <- P1[voltage == FALSE]
W[[length(W)+1]] <- report("  - drop voltage reason (strength-relevant only)", nrow(P2))

# Cut 3a: drop intervals where the system is not N-1 secure (short_n1): the
#   direction restores security against loss of the largest unit (collective need).
P3a <- P2[short_n1 == 0]
W[[length(W)+1]] <- report("  - drop short_n1 (system not N-1 secure -> directed to restore it)", nrow(P3a))

# Cut 3b: among N-1-secure intervals, drop those where the directed unit is itself
#   N-1-pivotal (clean incumbency under the credible contingency).
P3 <- P3a[piv_n1 == 0]
W[[length(W)+1]] <- report("  - drop N-1-pivotal unit (clean incumbency post-contingency)", nrow(P3))

# Cut 4: combos surviving removal of the directed unit i (near-margin vs redundant)
#   base-non-pivotal => >=1 combo survives; count how many. <=2 = near-margin (explained).
sidx <- match(P3$station, STATIONS)
P3[, combos_surv := vapply(seq_len(.N), function(k){
  cnt <- onmat[ridx[k], ]; si <- sidx[k]; cnt[si] <- max(cnt[si]-1L, 0L)
  feasible_count(cnt, nonsync_mw[k])
}, integer(1))]
P4 <- P3[combos_surv >= 3]
W[[length(W)+1]] <- report("  - drop near-margin (<=2 combos survive); keep >=3", nrow(P4))

wf <- rbindlist(W)
cat("\n================ WATERFALL: residual mass after each successive cut ================\n")
print(wf)
fwrite(wf, file.path(OUT, "directed_nonpivotal_waterfall.csv"))

cat("\n-- distribution of combos-surviving among P3 (base & N-1 non-pivotal, sync, strength) --\n")
print(P3[, .N, by=combos_surv][order(combos_surv)])

cat("\n-- final residual (truly redundant directions) by station --\n")
print(P4[, .(intervals=.N, approx_unit_hours=round(.N*5/60,0)), by=station][order(-intervals)])

cat("\n-- composition of P0 by instruction x reason (sanity) --\n")
print(P0[, .N, by=.(is_sync, voltage)][order(-N)])

cat("\nDONE -> pivotal_shares_base_n1_exante.csv, directed_nonpivotal_waterfall.csv\n")
