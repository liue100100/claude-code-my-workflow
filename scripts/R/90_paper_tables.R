# ==============================================================================
# 90_paper_tables.R — publication tables for the SA directions paper
#
# Reads ONLY existing verified outputs (no new estimation):
#   Direction_clean/outputs/03_rq1_essentiality/{rq1_core_results,rq1_wcb,rq1_robustness}.csv
#   Direction_clean/outputs/04_rq2_compensation_price/{rq2_results_full,rq2_wcb}.csv
#   Direction_clean/outputs/05_mechanism/{task9_results,task10_day_results}.csv
#   Direction/outputs/withhold_opportunity/stage4_did_results.csv
#
# Writes LaTeX table floats to output/tables/ (T1..T4), \input{} into
# manuscript/paper.tex sections.
#
# Run from repo root: Rscript scripts/R/90_paper_tables.R
# ==============================================================================

root <- normalizePath(".")
stopifnot(file.exists(file.path(root, "CLAUDE.MD")) || file.exists(file.path(root, "CLAUDE.md")))
dir.create(file.path(root, "output", "tables"), recursive = TRUE, showWarnings = FALSE)

dc  <- file.path(root, "Direction_clean", "outputs")
dw  <- file.path(root, "Direction", "outputs", "withhold_opportunity")
out <- file.path(root, "output", "tables")

fmt  <- function(x, d = 3) formatC(x, format = "f", digits = d)
star <- function(p) ifelse(p < .01, "^{***}", ifelse(p < .05, "^{**}", ifelse(p < .10, "^{*}", "")))
cell <- function(est, p, d = 3) paste0("$", fmt(est, d), star(p), "$")
se_  <- function(se, d = 3) paste0("(", fmt(se, d), ")")
wp_  <- function(p) paste0("[", fmt(p, 3), "]")

write_table <- function(lines, file) {
  # Shrink-to-width guard: wrap the whole threeparttable in adjustbox
  # (threeparttable's width measurement breaks if adjustbox sits inside it)
  lines <- sub("^(\\\\begin\\{threeparttable\\})", "\\\\begin{adjustbox}{max width=\\\\textwidth}\n\\1", lines)
  lines <- sub("^(\\\\end\\{threeparttable\\})", "\\1\n\\\\end{adjustbox}", lines)
  writeLines(lines, file.path(out, file))
  cat("wrote", file.path("output/tables", file), "\n")
}

# ------------------------------------------------------------------------------
# T1 — RQ1: essentiality and cheap-capacity share (pooled M1–M3 + heterogeneity)
# ------------------------------------------------------------------------------
core <- read.csv(file.path(dc, "03_rq1_essentiality", "rq1_core_results.csv"))
wcb1 <- read.csv(file.path(dc, "03_rq1_essentiality", "rq1_wcb.csv"))
rob  <- read.csv(file.path(dc, "03_rq1_essentiality", "rq1_robustness.csv"))

g1 <- function(o, m, t) core[core$outcome == o & core$model == m & core$term == t, ]
w1 <- function(o, m) wcb1[wcb1$outcome == o & wcb1$model == m & wcb1$weights == "rademacher", ]
gr <- function(o, m, r) rob[rob$outcome == o & rob$model == m & rob$row == r, ]

t1_ess_row <- function(field) {
  vapply(c("M1", "M2", "M3"), function(m) {
    a <- g1("a_fixed300", m, "essentialTRUE"); b <- g1("b_2xSRMC", m, "essentialTRUE")
    wa <- w1("a_fixed300", m); wb <- w1("b_2xSRMC", m)
    switch(field,
      est = paste(cell(a$estimate, a$p.value), "&", cell(b$estimate, b$p.value)),
      se  = paste(se_(a$std.error), "&", se_(b$std.error)),
      wcb = paste(wp_(wa$wcb_p), "&", wp_(wb$wcb_p)))
  }, character(1))
}
sat_a <- g1("a_fixed300", "M3", "saturatedTRUE"); sat_b <- g1("b_2xSRMC", "M3", "saturatedTRUE")
tor_a <- gr("a_fixed300", "M3", "Torrens only");  tor_b <- gr("b_2xSRMC", "M3", "Torrens only")
ppc_a <- gr("a_fixed300", "M3", "PPCCGT only (no unit FE possible)")
ppc_b <- gr("b_2xSRMC", "M3", "PPCCGT only (no unit FE possible)")
n_pool <- format(unique(core$nobs), big.mark = ",")

