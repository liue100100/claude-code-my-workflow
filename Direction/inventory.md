# Direction/ Inventory — Phase 1 (reorganisation around the RQ)

**RQ:** Do SA synchronous generators (esp. Torrens Island B) withhold to route into AEMO
directions and collect the directed price d_t, and does the shift scale with d_t?

**RQ chain (the spine the reorg is built around):**
`prize (d_t) → cost (SRMC) → outcome (withheld_share) → market power (pivotality/depth) →
directions (events/treatment) → triggering (rebid run-up into directions) → estimation`

Method: traced every `*.R` via `source()`, `readRDS/fread` (consumes) and
`saveRDS/fwrite/ggsave/writeLines` (produces); cross-checked downstream references in
`facts_memo.md` (facts `[F#]`), the readouts, and `build_docs.R`. Last-modified from the
filesystem. **Nothing has been moved or deleted.**

---

## 0. BLOCKER for "commit current state": Direction/ is untracked and 157 GB

`Direction/` is **not** in git (0 tracked files) and is **not** gitignored — git collapses
it to a single `?? Direction/`. A naive `git add Direction/` would try to stage **157 GB**:

| dir | size | nature |
|---|---|---|
| `nem_cache/` | **156 GB** | raw AEMO zips — regenerable, must NOT be committed |
| `bid_cache/` | 1.1 GB | extracted `.rds` cache — regenerable, too big for git |
| `outputs/` | 56 MB | figures/CSVs/rds deliverables — OK to commit |
| `direction_data/` | 24 MB | parsed events/costs/treatment — OK to commit |
| `extract_tmp/`, `torrb_slices/`, `.Rproj.user/`, `logs/` | small | scratch/IDE — exclude |
| 28 `*.R` + 6 `*.md` | <1 MB | code + docs — commit |

**Recommendation (needs your OK before I run it):** add a `Direction/.gitignore` excluding
`nem_cache/ bid_cache/ extract_tmp/ torrb_slices/ .Rproj.user/ *.tmp logs/*.log`, then on a
new branch commit only code + docs + `direction_data/parsed/` + `outputs/` (≈80 MB). That is
the genuine restore point for a code/doc reorg; the data caches stay local and regenerable.

---

## 1. Canonical pipeline order (from build_docs.R + source/IO trace)

```
[00 data spine]  sa_directions_feasibility.R ─┬→ extract_core.R ─┬→ run_month.R → run_all.R → bid_cache/*.rds
                                              │                  └→ extract_dispatchload.R → DISPATCHLOAD_*.rds
                 parse_direction_reports.R → direction_data/parsed/{direction_events,direction_costs,recovery_rates}
[01 prize]       descriptive_analysis.R (Gate0 block) → gate0_dt_series.rds   ← LOAD-BEARING
[02 cost]        gate_a_srmc.R (+ Quarterly_STTM_Price.CSV, gate0_dt_series) → GateA_srmc_params.csv
[03 outcome]     descriptive_analysis_v3.R → panel_v3.rds + Cut2–6 ─┬→ figures_srmc_controlled.R
                                                                    └→ cut5_spot_controlled.R
[04 market power] extract_dispatchload + sa_minimum_generator_combinations.csv → pivotality.R → pivotality_panel.rds
                  pivotality_panel → {pivotality_analysis, pivotality_decomposition, depth_report, depth_by_directed, rebid_analysis}
[05 directions]   build_treatment_panel.R → treatment_panel.rds ; reason_pivotality.R
                  00_episodes.R → episodes.rds → A_depth_eventstudy.R → B_rebid_runup.R  (run_direction_rebid.R driver)
[06 estimation]   (none built yet — WCB / triple-diff are open gaps [G8]) ; build_docs.R → proposal.docx, methods.docx
```

---

## 2. Script inventory (consumes → produces · last modified · referenced by · class)

### Data spine
| script | consumes → produces | mod | ref'd by | class |
|---|---|---|---|---|
| `sa_directions_feasibility.R` | (helpers) → `d_t_SA_90pct_365d.csv` | 06-19 | sourced by extract trio, run_month | **keep** |
| `extract_core.R` | zips → `bid_cache/*.rds` | 06-19 | run_month, extract_dispatchload | **keep** |
| `run_month.R` | sources core → 1 month | 06-18 | run_all | **keep** |
| `run_all.R` | drives run_month | 06-18 | (entry point) | **keep** |
| `extract_dispatchload.R` | zips → `DISPATCHLOAD_*.rds` | 06-20 | feeds pivotality.R | **keep** |
| `parse_direction_reports.R` | xlsx → `direction_{events,costs}`, `recovery_rates` | 06-19 | spine for 05 | **keep** |
| `bid_data_extraction_202201.R` | 202201 one-off → `gate3_oom_202201.csv` | 06-16 | none (superseded) | **archive** |
| `bid_extraction_duckdb_202201.R` | 202201 duckdb dev → `gate3_oom_202201_duckdb.csv` | 06-16 | none (superseded) | **archive** |
| `gate3_202201_unz_archive.R` | 202201 archive-format dev | 06-16 | none (superseded) | **archive** |
| `_url_test.R` | URL probe scratch | 06-18 | none | **archive** |

