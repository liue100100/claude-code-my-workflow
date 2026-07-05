#!/usr/bin/env Rscript
# task8_four_checks.R -- four checks before the final regression under pex_n1. NO regression.
# 1 spell/concentration structure of the N-1 label; 2 monotonicity validity (ordinary <
# N-1-only < N-0 on trouble indicators); 3 contamination survival of the newly-essential days;
# 4 the evening-on-offer count table that gates the test (thresholds: >=30 days, >=10 cancels).

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TOR <- c("TORRB2","TORRB3","TORRB4")

G <- fread(file.path(OUT, "task7_label_census.csv"))
G[, cal_day := as.Date(cal_day)]
G[, cat := fcase(ess_pex==TRUE, "N-0", ess_n1==TRUE, "N-1 only", default="ordinary")]

# ---------------------------------------------------------------------------
cat("================ CHECK 1: is 606 really 606? ================\n")
setorder(G, DUID, cal_day)
runs <- G[, {r <- rle(ess_n1); .(len=r$lengths, val=r$values)}, by=DUID][val==TRUE]
cat("N-1 essential-day spell lengths (consecutive days, per unit):\n")
print(runs[, .(n_spells=.N, med=as.numeric(median(len)), p75=as.numeric(quantile(len,.75)),
               p90=as.numeric(quantile(len,.9)), max=as.numeric(max(len))), by=DUID])
CE <- G[ess_n1==TRUE & clean==TRUE]
mo <- CE[, .N, by=.(yyyymm=format(cal_day,"%Y%m"))][order(-N)]
cat(sprintf("\n606 clean essential unit-days fall in %d months; top 3 hold %.1f%%, top 6 %.1f%%\n",
            nrow(mo), 100*sum(head(mo$N,3))/sum(mo$N), 100*sum(head(mo$N,6))/sum(mo$N)))
print(head(mo, 8))
cat(sprintf("Effective independent days (Torrens units share the station flag): %d Torrens station-days + %d PPCCGT days = %d station-days\n",
            uniqueN(CE[DUID %in% TOR, cal_day]), CE[DUID=="PPCCGT", .N],
            uniqueN(CE[DUID %in% TOR, cal_day]) + CE[DUID=="PPCCGT", .N]))
fwrite(mo, file.path(OUT, "task8_check1_months.csv"))

# ---------------------------------------------------------------------------
cat("\n================ CHECK 2: does N-1 mean what it claims? ================\n")
D <- readRDS(file.path(OUT, "task2_regression_panel.rds"))
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% c(TOR,"PPCCGT")]; ep[, s := force10(s)]
sd_tab <- ep[, .(dir_start = .N), by=.(DUID=duid, cal_day=dt10(s))]
ICDIR <- file.path(ROOT, "Direction_clean/_demand_ic_cache")
IC <- rbindlist(lapply(list.files(ICDIR, pattern="^INTERCONNECTOR_[0-9]{6}\\.rds$", full.names=TRUE), function(f) {
  x <- readRDS(f); setDT(x)
  keep <- intersect(c("SETTLEMENTDATE","INTERCONNECTORID","MWFLOW"), names(x)); x[, ..keep] }))
IC <- IC[, .(imp = sum(MWFLOW, na.rm=TRUE)), by=SETTLEMENTDATE]   # net import into SA (sign verified Stage 2)
IC[, cal_day := dt10(force10(SETTLEMENTDATE) - 1)]
ICd <- IC[, .(import_mw = mean(imp)), by=cal_day]
X2 <- merge(G, D[, .(DUID, cal_day, dem, ns, rrp, slope_mean, sat_share)], by=c("DUID","cal_day"))
X2 <- merge(X2, sd_tab, by=c("DUID","cal_day"), all.x=TRUE)[is.na(dir_start), dir_start := 0L]
X2 <- merge(X2, ICd, by="cal_day", all.x=TRUE)
t2 <- X2[, .(unit_days=.N,
             pct_direction_start = round(100*mean(dir_start > 0),1),
             renewable_share = round(mean(fifelse(dem > 500, ns/dem, NA_real_), na.rm=TRUE),2),
             import_mw = round(mean(import_mw, na.rm=TRUE)),
             slope_mean = round(mean(slope_mean, na.rm=TRUE),2),
             saturated_share = round(mean(sat_share, na.rm=TRUE),3),
             spot_mean = round(mean(rrp, na.rm=TRUE))), by=cat][order(match(cat, c("ordinary","N-1 only","N-0")))]
print(t2)
fwrite(t2, file.path(OUT, "task8_check2_monotonicity.csv"))

# ---------------------------------------------------------------------------
cat("\n================ CHECK 3: contamination survival of the newly-essential days ================\n")
n1o <- G[cat=="N-1 only"]
cat(sprintf("N-1-only unit-days BEFORE the screen: %d; clean after the Job-2 screen: %d (%.1f%% lost)\n",
            nrow(n1o), n1o[clean==TRUE, .N], 100*n1o[clean==FALSE, .N]/nrow(n1o)))
print(n1o[, .(total=.N, clean=sum(clean), pct_clean=round(100*mean(clean),1)), by=DUID])
cat("NOTE: the '526 newly-essential days' cited going in is the POST-screen count (606 clean N-1 minus 80 clean N-0); the pre-screen population is above.\n")

# ---------------------------------------------------------------------------
cat("\n================ CHECK 4: the count table that gates the regression (Torrens) ================\n")
POP <- readRDS(file.path(OUT, "task6_population.rds"))       # clean Torrens days, evening on offer yesterday
P4 <- merge(POP, G[, .(DUID, cal_day, cat)], by=c("DUID","cal_day"))
t4 <- P4[, .(evening_on_offer=.N, cancelled=sum(cancel), rate=round(100*mean(cancel),1)),
         by=cat][order(match(cat, c("ordinary","N-1 only","N-0")))]
print(t4)
for (cc in c("N-1 only","N-0")) {
  r <- t4[cat==cc]
  if (nrow(r)) cat(sprintf("GATE [%s]: days %d (>=30: %s), cancellations %d (>=10: %s) -> %s\n",
    cc, r$evening_on_offer, r$evening_on_offer>=30, r$cancelled, r$cancelled>=10,
    if (r$evening_on_offer>=30 && r$cancelled>=10) "TESTABLE" else "counts only"))
}
fwrite(t4, file.path(OUT, "task8_check4_gate.csv"))
cat("\nNo regression run, per instruction. Saved task8_check{1_months,2_monotonicity,4_gate}.csv\n")
