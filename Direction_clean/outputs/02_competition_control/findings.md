# Stage 2 build findings -- the competition measure (Direction_clean/)

Per 5-min interval, for each of the 3 focal generator groups (Torrens Island B [covers TORRB2/3/4],
Pelican Point [PPCCGT], Osborne [OSB-AG]): stacked all OTHER SA1 rivals' offered capacity (capped at
their own declared availability) on a local price grid around the realised SA1 spot price, and
computed the resulting competition measure two ways. See README glossary.

## Rival population and data sources
65 SA1 generators submit energy bids (confirmed to exactly match realised-dispatch coverage -- the
other ~45 SA1-registered generators never bid at all and were never part of the competitive stack).
Regional demand from the authoritative SA1 total-demand series (not a generator-summation
approximation); interconnector flow (Heywood + Murraylink) confirmed empirically to be signed
positive = import into SA (rises with SA demand, r=0.475 in a one-month check).

## Leave-out check (must pass in code, not just by design)
Recomputed one station's rival supply directly from only the non-station rows and compared against
the subtraction-based calculation used throughout: **max absolute difference = 0.00e+00 across all 36
months** (i.e. exactly zero after floating-point tolerance) -- confirms no focal station's own
offers ever enter its own competition measure.

## Slope-estimate agreement (direct-grid vs. kernel-smoothed)
- **osborne_gt_st**: corr(direct-20,kernel) = 0.979, corr(direct-5,kernel) = 0.81, median abs diff = 0.374361 (n=315648, 0.08% NA, 6.67% zero-slope)
- **pelican_point_gt**: corr(direct-20,kernel) = 0.98, corr(direct-5,kernel) = 0.814, median abs diff = 0.227871 (n=315648, 0.08% NA, 9.57% zero-slope)
- **torrens_island_b**: corr(direct-20,kernel) = 0.98, corr(direct-5,kernel) = 0.819, median abs diff = 0.322083 (n=315648, 0.08% NA, 6.7% zero-slope)

## Coverage caveats (reported, not smoothed over)
- **756 of 946944 rows (0.08%) are NA** -- a small month-boundary gap where the demand/interconnector
  cache doesn't perfectly line up with the bid data's interval range at a few month edges. Excluded
  from the correlation/median above (`use="complete.obs"`), not silently zero-filled.
- **A real share of intervals have exactly zero slope** (rivals already saturated within the local
  $50 price window, so the competition measure doesn't move locally) -- reported per station above
  as `zero_slope_pct`; the implied markup is undefined/infinite for these and excluded from any
  markup summary, not forced to a number.

## What this build does NOT decide
This script only builds the competition measure. The Stage-2 gate (correlation with the
essentiality flag, and whether the two are near-collinear for Torrens) is a separate script
(`stage2_gate_report.R`) and a separate stop-and-review point, per the approved plan.

