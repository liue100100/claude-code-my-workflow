#!/usr/bin/env Rscript
# task2_job2_contamination.R -- Job 2: the "already under direction" problem.
#
# COMMITTED READING (stated before running, per instruction): if the headline results hold on
# clean days alone, the contamination worry is closed. If they weaken materially, the clean-day
# estimates become the headline and the findings say why.
#
# Classification of every Task-2 unit-day (CORRECTED direction times; source fixed in Job 1):
#   lodge      = submission time of the day-ahead version in force at 00:00 of the trading day
#   day_start  = 00:00 of the trading day (the bid-formation window is [lodge, day_start])
#   continuation-active : a direction on the unit was ACTIVE at some point in [lodge, day_start]
#   issued-pending      : a direction was ISSUED by day_start that covers (part of) the outcome
#                         day but was not yet effective in the window -- the unit already knew
#                         tomorrow was covered; grouped WITH continuation for the clean rule
#   boundary            : a direction ENDED on the lodgement calendar day before the bid was
#                         lodged (reported separately; likely fine)
#   clean               : none of the above
# Precedence: continuation-active > issued-pending > boundary > clean.
#
# Plus the named sub-analysis: the 26 post-issue-exit episodes from the Task-1c redux --
# rebid metadata checked FIRST (AEMO-lodged variations?), own row in the contamination table.
#
# Run from my-project root. Outputs task2_job2_*.csv.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by="month"), "%Y%m")
WCB_R <- 999L

# ---------------------------------------------------------------------------
# 0. Lodgement time of the in-force day-ahead version, per unit-day (cached)
# ---------------------------------------------------------------------------
LCACHE <- file.path(OUT, "task2_stance_lodgement.rds")
if (file.exists(LCACHE)) { LG <- readRDS(LCACHE); cat("Loaded lodgement cache\n") } else {
  lg_list <- vector("list", length(MONTHS))
  for (k in seq_along(MONTHS)) {
    M <- MONTHS[k]
    b <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(b)
    b <- b[DUID %in% FOCUS & BIDTYPE=="ENERGY", .(DUID, OFFERDATETIME, INTERVAL_DATETIME)]
    b[, `:=`(odt = force10(OFFERDATETIME), cal_day = dt10(force10(INTERVAL_DATETIME) - 1))]
    b <- unique(b[, .(DUID, cal_day, odt)])
    b[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
    lg_list[[k]] <- b[odt <= day_start, .(lodge = max(odt)), by=.(DUID, cal_day)]
    cat(sprintf("  %s done\n", M)); rm(b); gc(verbose=FALSE)
  }
  LG <- rbindlist(lg_list); saveRDS(LG, LCACHE)
}
cat(sprintf("Lodgement rows: %d (expect 5 x 1096 = 5480)\n", nrow(LG)))

# ---------------------------------------------------------------------------
# 1. Classify every unit-day (corrected episodes; all focal episodes incl. pre-2022 tails)
# ---------------------------------------------------------------------------
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% FOCUS & !is.na(s) & !is.na(c) & c > s]
ep[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]