t1 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{RQ1: Essentiality and the cheap-capacity share}",
"\\label{tab:rq1}",
"\\begin{threeparttable}",
"\\begin{tabular}{lcccccc}",
"\\toprule",
" & \\multicolumn{2}{c}{M1} & \\multicolumn{2}{c}{M2} & \\multicolumn{2}{c}{M3} \\\\",
"\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
" & Fixed \\$300 & 2$\\times$SRMC & Fixed \\$300 & 2$\\times$SRMC & Fixed \\$300 & 2$\\times$SRMC \\\\",
"\\midrule",
"\\multicolumn{7}{l}{\\emph{Panel A: pooled (four focal units)}} \\\\",
paste("Essential &", paste(t1_ess_row("est"), collapse = " & "), "\\\\"),
paste(" &", paste(t1_ess_row("se"), collapse = " & "), "\\\\"),
paste(" &", paste(t1_ess_row("wcb"), collapse = " & "), "\\\\"),
paste0("Saturated (slope $=0$) & & & & & ", cell(sat_a$estimate, sat_a$p.value), " & ", cell(sat_b$estimate, sat_b$p.value), " \\\\"),
paste0(" & & & & & ", se_(sat_a$std.error), " & ", se_(sat_b$std.error), " \\\\"),
"\\midrule",
"\\multicolumn{7}{l}{\\emph{Panel B: heterogeneity (M3 specification)}} \\\\",
paste0("Essential, Torrens Island B only & & & & & ", cell(tor_a$estimate, tor_a$p.value), " & ", cell(tor_b$estimate, tor_b$p.value), " \\\\"),
paste0(" & & & & & ", se_(tor_a$std.error), " & ", se_(tor_b$std.error), " \\\\"),
paste0("Essential, Pelican Point only\\tnote{a} & & & & & ", cell(ppc_a$estimate, ppc_a$p.value), " & ", cell(ppc_b$estimate, ppc_b$p.value), " \\\\"),
paste0(" & & & & & ", se_(ppc_a$std.error), " & ", se_(ppc_b$std.error), " \\\\"),
"\\midrule",
paste0("Observations (pooled) & \\multicolumn{6}{c}{", n_pool, "} \\\\"),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item Outcome: share of registered capacity offered below the cheap threshold (fixed \\$300/MWh or 2$\\times$ engineering SRMC), 5-minute unit--interval panel, 2022--2024. M1 adds demand, non-synchronous supply, SRMC, and price controls; M2 adds the residual-demand slope; M3 adds the saturated (zero-slope) indicator. Analytic standard errors clustered by month in parentheses; wild cluster bootstrap $p$-values (Rademacher, $R=999$, 35 df) in brackets for the essentiality coefficient. Panel B re-estimates M3 on the Torrens Island B and Pelican Point subsamples.",
"\\item[a] The Pelican Point coefficient is not robust: it flips sign when October 2023 is dropped (leave-one-month-out, Section~\\ref{sec:robustness}) and is withdrawn as a finding.",
"\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$ (analytic).",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
write_table(t1, "T1_rq1.tex")

# ------------------------------------------------------------------------------
# T2 — RQ2: compensation-price dose response (headline)
# ------------------------------------------------------------------------------
rq2  <- read.csv(file.path(dc, "04_rq2_compensation_price", "rq2_results_full.csv"))
wcb2 <- read.csv(file.path(dc, "04_rq2_compensation_price", "rq2_wcb.csv"))

samples <- c("BASE: exclude suspension window only",
             "(i) exclude all June 2022",
             "(ii) include window at APC $300",
             "(iii) base minus pre-suspension June")
slab <- c("Base (exclude June-2022 suspension window)",
          "(i) Exclude all June 2022",
          "(ii) Include window at APC \\$300",
          "(iii) Base minus pre-suspension June")

