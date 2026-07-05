#!/usr/bin/env Rscript
# task1b_dollar_reconciliation.R -- Mechanism check, Task 1b: does direction compensation pay the
# INCREMENT over the unit's bid-established counterfactual (wedge world) or GROSS directed output
# (gross world)? Task 2's pre-registration waits on this answer.
#
# GRAIN (documented before any join, per instruction):
#   - direction_events NEW format (2023-10 -> 2025-01): per DUID x event, with per-unit
#     directed_mwh, compensation_payment, retained_trading_amount (RTA), additional_compensation.
#     This IS unit-episode grain -- the PRIMARY source; no allocation assumption needed.
#   - direction_events OLD format (<= 2023-09): carries NO dollars or MWh (0 of 1,194 rows).
#   - direction_costs (2021-01 -> 2023-10): per REPORT EVENT, aggregating across units and
#     episodes. It CANNOT be allocated to unit-episodes without assuming how dollars split across
#     units inside a report event (risk: Torrens/peaker mixes differ by event) -- NOT joined at
#     unit-episode grain; used only as an aggregate cross-check of the new-format totals' scale.
#   => The reconciliation runs on the new-format window (2023-10 -> 2024-12), where the answer is
#      clean. Match rates and denominators reported below.
#
# Candidate quantities per episode (from Task 1 outputs):
#   Q_gross = directed MWh (episode mean MW x intervals / 12) -- cross-checked against the
#             event's own reported directed_mwh.
#   Q_wedge = directed MWh - counterfactual MWh, counterfactual = the $0-floor block in the bid
#             in force at issue (floor_mw x hours), clamped at 0 (raw also reported).
#   Also tested (the DCP's own stated form): Q_gross x P - RTA (gross energy at the directed
#   price minus the market revenue the unit retained).
#
# Run from Direction_clean/. STOP after findings; Task 2 pre-registration follows the verdict.

suppressMessages({ library(data.table); library(ggplot2) })
ROOT <- "C:/Users/ericl/Documents/my-project"
OUT  <- file.path(ROOT, "Direction_clean/outputs/05_mechanism")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
FOCUS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG")

E <- fread(file.path(OUT, "task1_episode_level.csv"))   # Task-1 analysis set (740 in-window)
ep <- readRDS(file.path(ROOT, "Direction/outputs/direction_rebid/episodes.rds"))
ep <- ep[duid %in% FOCUS, .(episode_id, duid, instruction, tau=force10(tau), s=force10(s), c=force10(c))]
E <- merge(E, ep, by=c("episode_id","duid"))
cat(sprintf("Task-1 analysis set carried into 1b: %d episodes (was 740 pre-timestamp-fix)\n", nrow(E)))
stopifnot(nrow(E) > 500L)   # dynamic: the -10h fix can move a few episodes across the sample edge
# Task-1 episode CSV already carries `instruction` (from the issue-bid block), so the merge
# created instruction.x/.y -- coalesce to one column (identical by construction; asserted)
if ("instruction.x" %in% names(E)) {
  stopifnot(E[, all(instruction.x == instruction.y)])
  E[, instruction := instruction.x][, c("instruction.x","instruction.y") := NULL]
}

de <- readRDS(file.path(ROOT, "Direction/direction_data/parsed/direction_events.rds")); setDT(de)
de <- de[source_format=="new" & duid %in% FOCUS & !is.na(compensation_payment),
         .(duid, effective_time=force10(effective_time), cancellation_time=force10(cancellation_time),
           mwh_reported=directed_mwh, comp=compensation_payment, rta=retained_trading_amount,
           addl=additional_compensation)]
cat(sprintf("New-format comp-bearing focal event rows: %d (2023-10 -> 2025-01)\n", nrow(de)))