D <- readRDS(file.path(OUT, "task2_regression_panel.rds"))   # test units, controls, essential_day
D <- merge(D, LG, by.x=c("DUID","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)
stopifnot(D[is.na(lodge), .N] == 0)
D[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
D[, day_end := day_start + 86400]

classify_day <- function(u, lodge, day_start, day_end, excl_id = -1L) {
  e <- ep[duid == u & episode_id != excl_id]
  active  <- e[s < day_start & c > lodge, .N] > 0
  pending <- e[tau <= day_start & s >= day_start & s < day_end, .N] > 0
  lodge_day0 <- force10(as.POSIXct(paste(dt10(lodge), "00:00:00"), tz="Etc/GMT-10"))
  bound   <- e[c >= lodge_day0 & c <= lodge, .N] > 0
  if (active) "continuation-active" else if (pending) "issued-pending" else if (bound) "boundary" else "clean"
}
D[, contam := mapply(classify_day, DUID, lodge, day_start, day_end)]
D[, clean := contam == "clean"]
D[, contam_any := contam %in% c("continuation-active","issued-pending")]

tab <- D[, .(unit_days=.N, essential_days=sum(essential_day)), by=contam][order(-unit_days)]
cat("\n=== (a) Contamination table (test units, 4,384 unit-days) ===\n"); print(tab)
cat(sprintf("Essential days: clean %d / issued-pending %d / continuation-active %d / boundary %d (of %d)\n",
            D[contam=="clean", sum(essential_day)], D[contam=="issued-pending", sum(essential_day)],
            D[contam=="continuation-active", sum(essential_day)], D[contam=="boundary", sum(essential_day)],
            D[, sum(essential_day)]))

# ---------------------------------------------------------------------------
# 2. The 26 post-issue-exit episodes: rebid metadata FIRST, then their own table row
# ---------------------------------------------------------------------------
cat("\n=== (b) Named sub-analysis: the 26 post-issue-exit episodes ===\n")
RX <- fread(file.path(OUT, "task1c_redux_sequencing.csv"))
P26 <- RX[class=="signal after direction" & in_new_lobe==TRUE]
epi <- ep[episode_id %in% P26$episode_id]
P26 <- merge(P26, epi[, .(episode_id, tau, s, c)], by="episode_id")
P26[, exit_odt := tau + first_exit_rel_h*3600]
mm26 <- sort(unique(format(P26$exit_odt, "%Y%m")))
BD <- rbindlist(lapply(mm26, function(M) {
  f <- file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M)); if (!file.exists(f)) return(NULL)
  b <- readRDS(f); setDT(b)
  keep <- intersect(c("DUID","SETTLEMENTDATE","OFFERDATE","VERSIONNO","PARTICIPANTID","ENTRYTYPE",
                      "REBIDEXPLANATION","REBID_CATEGORY","REBID_EVENT_TIME"), names(b))
  b[DUID %in% FOCUS & BIDTYPE=="ENERGY", ..keep]
}), fill=TRUE)
BD[, od := force10(OFFERDATE)]
meta <- rbindlist(lapply(seq_len(nrow(P26)), function(j) {
  e <- P26[j]
  m <- BD[DUID == e$duid & abs(as.numeric(difftime(od, e$exit_odt, units="mins"))) <= 5]
  if (!nrow(m)) return(data.table(episode_id=e$episode_id, duid=e$duid, matched=FALSE))
  m <- m[which.min(abs(as.numeric(difftime(od, e$exit_odt, units="mins"))))]
  data.table(episode_id=e$episode_id, duid=e$duid, matched=TRUE,
             entrytype=if ("ENTRYTYPE" %in% names(m)) as.character(m$ENTRYTYPE) else NA_character_,
             participant=if ("PARTICIPANTID" %in% names(m)) as.character(m$PARTICIPANTID) else NA_character_,
             rebid_category=as.character(m$REBID_CATEGORY),
             mentions_direction=grepl("direction|AEMO", m$REBIDEXPLANATION, ignore.case=TRUE),
             explanation=substr(as.character(m$REBIDEXPLANATION), 1, 90))
}), fill=TRUE)
fwrite(meta, file.path(OUT, "task2_job2_postissue26_metadata.csv"))
cat(sprintf("Metadata matched for %d of %d post-issue exit versions\n", meta[matched==TRUE,.N], nrow(meta)))
if ("entrytype" %in% names(meta)) { cat("ENTRYTYPE distribution:\n"); print(meta[matched==TRUE, .N, by=entrytype]) }
cat("PARTICIPANTID distribution:\n"); print(meta[matched==TRUE, .N, by=participant])
cat(sprintf("Explanations mentioning direction/AEMO: %d of %d matched\n",
            meta[mentions_direction==TRUE, .N], meta[matched==TRUE, .N]))
cat("Global metadata check -- distinct ENTRYTYPE values in BIDDAYOFFER (any AEMO-lodged marker?):\n")
if ("ENTRYTYPE" %in% names(BD)) print(BD[, .N, by=ENTRYTYPE]) else cat("  ENTRYTYPE column absent in cache months\n")

# ---------------------------------------------------------------------------
# 3. Step-6 split: first directions after a clean day vs continuations (self-excluded)
# ---------------------------------------------------------------------------
cat("\n=== (c) Step-6 split: episodes by issue-day contamination (self-excluded) ===\n")
ep740 <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]
ep740[, cal_day := dt10(s)]
ep740 <- merge(ep740, LG, by.x=c("duid","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)
ep740 <- ep740[!is.na(lodge)]
ep740[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
ep740[, day_end := day_start + 86400]
ep740[, contam := mapply(classify_day, duid, lodge, day_start, day_end, episode_id)]
UD <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
ep740 <- merge(ep740, UD[, .(duid=DUID, cal_day, comp_A, composite)], by=c("duid","cal_day"), all.x=TRUE)
ep740[, exit_conduct := fifelse(comp_A==TRUE, "withdrawn", fifelse(composite > 300, "priced-out", "committed-cheap"))]
ep740[, p26 := episode_id %in% P26$episode_id]
split6 <- ep740[!is.na(exit_conduct), .N, by=.(group = fifelse(p26, "post-issue-exit (the 26)", contam), exit_conduct)]
split6 <- dcast(split6, group ~ exit_conduct, value.var="N", fill=0)
for (cc in c("withdrawn","priced-out","committed-cheap")) if (!cc %in% names(split6)) split6[, (cc) := 0L]
split6[, n := withdrawn + `priced-out` + `committed-cheap`]
split6[, exit_pct := round(100*(1 - `committed-cheap`/n), 1)]
fwrite(split6, file.path(OUT, "task2_job2_step6_split.csv"))
print(split6)
cln <- ep740[contam=="clean" & !p26 & !is.na(exit_conduct)]
cat(sprintf("\nTHE HONEST NUMBER -- clean-day first directions: %d episodes; withdrawn/priced-out %.1f%% (withdrawn %.1f%%, priced-out %.1f%%)\n",
            nrow(cln), 100*cln[, mean(exit_conduct != "committed-cheap")],
            100*cln[, mean(exit_conduct=="withdrawn")], 100*cln[, mean(exit_conduct=="priced-out")]))

# ---------------------------------------------------------------------------
# 4. RQ1 and RQ2 on clean days only; and with a contamination indicator
# ---------------------------------------------------------------------------
cat("\n=== (d) RQ1 on clean days only (M3) ===\n")
outcomes <- c(composite="composite", rank="comp_rank", A_withdrawal="comp_A", B_pricing="comp_B")
rhs3 <- "essential_day + srmc + dem + ns + rrp + slope_mean + sat_share"
tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  extra <- list(...); for (nm in names(extra)) set(ct, j=nm, value=extra[[nm]]); ct[] }
res1 <- list()
for (o in names(outcomes)) {
  dcl <- D[clean==TRUE]; if (o=="B_pricing") dcl <- dcl[comp_A==FALSE & !is.na(comp_B)]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs3)), dcl, vcov=~yyyymm)
  res1[[paste(o,"clean")]] <- tidy(f, outcome=o, spec="clean days only")
  dfull <- if (o=="B_pricing") D[comp_A==FALSE & !is.na(comp_B)] else D
  f2 <- feols(as.formula(sprintf("%s ~ essential_day*contam_any + srmc + dem + ns + rrp + slope_mean + sat_share | DUID + yyyymm",
                                 outcomes[[o]])), dfull, vcov=~yyyymm)
  res1[[paste(o,"indicator")]] <- tidy(f2, outcome=o, spec="full sample + contamination indicator")
}
res1 <- rbindlist(res1, fill=TRUE); fwrite(res1, file.path(OUT, "task2_job2_rq1.csv"))
print(res1[term %in% c("essential_dayTRUE"), .(outcome, spec, estimate=round(estimate,3), se=round(std.error,3), p=round(p.value,4), nobs)])
cat("Contamination terms (full-sample models):\n")
print(res1[grepl("contam", term), .(outcome, term, estimate=round(estimate,3), p=round(p.value,4))])

