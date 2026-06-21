# CHANGELOG — RQ-based reorganisation (2026-06-21)

Reorganised `Direction/` around the research question (do SA synchronous generators,
esp. Torrens Island B, withhold to route into AEMO directions and collect d_t). Every
move is reversible. Restore point: commit `325b7d8` ("checkpoint: Direction project
pre-reorg snapshot"). Pipeline re-verified end-to-end after the moves (see bottom).

**Conventions**
- All scripts are run **from the Direction/ root** (e.g. `Rscript 05_directions/run_direction_rebid.R`).
- Data dirs (`bid_cache/`, `nem_cache/`, `outputs/`, `direction_data/`), raw input CSVs,
  and reference `.md`s were **left in place** so no data path breaks.
- `_archive/` and `_uncertain/` mirror original relative paths.

## Moves: KEEP → themed folders

| from | to | reason (RQ chain) |
|---|---|---|
| `sa_directions_feasibility.R` | `00_data_spine/` | AEMO download helpers/constants (data spine) |
| `extract_core.R` | `00_data_spine/` | DuckDB extraction engine → `bid_cache/` |
| `run_month.R` | `00_data_spine/` | per-month extraction (skip-if-done) |
| `run_all.R` | `00_data_spine/` | extraction driver |
| `extract_dispatchload.R` | `00_data_spine/` | DISPATCHLOAD online-status extraction |
| `parse_direction_reports.R` | `00_data_spine/` | AEMO direction xlsx → parsed events/costs |
| `descriptive_analysis.R` | `01_prize/` | Gate0 d_t reconstruction → `gate0_dt_series.rds` (prize) |
| `gate_a_srmc.R` | `02_cost/` | SRMC per unit-month (cost) |
| `descriptive_analysis_v3.R` | `03_outcome/` | withheld_share panel + Cuts 2–6 (outcome) |
| `figures_srmc_controlled.R` | `03_outcome/` | SRMC-controlled figures |
| `cut5_spot_controlled.R` | `03_outcome/` | spot-controlled robustness |
| `pivotality.R` | `04_market_power/` | pivotality/depth/N-1 → `pivotality_panel.rds` |
| `pivotality_analysis.R` | `04_market_power/` | pivotal-vs-non-pivotal withholding |
| `pivotality_decomposition.R` | `04_market_power/` | directed-non-pivotal waterfall |
| `depth_report.R` | `04_market_power/` | depth-of-pivotality distributions |
| `depth_by_directed.R` | `04_market_power/` | depth × directed crosstab |
| `rebid_analysis.R` | `04_market_power/` | rebid quantity/price withholding |
| `build_treatment_panel.R` | `05_directions/` | events → 5-min treatment panel |
| `reason_pivotality.R` | `05_directions/` | reason × pivotality (informative null) |
| `00_episodes.R` | `05_directions/` | episode table (τ/s/c) |
| `A_depth_eventstudy.R` | `05_directions/` | ex-ante depth around start s |
| `B_rebid_runup.R` | `05_directions/` | pre-issue rebid run-up (headline) |
| `run_direction_rebid.R` | `05_directions/` | driver (00→A→B) |
| `build_docs.R` | `06_estimation/` | proposal.docx + methods.docx |

## Moves: ARCHIVE → `_archive/` (superseded; never deleted)

| from | to | reason |
|---|---|---|
| `bid_data_extraction_202201.R` | `_archive/` | 202201 one-off, superseded by `extract_core`+`run_month`+`run_all` |
| `bid_extraction_duckdb_202201.R` | `_archive/` | 202201 duckdb dev iteration, superseded |
| `gate3_202201_unz_archive.R` | `_archive/` | 202201 archive-format dev gate, superseded |
| `_url_test.R` | `_archive/` | URL probe scratch |
| `gate3_oom_202201.csv`, `gate3_oom_202201_duckdb.csv` | `_archive/` | dev artifacts of the above |
| `outputs/descriptives/Cut2_rent_distribution.png` | `_archive/outputs/descriptives/` | v1 cut, superseded by descriptives_v3 |
| `outputs/descriptives/Cut3_offer_behaviour.png` | `_archive/outputs/descriptives/` | v1 cut, superseded |
| `outputs/descriptives/Cut4_mechanism.png` | `_archive/outputs/descriptives/` | v1 cut, superseded |
| `outputs/descriptives/Cut5_eventstudy.png` | `_archive/outputs/descriptives/` | explicitly deprecated ([G3]) |
| `outputs/descriptives/monthly_bid_agg.rds` | `_archive/outputs/descriptives/` | produced, never consumed |
| `outputs/descriptives/run_descriptive.log{,.err}` | `_archive/outputs/descriptives/` | v1 run logs |

## Moves: UNCERTAIN → `_uncertain/` (your call; nothing depends on these)

| from | to | open question |
|---|---|---|
| `direction_data/parsed/recovery_rates.rds` | `_uncertain/direction_data/parsed/` | only needed for future dollar-rent merge [G7] |
| `outputs/descriptives_v3/pivotality_analysis_panel.rds` | `_uncertain/outputs/descriptives_v3/` | terminal, never consumed |
| `bid_extraction_handoff.md` | `_uncertain/` | superseded by agent memory |

## Path edits (so the pipeline still runs from the Direction root)

| file | change |
|---|---|
| `00_data_spine/extract_dispatchload.R` | `source("…")` → `source("00_data_spine/…")` |
| `00_data_spine/run_month.R` | `setwd` re-anchored to root (`dirname(dirname(--file))`); `source("…")` → `source("00_data_spine/…")` |
| `00_data_spine/run_all.R` | `setwd` re-anchored to root; `system2(… "run_month.R")` → `"00_data_spine/run_month.R"` |
| `05_directions/run_direction_rebid.R` | `steps` → `"05_directions/…"` |

Also added `Direction/.gitignore` (excludes `nem_cache/`, `bid_cache/`, scratch).

## NOT moved (load-bearing or input — left in place deliberately)

- `outputs/descriptives/gate0_dt_series.rds` — the d_t spine, consumed by `02_cost/gate_a_srmc.R`
  and `03_outcome/descriptive_analysis_v3.R`. **Do not archive** (it lives in the v1 folder but is live).
- `outputs/descriptives/{Gate0_dt_table.csv, Gate0_dt_validation.png, Cut1_treatment_variation.png, descriptive_readout.md}` — still cited by facts_memo [F1][F2][F12].
- Raw inputs at root: `Quarterly_STTM_Price.CSV`, `sa_minimum_generator_combinations.csv`, `d_t_SA_90pct_365d.csv`.
- Reference docs at root: `facts_memo.md`, `rq_and_id.md`, `sa_directions_research_context.md`,
  `why_directed_nonpivotal.md`, `inventory.md`.

## Verification (post-reorg)

- All 24 moved scripts `parse()` clean.
- `Rscript 00_data_spine/run_month.R 202401` → `SKIP 202401 already done` (driver anchors to root, no re-extract).
- `Rscript 05_directions/run_direction_rebid.R` → all stages PASS; 1,492 episodes / 25,250 version rows (identical to pre-reorg).

## Open follow-up

- `01_prize/descriptive_analysis.R` still bundles the load-bearing Gate0 block with superseded
  v1 cut figures. Future cleanup: split the Gate0 block into a dedicated `01_prize` script and
  retire the rest.
