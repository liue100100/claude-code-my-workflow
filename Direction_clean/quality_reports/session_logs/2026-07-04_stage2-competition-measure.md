# Session log — 2026-07-04 — Direction_clean/ Stage 2 (competition faced: residual demand)

## Goal
Build the priority new component: a generator-specific competition measure (residual-demand
slope near the realised spot price) that lets RQ1 separate "responds to being essential" from
"has market power because the system needs it." Build through Stage 2's own explicit gate
(correlation with essentiality), then stop for review — no Stage 3 this pass.

## Data resolved this session (all three open questions from Stage 0/1)
1. Full rival roster = the 65 SA1 generators that actually submit ENERGY bids — confirmed to
   exactly match `DISPATCHLOAD`'s coverage; the other ~45 SA1-registered generators never bid,
   so no new bid extraction was needed, just widening the existing DUID filter.
2. Regional demand — pulled `DISPATCHREGIONSUM` live (new, small extraction, reusing the Stage-0
   AEMO download mechanism) for the authoritative `TOTALDEMAND`, not a generator-summation proxy.
3. Interconnector flow — pulled `DISPATCHINTERCONNECTORRES` live; SA's links are `V-SA` (Heywood)
   and `V-S-MNSP1` (Murraylink); confirmed empirically (not assumed) that positive `MWFLOW` =
   import into SA (correlates +0.475 with SA demand in a spot check).

## Build
- `extract_demand_interconnector.R` — 36 months × 2 tables, cached into `Direction_clean/`, never
  touching `Direction/`. One real hiccup: my own diagnostic command piped the first run through
  `head -60`, which SIGPIPE-killed the R process after 60 lines — misread as a script bug at
  first. Re-ran cleanly (skip-if-cached made the re-run cheap); all 36 months confirmed present.
- `build_residual_demand.R` — for each of 3 station groups (Torrens Island B covering
  TORRB1/2/3/4, Pelican Point, Osborne), scanned all ~65 rivals' bid ladders per month, evaluated
  cumulative rival supply on a 7-point local price grid around RRP, computed both a direct-grid
  and a kernel-smoothed slope (derived a fixed-coefficient closed form for the kernel slope since
  the grid offsets are the same for every row — no per-row regression needed), residual demand
  under both interconnector treatments, and the implied markup.
  - **Leave-out assertion passes exactly (0.00e+00) across all 36 months** — recomputed one
    station's rival supply directly from non-station rows and compared against the
    subtraction-based calculation used throughout.
  - **Bug caught before shipping:** the first `cor()`/`median()` aggregation had no
    `use="complete.obs"`/`na.rm=TRUE`, so ~756 boundary-gap NA rows (0.08% of the panel) silently
    turned every slope-agreement number into NA. Fixed; re-derived the aggregation from the
    already-built panel rather than re-running the full 36-month scan.
  - Slope methods agree well: corr(direct-20, kernel) = 0.98 for every station; corr(direct-5,
    kernel) = 0.81-0.82 (sensibly lower — a tighter window is noisier against the smoother kernel
    estimate, not a red flag).
- `stage2_gate_report.R` — joined the essentiality flag, computed the gate correlation.
  - **Second bug caught:** the markup column explodes numerically wherever slope is close to (but
    not exactly) zero — up to ~1e22 in magnitude, 37.5% of finite values exceeding |100|. A raw
    correlation against essentiality came back as a suspiciously exact 0.000 for every station —
    degenerate, not a real null. Fixed with a documented, generous trim (|markup|<=10) and
    reported the exclusion rate (62.7-67.4%) rather than hiding it. Flagged as a first-order
    caveat Stage 5's markup appendix will need to inherit.

## Headline finding (the gate)
**Not the collinearity risk the plan flagged, but not a clean story either.** The linear
correlation between the competition measure and essentiality is small everywhere (Torrens -0.036,
pooled -0.018) — on its face, plenty of independent variation for Stage 3. But this sits in
tension with the conditional means: essential intervals ARE somewhat tighter on average (Torrens
mean slope -5.04 vs. -3.31 non-essential; Osborne -14.45 vs. -3.51, visually striking in the
figure despite n=18). Reconciliation: the competition measure has a large point mass at exactly
zero (6.7-9.6% of intervals per station — rivals already saturated within the local $50 window),
which flattens Pearson correlation regardless of the real variation in the tail. Recorded as a
methodological flag for Stage 3: a raw correlation isn't the right diagnostic here, and the
zero-slope mass point may need explicit handling (e.g. its own indicator), not treatment as
ordinary continuous variation.

## Status: Stage 2 COMPLETE through its own gate. Stopped per the approved plan — Stage 3 (RQ1
regression, with vs. without the competition control) needs its own plan and approval.

## Open for the user
- Review `outputs/02_competition_control/stage2_gate_report.md` and the distribution figure.
- Decide how to carry the zero-slope mass point into Stage 3 (continuous control vs. an explicit
  "saturated" indicator, or both).
- Housekeeping carried over: nothing committed in `Direction/` since 2026-06-21; nothing yet
  committed in `Direction_clean/` at all.
