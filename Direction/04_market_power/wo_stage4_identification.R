#!/usr/bin/env Rscript
# wo_stage4_identification.R  --  Stage 4 of the withhold-to-be-directed design.
#
# (i) Consistency count (DESCRIPTIVE, not identifying -- carries Stage 2's own guardrail forward):
#     withheld% among opportunity vs. matched-comparison intervals, across the Stage-3 threshold
#     sweep. Torrens's near-universal opportunity-withholding is expected to look similar on the
#     comparison side too (competitive baseline already ~60-65%, stage1b_diagnostics.md [F6a]) --
#     if so this section is NOT the headline result.
#
# (ii) THE IDENTIFYING TEST -- does withholding sort on the predetermined prize d_t, and is that
#     sort SPECIFIC to opportunity intervals vs. the CEM-matched non-opportunity comparison set?
#         withheld ~ dt * opp + srmc | duid + nsq + hour_block     (LPM, headline)
#         cheap300 ~ dt * opp + srmc | duid + nsq + hour_block     (continuous, robustness)
#     Run on the matched sample (matched==TRUE, i.e. opp==TRUE | comparison==TRUE) four ways:
#     pooled TORRB2/3/4+PPCCGT, and each of TORRB2/TORRB3/TORRB4/PPCCGT separately; both the base
#     dt (202206 dropped, NA) and dt_robust (202206 imputed) variants. OSB-AG is DESCRIPTIVE ONLY
#     (n_opp=18 < MIN_TEST_N) -- never enters a regression.
#     Inference: cluster by month (vcov=~yyyymm), matching the project's standing feols convention
#     (pivotality_analysis.R). Wild-cluster bootstrap remains an OPEN project-wide item ([G8]) --
#     flagged, not resolved or silently ignored, here.
#
# Run from Direction/. Outputs to outputs/withhold_opportunity/.

