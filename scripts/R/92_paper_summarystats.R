# ==============================================================================
# 92_paper_summarystats.R — T0 summary-statistics table for the SA directions paper
# Reads the (large) verified panels; kept separate from 90_paper_tables.R for speed.
# Run from repo root: Rscript scripts/R/92_paper_summarystats.R
# ==============================================================================
suppressPackageStartupMessages(library(data.table))

root <- normalizePath(".")
out  <- file.path(root, "output", "tables")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

O <- readRDS(file.path(root, "Direction_clean/outputs/01_outcome_withholding/outcome_panel.rds"))
setDT(O)
rc <- fread(file.path(root, "Direction_clean/outputs/00_inventory/focal_unit_registered_capacity.csv"))
rc <- rc[, .(DUID = duid, reg_cap = reg_cap_mw)]

S <- O[, .(
  n_intervals    = .N,
  reg_share_mean = round(mean(cheap_a_share), 3),
  pct_zero_avail = round(100 * mean(MAXAVAIL == 0), 1),
  pct_share_lt10 = round(100 * mean(cheap_a_share < 0.10), 1),
  pct_essential  = round(100 * mean(essential, na.rm = TRUE), 2)
), by = DUID]
S <- merge(S, rc[, .(DUID, reg_cap)], by = "DUID", all.x = TRUE)
ordu <- c("TORRB2", "TORRB3", "TORRB4", "PPCCGT", "OSB-AG")
S <- S[match(ordu, DUID)]

fmtn <- function(x) format(x, big.mark = ",")
rows <- S[, sprintf("%s & %s & %s & %.3f & %.1f & %.1f & %.2f \\\\",
                    DUID, fmtn(reg_cap), fmtn(n_intervals), reg_share_mean,
                    pct_zero_avail, pct_share_lt10, pct_essential)]

t0 <- c(
"\\begin{table}[!htbp]\\centering",
"\\caption{Summary statistics, five-minute unit--interval panel, 2022--2024}",
"\\label{tab:sumstats}",
"\\begin{adjustbox}{max width=\\textwidth}",
"\\begin{threeparttable}",
"\\begin{tabular}{lcccccc}",
"\\toprule",
" & Registered & Intervals & Mean cheap & Zero declared & Cheap share & Essential \\\\",
" & capacity (MW) & & share & availability (\\%) & $<$0.10 (\\%) & intervals (\\%) \\\\",
"\\midrule",
rows,
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}\\footnotesize",
"\\item Cheap share: capacity offered at or below \\$300/MWh, capped at declared availability, over registered capacity (the fixed-threshold definition; the cost-indexed definition agrees on 96--100\\% of intervals). Essential: the rivals-only flag of Section~\\ref{sec:design}. OSB-AG is descriptive only throughout.",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{adjustbox}",
"\\end{table}")
writeLines(t0, file.path(out, "T0_sumstats.tex"))
cat("wrote output/tables/T0_sumstats.tex\n")
print(S)
