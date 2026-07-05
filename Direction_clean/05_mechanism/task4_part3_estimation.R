#!/usr/bin/env Rscript
# task4_part3_estimation.R -- Part 3: the registered instrument test.
# Pre-registration: task4_part3_preregistration.md, committed 5d0451b BEFORE this script ran.
# Eligibility from the Part 2 gate. Clean days only, corrected clock, suspension days excluded
# in regressions (established June handling). Event counts before coefficients, always.

suppressMessages({ library(data.table); library(fixest); library(sandwich) })
set.seed(20260705)
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TEST_UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT")
WCB_R <- 999L

# ---------------------------------------------------------------------------
# Assemble the unit-day analysis table
# ---------------------------------------------------------------------------
SH  <- readRDS(file.path(OUT, "task4_ladder_shape.rds"))
CHD <- readRDS(file.path(OUT, "task4_churn.rds"))[, .(DUID, cal_day, churn_total)]
TX  <- fread(file.path(OUT, "task4_absence_type.csv")); TX[, cal_day := as.Date(cal_day)]
UD  <- readRDS(file.path(OUT, "task2_unit_day_panel.rds"))
D   <- readRDS(file.path(OUT, "task2_regression_panel.rds"))   # controls, clean via join below
DC  <- fread(file.path(OUT, "task2_job2_day_classes.csv")); DC[, cal_day := as.Date(cal_day)]
RBP <- readRDS(file.path(OUT, "task4_rebid_panel.rds")); BD <- RBP$BD; LV <- RBP$LV
TRS <- fread(file.path(OUT, "task3_part4_transitions.csv")); TRS[, cal_day := as.Date(cal_day)]
ep  <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep  <- ep[duid %in% TEST_UNITS]; ep[, `:=`(tau=force10(tau), s=force10(s), c=force10(c))]
ep740 <- ep[s >= as.POSIXct("2022-01-01", tz="Etc/GMT-10") & s < as.POSIXct("2025-01-01", tz="Etc/GMT-10")]

BD[, dir_tag := grepl("RTS|direction|MN ?#?[0-9]", REBIDEXPLANATION, ignore.case=TRUE)]
setkey(LV, DUID, td, odt); BD[, odt := od]
BDL <- LV[BD, on=.(DUID, td, odt), roll="nearest"]
BDL[, dt_gap := abs(as.numeric(difftime(odt, od, units="secs")))]
BDL[dt_gap > 60, lever := NA_character_]
RBD <- BDL[, .(n_nontag = sum(!dir_tag & (is.na(lever) | lever!="none")),
               n_nontag_am = sum(!dir_tag & (is.na(lever) | lever!="none") & as.integer(format(od,"%H")) < 12,
                                 na.rm=TRUE),
               n_nontag_ma = sum(!dir_tag & !is.na(lever) & lever %chin% c("MAXAVAIL","both")),
               n_tag = sum(dir_tag)), by=.(DUID, cal_day = dt10(od))]
grid <- CJ(DUID=TEST_UNITS, cal_day=seq(as.Date("2022-01-01"), as.Date("2024-12-31"), by="day"))
RBD <- merge(grid, RBD, by=c("DUID","cal_day"), all.x=TRUE)
for (cc in c("n_nontag","n_nontag_am","n_nontag_ma","n_tag")) RBD[is.na(get(cc)), (cc) := 0L]
RBD[, ma_share := fifelse(n_nontag > 0, n_nontag_ma/n_nontag, NA_real_)]

A <- Reduce(function(a,b) merge(a,b,by=c("DUID","cal_day"),all.x=TRUE),
  list(D[, .(DUID, cal_day, yyyymm, essential_day, segment, srmc, dem, ns, rrp, slope_mean, sat_share, composite)],
       SH[, .(DUID, cal_day, wmean_price, top2_share, steep_iqr, q_2xsrmc, q_shoulder)],
       CHD, RBD, TX[, .(DUID, cal_day, exit_day, atype)]))
A <- merge(A, DC[, .(DUID, cal_day, clean)], by=c("DUID","cal_day"))
tol <- rbindlist(lapply(seq_len(nrow(ep740)), function(j)
  data.table(DUID=ep740$duid[j], cal_day=seq(dt10(ep740$s[j])-2, dt10(ep740$c[j])+2, by="day"))))
tol <- unique(rbind(tol, TRS[, .(DUID, cal_day)], TRS[, .(DUID, cal_day=cal_day-1)], TRS[, .(DUID, cal_day=cal_day+1)]))
A[, quiet := clean==TRUE & !paste(DUID, cal_day) %in% tol[, paste(DUID, cal_day)]]

