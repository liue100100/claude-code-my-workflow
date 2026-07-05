#!/usr/bin/env Rscript
# stage3b_closeout.R -- Stage 3b: close-out amendments to RQ1 (user-specified, 2026-07-04).
#
# (A) SYMMETRIC FRAGILITY: leave-one-month-out (LOMO) coefficient path for BOTH headline unit
#     results -- Pelican Point's +0.18 (previously unchecked) and Torrens's -0.076 (previously
#     checked only for June-2022) -- so both carry the same honesty label.
# (B) THREE-WAY JUNE-2022 SPLIT: the month is not one block. Segments defined from AEMO's own
#     per-interval flags (DISPATCHPRICE MARKETSUSPENDEDFLAG), not hardcoded dates:
#       pre-suspension:    2022-06-01 -> 2022-06-15 14:05 (includes an APC/administered-price
#                          sub-period from 2022-06-05 18:05, reported as an overlay)
#       suspension window: 2022-06-15 14:10 -> 2022-06-24 14:00 (2,591 intervals, contiguous,
#                          verified zero unflagged intervals inside)
#       post-suspension:   2022-06-24 14:05 -> month end
#     Torrens essentiality coefficient re-reported with each segment included/excluded.
#
# Run from Direction_clean/, after run_rq1.R. Writes outputs/03_rq1_essentiality/stage3b_*.
# Findings-file text amendments (elimination logic, two named findings) live in
# finalize_findings.R; this script produces the numbers + findings_3b.md.

