#!/usr/bin/env Rscript
# task4_part2_validation.R -- Instrumentation Part 2: the validation gate.
# Do the instruments detect changes we KNOW happened? Amendments in force:
#  - AEMO dual-definition resolved FIRST: the direction tag is tightened to
#    RTS | "direction" | market-notice numbers; bare "AEMO"+price/MPD strings move to
#    price/forecast. Reclassification counts reported.
#  - Rebid instrument enters as TWO rows (direction-tagged / non-tagged); only the non-tagged
#    row is eligible for Part 3 conduct claims. "None"-lever rebids = separate descriptive
#    stream (must NOT register on energy instruments).
#  - Held prediction: the shape instrument must validate on the plant-regime events, else that
#    is a real blindness finding.
# MOVED RULE (fixed): per unit-day scalar v, z = (v - baseline median_u) / baseline IQR_u,
# baseline = clean days >2 days from any episode boundary and >1 day from any transition.
# An instrument MOVES on an event class if |median z| > 0.5 over the event unit-days, n >= 10
# (pooled across units via z). BC = moves by construction (not a validation win). n<10 =
# untestable, reason given. Known events: (i) the 26 post-issue RTS rebids; (ii) direction
# starts / ends (all 740, corrected clock; daily instruments read at the NEXT midnight);
# (iii) the state transitions; (iv) plant regime: closure announcement 2022-11-24 (week window)
# + mothball-like full-exit spell starts (>=14 d); B1 mothballing Oct 2021 = pre-sample,
# untestable.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")

SH  <- readRDS(file.path(OUT, "task4_ladder_shape.rds"))
RBP <- readRDS(file.path(OUT, "task4_rebid_panel.rds")); RB <- RBP$RB; BD <- RBP$BD; LV <- RBP$LV
CHD <- readRDS(file.path(OUT, "task4_churn.rds"))
TX  <- fread(file.path(OUT, "task4_absence_type.csv")); TX[, cal_day := as.Date(cal_day)]
UD  <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
DC  <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
TRS <- fread(file.path(OUT, "task3_part4_transitions.csv")); TRS[, cal_day := as.Date(cal_day)]
RX  <- fread(file.path(OUT, "task1c_redux_sequencing.csv"))
ep  <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep  <- ep[duid %in% TEST_UNITS]; ep[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
ep740 <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]

# ---------------------------------------------------------------------------
# 0. AEMO dual-definition resolution (first, per amendment) + rebid streams
# ---------------------------------------------------------------------------
BD[, dir_tag := grepl("RTS|direction|MN ?#?[0-9]", REBIDEXPLANATION, ignore.case=TRUE)]
n_moved <- BD[cat=="direction/RTS" & dir_tag==FALSE, .N]
cat(sprintf("AEMO dual-definition: %d rebids leave the old direction/RTS category (bare-AEMO price strings etc.) of %d; tightened tag keeps %d\n",
            n_moved, BD[cat=="direction/RTS", .N], BD[dir_tag==TRUE, .N]))
# join levers (BDO od == BOP odt for the same version, within 60s)
setkey(LV, DUID, td, odt)
BD[, odt := od]
BDL <- LV[BD, on=.(DUID, td, odt), roll="nearest"]
BDL[, dt_gap := abs(as.numeric(difftime(odt, od, units="secs")))]
BDL[dt_gap > 60, lever := NA_character_]
cat(sprintf("Rebid-to-lever match within 60s: %d of %d (%.1f%%)\n",
            BDL[!is.na(lever), .N], nrow(BDL), 100*BDL[, mean(!is.na(lever))]))
RBD <- BDL[, .(n_tag = sum(dir_tag), n_nontag = sum(!dir_tag & (is.na(lever) | lever!="none")),
               n_none = sum(!dir_tag & !is.na(lever) & lever=="none")), by=.(DUID, cal_day=dt10(od))]
base_grid <- CJ(DUID=TEST_UNITS, cal_day=seq(as.Date("2022-01-01"), as.Date("2024-12-31"), by="day"))
RBD <- merge(base_grid, RBD, by=c("DUID","cal_day"), all.x=TRUE)
for (cc in c("n_tag","n_nontag","n_none")) RBD[is.na(get(cc)), (cc) := 0L]

# ---------------------------------------------------------------------------
# 1. Instrument scalars per unit-day + clean quiet baseline
# ---------------------------------------------------------------------------
V <- Reduce(function(a,b) merge(a,b,by=c("DUID","cal_day"),all=TRUE), list(
  SH[, .(DUID, cal_day, wmean_price, q_2xsrmc, q_shoulder, top2_share, steep_iqr)],
  RBD,
  CHD[, .(DUID, cal_day, churn_total)],
  UD[DUID %in% TEST_UNITS, .(DUID, cal_day, composite)],
  TX[, .(DUID, cal_day, exit_day, full_exit = atype=="full exit")]))
epd <- ep740[, .(DUID=duid, d1=dt10(s), d2=dt10(c))]
tolerance_days <- rbindlist(lapply(seq_len(nrow(epd)), function(j)
  data.table(DUID=epd$DUID[j], cal_day=seq(epd$d1[j]-2, epd$d2[j]+2, by="day"))))
tolerance_days <- unique(rbind(tolerance_days,
  TRS[, .(DUID, cal_day)], TRS[, .(DUID, cal_day=cal_day-1)], TRS[, .(DUID, cal_day=cal_day+1)]))
