# Session log — Proposal descriptive figures

**Date:** 2026-06-29
**Plan:** `quality_reports/plans/twinkling-baking-floyd.md` (APPROVED)
**Deliverable:** `Direction/proposal_figures.R` → `Direction/outputs/proposal_figures/` (5 PNG @300dpi + CSVs + readout.md)

## Goal
Five descriptive figures to motivate the SA-directions proposal, assembled from existing cached
panels (no new estimation): F1 d_t vs gas (temporal misalignment), F2 direction volume/cost,
F3 pivotality composition of directed intervals, F4 rebidding across 3 samples, F5 pivotality vs
non-sync (user-selected extra). User chose PNG output; F4 defaulted to all 3 rebid metrics.

## Key decisions / findings
- d_t from `Gate0_dt_table.csv` (blended realised/reconstructed); gas parser reused from
  `02_cost/gate_a_srmc.R`.
- F2 cost data splits cleanly at 202310: `direction_costs.rds` (event-level, ≤202309) +
  `direction_events.rds` new format (per-DUID, ≥202310). Old-format event rows carry NO mwh/cost.
- F3 reused the validated directed-interval construction from `pivotality_decomposition.R`
  (events effective→cancellation expansion, STAT map, merge with long pivotality `pl`). Tiers are
  mutually-exclusive, most-binding-first: N-0 `piv` → N-1-secure `piv_n1 & short_n1==0` → ex-ante
  `pex` → none. Headline (all years, n=183,552): 58% directly pivotal, 14% N-1, ~0% ex-ante, 28% none.
- F4 honesty correction: rebid frequency is ~flat; capacity-withheld goes NEGATIVE on direction
  days (directed units are required to inject, mechanical); the real strategic signal is price
  escalation (above-SRMC share rises -0.01 → 0.027 → 0.038). Retitled away from "intensifies".

## Bugs fixed during implementation
1. Locale: machine `LC_TIME` is Chinese → month axis labels rendered "5月 2022". Fixed with
   `Sys.setlocale("LC_TIME","C")`.
2. F3 phantom "NA" 100% bar: (a) `rbindlist` of year-rows vs All-row bound by position (grp/tier
   swapped) → added `use.names=TRUE`; (b) pivotality panel has a lone `2025-01-01` boundary instant
   → `year=2025` → `grp=NA` drawn full-height. Filtered F3 & F5 to 2022-2024.

## Coverage note (for the writeup)
F1 d_t and F3/F5 (pivotality panel) cover 2022-2024; F2 (directions cost record) covers 2021-2024.

## Revision (same session, user feedback)
- Plain-language relabel of every title/axis/legend (no `d_t`/`SRMC`/`N-0` jargon); checked all text for overlap.
- F1: shaded + labelled **low-rent** (2022 fuel spike) and **high-rent** (2023) regions.
- F2: highlighted the small-volume/high-cost quarters (2022Q4–2023Q1, ~$349/MWh) and tied to F1's high-rent period.
- F3: dropped the invisible ex-ante tier (now 3 categories); kept **"pivotal"** wording (user: not "essential");
  added footnote explaining pivotal via the minimal-combination-of-other-SA-units test.
- F4: replaced above-SRMC metric with **share of capacity offered above $300/MWh** (fixed threshold well above
  ~$100/MWh gas cost — a model-free SRMC stand-in). New one-time cached step `_price_daily.rds` computes
  per-unit-day high-price shares from the bid cache. Group n baked into x-axis labels to avoid on-bar overlap.
  Values: share>$300 rises 77.4% → 82.4% → 83.8% across every-day → direction → pivotal-direction.
- F5 (pivotality vs non-sync) dropped per user. Files renamed: F1_compensation_vs_fuel, F3_pivotal_composition.

## Revision 2 — F5 run-up figure (user request)
- New **F5_runup.png**: for each direction episode, the change in the offer for its directed intervals from the
  **first bid version to the last version before issue**, on x = hours before the direction is issued.
- Two scopes (the user's "two versions"): **full directed period** vs **first hour** (onset = first 12 intervals;
  confirmed sensible — single interval too short, ~6 versions/episode in the first hour). Reuses `ONSET_N=12`.
- Two metrics (rows): capacity offered (MW) and share offered above $300/MWh (SRMC-free, consistent with F4).
- Two lines: Synchronise (start up) vs Remain (keep running).
- Built by recomputing per-version run-up from the bid cache with the validated episode-mapping logic from
  `05_directions/B_rebid_runup.R` (foverlaps), $300 threshold; cached to `_runup_versions.rds` (~10-min one-time).
- **KEY FIX:** first cut plotted the pooled LEVEL by Δ-bin → showed a spurious *decline* in the price share toward
  issue (composition: different episodes enter different bins, contradicts the validated within-episode rise).
  Switched to **baseline-relative (within-episode) change vs each episode's first version** — the same
  normalisation B uses for MAXAVAIL. Now the share above $300/MWh clearly rises (~0 → +2 to +6 pts) in the run-up
  for all four series; capacity is noisier/mixed (title leads with the robust price signal).
- Coarsened near-issue bins (final 3h pooled) because the last bins had few versions (n≈12–36).

## Revision 3 — integrated figures into the proposal (`06_estimation/build_docs.R`)
Proposal is authored in `build_docs.R` (officer, text inline) → `outputs/docs/proposal.docx`. Restructured:
- Added `FIG`/`CAP` helpers (`body_add_img` + caption paragraph).
- **§1 Motivation:** + Figure 1 (volume/cost, F2_volume_cost.png) — rent is large and doesn't track volume.
- **§2 retitled "directions, the directed price, and pivotality":** + Figure 2 (price/fuel, F1_compensation_vs_fuel.png)
  by the d_t-exit paragraph; expanded the pivotality definition (minimal-combination test, N-0 vs N-1) + Figure 3
  (F3_pivotal_composition.png) with the 58/14/28 split.
- **§5 Descriptive evidence (new):** Figure 4 (F4) + Figure 5 (F5) with plain-language paragraphs.
- Identification (→§6) and Methodology (→§7) moved under descriptive; **Contribution & Timeline dropped**.
- Figures renumbered to APPEARANCE order (doc Figure N ≠ PNG F#): doc Fig1=F2_volume_cost, Fig2=F1_compensation_vs_fuel,
  Fig3=F3_pivotal, Fig4=F4_rebidding, Fig5=F5_runup. Captions + in-text refs reconciled.
- Verified: 5 images embedded, section order 1-2-3-4-5(desc)-6-7-Refs, regenerated cleanly (proposal.docx ~1 MB).

## Revision 4 — plain-language proposal (second version)
- New script `06_estimation/build_proposal_v2.R` → `outputs/docs/proposal_v2.docx` (original `proposal.docx`
  and `build_docs.R` left untouched, per request).
- Same structure (1 Motivation, 2 Background+pivotality, 3 RQ, 4 Data, 5 Descriptive evidence, 6 Identification,
  7 Methodology, Refs) and same 5 figures, but prose rewritten: concise, factual, low-jargon, no rhetorical/
  emotional language. Dropped inline `[F#]` fact tags for a clean reading copy (kept `[CITE]` literature markers).
  Replaced "triple-difference"/"two-way fixed effects"/"predetermined regressor" etc. with plain glosses.
- Verified: 5 images embedded, sections + figures in order, no leftover `[F#]`/emotional terms.

## Status: COMPLETE. Verified by running both build scripts + docx structure checks. Two proposal versions coexist:
proposal.docx (original) and proposal_v2.docx (plain-language).