### Prize / cost
| `descriptive_analysis.R` | costs/events → `gate0_dt_series.rds` (**load-bearing**) + `monthly_bid_agg.rds` + old Cut1–5 | 06-19 | gate0 consumed by gate_a_srmc & v3; Cut1–5 **superseded by v3** | **keep** (script; archive its `outputs/descriptives/` Cut figures) |
| `gate_a_srmc.R` | gate0, STTM → `GateA_srmc_params.csv`, margin summary | 06-19 | [F3][F4]; consumed by v3, rebid, B | **keep** |

### Outcome
| `descriptive_analysis_v3.R` | caches, gate0, srmc, treatment → `panel_v3.rds`, Cut2–6 | 06-19 | [F5–F10]; panel_v3 consumed downstream | **keep** |
| `figures_srmc_controlled.R` | `panel_v3.rds` → controlled figures, Margin_vs_DirectionVolume | 06-20 | [F8][F11] | **keep** |
| `cut5_spot_controlled.R` | `panel_v3.rds` → spot robustness | 06-20 | [F8] | **keep** |

### Market power
| `pivotality.R` | DISPATCHLOAD, combos → `pivotality_panel.rds` (piv/pex/n1/depth) | 06-20 | central; [F13–F19] | **keep** |
| `pivotality_analysis.R` | pivotality_panel, panel_v3 → level effects, `pivotality_analysis_panel.rds` | 06-20 | [F14][F15] | **keep** |
| `pivotality_decomposition.R` | pivotality_panel, events → waterfall | 06-20 | [F18] | **keep** |
| `depth_report.R` | pivotality_panel → depth distributions | 06-20 | [F19] | **keep** |
| `depth_by_directed.R` | pivotality_panel, events → depth×directed | 06-20 | [F19] | **keep** |
| `rebid_analysis.R` | caches, srmc, pivotality_panel, treatment → `rebid_pivotality_daily.*` | 06-20 | [F16] | **keep** |

### Directions / triggering
| `build_treatment_panel.R` | events → `treatment_panel.rds` | 06-19 | consumed by v3, rebid, A | **keep** |
| `reason_pivotality.R` | events, pivotality → reason×pivotal (**informative null**) | 06-20 | [F17] | **keep** |
| `00_episodes.R` | events → `episodes.rds` | 06-21 | A, B | **keep** |
| `A_depth_eventstudy.R` | episodes, pivotality, treatment → depth event study | 06-21 | B | **keep** |
| `B_rebid_runup.R` | episodes, caches, srmc, A → run-up + regressions | 06-21 | headline | **keep** |
| `run_direction_rebid.R` | driver (sources 00/A/B) | 06-21 | entry point | **keep** |

### Meta / docs
| `build_docs.R` | reads `facts_memo.md` cites → `proposal.docx`, `methods.docx` | 06-20 | deliverable | **keep** (placement uncertain — suggest 06) |

### Reference docs (root `*.md`)
| `facts_memo.md` (central [F#] ledger) · `rq_and_id.md` (RQ+identification) | 06-20 | cited everywhere | **keep** |
| `sa_directions_research_context.md` · `why_directed_nonpivotal.md` ([F17] grounding) | 06-19/20 | reference | **keep** |
| `bid_extraction_handoff.md` (extraction handoff — now also in agent memory) | 06-16 | none active | **uncertain** |

---

## 3. Orphans

**Scripts no longer called** (superseded by `extract_core`/`run_month`/`run_all`):
`bid_data_extraction_202201.R`, `bid_extraction_duckdb_202201.R`,
`gate3_202201_unz_archive.R`, `_url_test.R`.

**Outputs with no consumer / stale producer:**
- `outputs/descriptives/Cut1–Cut5_*.png`, `descriptive_readout.md` — **superseded by `descriptives_v3`** (only `gate0_dt_series.rds` from that folder is still consumed).
- `outputs/descriptives/Cut5_eventstudy.png` — explicitly deprecated ([G3]).
- `outputs/descriptives/monthly_bid_agg.rds` — produced, never consumed.
- `gate3_oom_202201.csv`, `gate3_oom_202201_duckdb.csv` — dev artifacts of the archived 202201 one-offs.
- `outputs/descriptives_v3/pivotality_analysis_panel.rds` — terminal, never consumed (**uncertain**: may be a deliverable).
- `direction_data/parsed/recovery_rates.rds` — never consumed (kept for future dollar-rent merge [G7]).

**Load-bearing despite living in a "superseded" folder:** `outputs/descriptives/gate0_dt_series.rds`
(the d_t spine) — consumed by `gate_a_srmc.R` and `descriptive_analysis_v3.R`. Do **not** archive.

---

## 4. KEEP — informative nulls / placebos (explicitly retained)
- **Remain placebo** — `B_rebid_runup.R`, `Cut2` Remain tercile, treatment split [F12].
- **Direction-incidence ⟂ rent** — `Margin_vs_DirectionVolume*.png`, corr 0.167 [F11] (exogeneity).
- **No cost break at the exit** — `GateA_srmc*` flat SRMC [F3].
- **d_t × pivotal insignificant** — `Pivotality_interaction.csv` [F15].
- **`reason` field degenerate** — `reason_pivotality.R`, reason×pivotal tables [F17].

Null is evidence here, not clutter — none of these are archive candidates.