V <- merge(V, DC[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"), all.x=TRUE)
V[, quiet := clean==TRUE & !paste(DUID, cal_day) %in% tolerance_days[, paste(DUID, cal_day)]]
cat(sprintf("Quiet baseline days: %d of %d unit-days\n", V[quiet==TRUE, .N], nrow(V)))
INSTR <- c("wmean_price","q_2xsrmc","q_shoulder","top2_share","steep_iqr",
           "n_tag","n_nontag","n_none","churn_total","composite")
BASEL <- melt(V[quiet==TRUE, c("DUID", INSTR), with=FALSE], id.vars="DUID",
              variable.factor=FALSE)[, .(med=median(value, na.rm=TRUE),
                                         iqr=max(IQR(value, na.rm=TRUE), 1e-6)), by=.(DUID, variable)]
for (ii in INSTR) {
  b <- BASEL[variable==ii]
  V[b, on="DUID", (paste0("z_", ii)) := (get(ii) - i.med) / i.iqr]
}

# ---------------------------------------------------------------------------
# 2. Event sets (unit-day windows)
# ---------------------------------------------------------------------------
P26 <- RX[class=="signal after direction" & in_new_lobe==TRUE, .(episode_id)]
P26 <- merge(P26, ep[, .(episode_id, DUID=duid, tau)], by="episode_id")
P26 <- merge(P26, RX[, .(episode_id, first_exit_rel_h)], by="episode_id")
P26[, cal_day := dt10(tau + first_exit_rel_h*3600)]
events <- list(
  "RTS-26 rebid day (rebids at D; daily instruments at D+1)" =
    rbind(P26[, .(DUID, cal_day, wave="D")], P26[, .(DUID, cal_day=cal_day+1, wave="D1")]),
  "direction START (rebids D; daily D+1)" =
    rbind(ep740[, .(DUID=duid, cal_day=dt10(s), wave="D")], ep740[, .(DUID=duid, cal_day=dt10(s)+1, wave="D1")]),
  "direction END (rebids D; daily D+1)" =
    rbind(ep740[, .(DUID=duid, cal_day=dt10(c), wave="D")], ep740[, .(DUID=duid, cal_day=dt10(c)+1, wave="D1")]),
  "state transition day" = TRS[, .(DUID, cal_day, wave="D")],
  "closure announcement week (2022-11-24 +6d, Torrens)" =
    CJ(DUID=c("TORRB2","TORRB3","TORRB4"), cal_day=seq(as.Date("2022-11-24"), as.Date("2022-11-30"), by="day"))[, wave := "D"][],
  "mothball-like spell starts (full-exit runs >=14d)" = local({
    setorder(TX, DUID, cal_day)
    TX[, fe := atype=="full exit" & !is.na(atype)]
    r <- TX[, .(len=rle(fe)$lengths, val=rle(fe)$values), by=DUID]
    r[, end := cumsum(len), by=DUID]; r[, start := end - len + 1]
    days <- TX[, .(cal_day, DUID)][, idx := seq_len(.N), by=DUID]
    st <- r[val==TRUE & len>=14]
    rbindlist(lapply(seq_len(nrow(st)), function(j)
      data.table(DUID=st$DUID[j], cal_day=days[DUID==st$DUID[j] & idx==st$start[j], cal_day] + 0:3, wave="D")))
  })
)

# ---------------------------------------------------------------------------
# 3. Hit table
# ---------------------------------------------------------------------------
rebid_instr <- c("n_tag","n_nontag","n_none")
two_wave <- names(events)[1:3]   # these carry D (rebids) and D+1 (daily instruments) waves
cells <- list()
for (evn in names(events)) {
  E <- events[[evn]]
  for (ii in INSTR) {
    Ew <- if (evn %in% two_wave) E[wave == (if (ii %in% rebid_instr) "D" else "D1")] else E
    m <- merge(unique(Ew[, .(DUID, cal_day)]), V, by=c("DUID","cal_day"))
    z <- m[[paste0("z_", ii)]]
    z <- z[is.finite(z)]
    cells[[paste(evn, ii)]] <- data.table(event=evn, instrument=ii, n=length(z),
      med_z = if (length(z)) round(median(z),2) else NA_real_,
      verdict = if (length(z) < 10) "untestable (n<10)" else if (abs(median(z)) > 0.5) "MOVED" else "flat")
  }
}
HT <- rbindlist(cells)
# by-construction flags
HT[event=="state transition day" & instrument %in% c("churn_total","composite"), verdict := paste(verdict, "(BC)")]
fwrite(HT, file.path(OUT, "task4_part2_hit_cells.csv"))
HTw <- dcast(HT, instrument ~ event, value.var="verdict")
cat("\n=== HIT TABLE (MOVED = |median z| > 0.5 vs own-unit quiet-clean baseline; BC = by construction) ===\n")
print(HTw, nrows=20)
fwrite(HTw, file.path(OUT, "task4_part2_hit_table.csv"))
cat("\nMedian-z detail:\n")
print(dcast(HT, instrument ~ event, value.var="med_z"), nrows=20)
cat("\nB1 mothballing (Oct 2021): pre-sample -- untestable, recorded.\n")
cat("\nTaxonomy note: on transition days the taxonomy moves by construction; its validation rests on the mothball-spell and direction event classes via the full-exit indicator below.\n")
fx <- merge(events[["mothball-like spell starts (full-exit runs >=14d)"]][, .(DUID, cal_day)],
            V[, .(DUID, cal_day, full_exit)], by=c("DUID","cal_day"))
cat(sprintf("Full-exit share on mothball-spell-start windows: %.0f%% (n=%d) vs %.0f%% on quiet exit days\n",
            100*fx[, mean(full_exit, na.rm=TRUE)], nrow(fx),
            100*V[quiet==TRUE & exit_day==TRUE, mean(full_exit, na.rm=TRUE)]))
