# INDEX — Direction/ (kept set, in pipeline order)

**RQ:** Do SA synchronous generators (esp. Torrens Island B) withhold to route into AEMO
directions and collect the directed price d_t, and does the shift scale with d_t?

**Run everything from the `Direction/` root**, e.g. `Rscript 05_directions/run_direction_rebid.R`.
Data caches (`bid_cache/`, `nem_cache/`), parsed data (`direction_data/`), and outputs
(`outputs/`) stay at the root and are shared across stages. Numbers trace to `facts_memo.md` `[F#]`.

## 00_data_spine — extraction & parsing
| script | one-liner |
|---|---|
| `sa_directions_feasibility.R` | AEMO URL/download helpers + constants (sourced by the extractors) |
| `extract_core.R` | DuckDB extraction engine; writes `bid_cache/*.rds` (sourced) |
| `run_month.R` | extract one month with skip-if-done; `Rscript 00_data_spine/run_month.R YYYYMM` |
| `run_all.R` | driver: shells `run_month.R` per month 202202–202412 |
| `extract_dispatchload.R` | DISPATCHLOAD online-status extraction (feeds pivotality) |
| `parse_direction_reports.R` | AEMO direction xlsx → `direction_data/parsed/{direction_events,direction_costs}` |

## 01_prize — the directed price d_t
| `descriptive_analysis.R` | Gate0 d_t reconstruction (trailing-365d 90th pct) → `outputs/descriptives/gate0_dt_series.rds` [F1][F2]. (Also emits legacy v1 cuts — split pending; see CHANGELOG.) |

## 02_cost — marginal cost
| `gate_a_srmc.R` | SRMC per unit-month from STTM gas + heat rates + VOM → `outputs/descriptives_v3/GateA_srmc_params.csv` [F3][F4] |
| `gate_a_revealed_cost.R` | Revealed-cost anchor, **price margin** (§7): low offer band vs gas, competitive unit-days → `GateA_revealed_cost.csv`; **rejected** [F3a] |
| `gate_a_revealed_cost_qty.R` | Revealed-cost anchor, **quantity margin** (§7): low-tranche price + share-below-threshold vs gas, competitive unit-months → `GateA_revealed_cost_qty.csv`; **rejected** [F3a] |
| `SRMC_methodology.md` | Methodology + results write-up for the whole 02_cost stage |

## 03_outcome — withholding (withheld_share)
| `descriptive_analysis_v3.R` | builds `panel_v3.rds` + Cuts 2–6 (rent, slopes, mechanism, d_t regressions) [F5–F10] |
| `figures_srmc_controlled.R` | SRMC-controlled figures + `Margin_vs_DirectionVolume` [F8][F11] |
| `cut5_spot_controlled.R` | spot-controlled robustness of the d_t slope [F8] |

## 04_market_power — pivotality & depth
| `pivotality.R` | system-strength pivotality (realised/ex-ante), N-1, depth → `pivotality_panel.rds` [F13][F18][F19] |
| `pivotality_analysis.R` | pivotal-vs-non-pivotal withholding level effects [F14][F15] |
| `pivotality_decomposition.R` | waterfall of directed-but-non-pivotal intervals [F18] |
| `depth_report.R` | depth-of-pivotality distributions [F19] |
| `depth_by_directed.R` | depth × directed crosstab [F19] |
| `rebid_analysis.R` | rebid intensity + quantity/price withholding vs pivotality [F16] |
| `supply_curves_by_regime.R` | recovered offer curves by 2×2 direction×pivotality → `outputs/descriptives_v3/supply_curves/` [F14a] |
| `f4_supply_curves.R` | offer curves by nested cut (all / directed / directed-pivotal) — F4 as supply curves [F14a] |
| `constraint_decomposition.R` | directed-interval decomposition by binding security constraint (N-1 fault-level / inertia / voltage / residual) → `constraint_decomposition_{panel,mechanism,torrb_summary}` [F20] |
| `wo_stage1_baseline.R` | withhold-to-be-directed Stage 1: counterfactual "normal" bid per unit (undirected, non-pivotal) → `outputs/withhold_opportunity/stage1_*` [F21] |
| `wo_stage2_opportunity.R` | Stage 2: `pex`-based opportunity set + leakage audit + CEM-matched comparison → `stage2_panel.rds` [F21] |
| `wo_stage3_threshold_dt.R` | Stage 3: withheld-threshold sensitivity sweep + `d_t` finalisation (202206 base/robust) → `stage3_panel.rds` [F21] |
| `wo_stage4_identification.R` | Stage 4: consistency count + the `dt x opp` identifying test on the matched sample → `stage4_*` [F21] |

## 05_directions — directions & triggering
| `build_treatment_panel.R` | events → 5-min `treatment_panel.rds` (directed/synchronise flags) [F12] |
| `reason_pivotality.R` | reason field × pivotality — informative null [F17] |
| `00_episodes.R` | per-DUID episode table: issue τ, effective s, cancel c, lead |
| `A_depth_eventstudy.R` | ex-ante depth around episode start s; onset vs tail vs matched |
| `B_rebid_runup.R` | **headline**: pre-issue rebid run-up indexed by Δ = OFFERDATETIME − τ |
| `run_direction_rebid.R` | driver: 00_episodes → A → B |
| `f5_runup_supply_curves.R` | run-up as evolving offer curve by lead-time bin (pooled — composition-confounded, see f5b) → `outputs/direction_rebid/f5_runup_supply_curves*` [F14a] |
| `f5b_within_episode_runup.R` | **composition-proof** within-episode run-up: carry each episode's bid forward to a common event grid, fixed set, change-from-baseline → `f5b_*` [F14a] |

## 06_estimation — write-up (formal estimation TBD)
| `build_docs.R` | generates `outputs/docs/{proposal,methods}.docx` from facts_memo [F#] |

*(Open estimation gaps: wild-cluster bootstrap inference [G8], the d_t × pivotality ×
requirement triple-difference — not yet built.)*

## Reference docs (Direction/ root)
`facts_memo.md` (the [F#] ledger) · `rq_and_id.md` (RQ + identification) ·
`sa_directions_research_context.md` · `why_directed_nonpivotal.md` · `inventory.md` ·
`CHANGELOG.md` (this reorg).

## Not in the pipeline
`_archive/` — superseded dev iterations and v1 outputs. `_uncertain/` — items awaiting a
keep/archive decision (nothing depends on them).
