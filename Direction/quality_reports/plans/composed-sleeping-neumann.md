# Plan: SA Direction Events — Ex-ante Depth (A) & Pre-issue Rebid Run-up (B)

**Status:** DRAFT (awaiting approval)
**Date:** 2026-06-21
**Sub-project:** `Direction/`

---

## Context

We have a complete bid cache (202201–202412) and a parsed AEMO direction event log. The
question is behavioural: **do SA generators position their offers in anticipation of a
system-security direction, before the direction is even issued?** Two angles:

- **Analysis A** — is a unit *more pivotal* (lower ex-ante depth = fewer available rivals)
  at the **onset** of a directed episode than at its tail or in matched non-directed
  intervals? This establishes the setting (directions land when the unit is pivotal).
- **Analysis B** — within the pre-issue window (submission time **before** the direction
  is issued), do units **withhold capacity** (cut `MAXAVAIL`) and **shift capacity above
  SRMC**? This is the run-up. The headline is Synchronise directions; Remain is the
  placebo. The run-up effect is interacted with ex-ante depth and with a post-2023-07
  thermal-exit indicator.

The defining discipline (stated by the user): **never conflate submission time
(`OFFERDATETIME`) with the target dispatch interval (`INTERVAL_DATETIME` = g ∈ [s,c])**.
Everything in B is indexed by **Δ = OFFERDATETIME − τ** (issue time). Δ<0 is the
legitimate run-up; **Δ>0 is contaminated** by the direction itself (and its compensation
mechanics) and is plotted but never interpreted as "reversion".

### Three timestamps per episode (per-DUID)
- **τ** = `issue_time` — when AEMO issued the direction
- **s** = `effective_time` — start of the directed window
- **c** = `cancellation_time` — end
- **lead** = s − τ

### Data already in place (reused, not rebuilt)
| Input | Provides |
|---|---|
| `direction_data/parsed/direction_events.rds` (from `direction_events.csv`) | τ, s, c, `direction_instruction` (Synchronise/Remain), per DUID |
| `outputs/descriptives_v3/pivotality_panel.rds` | `depth_ex_<station>` = ex-ante depth (own-status-invariant, "available rivals"), 5-min, 8 focal stations |
| `direction_data/parsed/treatment_panel.rds` | directed/synchronise flag per (duid, 5-min interval) — for matched controls |
| `bid_cache/BIDOFFERPERIOD_YYYYMM.rds` | versions: `OFFERDATETIME`, `INTERVAL_DATETIME`=g, `MAXAVAIL`, `BANDAVAIL1-10` |
| `bid_cache/BIDDAYOFFER_YYYYMM.rds` | `PRICEBAND1-10` (price ladder) |
| `outputs/descriptives_v3/GateA_srmc_params.csv` | `srmc_marginal` per DUID-month |

### Scope (resolved from the data)
The directed SA sample is **1,492 episodes (730 Synchronise / 762 Remain)** across **12
DUIDs**, every one of which maps to one of the **8 focal stations** that already have a
`depth_ex` measure (Torrens B, Pelican Pt GT, Osborne, Quarantine 5, Dry Creek, Mintaro,
BIPS; Snapper has no directions). **No depth rebuild is needed** — the directed sample is
already fully covered. DUID→station map and the TORRB35→TORRB3 / TORRB46→TORRB4 /
MINTARO1→MINTARO recodes are reused verbatim from `build_treatment_panel.R` /
`depth_by_directed.R`.

### Design parameters (resolved)
- **B baseline version** = the **earliest** version targeting g (most-negative Δ).
  "Last pre-issue" = version with the largest Δ < 0.
- **B target-interval definitions — run BOTH and compare** (user request):
  - **B-whole**: g ∈ [s, c] (the entire directed window)
  - **B-onset**: g = the starting interval(s) only (first hour: g ∈ [s, s+12 intervals])
- **A event window** = e ∈ [−12, +24] 5-min intervals centred on s (1h pre, 2h post; well
  inside the 8.2h median Synchronise duration). **Onset** = e ∈ [0,+12] (first hour
  directed). **Tail** = last 12 intervals before c. Both clipped to [s, c].
- **d_t** = 1{interval date ≥ 2023-07-01} (post SA thermal exit), exactly as specified —
  *not* the continuous `gate0_dt_series` reconstruction (different object; not conflated).
- **37 episodes with lead ≤ 0** (issued at/after effective) have no pre-issue window →
  excluded from B run-up metrics, reported as a count.

---

## Files to create (all new; nothing existing is modified)

All under `Direction/`. Outputs to a new `outputs/direction_rebid/`.