suppressMessages({ library(data.table); library(fixest); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/withhold_opportunity"

FOCUS_TEST <- c("TORRB2","TORRB3","TORRB4","PPCCGT")   # regression-eligible (OSB-AG excluded, n_opp<30)
SWEEP  <- c(80,100,120,150,170)
TROUGH <- c(TORRB2=170, TORRB3=131, TORRB4=171, PPCCGT=180, `OSB-AG`=90)

X <- readRDS(file.path(OUT, "stage3_panel.rds"))
M <- X[matched==TRUE]   # opp==TRUE | comparison==TRUE, common-support strata only
cat(sprintf("Loaded stage3_panel.rds: %d rows | matched (opp|comparison): %d\n", nrow(X), nrow(M)))

# ---------------------------------------------------------------------------
# (i) Consistency count -- opp vs comparison, across the threshold sweep (DESCRIPTIVE)
# ---------------------------------------------------------------------------
grp_pct <- function(d, thr) {
  d[, .(n=.N, withheld_pct=round(100*mean(cheap300 < thr),1)), by=.(group=fifelse(opp,"opportunity","comparison"))]
}
consist <- rbindlist(lapply(names(TROUGH), function(u) {
  d <- M[duid==u]
  rbindlist(c(
    lapply(SWEEP, function(t) cbind(duid=u, threshold=t, label="sweep", grp_pct(d, t))),
    list(cbind(duid=u, threshold=TROUGH[[u]], label="trough_default", grp_pct(d, TROUGH[[u]])))
  ))
}))
setorder(consist, duid, threshold, group)
fwrite(consist, file.path(OUT, "stage4_consistency.csv"))
cat("\n=== STAGE 4(i): withheld% opportunity vs. matched comparison (DESCRIPTIVE, not identifying) ===\n")
print(consist[label=="trough_default"])

# ---------------------------------------------------------------------------
# (ii) Identifying test -- dt x opp on the matched sample
# ---------------------------------------------------------------------------
tidy_feols <- function(f, scope, dtvar, outcome) {
  ct <- as.data.table(summary(f)$coeftable, keep.rownames = "term")
  setnames(ct, c("term","estimate","std.error","statistic","p.value"))
  ct[, `:=`(scope=scope, dt_variant=dtvar, outcome=outcome, nobs=nobs(f))]
  ct[]
}

run_one <- function(data, dtcol, scope_label, outcome_col, outcome_label) {
  fml <- as.formula(sprintf("%s ~ %s*opp + srmc | %s", outcome_col, dtcol,
                             if (scope_label=="pooled") "duid + nsq + hour_block" else "nsq + hour_block"))
  d <- data[!is.na(get(dtcol)) & is.finite(get(dtcol))]
  f <- feols(fml, d, vcov = ~yyyymm)
  tidy_feols(f, scope_label, dtcol, outcome_label)
}

scopes <- c("pooled", FOCUS_TEST)
results <- rbindlist(lapply(scopes, function(sc) {
  d <- if (sc=="pooled") M[duid %in% FOCUS_TEST] else M[duid==sc]
  rbindlist(lapply(c("dt","dt_robust"), function(dtcol) {
    rbindlist(list(
      run_one(d, dtcol, sc, "withheld", "withheld_LPM"),
      run_one(d, dtcol, sc, "cheap300", "cheap300_continuous")
    ))
  }))
}))
fwrite(results, file.path(OUT, "stage4_did_results.csv"))

headline <- results[grepl(":", term) & outcome=="withheld_LPM"]
cat("\n=== STAGE 4(ii): headline dt:opp interaction, withheld ~ dt*opp + srmc | FE, cluster month ===\n")
print(headline[, .(scope, dt_variant, term, estimate, std.error, statistic, p.value, nobs)])

# ---------------------------------------------------------------------------
# Figure: binned withheld share vs. dt, opportunity vs. comparison, per unit
# ---------------------------------------------------------------------------
Mf <- M[duid %in% FOCUS_TEST & !is.na(dt)]
Mf[, dt_bin := cut(dt, quantile(dt, seq(0,1,0.2), na.rm=TRUE), include.lowest=TRUE)]
bins <- Mf[, .(withheld_pct=100*mean(withheld), dt_mid=mean(dt), n=.N),
           by=.(duid, group=fifelse(opp,"Opportunity","Comparison"), dt_bin)]
bins[, duid := factor(duid, levels=FOCUS_TEST)]
p <- ggplot(bins, aes(dt_mid, withheld_pct, colour=group)) +
  geom_line(linewidth=0.8) + geom_point(aes(size=n)) +
  facet_wrap(~duid, scales="free_x") +
  labs(title="Stage 4: withheld share vs. d_t (predetermined prize), opportunity vs. matched comparison",
       subtitle="Quintile bins of d_t (base-case, 202206 excluded). Diverging lines = the identifying signal.",
       x="d_t ($/MWh, quintile bin mean)", y="Share of intervals withheld (%)", size="n intervals") +
  theme_bw(base_size=10)
ggsave(file.path(OUT, "stage4_dt_sort.png"), p, width=11, height=7, dpi=150)

# ---------------------------------------------------------------------------
# Findings note
# ---------------------------------------------------------------------------
hl_pooled_base <- headline[scope=="pooled" & dt_variant=="dt"]
hl_pooled_rob  <- headline[scope=="pooled" & dt_variant=="dt_robust"]
per_unit_lines <- paste(sprintf("- **%s** (base dt): coef=%.3g, se=%.3g, t=%.2f, p=%.3f, n=%d",
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", scope],
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", estimate],
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", std.error],
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", statistic],
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", p.value],
  headline[scope %in% FOCUS_TEST & dt_variant=="dt", nobs]), collapse="\n")

findings <- sprintf(
"# Stage 4 findings -- consistency count + the identifying dt-sort test

Script: `04_market_power/wo_stage4_identification.R`. Matched sample (opp|comparison, CEM strata
with common support): %d rows.

## (i) Consistency count -- DESCRIPTIVE ONLY (see `stage4_consistency.csv`)
Withheld%% at the trough-default threshold, opportunity vs. matched comparison, per unit. Per the
Stage-2 guardrail this is NOT the identifying result -- Torrens's baseline competitive withholding
rate is already ~60-65%% ([F6a]), so a high withheld%% on opportunity intervals alone cannot
distinguish market power from directions-seeking.

## (ii) THE IDENTIFYING TEST (see `stage4_did_results.csv`, `stage4_dt_sort.png`)
`withheld ~ dt*opp + srmc | duid + nsq + hour_block`, matched sample, clustered by month (35
clusters; wild-cluster bootstrap remains an OPEN project-wide item [G8], not resolved here).

**Pooled TORRB2/3/4+PPCCGT (base dt, 202206 excluded):** dt:opp coef = %.3g (se %.3g, t %.2f,
p %.3f, n=%d).
**Pooled, dt_robust (202206 imputed at \\$164.38/MWh):** dt:opp coef = %.3g (se %.3g, t %.2f,
p %.3f, n=%d).

**Per-unit (base dt):**
%s

## Reading
[TO BE INTERPRETED BY THE USER -- sign/significance stated plainly above, framing (headline vs.
robustness vs. footnote) deferred, same as the F3a decision this session.] A positive, significant
dt:opp coefficient says withholding intensifies with the predetermined prize *specifically* on
opportunity intervals relative to the matched comparison set -- the revealed-preference complement
to the `rq_and_id.md` Design-2 triple-diff. A null or negative coefficient says the opportunity-set
withholding (part (i)) is driven by pivotality/market power alone, not a d_t-specific channel.

## Caveats carried forward
- Look-ahead in state variables (Threat B, `stage0_inventory.md` §5) is unresolved -- `pex`/
  `nonsync`/`short` are realised-state proxies, not bid-time forecasts.
- OSB-AG excluded from all regressions (n_opp=18 < MIN_TEST_N=30) -- descriptive only, see
  Stage 2/3 outputs.
- Threshold sensitivity (Stage 3(A)) shows the withheld%% classification for TORRB is fairly stable
  across the sweep (all >=94%%), so the classification choice is not doing the work in part (i);
  PPCCGT and OSB-AG are more threshold-sensitive and should be read with that in mind.
", nrow(M),
  hl_pooled_base$estimate, hl_pooled_base$std.error, hl_pooled_base$statistic, hl_pooled_base$p.value, hl_pooled_base$nobs,
  hl_pooled_rob$estimate,  hl_pooled_rob$std.error,  hl_pooled_rob$statistic,  hl_pooled_rob$p.value,  hl_pooled_rob$nobs,
  per_unit_lines)
writeLines(findings, file.path(OUT, "stage4_findings.md"))
cat("\nSaved stage4_consistency.csv, stage4_did_results.csv, stage4_dt_sort.png, stage4_findings.md.\n")