# WCB for the two headline components on clean days
cat("\nWCB (clean days, Rademacher/Webb):\n")
for (o in c("A_withdrawal","B_pricing")) {
  dcl <- D[clean==TRUE]; if (o=="B_pricing") dcl <- dcl[comp_A==FALSE & !is.na(comp_B)]
  fml <- as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", outcomes[[o]], rhs3))
  lmf <- lm(fml, dcl); b <- coef(lmf)[["essential_dayTRUE"]]
  for (tp in c(rademacher="wild", webb="wild-webb")) {
    set.seed(20260705); v <- vcovBS(lmf, cluster=~yyyymm, R=WCB_R, type=tp)
    se <- sqrt(v["essential_dayTRUE","essential_dayTRUE"]); df <- uniqueN(dcl$yyyymm)-1L
    cat(sprintf("  [%s %s] b=%.4f  wcb_p=%.4f\n", o, tp, b, 2*pt(-abs(b/se), df)))
  }
}

cat("\n=== (e) RQ2 on clean matched days (base June treatment) ===\n")
# stratum was built after the panel save in task2_estimation.R -- rebuild with IDENTICAL
# definitions (quantiles/terciles computed on the FULL panel, then applied)
D[, nsq := cut(ns, quantile(ns, seq(0,1,.2), na.rm=TRUE), include.lowest=TRUE, labels=1:5)]
sl_terc <- quantile(D[sat_share < .5, slope_mean], c(1/3,2/3), na.rm=TRUE)
D[, comp_bin := fifelse(sat_share >= .5, "saturated_day",
               fifelse(slope_mean <= sl_terc[1], "t1", fifelse(slope_mean <= sl_terc[2], "t2", "t3")))]