CL <- A[clean==TRUE & segment != "suspension_window"]
cat(sprintf("COUNTS FIRST: clean regression days %d (essential %d; PPCCGT essential %d); quiet baseline days %d\n",
            nrow(CL), CL[, sum(essential_day)], CL[DUID=="PPCCGT", sum(essential_day)], A[quiet==TRUE, .N]))

tidy <- function(f, ...) { ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value")); ct[, nobs := nobs(f)]
  extra <- list(...); for (nm in names(extra)) set(ct, j=nm, value=extra[[nm]]); ct[] }
rhs <- "essential_day + srmc + dem + ns + rrp + slope_mean + sat_share"
wcb <- function(d, lhs) {
  d <- d[!is.na(get(lhs))]
  lmf <- lm(as.formula(sprintf("%s ~ %s + factor(DUID) + factor(yyyymm)", lhs, rhs)), d)
  b <- coef(lmf)[["essential_dayTRUE"]]
  sapply(c(rademacher="wild", webb="wild-webb"), function(tp) {
    set.seed(20260705); v <- vcovBS(lmf, cluster=~yyyymm, R=WCB_R, type=tp)
    2*pt(-abs(b/sqrt(v["essential_dayTRUE","essential_dayTRUE"])), uniqueN(d$yyyymm)-1L) })
}

# ---------------------------------------------------------------------------
# (i) + (ii-regression): shape, benchmark, rebid intensity on essential days
# ---------------------------------------------------------------------------
cat("\n=== (i)/(ii) Essential-day coefficients, clean days (analytic + WCB) ===\n")
outs <- c("wmean_price","top2_share","steep_iqr","composite","n_nontag","n_nontag_am","ma_share")
res <- list()
for (o in outs) {
  d <- CL[!is.na(get(o))]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", o, rhs)), d, vcov=~yyyymm)
  w <- wcb(CL, o)
  res[[o]] <- tidy(f, outcome=o)[term=="essential_dayTRUE"][, `:=`(wcb_p_rad=w[1], wcb_p_webb=w[2])][]
}
for (o in c("q_2xsrmc","q_shoulder")) {   # PPCCGT only (Torrens declared blind)
  d <- CL[DUID=="PPCCGT" & !is.na(get(o))]
  f <- feols(as.formula(sprintf("%s ~ %s | yyyymm", o, rhs)), d, vcov=~yyyymm)
  res[[o]] <- tidy(f, outcome=paste0(o," (PPCCGT only)"))[term=="essential_dayTRUE"][, `:=`(wcb_p_rad=NA_real_, wcb_p_webb=NA_real_)][]
}
RES <- rbindlist(res, fill=TRUE)
fwrite(RES, file.path(OUT, "task4_part3_regressions.csv"))
print(RES[, .(outcome, estimate=round(estimate,3), se=round(std.error,3), p=round(p.value,4),
              wcb_p=round(wcb_p_rad,4), nobs)])

# ---------------------------------------------------------------------------
# (ii-window): rebids in the 48h before the 280 clean first directions
# ---------------------------------------------------------------------------
cat("\n=== (ii) Rebid window D-2/D-1 before clean first directions (count rule) ===\n")
LG <- readRDS(file.path(OUT, "task2_stance_lodgement.rds"))
RX <- fread(file.path(OUT, "task1c_redux_sequencing.csv"))
p26_ids <- RX[class=="signal after direction" & in_new_lobe==TRUE, episode_id]
ep740[, cal_day := dt10(s)]
ep740 <- merge(ep740, LG, by.x=c("duid","cal_day"), by.y=c("DUID","cal_day"), all.x=TRUE)
ep740 <- ep740[!is.na(lodge)]
ep740[, day_start := force10(as.POSIXct(paste(cal_day, "00:00:00"), tz="Etc/GMT-10"))]
cls1 <- function(u, lodge, day_start, excl_id) {
  e <- ep[duid==u & episode_id != excl_id]
  if (e[s < day_start & c > lodge, .N] > 0) return("continuation-active")
  if (e[tau <= day_start & s >= day_start & s < day_start+86400, .N] > 0) return("issued-pending")
  ld0 <- force10(as.POSIXct(paste(dt10(lodge), "00:00:00"), tz="Etc/GMT-10"))
  if (e[c >= ld0 & c <= lodge, .N] > 0) return("boundary")
  "clean"
}
ep740[, contam := mapply(cls1, duid, lodge, day_start, episode_id)]
CLF <- ep740[contam=="clean" & !episode_id %in% p26_ids]
wins <- rbindlist(lapply(c(-2L,-1L), function(k) CLF[, .(DUID=duid, cal_day=cal_day+k, rel=k)]))
wins <- merge(wins, A[, .(DUID, cal_day, clean, n_nontag, n_nontag_ma, n_tag, churn_total, composite)],
              by=c("DUID","cal_day"))