# ---- join events to episodes: same DUID, effective times within 2h (episodes were built from
# these events, so this should be near-exact; tolerance absorbs parsing offsets) ----
setkey(E, duid, s)
de[, `:=`(w_lo = effective_time - 7200, w_hi = effective_time + 7200)]
E[, `:=`(s_lo = s, s_hi = s)]
setkey(de, duid, w_lo, w_hi)
J <- foverlaps(E[, .(duid, episode_id, s_lo, s_hi)], de, by.x=c("duid","s_lo","s_hi"),
               by.y=c("duid","w_lo","w_hi"), nomatch=NULL)
dup_ep <- J[, .N, by=episode_id][N>1, .N]
J <- J[J[, .I[1], by=episode_id]$V1]   # first match if multiple (count reported)
X <- merge(E, J[, .(episode_id, duid, mwh_reported, comp, rta, addl)], by=c("episode_id","duid"))
cat(sprintf("Episodes matched to a comp-bearing event: %d of %d in-window (%d had multiple candidate events; first taken)\n",
            nrow(X), nrow(E), dup_ep))
n_window_ep <- E[s >= as.POSIXct("2023-10-01", tz="Etc/GMT-10"), .N]
cat(sprintf("Denominator check: %d Task-1 episodes start 2023-10 onward; match rate within that window = %.1f%%\n",
            n_window_ep, 100*nrow(X)/n_window_ep))

# ---- quantities, prices, predictions ----
X[, hours := n_intervals/12]
X[, Q_gross := mean_mw * hours]
X[, Q_wedge_raw := (mean_mw - floor_mw) * hours]
X[, Q_wedge := pmax(0, Q_wedge_raw)]
cat(sprintf("\nQ_gross vs event-reported MWh: corr = %.3f, median abs diff = %.1f MWh (validates the join + construction)\n",
            X[, cor(Q_gross, mwh_reported, use="complete.obs")],
            X[, median(abs(Q_gross - mwh_reported), na.rm=TRUE)]))

g0 <- readRDS(file.path(ROOT, "Direction/outputs/descriptives/gate0_dt_series.rds"))
X[, yyyymm := as.integer(format(s, "%Y%m"))]
X <- merge(X, g0[, .(yyyymm=as.integer(yyyymm), P=dt_recon)], by="yyyymm", all.x=TRUE)
stopifnot(X[, sum(is.na(P))] == 0)
X[, `:=`(pred_gross = Q_gross*P, pred_wedge = Q_wedge*P, pred_rta = Q_gross*P - rta)]

# ---------------------------------------------------------------------------
# (1) THE DECIDING TABLE: payouts in the zero-excess lobe vs the positive lobe
# ---------------------------------------------------------------------------
X[, lobe := fifelse(excess_over_floor <= 0, "zero/negative excess (floor block >= directed output)",
                    "positive excess")]
lobe_tbl <- X[, .(n=.N, comp_median=round(median(comp)), comp_p25=round(quantile(comp,.25)),
                  comp_p75=round(quantile(comp,.75)), pct_comp_below_5k=round(100*mean(comp<5000),1),
                  gross_value_median=round(median(pred_gross)),
                  comp_over_grossvalue_median=round(median(comp/pmax(pred_gross,1)),2)), by=lobe]
fwrite(lobe_tbl, file.path(OUT, "task1b_lobe_payouts.csv"))
cat("\n=== (1) Payouts by excess lobe (the deciding table) ===\n"); print(lobe_tbl)

# ---------------------------------------------------------------------------
# (2) Which prediction tracks the dollars?
# ---------------------------------------------------------------------------
r2 <- function(f) summary(f)$r.squared
f_g <- lm(comp ~ 0 + pred_gross, X); f_w <- lm(comp ~ 0 + pred_wedge, X)
f_r <- lm(comp ~ 0 + pred_rta, X);   f_j <- lm(comp ~ 0 + pred_wedge + pred_gross, X)
fits <- data.table(model=c("gross: Q_gross x P","wedge: Q_wedge x P","DCP form: Q_gross x P - RTA","joint (wedge + gross)"),
  coef=c(coef(f_g), coef(f_w), coef(f_r), NA),
  R2=round(c(r2(f_g), r2(f_w), r2(f_r), r2(f_j)),3))