### `00_episodes.R` — shared episode builder
- Load `direction_events.rds`; filter SA-panel DUIDs, instruction ∈ {Synchronise, Remain};
  apply DUID recodes; drop dur ≤ 0; attach station via the focal map.
- Emit per-episode table: `episode_id, duid, station, tau, s, c, lead_h, dur_h, instruction`.
- Save `outputs/direction_rebid/episodes.rds`. Print the 1,492 / 730 / 762 sanity counts.

### `A_depth_eventstudy.R` — Analysis A
- Join each episode to `pivotality_panel.rds` via station; pull `depth_ex` at intervals
  s + e·5min for e ∈ [−12,+24] → long event-time panel.
- **Onset / tail** depth per episode (clipped to [s,c]).
- **Matched non-directed control**: for each (station, hour-of-day, month, weekend) cell,
  mean `depth_ex` over intervals NOT directed for that station (`treatment_panel`). Attach
  the matching cell's counterfactual depth to each episode. (Caliper alternative noted in
  comments; exact-cell is the primary.)
- Outputs to `outputs/direction_rebid/`:
  - `A_depth_profile.csv` + `A_depth_profile.png` — mean depth_ex(e) ± 95% CI, **Synchronise
    vs Remain**, with the matched-control band overlaid.
  - `A_onset_tail_matched.csv` — mean depth at onset vs tail vs matched, by instruction,
    with paired tests (onset vs matched; onset vs tail).

### `B_rebid_runup.R` — Analysis B (the headline)
For each episode, for **both** B-whole and B-onset target-interval sets:
1. Pull all `BIDOFFERPERIOD` versions for the DUID with `INTERVAL_DATETIME` = g; compute
   Δ = `OFFERDATETIME` − τ.
2. Per (version, g) then averaged across g (interval-fixed, like `rebid_analysis.R`):
   - `MAXAVAIL(Δ)`
   - `aboveSRMC_share(Δ)` = Σ_k BANDAVAILk·1{PRICEBANDk > srmc_marginal} / Σ_k BANDAVAILk,
     pricebands from the latest `BIDDAYOFFER` ladder at/under that version's date.
3. **Event-time traces** binned on Δ, split Synchronise vs Remain, Δ<0 solid / Δ>0 shaded
   "contaminated":
   - `B_trace_maxavail_{whole,onset}.png/.csv`
   - `B_trace_abovesrmc_{whole,onset}.png/.csv`
4. **Run-up metrics** per episode (Δ<0 only):
   - `runup_withhold` = `MAXAVAIL`(baseline) − `MAXAVAIL`(last_pre)  (>0 = withdrew capacity)
   - `runup_abovesrmc` = `aboveSRMC`(last_pre) − `aboveSRMC`(baseline) (>0 = shifted above cost)
5. **Regressions** (`fixest`, DUID FE, cluster by month), headline Synchronise, Remain as
   placebo, for B-whole and B-onset side by side:
   - `runup_withhold ~ depth_onset * d_t | DUID`
   - `runup_abovesrmc ~ depth_onset * d_t | DUID`
   - `depth_onset` = the episode's onset ex-ante depth from Analysis A (the interaction the
     spec asks for: run-up withholding × ex-ante depth × pre/post-exit).
   - Output `B_runup_regression.txt` (etable) + `B_runup_metrics.csv` (per-episode).

### `run_direction_rebid.R` — wrapper
Sources the three scripts in order; prints a one-line PASS/FAIL summary per stage.

---

## Verification
1. `Rscript 00_episodes.R` → expect 1,492 episodes (730 Sync / 762 Remain), 12 DUIDs.
2. `Rscript A_depth_eventstudy.R` → `A_*` files exist; depth profile non-empty for both
   instructions; matched-control cells populated.
3. `Rscript B_rebid_runup.R` → `B_*` files exist for both whole & onset; confirm Δ<0 and
   Δ>0 versions both present; metrics computed on ≥ (1,492 − 37) episodes; regression tables
   render with non-degenerate N.
4. Spot-check one episode by hand: print its versions, Δ values, and confirm
   baseline = earliest, last_pre = max Δ<0, and that no g lies outside [s,c].
5. Run `verifier` expectations: scripts run clean under `Rscript`; no writes outside
   `outputs/direction_rebid/`.

## Notes / risks
- Pre-issue coverage depends on how early units bid for g; the lead distribution (median
  15h Sync) suggests adequate Δ<0 room, but per-episode version counts at Δ<0 will be
  reported so thin episodes are visible.
- SRMC join is monthly; a version near a month boundary uses its own month's SRMC.
- Plain declarative readouts; figures self-captioned. No manuscript edits — analysis only.
