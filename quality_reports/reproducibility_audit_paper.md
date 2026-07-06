# Reproducibility Audit: "Paid to Be Absent" (manuscript/paper.tex)

**Date:** 2026-07-06
**Manuscript:** manuscript/paper.tex + manuscript/sections/*.tex
**Outputs audited against:** Direction_clean/outputs/ (stages 01–05 findings.md + CSVs), Direction/outputs/withhold_opportunity/, Direction/outputs/proposal_figures/ (CSVs + readout)
**Tolerances:** defaults (integers exact; estimates <0.01; SEs <0.05; p-values same significance level; percentages ±0.1pp)
**Provenance note:** Tables T1–T4 and Figures 1–5 are generated mechanically from the source CSVs by `scripts/R/90_paper_tables.R` / `91_paper_figures.R` (strongest provenance — no hand-typed exhibit numbers). This audit therefore focuses on numbers typed into prose.

## Summary

| Status | Count |
|---|---|
| PASS | 94 |
| FAIL (corrected during audit) | 6 → 0 |
| EXPLAINED | 1 |
| UNMATCHED | 0 |
| **Overall verdict** | **PASS** |

## Corrected during audit (were FAIL, now PASS)

| Claim | Was | Source says | Fix applied |
|---|---|---|---|
| §2 "d_t at peak until mid-2023, a full year after gas fell" | "a full year after" | Gas hit $12.59 Jan-2023; d_t peak ended May/Jun-2023 (~4 months) | Rephrased: "while gas prices fell from $29.85 (mid-2022) to $12.59 (early 2023)" |
| §3 d_t series "spanning $108 to $378/MWh" | Mixed two series | F1 reconstruction range 108.7–349.6; estimation-series committed range 121–378 | Span removed from §3 (see EXPLAINED row) |
| §4 "cost/MWh $351–382 through mid-2023" | "through mid-2023" | F2 CSV: 351.6 (22Q4), 351.1 (23Q1), 382.4 (23Q2), 351.7 (23Q3) | "from late 2022 through the third quarter of 2023" |
| §7 floor-price effect "+$45 on a base in the hundreds of dollars" | Unsupported base | Task 10: floor prices sit at −$998 to −$1,000; no base stated | Base clause deleted |
| §9 "$200/MWh margin for a full year" | Overstated | F1 rent: ≥$100 for 11 months (Oct-22–Aug-23); ≥$200 only Jan–Mar-23 (peak $211) | "above $100/MWh for eleven consecutive months, peaking at $211" |
| App A "baseline withheld rate 90–97%" | Range conflated | stage4_findings: comparison 90.3–94.2%, opportunity 96.7–98.7% | Split: "90–94% comparison / 97–99% opportunity" |

## EXPLAINED (named discrepancy, non-blocking — flagged for the author)

| Claim | Issue | Named explanation | Resolution |
|---|---|---|---|
| Compensation-price range: §5/§6 cite "$121–378/MWh" (RQ2 findings, committed power diagnostic) while Fig 1's plotted reconstruction peaks at $349.65 | Two d_t series exist in the project: the F1 figure reconstruction (`dt` in F1_compensation_vs_fuel.csv; June-2022 imputed at $164.38, max 349.65) and the estimation `comp_price` (RQ2 committed month-level range $121–378, also used by task11 which reports peaks $365–378) | Subset range ($121–378 over essential-bearing months) exceeding the F1 max proves these are different constructions, not the same series at different granularity. Manuscript now prints only the estimation range; Fig 1 is labelled as the trailing-percentile reconstruction. **Author should confirm which construction `comp_price`/`dt_recon` uses vs F1's, and reconcile or footnote before submission.** | DEFENSIBLE-ALTERNATIVE (pending author confirmation) |

## PASS highlights (spot-verified against verbatim source text this session)

- **RQ1:** pooled −0.0045/−0.048 (WCB p .847/.208–.21); M1→M3 +6.2%/+0.7%; Torrens −0.037/−0.076 (p .106/.039); saturated −0.0321 (p<0.001); slope p .995; LOMO 72/72 negative; PPCCGT +0.184→−0.083 flip on drop-Oct-2023 — all vs `rq1_core_results.csv`, `rq1_wcb.csv`, `rq1_robustness.csv`, `findings_3b.md`. ✓
- **RQ2:** −0.0512 (p .00475; WCB .0041/.0040), −0.0554 (p .00749; WCB .0073/.0061); treatments −0.044..−0.058 (p .001–.029); 12,513 essential; 21 clusters; top-3 50.8%; sd $76.6; ~10 MW/unit; ~0.13 across range; 27% 2024 mass — vs `rq2_results_full.csv`, `rq2_wcb.csv`, `findings.md`. ✓
- **Mechanism:** 740 episodes, median 40 MW = floor, 55.9% ≤0 excess, 80.8% ≤25 MW (post-fix findings_task1.md — the pre-fix 36.9% figure appears nowhere in the manuscript); comp = 0.95×MWh×P, R²=0.99, wedge 0.364, 271 episodes, 0.7% misfits (task1b post-fix); $141.9M/$7.2M/$134.7M/625,635 MWh/683 episodes/48.2% negative-spot/spot $191–272 dir $/MWh (task5b); 3.9% profitable intervals, median −$141, 11/683 = 1.6% (task14 via task5b addendum); exit act −0.163 WCB .017–.019, −0.124 w/ loss control, three-tier −0.190/−0.001, 22.5% base, exp_loss wrong sign p .005 (task9); floor price +$45 p .86, +$65 p .40, PPCCGT $0.0, medians −$998..−$1,000, 115 vs 16 days, +$2,414 p .17 (task10); contamination 54% (101/186), clean 80, A: −0.127 WCB .0004 → −0.015 p .71, B +$2,414 16 days, 95.4% of 280 (71.8/23.6), day-RQ2 null 49 days/14 months p .50–.96 (job2); base rate 76–80%; task2 1/300th sample language for the grain comparison. ✓
- **Descriptives:** rent −$185.25 (Apr-22) / +$211.6 (Jan-23) peak ~$212 (Feb/Mar-23) — text says "peaking at $211", within display rounding of the committed readout; d_t $348–350 Jul-22–May-23; gas 29.85→12.59; $416.06 2022Q3; 2021 $85–134 on 3–4× volume; pct-time peak 85.7%→"up to 86%"; avg MW 117–196 (2021) vs 49.0–77.0 (2022+); QED reconciliation 0.1pp in 6/9, worst 2.3pp; Q2-23 machine precision (F1/F2/F2b CSVs + recon log). ✓
- **Design:** 1,578,240 / 1,261,576 / 140,259 / 12,513 / 375,264 / 1,638 rows-events; agreement 96–100% worst 3.9%; thresholds 82–96%; channels 51–99% withdrawn, 10–33% both (findings' own range); floor-share 69–77%; leakage R² ≤.0028; bid-as-usual 2–6%/66%; corr −0.036/−0.018; slopes −5.04/−3.31; saturated mass 6.7%; ~10× share-control inflation; June 19% (stage 0–3 files). ✓
- **Availability anatomy:** zero-avail 47.5/58.8/62.7% → "47–63%"; derate 0.2%; 3-up 4% (44/1,096); spells 2–4 median, max 100; anti-corr 0.34–0.42; roster: 93.3% zero-ask, 0 violations in 73 (task12/13). ✓
- **Appendices:** withhold-opp pooled .000242 t 1.55 p .137, TORRB4 .000554 p .073, $164.38 imputation, byte-identical sets (stage3/4/4b); markup 37.5% >|100|, trim 62.7–67.4%, corr +.076/+.041 (stage2 gate); N-1 census 1,290/186, 606/80, 7.6× (task7). ✓

## Environment
Sources are static findings/CSV artifacts (no pipeline re-run required — the manuscript cites recorded outputs, and exhibits regenerate deterministically from CSVs; verified this session).

## Addendum — round-2 revision claims (2026-07-06, Test-4 writing batch): PASS
Every numeric claim added in the round-2 revision traces to the committed round-2 record
(verified against verbatim source text in-session):
- Eligibility margin −0.0855 → "8.6 pp" (abstract/§1/§6.3), WCB p .0028→".003", RI p 0.0460→"0.046",
  base essential reach 10.1%→"only 10%", intensive p .54–.79 (test1/test3d findings + CSVs). ✓
- Timing wedge: crisis −0.100 p .030; lag-wedge −0.075 WCB p .089→"p=0.089"/"the 10% level";
  four-period monotone ordering; "gas fell nine months before the payment" (Oct-22→Jul-23) (test2). ✓
- Month grain: −0.0964→"−0.096", HC1 p .0012→".001", 19 months (test3a). ✓
- Horse race: share −0.0535→"−0.054" p .013, gas p .85; reach variance-split described
  qualitatively; cor(d_t,gas)=0.48 (test3b + task11). ✓
- Placebo: candidate stations 0–45 essential intervals vs Torrens 4,083; Mintaro directed 236×
  (test3c corrected gate). ✓
- "Band prices change twice in roughly a thousand revisions" (task2 lever table: 2 in ~1,030). ✓
- "683 episodes of the 740" (task5b 683 Torrens; task1 740 = 197+260+226+29+28). ✓
- RRP own-coefficient p .77–.96 (rq1_core_results.csv, 6 models). ✓
- T0/T5 and the T2 main-effect row are generated mechanically from source CSVs (92/90 scripts);
  T0 values cross-check Stage-1 findings (means .117/.164/.136/.429/.280; <10% shares
  77.4/69.1/74.4/41.9/71.0; essential rates 1.29/0.08/0.01). ✓
Note: T0's zero-declared-availability column (60.4/43.8/56.1%) measures in-force intervals and
intentionally differs from task12's day-ahead-stance rates (62.7/47.5/58.8%). §4 now states both
bases explicitly ("day-ahead stances ... 47–63%; in-force ... 44–60%, Table T0"); §7's spell/
roster figures remain day-ahead-stance quantities per task12. ✓

## Next steps
1. Author: resolve the EXPLAINED d_t-series row (confirm `comp_price` construction vs F1's `dt`; footnote §5 or harmonise Fig 1 if they differ by construction).
2. Re-run this audit after any pipeline re-run or section rewrite.
3. Pre-submission: Rtools + null-imposed WCB (registered upgrade path, §8).