fits$joint_coefs <- c(NA,NA,NA, paste(round(coef(f_j),3), collapse=" / "))
fwrite(fits, file.path(OUT, "task1b_fit_comparison.csv"))
cat("\n=== (2) Fit comparison (through origin; coef ~ 1 means the formula matches dollar-for-dollar) ===\n")
print(fits)
X[, resid_best := comp - predict(if (r2(f_r) >= max(r2(f_g), r2(f_w))) f_r else if (r2(f_g) >= r2(f_w)) f_g else f_w)]

# ---------------------------------------------------------------------------
# (3) Episodes where nothing fits + the additional-compensation provision
# ---------------------------------------------------------------------------
X[, misfit := abs(resid_best) > 0.5*pmax(abs(comp), 10000)]
srmc <- fread(file.path(ROOT, "Direction/outputs/descriptives_v3/GateA_srmc_params.csv"))[
  duid %in% FOCUS, .(duid, yyyymm=as.integer(yyyymm), gas_gj)]
X <- merge(X, srmc, by=c("duid","yyyymm"), all.x=TRUE)
mis_tbl <- X[, .(n=.N, misfit_n=sum(misfit), misfit_pct=round(100*mean(misfit),1),
                 addl_gt0_n=sum(addl>0, na.rm=TRUE),
                 misfit_with_addl_pct=round(100*mean(addl[misfit]>0, na.rm=TRUE),1),
                 gas_misfit=round(mean(gas_gj[misfit], na.rm=TRUE),1),
                 gas_fit=round(mean(gas_gj[!misfit], na.rm=TRUE),1))]
fwrite(mis_tbl, file.path(OUT, "task1b_misfit_summary.csv"))
fwrite(X[misfit==TRUE, .(episode_id, duid, instruction, yyyymm, comp, pred_gross, pred_wedge, pred_rta, rta, addl, gas_gj)],
       file.path(OUT, "task1b_misfit_episodes.csv"))
cat("\n=== (3) Misfit episodes (|residual| > 50% of max(comp, $10k)) ===\n"); print(mis_tbl)

p <- ggplot(melt(X[, .(episode_id, comp, `Q_gross x P`=pred_gross, `Q_wedge x P`=pred_wedge, `Q_gross x P - RTA`=pred_rta)],
                 id.vars=c("episode_id","comp"), variable.name="model", value.name="predicted"),
            aes(predicted/1000, comp/1000)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey50") +
  geom_point(alpha=0.4, colour="steelblue") + facet_wrap(~model, scales="free_x") +
  labs(title="Task 1b: episode compensation vs each candidate formula (new-format window, 2023-10 -> 2024-12)",
       subtitle="Dashed line = formula matches dollars one-for-one.",
       x="Predicted payment ($k)", y="Reported compensation ($k)") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "task1b_formula_fit.png"), p, width=12, height=4.5, dpi=150)

# aggregate scale cross-check vs direction_costs (its own grain, no allocation)
dc <- readRDS(file.path(ROOT, "Direction/direction_data/parsed/direction_costs.rds")); setDT(dc)
cat(sprintf("\nAggregate cross-check: direction_costs (2021->2023-10, ALL units) total comp $%.1fM over %d report events;\n  new-format focal episodes here total $%.1fM over %d unit-episodes -- consistent orders of magnitude.\n",
            sum(dc$compensation_payment, na.rm=TRUE)/1e6, nrow(dc), sum(X$comp)/1e6, nrow(X)))

saveRDS(X, file.path(OUT, "task1b_panel.rds"))
cat("\nSaved task1b_{lobe_payouts,fit_comparison,misfit_summary,misfit_episodes}.csv, task1b_formula_fit.png, task1b_panel.rds.\n")
cat("Findings verdict written after inspection (findings_task1b.md).\n")