wins <- wins[clean==TRUE]
qb <- A[quiet==TRUE, .(nontag=mean(n_nontag), ma=mean(n_nontag_ma), tag=mean(n_tag))]
w2 <- wins[, .(n_days=.N, nontag=round(mean(n_nontag),2), rr_nontag=round(mean(n_nontag)/qb$nontag,1),
               ma_lever=round(mean(n_nontag_ma),2), rr_ma=round(mean(n_nontag_ma)/max(qb$ma,.01),1),
               tag=round(mean(n_tag),2), rr_tag=round(mean(n_tag)/max(qb$tag,.01),1)), by=rel]
cat(sprintf("Approach days that are themselves clean: D-2 %d, D-1 %d (of %d clean first directions)\n",
            wins[rel==-2,.N], wins[rel==-1,.N], nrow(CLF)))
print(w2)
fwrite(w2, file.path(OUT, "task4_part3_rebid_window.csv"))

# ---------------------------------------------------------------------------
# (iii) taxonomy approach: within-spell transitions x distance to next direction
# ---------------------------------------------------------------------------
cat("\n=== (iii) Type transitions conditioned on direction approach (counts, per prereg a bound) ===\n")
setorder(TX, DUID, cal_day)
TX[, `:=`(atype_next = shift(atype,-1), day_next = shift(cal_day,-1)), by=DUID]
TP <- TX[exit_day==TRUE & !is.na(atype_next) & day_next==cal_day+1]
sdays <- ep740[, .(DUID=duid, sday=cal_day)]
TP[, next_dir_2d := mapply(function(u,d) sdays[DUID==u & sday > d & sday <= d+2, .N] > 0, DUID, cal_day)]
TP[, no_dir_7d   := mapply(function(u,d) sdays[DUID==u & sday > d & sday <= d+7, .N] == 0, DUID, cal_day)]
t3 <- TP[, .N, by=.(cond = fifelse(next_dir_2d, "direction within 2d",
                     fifelse(no_dir_7d, "no direction within 7d", "between")), atype, atype_next)]
cat("Priced-out day transitions by condition:\n")
print(dcast(t3[atype=="priced-out"], cond ~ atype_next, value.var="N", fill=0))
cat("All exit-day transitions, direction-within-2d condition:\n")
print(dcast(t3[cond=="direction within 2d"], atype ~ atype_next, value.var="N", fill=0))
fwrite(t3, file.path(OUT, "task4_part3_taxonomy_approach.csv"))

# ---------------------------------------------------------------------------
# (iv) churn concentration ahead of directions and essentiality onsets
# ---------------------------------------------------------------------------
cat("\n=== (iv) Churn event-time profile (median z vs quiet baseline) ===\n")
bz <- A[quiet==TRUE, .(med=median(churn_total, na.rm=TRUE), iqr=max(IQR(churn_total, na.rm=TRUE),1e-6)), by=DUID]
bc <- A[quiet==TRUE, .(medc=median(composite, na.rm=TRUE), iqrc=max(IQR(composite, na.rm=TRUE),1e-6)), by=DUID]
prof <- function(anchors, label) {
  rbindlist(lapply(-3:1, function(k) {
    m <- merge(anchors[, .(DUID, cal_day=cal_day+k)], A[, .(DUID, cal_day, clean, churn_total, composite)],
               by=c("DUID","cal_day"))
    if (k < 0) m <- m[clean==TRUE]
    m <- merge(merge(m, bz, by="DUID"), bc, by="DUID")
    m[, .(event=label, rel=k, n=.N, med_z_churn=round(median((churn_total-med)/iqr, na.rm=TRUE),2),
          med_z_composite=round(median((composite-medc)/iqrc, na.rm=TRUE),2))]
  }))
}
ess_on <- A[essential_day==TRUE][order(DUID, cal_day)]
ess_on[, prev7 := sapply(seq_len(.N), function(i) A[DUID==ess_on$DUID[i] & cal_day >= ess_on$cal_day[i]-7 &
                                                    cal_day < ess_on$cal_day[i], sum(essential_day, na.rm=TRUE)])]
ess_on <- ess_on[prev7==0 & clean==TRUE]
P4 <- rbind(prof(CLF[, .(DUID=duid, cal_day)], "clean first direction"),
            prof(ess_on[, .(DUID, cal_day)], "essentiality onset (clean, >=7d gap)"))
print(P4)
fwrite(P4, file.path(OUT, "task4_part3_churn_profile.csv"))
cat("\nSaved task4_part3_{regressions,rebid_window,taxonomy_approach,churn_profile}.csv\n")
