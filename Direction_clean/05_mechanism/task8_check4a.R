#!/usr/bin/env Rscript
# task8_check4a.R -- Check 4a: does the known exit act track the ENVELOPE (N-1 state), the
# EVENT (direction approach), or neither? Descriptive only, no test.
# Population = Check 4's: clean Torrens days with a full evening on offer yesterday.
# Approach window = within D-3..D-1 of any of the unit's direction starts (corrected clock),
# matching the churn-ramp windows. Factorial rows: {ordinary, N-1 only, N-0} x {outside,
# inside}; ordinary-outside is the base. Rates with denominators everywhere.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
dt10 <- function(x) as.Date(x, tz="Etc/GMT-10")
TOR <- c("TORRB2","TORRB3","TORRB4")

POP <- readRDS(file.path(OUT, "task6_population.rds"))
G <- fread(file.path(OUT, "task7_label_census.csv")); G[, cal_day := as.Date(cal_day)]
G[, cat := fcase(ess_pex==TRUE, "N-0", ess_n1==TRUE, "N-1 only", default="ordinary")]
P <- merge(POP, G[, .(DUID, cal_day, cat)], by=c("DUID","cal_day"))

ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% TOR]; ep[, s := force10(s)]
app <- unique(rbindlist(lapply(1:3, function(k) ep[, .(DUID=duid, cal_day = dt10(s) - k)])))
P[, inside := paste(DUID, cal_day) %in% app[, paste(DUID, cal_day)]]

T <- P[, .(evening_on_offer=.N, cancelled=sum(cancel), rate=round(100*mean(cancel),1)),
       by=.(cat, window = fifelse(inside, "inside approach (D-3..D-1)", "outside"))]
T <- T[order(match(cat, c("ordinary","N-1 only","N-0")), window)]
cat("=== Check 4a: evening floor-crossing rate, envelope x event (clean Torrens evening-on-offer days) ===\n")
print(T)
cat("\nBase (ordinary, outside):", T[cat=="ordinary" & window=="outside", sprintf("%d/%d = %.1f%%", cancelled, evening_on_offer, rate)], "\n")
fwrite(T, file.path(OUT, "task8_check4a.csv"))