D[, stratum := paste(DUID, yyyymm, nsq, comp_bin, sep="|")]
D[, matched_clean := FALSE]
ok <- D[clean==TRUE, .(ne=sum(essential_day), nc=sum(!essential_day)), by=stratum][ne>0 & nc>0, stratum]
D[clean==TRUE & stratum %in% ok, matched_clean := TRUE]
cat(sprintf("Clean matched: %d unit-days, %d essential days over %d months\n",
            D[matched_clean==TRUE, .N], D[matched_clean==TRUE, sum(essential_day)],
            D[matched_clean==TRUE & essential_day==TRUE, uniqueN(yyyymm)]))
rhs2 <- "essential_day*comp_price_100 + srmc + dem + ns + rrp + slope_mean + sat_share"
res2 <- list()
for (o in names(outcomes)) {
  dcl <- D[matched_clean==TRUE & segment != "suspension_window"]
  if (o=="B_pricing") dcl <- dcl[comp_A==FALSE & !is.na(comp_B)]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs2)), dcl, vcov=~yyyymm)
  res2[[o]] <- tidy(f, outcome=o, spec="clean matched, base")
}
res2 <- rbindlist(res2, fill=TRUE); fwrite(res2, file.path(OUT, "task2_job2_rq2.csv"))
print(res2[term=="essential_dayTRUE:comp_price_100",
           .(outcome, estimate=round(estimate,4), se=round(std.error,4), p=round(p.value,4), nobs)])
fwrite(tab, file.path(OUT, "task2_job2_contamination_table.csv"))
fwrite(D[, .(DUID, cal_day, contam, clean, essential_day)], file.path(OUT, "task2_job2_day_classes.csv"))
cat("\nSaved task2_job2_{contamination_table,day_classes,postissue26_metadata,step6_split,rq1,rq2}.csv\n")
