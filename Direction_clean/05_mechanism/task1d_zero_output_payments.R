#!/usr/bin/env Rscript
# task1d_zero_output_payments.R -- Task 1d: the 35 episodes directed with ~zero output but
# material payment. Do the dollars scale like cost reimbursements (additional-compensation
# channel; duration/starts/fuel) or like output payments (MWh x directed price)?
#
# Decision rule FIXED in task2_preregistration.md (committed 405ef65): set = the 35 Task-1c
# capped survivors (window_excess_capped_mwh <= 0). A shape "fits" if its single-regressor
# through-origin R^2 >= 0.6 OR its channel carries >= 60% of total dollars. Neither fits ->
# flagged, stopped, no invented explanations. Issued-then-cancelled checked from event times +
# whether the unit ever synchronised (INITIALMW > 1) inside the window.
#
# Run from my-project root. One table, one findings file. STOP after.

suppressMessages({ library(data.table) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }

X <- readRDS(file.path(OUT, "task1b_panel.rds"))
X[, `:=`(s=force10(s), c=force10(c))]
A <- fread(file.path(OUT, "task1c_a_window_counterfactual.csv"))
Z <- merge(X, A[, .(episode_id, window_output_mwh, window_hours, window_excess_capped_mwh)], by="episode_id")
Z <- Z[window_excess_capped_mwh <= 0]
stopifnot(nrow(Z) == 35L)
cat(sprintf("Set: %d capped-survivor episodes. Output: median %.1f MWh (p75 %.1f); payment: median $%s (p25 $%s, p75 $%s); total $%.2fM\n",
            nrow(Z), Z[, median(window_output_mwh)], Z[, quantile(window_output_mwh,.75)],
            format(round(Z[, median(comp)]), big.mark=","), format(round(Z[, quantile(comp,.25)]), big.mark=","),
            format(round(Z[, quantile(comp,.75)]), big.mark=","), Z[, sum(comp)]/1e6))

# never-synchronised + issued-then-cancelled checks (dispatch from the Task-1c cache)
cc <- readRDS(file.path(OUT, "_task1c_cache.rds")); DL <- cc$DL; rm(cc)
sync <- rbindlist(lapply(seq_len(nrow(Z)), function(j) {
  e <- Z[j]
  d <- DL[DUID == e$duid & idt > e$s & idt <= e$c]
  data.table(episode_id = e$episode_id,
             ever_sync = d[, any(INITIALMW > 1)],
             ever_cleared = d[, any(TOTALCLEARED > 1)])
}))
Z <- merge(Z, sync, by="episode_id")

# payment shapes (through-origin, per the committed rule)
Z[, pred_energy := mwh_reported * P]              # output-payment shape (event-reported MWh)
Z[, pred_energy_computed := window_output_mwh * P]
r2 <- function(f) summary(f)$r.squared
f_energy  <- lm(comp ~ 0 + pred_energy, Z)
f_energy2 <- lm(comp ~ 0 + pred_energy_computed, Z)
f_hours   <- lm(comp ~ 0 + window_hours, Z)       # flat per-hour reimbursement shape
f_addl    <- lm(comp ~ 0 + addl, Z)               # dollars tracking the additional-comp channel
addl_share_total <- Z[, sum(addl, na.rm=TRUE)/sum(comp)]
tbl <- data.table(
  shape = c("output payment: event MWh x directed price",
            "output payment: computed window MWh x price",
            "cost shape: flat $/hour of direction",
            "cost channel: additional_compensation"),
  coef  = c(coef(f_energy), coef(f_energy2), coef(f_hours), coef(f_addl)),
  R2    = round(c(r2(f_energy), r2(f_energy2), r2(f_hours), r2(f_addl)), 3),
  share_of_dollars = c(Z[, sum(pred_energy, na.rm=TRUE)/sum(comp)],
                       Z[, sum(pred_energy_computed)/sum(comp)],
                       NA, addl_share_total))
tbl[, share_of_dollars := round(share_of_dollars, 3)]
fwrite(tbl, file.path(OUT, "task1d_payment_shapes.csv"))
cat("\n=== Payment-shape table (through-origin fits; rule: fits if R2>=0.6 or channel>=60% of dollars) ===\n")
print(tbl)
cat(sprintf("\nPer-episode additional-comp share of payment: median %.2f, p25 %.2f, p75 %.2f; episodes with addl>50%% of comp: %d/35\n",
            Z[, median(addl/comp, na.rm=TRUE)], Z[, quantile(addl/comp, .25, na.rm=TRUE)],
            Z[, quantile(addl/comp, .75, na.rm=TRUE)], Z[addl/comp > .5, .N]))
cat(sprintf("RTA (retained trading amount): median $%s; episodes with rta > 0: %d/35\n",
            format(round(Z[, median(rta, na.rm=TRUE)]), big.mark=","), Z[rta > 0, .N]))
cat(sprintf("\nNever synchronised in window (INITIALMW never >1): %d/35 | never cleared >1 MW: %d/35 | window < 2h: %d/35\n",
            Z[ever_sync==FALSE, .N], Z[ever_cleared==FALSE, .N], Z[window_hours < 2, .N]))
cat("By unit:\n"); print(Z[, .(n=.N, comp_median=round(median(comp)), out_median=round(median(window_output_mwh),1),
                               mwh_reported_median=round(median(mwh_reported, na.rm=TRUE),1),
                               never_sync=sum(!ever_sync)), by=duid][order(-n)])
cat("\nNB compare event-reported MWh vs computed window MWh (grain mismatch diagnostic):\n")
print(Z[, .(episode_id, duid, window_hours=round(window_hours,1), window_output_mwh=round(window_output_mwh,1),
            mwh_reported=round(mwh_reported,1), comp=round(comp), addl=round(addl), rta=round(rta))][order(-comp)][1:12])
fwrite(Z[, .(episode_id, duid, s, c, window_hours, window_output_mwh, mwh_reported, comp, addl, rta,
             P, gas_gj, ever_sync, ever_cleared)], file.path(OUT, "task1d_episode_table.csv"))
cat("\nSaved task1d_{payment_shapes,episode_table}.csv. Findings written after inspection.\n")