suppressMessages({ library(data.table); library(fixest); library(ggplot2) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

D <- readRDS(file.path(OUT, "regression_panel.rds"))
outcomes <- c(a_fixed300 = "cheap_a_share", b_2xSRMC = "cheap_b_share")
rhs_m3 <- "essential + srmc + TOTALDEMAND + nonsync_mw + RRP + slope_kernel + saturated"
months <- sort(unique(D$yyyymm))
stopifnot(length(months) == 36L)

ess_row <- function(f) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames="term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct[term=="essentialTRUE", .(estimate, std.error, p.value)]
}

# ---------------------------------------------------------------------------
# (A) Leave-one-month-out, both units, both outcomes, M3
# ---------------------------------------------------------------------------
cat("=== (A) Leave-one-month-out coefficient paths ===\n")
units <- list(torrens = list(d = D[DUID %in% c("TORRB2","TORRB3","TORRB4")], fe = "DUID + yyyymm"),
              pelican = list(d = D[DUID == "PPCCGT"],                        fe = "yyyymm"))
lomo <- rbindlist(lapply(names(units), function(u) rbindlist(lapply(names(outcomes), function(o) {
  base <- ess_row(feols(as.formula(sprintf("%s ~ %s | %s", outcomes[[o]], rhs_m3, units[[u]]$fe)),
                         units[[u]]$d, vcov=~yyyymm))
  path <- rbindlist(lapply(months, function(m) {
    f <- feols(as.formula(sprintf("%s ~ %s | %s", outcomes[[o]], rhs_m3, units[[u]]$fe)),
               units[[u]]$d[yyyymm != m], vcov=~yyyymm)
    cbind(dropped_month = m, ess_row(f))
  }))
  cbind(unit = u, outcome = o, base_estimate = base$estimate, base_p = base$p.value, path)
}))))
lomo[, `:=`(sign_flip = sign(estimate) != sign(base_estimate),
            crosses_05 = (base_p < 0.05) != (p.value < 0.05),
            crosses_10 = (base_p < 0.10) != (p.value < 0.10))]
fwrite(lomo, file.path(OUT, "stage3b_lomo_path.csv"))

driver <- lomo[sign_flip | crosses_05 | crosses_10][order(unit, outcome, dropped_month)]
cat("\nMonths whose removal flips the sign or moves p across 0.05/0.10:\n")
print(driver[, .(unit, outcome, dropped_month, estimate, p.value, base_estimate, base_p, sign_flip, crosses_05, crosses_10)])

lomo[, unit_lab := fifelse(unit=="torrens", "Torrens Island B (TORRB2/3/4)", "Pelican Point (PPCCGT)")]
lomo[, out_lab  := fifelse(outcome=="a_fixed300", "Fixed $300", "Cost-indexed 2xSRMC")]
p <- ggplot(lomo, aes(as.factor(dropped_month), estimate)) +
  geom_hline(yintercept=0, linetype="dashed", colour="grey50") +
  geom_hline(aes(yintercept=base_estimate), colour="steelblue", linetype="dotted") +
  geom_pointrange(aes(ymin=estimate-1.96*std.error, ymax=estimate+1.96*std.error,
                      colour=sign_flip | crosses_05 | crosses_10), size=0.25) +
  scale_colour_manual(values=c(`FALSE`="grey30", `TRUE`="red"), guide="none") +
  facet_grid(unit_lab ~ out_lab, scales="free_y") +
  labs(title="Stage 3b: leave-one-month-out path of the essentiality coefficient",
       subtitle="Each point = coefficient with that month dropped. Dotted line = full-sample estimate. Red = dropping that month flips the sign or moves p across 0.05/0.10.",
       x="Month dropped", y="Essentiality coefficient") +
  theme_bw(base_size=9) + theme(axis.text.x = element_text(angle=90, vjust=0.5, size=5))
ggsave(file.path(OUT, "stage3b_lomo_path.png"), p, width=13, height=7, dpi=150)

# ---------------------------------------------------------------------------
# (B) Three-way June-2022 split (segments from AEMO's own flags)
# ---------------------------------------------------------------------------
cat("\n=== (B) Three-way June-2022 split, Torrens ===\n")
prc <- readRDS(file.path(ROOT, "Direction/bid_cache/DISPATCHPRICE_202206.rds")); setDT(prc)
prc <- prc[REGIONID=="SA1" & as.numeric(INTERVENTION)==0]
prc[, interval_dt := force10(SETTLEMENTDATE)]
prc[, ms := as.numeric(MARKETSUSPENDEDFLAG)]; prc[, apc := as.numeric(APCFLAG)]
susp_start <- min(prc[ms>0, interval_dt]); susp_end <- max(prc[ms>0, interval_dt])
stopifnot(prc[interval_dt >= susp_start & interval_dt <= susp_end & ms==0, .N] == 0)  # contiguity
seg_map <- prc[, .(interval_dt,
                   segment = fifelse(interval_dt < susp_start, "pre_suspension",
                              fifelse(interval_dt <= susp_end, "suspension_window", "post_suspension")),
                   apc = apc > 0)]
cat(sprintf("Suspension window (from MARKETSUSPENDEDFLAG): %s -> %s\n", format(susp_start), format(susp_end)))

Dt <- D[DUID %in% c("TORRB2","TORRB3","TORRB4")]
Dt <- merge(Dt, seg_map[, .(interval_dt, segment, apc)], by="interval_dt", all.x=TRUE)
Dt[is.na(segment), segment := "outside_june2022"]

seg_counts <- Dt[segment != "outside_june2022",
  .(intervals = uniqueN(interval_dt), unit_rows = .N,
    essential_unit_rows = sum(essential), essential_intervals = uniqueN(interval_dt[essential]),
    apc_intervals = uniqueN(interval_dt[apc])), by=segment]
tot_ess <- Dt[, .(essential_unit_rows_total = sum(essential), essential_intervals_total = uniqueN(interval_dt[essential]))]
fwrite(seg_counts, file.path(OUT, "stage3b_june_segment_counts.csv"))
cat("\nSegment denominators (Torrens):\n"); print(seg_counts)
cat(sprintf("Torrens essential intervals, whole sample: %d (unit-rows %d)\n",
            tot_ess$essential_intervals_total, tot_ess$essential_unit_rows_total))

variants <- list(
  "baseline (all months)"        = quote(rep(TRUE, .N)),
  "drop suspension window only"  = quote(segment != "suspension_window"),
  "drop pre-suspension June only"= quote(segment != "pre_suspension"),
  "drop post-suspension June only"= quote(segment != "post_suspension"),
  "drop all of June 2022"        = quote(segment == "outside_june2022")
)
june_split <- rbindlist(lapply(names(variants), function(v) rbindlist(lapply(names(outcomes), function(o) {
  d <- Dt[eval(variants[[v]])]
  f <- feols(as.formula(sprintf("%s ~ %s | DUID + yyyymm", outcomes[[o]], rhs_m3)), d, vcov=~yyyymm)
  cbind(variant = v, outcome = o, ess_row(f), nobs = nobs(f),
        n_essential_rows = d[, sum(essential)])
}))))
fwrite(june_split, file.path(OUT, "stage3b_june_split.csv"))
cat("\nTorrens essentiality coefficient by June-2022 segment treatment (M3):\n")
print(june_split)

# ---------------------------------------------------------------------------
# findings_3b.md
# ---------------------------------------------------------------------------
n_driver_pp <- driver[unit=="pelican", uniqueN(dropped_month)]
n_driver_tr <- driver[unit=="torrens", uniqueN(dropped_month)]
drv_list <- function(u) {
  d <- driver[unit==u, .(months = paste(unique(dropped_month), collapse=", ")), by=outcome]
  if (!nrow(d)) return("none")
  paste(sprintf("%s: %s", d$outcome, d$months), collapse=" | ")
}
js <- function(v,o) june_split[variant==v & outcome==o]

findings <- sprintf(
"# Stage 3b findings -- close-out amendments to RQ1 (Direction_clean/)

## (A) Symmetric fragility: leave-one-month-out paths for BOTH headline unit results
Full paths in `stage3b_lomo_path.csv` / `.png` (36 re-estimates per unit x outcome, M3
specification). Months whose removal flips the sign or moves p across the 0.05 or 0.10 threshold:

- **Pelican Point** (+0.184 base, p=0.070 fixed-$300): %d such month(s) -- %s
- **Torrens** (-0.076 base, p=0.039 cost-indexed): %d such month(s) -- %s

Both headline coefficients now carry the same honesty label; see the table for exactly which
months move which result across which threshold.

## (B) Three-way June-2022 split (segments from AEMO's own per-interval flags, not assumed dates)
- Suspension window: **%s -> %s** (contiguity verified: zero unflagged intervals inside).
- Pre-suspension June includes an administered-price (APC) sub-period from 2022-06-05 18:05 --
  those days are not ordinary pricing either; APC interval counts reported per segment below.

Segment denominators (Torrens; unit-rows = interval x unit):
%s
Torrens essential intervals in the whole 36-month sample: %d.

Torrens essentiality coefficient (M3) under each treatment:
| Variant | Fixed $300 (p) | Cost-indexed (p) | n essential unit-rows |
|---|---|---|---|
%s

**Reading:** see the table -- the segment whose exclusion moves the coefficient/significance the
most is where the result's power sits. If the pre-suspension fortnight alone sustains a negative
coefficient, the result is not merely suspension-era administered-price conduct; if all action
sits inside the suspension window, that is the scope limitation, stated as such.

## (C)/(D) Findings-file amendments
The elimination-logic correction (RQ1's residual = payment-seeking OR presence-inelasticity
conduct, split by RQ2 -- not 'compensation-eligibility by default') and the two newly named
findings (the wrong-sign orthogonality result; the regime-not-dose pattern) are in the revised
main `findings.md` (regenerated by `finalize_findings.R`).

**STOP -- Stage 3b complete. Awaiting review before Stage 4 (RQ2).**
",
  n_driver_pp, drv_list("pelican"), n_driver_tr, drv_list("torrens"),
  format(susp_start), format(susp_end),
  paste(sprintf("- %s: %s intervals (%s unit-rows), %s essential unit-rows (%s essential intervals), %s APC intervals",
                seg_counts$segment, seg_counts$intervals, seg_counts$unit_rows,
                seg_counts$essential_unit_rows, seg_counts$essential_intervals, seg_counts$apc_intervals), collapse="\n"),
  tot_ess$essential_intervals_total,
  paste(sprintf("| %s | %.4f (%.3f) | %.4f (%.3f) | %d |",
                names(variants),
                june_split[outcome=="a_fixed300"][match(names(variants), variant), estimate],
                june_split[outcome=="a_fixed300"][match(names(variants), variant), p.value],
                june_split[outcome=="b_2xSRMC"][match(names(variants), variant), estimate],
                june_split[outcome=="b_2xSRMC"][match(names(variants), variant), p.value],
                june_split[outcome=="a_fixed300"][match(names(variants), variant), n_essential_rows]), collapse="\n"))
writeLines(findings, file.path(OUT, "findings_3b.md"))
cat("\nSaved stage3b_{lomo_path.csv/png, june_segment_counts.csv, june_split.csv}, findings_3b.md.\n")
cat("\n=== STOP: Stage 3b numbers complete. Findings-text amendments next (finalize_findings.R). ===\n")
