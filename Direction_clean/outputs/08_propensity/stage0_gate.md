# Stage 0 — data gate: **HALT** (registered stop condition fires on PREDISPATCH coverage)

Registration: `08_propensity/registration.md`. Script: `08_propensity/stage0_gate.R`; outputs
`stage0_onsets.csv`, `stage0_spells.csv`. Per the registration, a fired stop condition halts the
pipeline with Layer 1 as the fallback; the decision on how to proceed is the author's.

## (a) PREDISPATCH coverage — FAIL (0 months; threshold ≥ 24)

The cache holds BIDDAYOFFER, BIDOFFERPERIOD, DISPATCHLOAD (2021-01→2024-12), DISPATCHPRICE,
pivotality, SA_DUIDS. **No PREDISPATCH tables exist anywhere in the pipeline.** Forecast slack
at 1h/4h/8h horizons (Stage 1) and the hazard's expected workhorse regressor (minimum forecast
slack over the commitment lead window, Stage 2) cannot be built from current holdings.

Repairability, for the decision: AEMO's MMSDM archive (nemweb) publishes the needed tables
back-catalogue: `PREDISPATCH_REGION_SOLUTION` (30-min regional demand + UIGF forecasts per run;
light, ~36 monthly archives, SA1-filterable) and `PREDISPATCHLOAD` (per-unit forecast
availability per run — the rivals'-availability-at-horizon input; **heavy**, hundreds of MB per
month before filtering). Building this is a new Python ETL comparable in scale to the original
35-month bid-cache extraction. It is the difference between the full two-layer model and the
fallback.

## (b) Combination-table vintages — PARTIAL

In hand: `Direction/sa_minimum_generator_combinations.csv` — 122 combinations, regimes
system_normal (79) and risk_island_or_island (43), `syn_cons = 4` throughout, non-synchronous-MW
thresholds; already exercised at 5-min grain by Task 13's feasibility machinery. **Single
vintage, no effective-date column.**

Public record (AEMO limits-advice page; PDFs not machine-retrievable, HTTP 403):
- The governing document is AEMO's *Transfer Limit Advice — System Strength (SA)*, which
  tabulates minimum synchronous generator combinations by non-synchronous output level.
- The four ElectraNet synchronous condensers were all in service from late 2021, so the
  `syn_cons = 4` table regime spans the whole 2022–2024 window.
- The two-unit minimum standard held throughout 2022–2024; the reduction toward one unit is
  September 2025 (outside the sample; consistent with the project's regime-exit record).
- **Unverified:** whether AEMO revised the non-sync-MW bands or combination rows *within*
  2022–2024. TLA documents are revised periodically; the in-window revision dates could not be
  enumerated remotely. Stage 1, if run, should treat the single vintage as an approximation and
  say so; obtaining the versioned PDFs (manual download from the AEMO congestion-information
  resource) upgrades this to vintage-correct.

## (c) Independent onsets — PASS at the 4h/8h definitions; the 24h definition fails

1,061 direction-window rows (661 old-format event windows, 400 new-format per-DUID) merge into
**480 continuous directed spells** over 2022–2024 (11,976 directed hours; median spell 11.8 h,
max 231.5 h). The parsed record does not natively distinguish re-issues, so the gap rule was
applied as registered:

| gap rule N | independent onsets | 2022 / 2023 / 2024 |
|---|---|---|
| 4 h | **448** | 134 / 190 / 124 |
| 8 h | **386** | 115 / 173 / 98 |
| 24 h | 121 | 48 / 36 / 37 |

Threshold ≥ 150 (and onsets/15 ≥ 10 parameters, which coincides at 150): **passes at N = 4h and
8h**, fails only under the very strict 24-hour independence rule. Events-per-parameter at N=8h:
386/10 ≈ 39 — comfortable.

## Gate verdict and the decision

The onset count supports the hazard model; the table vintage is approximable; **PREDISPATCH is
the binding failure.** Per the registration: HALT; fallback is Layer 1 only.

Options (author's decision; no work proceeds until chosen):

1. **Fallback as registered — Layer 1 only.** Deterministic requirement state + realized slack
   at 30-min grain, vintage caveat noted. The five-bucket decomposition of directed time (core
   need / buffer / persistence / chaining / residual) is computable from realized slack + issue
   times without forecasts, so the decomposition finding — the §9 feed — survives; the hazard,
   the propensity π, and the Stage-4 conduct test do not run.
2. **Repair the gate.** Build the PREDISPATCH extraction (Python ETL, new nemweb pull:
   REGION_SOLUTION light + PREDISPATCHLOAD heavy), then run the full registered pipeline. This
   is days of pipeline work and tens of GB of intermediate data before filtering.
3. **Amend the registration** to a current-state-only hazard (drop the forecast-slack
   regressors, keep the rest). Explicitly an amendment — the expected workhorse regressor
   disappears, and the "desk could compute it" argument weakens to nowcast rather than
   forecast. Requires a dated amendment note in the registration before any Stage-2 code.

**STOP — awaiting the author's choice among 1/2/3.**

---

## Addendum (2026-07-07, post-decision): author chose option 2 — repair the gate

Repair design, revised after source verification (documented here because the naive design was
infeasible):

- **MMSDM's monthly PREDISPATCH tables are final-run-only.** `PREDISPATCHREGIONSUM_D` /
  `PREDISPATCHLOAD_D` hold one row per target interval (verified: 1,487 SA1 regional rows and
  19,331 unit rows for Jan 2022 ≈ one per half-hour) — no forecast horizons. The all-runs
  unit-level source (Next-Day-PreDispatch reports) is a rolling ~13-month archive starting
  May 2025 — the 2022–2024 record is not publicly retrievable. A literal PREDISPATCHLOAD
  extraction cannot repair the gate.
- **The repair that works:**
  1. **Forecast regional conditions at all horizons: `PDPASA_REGIONSOLUTION`** (MMSDM, all
     half-hourly runs retained — verified 48 runs/day, median 55 intervals/run, 39 h max lead,
     Jan 2022 = 82,508 SA1 rows). Carries DEMAND10/50/90, aggregate + semi-scheduled capacity,
     SS_SOLAR_UIGF/SS_WIND_UIGF, surplus/LRC fields.
  2. **Rivals' unit availability at horizon h: the bid cache already in the pipeline.**
     Pre-dispatch consumes the latest lodged bid, so rival `MAXAVAIL` from the latest offer
     version lodged before (t − h) for target interval t reproduces the operator's unit-level
     information set — rivals-only by construction, and public (bids disclose next-day).
  3. **Validation:** the final-run `PREDISPATCH_LOAD_*` tables (extracted anyway, light) check
     the bid-based reconstruction at the shortest horizon; the final-run availability should
     match the last-lodged-bid MAXAVAIL closely.
- This implements the registration's Stage-1 forecast-slack requirement with a different (and
  strictly public) source for the unit layer; it is a source substitution, not a scope
  amendment. Extraction: `Direction/00_data_spine/extract_predispatch.R`, months 202112–202412,
  outputs `bid_cache/{PREDISPATCH_RS,PREDISPATCH_LOAD,PDPASA_RS}_<M>.rds` + sentinels +
  `predispatch_manifest.csv`.

**Gate status after repair completes: (a) satisfied via PDPASA + bid-versioned availability;
(b) single-vintage caveat stands (manual TLA PDF pull upgrades it); (c) passed (N=8h: 386
onsets). Pipeline resumes at Stage 1 when the 37-month manifest reads OK.**