t2_rows <- unlist(lapply(seq_along(samples), function(i) {
  a <- rq2[rq2$sample == samples[i] & rq2$outcome == "a_fixed300" & rq2$term == "essentialTRUE:comp_price_100", ]
  b <- rq2[rq2$sample == samples[i] & rq2$outcome == "b_2xSRMC"   & rq2$term == "essentialTRUE:comp_price_100", ]
  c(paste0(slab[i], " & ", cell(a$estimate, a$p.value), " & ", cell(b$estimate, b$p.value),
           " & ", format(a$nobs, big.mark = ","), " \\\\"),
    paste0(" & ", se_(a$std.error), " & ", se_(b$std.error), " & \\\\"))
}))
me_a <- rq2[rq2$sample == samples[1] & rq2$outcome == "a_fixed300" & rq2$term == "essentialTRUE", ]
me_b <- rq2[rq2$sample == samples[1] & rq2$outcome == "b_2xSRMC"   & rq2$term == "essentialTRUE", ]
t2_rows <- c(t2_rows,
  "\\midrule",
  paste0("Essential (main effect, base sample) & ", cell(me_a$estimate, me_a$p.value),
         " & ", cell(me_b$estimate, me_b$p.value), " & \\\\"),
  paste0(" & ", se_(me_a$std.error), " & ", se_(me_b$std.error), " & \\\\"))
wr <- function(o, w) wcb2[wcb2$outcome == o & wcb2$weights == w, "wcb_p"]

t2 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{RQ2: The essential-interval withholding gap widens with the compensation price}",
"\\label{tab:rq2}",
"\\begin{threeparttable}",
"\\begin{tabular}{lccc}",
"\\toprule",
" & \\multicolumn{2}{c}{Essential $\\times$ compensation price (\\$100/MWh)} & \\\\",
"\\cmidrule(lr){2-3}",
"Sample treatment of June 2022 & Fixed \\$300 & 2$\\times$SRMC & $N$ \\\\",
"\\midrule",
t2_rows,
"\\midrule",
paste0("WCB $p$ (base row): Rademacher & ", fmt(wr("a_fixed300", "rademacher"), 3), " & ", fmt(wr("b_2xSRMC", "rademacher"), 3), " & \\\\"),
paste0("\\phantom{WCB $p$ (base row):} Webb & ", fmt(wr("a_fixed300", "webb"), 3), " & ", fmt(wr("b_2xSRMC", "webb"), 3), " & \\\\"),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item Coefficient on essential $\\times$ compensation price (per \\$100/MWh) on the CEM-matched sample (unit $\\times$ month $\\times$ non-synchronous quintile $\\times$ hour block $\\times$ competition bin). A coefficient of $-0.051$ means the essential-vs-matched gap in the cheap-capacity share widens by 5.1 percentage points of registered capacity per \\$100/MWh. Analytic standard errors clustered by month in parentheses; specification and controls as in Table~\\ref{tab:rq1} (M3). Wild cluster bootstrap $p$-values ($R=999$, 20 df) for the base sample. The interpretation of this test, including the reading of a null, was committed in the project record before estimation.",
"\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$ (analytic).",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
write_table(t2, "T2_rq2.tex")

# ------------------------------------------------------------------------------
# T3 — Mechanism: exit act (Task 9) and floor pricing (Task 10), N-1 essentiality
# ------------------------------------------------------------------------------
t9  <- read.csv(file.path(dc, "05_mechanism", "task9_results.csv"))
t10 <- read.csv(file.path(dc, "05_mechanism", "task10_day_results.csv"))

p9  <- function(m, t, f) { r <- t9[t9$model == m & t9$term == t, ]; if (nrow(r) == 0) return(""); switch(f, est = cell(r$estimate, r$p.value), se = se_(r$std.error)) }
p10 <- function(m, t, f) { r <- t10[t10$model == m & t10$term == t, ]; if (nrow(r) == 0) return(""); switch(f, est = cell(r$estimate, r$p.value, 1), se = se_(r$std.error, 1)) }

