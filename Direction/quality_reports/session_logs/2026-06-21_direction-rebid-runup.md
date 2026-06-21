# Session: direction-event ex-ante depth + pre-issue rebid run-up

**Date:** 2026-06-21
**Plan:** `quality_reports/plans/composed-sleeping-neumann.md` (APPROVED)

## Goal
Two behavioural analyses on AEMO SA direction events, indexed on the three episode
timestamps (issue τ, effective s, cancellation c):
- **A** — ex-ante depth event study centred on s; onset vs tail vs matched non-directed.
- **B** — pre-issue rebid run-up indexed by Δ = OFFERDATETIME − τ; whole window vs onset;
  run-up × ex-ante depth × post-2023-07 exit. Headline Synchronise, placebo Remain.

## Key decisions
- Built on existing panels (pivotality, treatment, SRMC, bid cache); no rebuild needed.
- All 12 directed DUIDs already map to the 8 focal stations with a depth measure.
- B baseline = earliest version targeting g (user choice); both target-interval defs run.
- d_t = 1{date ≥ 2023-07-01}, the literal indicator, NOT the continuous gate0_dt series.
- OFFERDATETIME (submission) vs INTERVAL_DATETIME (target g) kept strictly separate;
  foverlaps maps bid rows to episodes by g ∈ [s,c]; Δ from submission time only.
- Δ>0 plotted but flagged contaminated, never interpreted.

## Results
- A: onset depth ~0.8–0.9 rivals below matched baseline for both instructions (p≈1e−50);
  directions land when the unit is pivotal.
- B headline: above-SRMC run-up is larger the more pivotal the Synchronise unit
  (depth_onset −0.019**/−0.023***); Remain placebo shows no depth gradient. Whole and
  onset agree; onset price channel slightly stronger.

## Artifacts
- Scripts: `00_episodes.R`, `A_depth_eventstudy.R`, `B_rebid_runup.R`, `run_direction_rebid.R`
- Outputs: `outputs/direction_rebid/` (figures, CSVs, `B_versions.rds`, `readout.md`)
- B has SKIP-IF-DONE on `B_versions.rds` (REBUILD_VERSIONS=1 to rescan, ~10 min).

## Open / next
- B coverage limited to 2022–2024 bid cache (episodes outside drop out).
- MAXAVAIL channel weaker than the price channel; net capacity rises pre-issue (units come
  online in anticipation) — could decompose online vs offline starting state.
- Not committed; analysis only, no manuscript edits.
