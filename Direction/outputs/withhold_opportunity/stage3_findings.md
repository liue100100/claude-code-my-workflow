# Stage 3 findings -- threshold sensitivity + d_t finalisation

Script: `04_market_power/wo_stage3_threshold_dt.R`. Reads `stage2_panel.rds` (1578240 rows), re-saves as
`stage3_panel.rds` with two additions: `withheld` (headline flag, cheap300 < per-unit trough) and
`dt_robust`/`dt_imputed` (the resolved 202206 handling).

## (A) Threshold sensitivity (see `stage3_threshold_sensitivity.csv`)
Swept {80,100,120,150,170} MW alongside each unit's empirical trough (TORRB2=170, TORRB3=131, TORRB4=171, PPCCGT=180, OSB-AG=90) on the OPPORTUNITY set.
Verified: the trough-default row reproduces `stage2_opportunity_summary.csv`'s withheld_share_opp /
asusual_share_opp exactly, unit by unit (self-check passed, see console log).

## (B) d_t finalisation (resolved decision, 2026-07-04)
- **Base case (`dt`):** unchanged -- 202206 stays NA, dropped in any dt-based regression via
  `!is.na(dt)`.
- **Robustness (`dt_robust`):** 202206 imputed at **\$164.38/MWh** -- the directed_mwh-weighted mean
  implied \$/MWh (`compensation_payment/directed_mwh`) across the 3 June-2022 `direction_costs`
  report-events. `dt_imputed` flags the 43200 rows (yyyymm==202206) this applies to.
- Assertions passed: pre-fix, is.na(dt) is TRUE for 202206 rows and only those; post-fix,
  `dt_robust` has zero NA.

Next: Stage 4 -- the identifying test (does withheld sort on dt, specific to opportunity vs.
matched-comparison intervals), run on both dt and dt_robust.