t3 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{Mechanism: the exit act is state-dependent; floor pricing is not}",
"\\label{tab:mechanism}",
"\\begin{threeparttable}",
"\\begin{tabular}{lcccc}",
"\\toprule",
" & \\multicolumn{3}{c}{Exit act (evening offered share)} & Floor price (\\$/MWh) \\\\",
"\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}",
" & (1) & (2) & (3) & (4) \\\\",
"\\midrule",
paste0("Essential ($N{-}1$) & ", p9("no loss control", "ess_n1TRUE", "est"), " & ", p9("with loss control", "ess_n1TRUE", "est"), " & & ", p10("no loss control", "ess_n1TRUE", "est"), " \\\\"),
paste0(" & ", p9("no loss control", "ess_n1TRUE", "se"), " & ", p9("with loss control", "ess_n1TRUE", "se"), " & & ", p10("no loss control", "ess_n1TRUE", "se"), " \\\\"),
paste0("Essential ($N{-}1$) $\\times$ expected loss & & ", p9("with loss control", "ess_n1TRUE:exp_loss", "est"), " & & \\\\"),
paste0(" & & ", p9("with loss control", "ess_n1TRUE:exp_loss", "se"), " & & \\\\"),
paste0("$N{-}1$ only (not $N{-}0$) & & & ", p9("three-tier (N-0 context only)", "n1onlyTRUE", "est"), " & \\\\"),
paste0(" & & & ", p9("three-tier (N-0 context only)", "n1onlyTRUE", "se"), " & \\\\"),
paste0("Directly pivotal ($N{-}0$, \\textit{pex}) & & & ", p9("three-tier (N-0 context only)", "ess_pexTRUE", "est"), " & \\\\"),
paste0(" & & & ", p9("three-tier (N-0 context only)", "ess_pexTRUE", "se"), " & \\\\"),
"\\midrule",
paste0("Observations & ", t9$nobs[1], " & ", t9$nobs[8], " & ", t9$nobs[16], " & ", t10$nobs[1], " \\\\"),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item Day-level regressions on clean days (bids formed outside direction exposure), $N{-}1$ essentiality flag (Task~7 construction). Columns (1)--(3): outcome is the evening offered share (exit act); column (2) adds the expected foregone-loss control and its interaction; column (3) splits essentiality into tiers. Column (4): outcome is the offered floor price. Wild-cluster-bootstrap-based inference in the source analysis confirms column (1) at $p=0.017$. Standard errors clustered by month in parentheses. Both tests' interpretations were committed in the project record before estimation; the $N{-}1$ flag construction is Appendix~\\ref{app:n1}.",
"\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$ (analytic).",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
write_table(t3, "T3_mechanism.tex")

# ------------------------------------------------------------------------------
# T4 — Appendix: earlier withhold-opportunity design (null)
# ------------------------------------------------------------------------------
s4 <- read.csv(file.path(dw, "stage4_did_results.csv"))

units <- c("pooled", "TORRB2", "TORRB3", "TORRB4", "PPCCGT")
ulab  <- c("Pooled", "TORRB2", "TORRB3", "TORRB4", "PPCCGT\\tnote{a}")
p4 <- function(u, v, f) {
  term <- paste0(v, ":oppTRUE")
  r <- s4[s4$scope == u & s4$dt_variant == v & s4$outcome == "withheld_LPM" & s4$term == term, ]
  if (nrow(r) == 0) return("")
  switch(f, est = cell(r$estimate, r$p.value, 5), se = se_(r$std.error, 5), n = format(r$nobs, big.mark = ","))
}
t4_rows <- unlist(lapply(seq_along(units), function(i) c(
  paste0(ulab[i], " & ", p4(units[i], "dt", "est"), " & ", p4(units[i], "dt_robust", "est"),
         " & ", p4(units[i], "dt", "n"), " \\\\"),
  paste0(" & ", p4(units[i], "dt", "se"), " & ", p4(units[i], "dt_robust", "se"), " & \\\\"))))

