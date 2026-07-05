#!/usr/bin/env Rscript
# task1c_redux_sequencing.R -- Job 1: re-establish the Task 1c sequencing finding on CORRECTED
# direction times (the +10h parser bug is fixed at source; episodes.rds is rebuilt).
#
# Same committed definitions as Task 1c (findings_task1c.md, now superseded):
#   exit signal = a bid version in [tau-48h, c] declaring MAXAVAIL = 0 for >= 12 consecutive
#   future intervals INSIDE the direction window (s, c]; classes: no exit signal ever /
#   signal then direction / signal after direction; reduction = >=20 MW mean cut (secondary);
#   reversal = later version restoring > 50% of the pre-cut level.
#   Availability-at-issue = mean MAXAVAIL over window intervals in the version in force at tau.
#
# Sets: (A) the NEW zero-excess lobe from the corrected Task 1b panel (headline denominators);
#       (B) the OLD 69 pre-fix lobe episodes (episode_id is stable across the fix) -- re-run for
#           the flip table against the archived pre-fix classification.
#
# Run from my-project root AFTER task1{,b} re-runs. Outputs task1c_redux_*.csv.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")

X <- readRDS(file.path(OUT, "task1b_panel.rds"))   # rebuilt on corrected windows
X[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
Zn <- X[excess_over_floor <= 0]
old <- fread(file.path(OUT, "_pre_tzfix/task1c_b_sequencing.csv"))
cat(sprintf("NEW zero-excess lobe: %d of %d comp-matched (pre-fix: 69 of 271); overlap with old lobe: %d\n",
            nrow(Zn), nrow(X), length(intersect(Zn$episode_id, old$episode_id))))
print(Zn[, .N, by=duid][order(-N)])

ep_all <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep_all[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
ids <- union(Zn$episode_id, old$episode_id)
T <- ep_all[episode_id %in% ids]
cat(sprintf("Target episodes for sequencing: %d (new lobe + old-69 union)\n", nrow(T)))

# ---- BOP subset for the corrected windows (fresh cache; months from corrected times) ----
RCACHE <- file.path(OUT, "_task1c_redux_cache.rds")
mrange <- function(a,b) format(seq(as.Date(cut(a,"month")), as.Date(cut(b,"month")), by="month"), "%Y%m")
mm <- sort(unique(unlist(mapply(mrange, dt10(T$tau - 48*3600), pmin(dt10(T$c)+1, as.Date("2024-12-31"))))))
mm <- mm[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", mm)))]
if (file.exists(RCACHE)) { BOP <- readRDS(RCACHE); cat("Loaded redux cache\n") } else {
  cat("Loading BOP months:", paste(mm, collapse=" "), "\n")
  keep <- c("DUID","OFFERDATETIME","MAXAVAIL","INTERVAL_DATETIME")
  BOP <- rbindlist(lapply(mm, function(M) {
    b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
    b <- b[DUID %in% FOCUS & BIDTYPE=="ENERGY", ..keep]; gc(verbose=FALSE); b }))
  BOP[, `:=`(odt = force10(OFFERDATETIME), idt = force10(INTERVAL_DATETIME))]
  BOP[, td := dt10(idt - 1)]   # Task-1c label re-key
  BOP[, c("OFFERDATETIME","INTERVAL_DATETIME") := NULL]
  saveRDS(BOP, RCACHE)
}

seq_one <- function(e) {
  tds <- seq(dt10(e$tau - 48*3600), dt10(e$c) + 1, by="day")
  v <- BOP[DUID == e$duid & td %in% tds & odt >= e$tau - 48*3600 & odt <= e$c]
  if (!nrow(v)) return(data.table(episode_id=e$episode_id, duid=e$duid, class="no pre-issue version covers the window",
    first_exit_rel_h=NA_real_, reversed=NA, ma_at_issue=NA_real_))
  setorder(v, td, odt, idt)
  vs <- v[idt > odt & idt > e$s & idt <= e$c,
          .(mean_ma=mean(MAXAVAIL),
            max_run0={r <- rle(MAXAVAIL==0); m <- r$lengths[r$values]; if (length(m)) max(m) else 0L},
            .N), by=.(td, odt)]
  # availability at issue: latest version <= tau per window trading day
  vi <- v[odt <= e$tau & idt > e$s & idt <= e$c]
  ma_iss <- if (nrow(vi)) { vi <- vi[vi[, .I[odt == max(odt)], by=td]$V1]; vi[, mean(MAXAVAIL)] } else NA_real_
  if (!nrow(vs)) return(data.table(episode_id=e$episode_id, duid=e$duid, class="no pre-issue version covers the window",
    first_exit_rel_h=NA_real_, reversed=NA, ma_at_issue=ma_iss))
  vs[, exit0 := max_run0 >= 12L]
  vs[, rel_h := as.numeric(difftime(odt, e$tau, units="hours"))]
  fe <- vs[exit0==TRUE][order(odt)][1]
  reversed <- FALSE
  if (!is.na(fe$odt)) {
    later <- vs[td == fe$td & odt > fe$odt]; base <- vs[td == fe$td & odt < fe$odt, mean_ma]
    if (nrow(later) && length(base)) reversed <- any(later$mean_ma > 0.5*max(base, na.rm=TRUE))
  }
  cls <- if (is.na(fe$odt)) "no exit signal ever" else if (fe$rel_h < 0) "signal then direction" else "signal after direction"
  data.table(episode_id=e$episode_id, duid=e$duid, class=cls, first_exit_rel_h=fe$rel_h,
             reversed=reversed, ma_at_issue=ma_iss)
}
R <- rbindlist(lapply(seq_len(nrow(T)), function(j) seq_one(T[j])))
R[, in_new_lobe := episode_id %in% Zn$episode_id]
R[, in_old_lobe := episode_id %in% old$episode_id]
fwrite(R, file.path(OUT, "task1c_redux_sequencing.csv"))

cat("\n=== CORRECTED sequencing, NEW zero-excess lobe ===\n")
print(R[in_new_lobe==TRUE, .N, by=class][order(-N)])
cat(sprintf("Exit-before-direction share: %d of %d (%.0f%%) | median lead %.1f h | reversals %d of %d signal episodes\n",
            R[in_new_lobe==TRUE & class=="signal then direction", .N], R[in_new_lobe==TRUE, .N],
            100*R[in_new_lobe==TRUE, mean(class=="signal then direction")],
            R[in_new_lobe==TRUE & class=="signal then direction", -median(first_exit_rel_h)],
            R[in_new_lobe==TRUE & class!="no exit signal ever" & reversed==TRUE, .N],
            R[in_new_lobe==TRUE & class!="no exit signal ever", .N]))
cat(sprintf("Availability withdrawn at issue (mean window MAXAVAIL < 5 MW): %d of %d (%.0f%%)\n",
            R[in_new_lobe==TRUE & ma_at_issue < 5, .N], R[in_new_lobe==TRUE & !is.na(ma_at_issue), .N],
            100*R[in_new_lobe==TRUE & !is.na(ma_at_issue), mean(ma_at_issue < 5)]))

cat("\n=== FLIP TABLE: the old 69 episodes, pre-fix class vs corrected class ===\n")
FL <- merge(old[, .(episode_id, class_old=class)], R[, .(episode_id, class_new=class)], by="episode_id")
print(dcast(FL[, .N, by=.(class_old, class_new)], class_old ~ class_new, value.var="N", fill=0))
cat(sprintf("Flipped: %d of %d\n", FL[class_old != class_new, .N], nrow(FL)))
fwrite(FL, file.path(OUT, "task1c_redux_flips.csv"))

cat("\n=== Context: corrected sequencing across ALL comp-matched episodes (271-set) ===\n")
ids271 <- X$episode_id
T2 <- ep_all[episode_id %in% setdiff(ids271, R$episode_id)]
if (nrow(T2)) {
  R2 <- rbindlist(lapply(seq_len(nrow(T2)), function(j) seq_one(T2[j])))
  RA <- rbind(R[, .(episode_id, duid, class, first_exit_rel_h, ma_at_issue)],
              R2[, .(episode_id, duid, class, first_exit_rel_h, ma_at_issue)])
  RA <- RA[episode_id %in% ids271]
  cat(sprintf("All %d comp-matched: exit-before-direction %.0f%%; withdrawn-at-issue %.0f%%\n",
              nrow(RA), 100*RA[, mean(class=="signal then direction")],
              100*RA[!is.na(ma_at_issue), mean(ma_at_issue < 5)]))
  fwrite(RA, file.path(OUT, "task1c_redux_all271.csv"))
}
cat("\nSaved task1c_redux_{sequencing,flips,all271}.csv\n")