t4 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{Appendix: earlier opportunity-set design --- $d_t \\times$ opportunity interaction (withheld indicator)}",
"\\label{tab:withhold_opp}",
"\\begin{threeparttable}",
"\\begin{tabular}{lccc}",
"\\toprule",
" & $d_t \\times$ opp & $d_t^{robust} \\times$ opp & $N$ \\\\",
"\\midrule",
t4_rows,
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item Linear probability model: withheld $\\sim d_t \\times$ opportunity $+$ SRMC with unit, non-synchronous-quintile, and hour-block fixed effects on the CEM-matched sample, clustered by month. $d_t^{robust}$ imputes the June-2022 compensation-price gap at \\$164.38/MWh. This earlier, coarser design is superseded by the specification of Section~\\ref{sec:design}; it is reported for completeness.",
"\\item[a] PPCCGT is underpowered in this design (few opportunity intervals); estimates are unstable.",
"\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$ (analytic).",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
write_table(t4, "T4_withhold_opportunity.tex")

# ------------------------------------------------------------------------------
# T5 — Round 2: the floor-reach decomposition + inference battery (Tests 1, 3a, 3d)
# ------------------------------------------------------------------------------
r2 <- file.path(root, "Direction_clean", "outputs", "06_round2")
t1i <- read.csv(file.path(r2, "test1_interaction.csv"))
t1w <- read.csv(file.path(r2, "test1_wcb.csv"))
t3a <- read.csv(file.path(r2, "test3a_result.csv"))
t3d <- read.csv(file.path(r2, "test3d_inference.csv"))

base_lab <- "BASE: exclude suspension window only"
g5  <- function(o) t1i[t1i$sample == base_lab & t1i$outcome == o, ]
rng5 <- function(o) { x <- t1i[t1i$outcome == o, ]; paste0("$", fmt(min(x$estimate)), "$ to $", fmt(max(x$estimate)), "$") }
w5  <- function(o) t1w[t1w$outcome == o & t1w$weights == "rademacher", "wcb_p"]
re  <- g5("reach_a"); ia <- g5("intensive_a"); ib <- g5("intensive_b")

t5 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{Decomposing the dose response: eligibility versus intensive margin}",
"\\label{tab:decomposition}",
"\\begin{threeparttable}",
"\\begin{tabular}{lcc}",
"\\toprule",
" & Floor within reach & Offered depth, given reach \\\\",
" & (eligibility margin) & (intensive margin) \\\\",
"\\midrule",
paste0("Essential $\\times$ compensation price (\\$100/MWh) & ", cell(re$estimate, re$p.value),
       " & ", cell(ia$estimate, ia$p.value), " \\\\"),
paste0(" & ", se_(re$std.error), " & ", se_(ia$std.error), " \\\\"),
paste0("Wild-cluster-bootstrap $p$ (Rademacher) & ", fmt(w5("reach_a"), 3), " & ", fmt(w5("intensive_a"), 3), " \\\\"),
paste0("Range across June-2022 treatments & ", rng5("reach_a"), " & ", rng5("intensive_a"), " \\\\"),
paste0("Randomization-inference $p$ (999 month-permutations) & ", fmt(t3d$p[1], 3), " & --- \\\\"),
paste0("Month-grain WLS slope (19 months, HC1 $p$) & $", fmt(t3a$slope), "$ (", fmt(t3a$p, 4), ") & --- \\\\"),
paste0("Observations (base sample) & ", format(re$nobs, big.mark = ","), " & ", format(ia$nobs, big.mark = ","), " \\\\"),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item The eligibility margin is an indicator for the unit's minimum-stable quantum (its frozen floor: 40~MW per Torrens unit) being offered within dispatch's reach; it is identical under both cheap thresholds because the floor block, when offered, sits at the $-\\$1{,}000$ band. The intensive margin is the cheap-capacity share on the subsample with the floor in reach (a decomposition aid: it conditions on an outcome). Specification, matching, controls, clustering, and June-2022 treatments exactly as in Table~\\ref{tab:rq2}. The cost-indexed intensive margin behaves identically (base $", fmt(ib$estimate), "$, $p=", fmt(ib$p.value, 2), "$). Interpretations for all cells were committed in the project record before estimation.",
"\\item $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$ (analytic).",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
write_table(t5, "T5_decomposition.tex")

cat("\nAll tables written.\n")
