# Session log — 2026-07-04 — Direction_clean/ Stage 0 (inventory) + Stage 1 (outcome: withholding)

## Goal
Start the clean rebuild of the SA-directions strategic-bidding study: a plain-language, gated
pipeline in a new sibling folder `Direction_clean/`, reusing `Direction/`'s cached data read-only.
This session: Stage 0 (inventory) and Stage 1 (the withholding outcome) only, per explicit gating.

## Setup
- New folder created at project root (had to `mv` it up one level after an initial `mkdir`
  mistakenly nested it inside `Direction/`).
- README.md written first: glossary, RQ1/RQ2 identification logic, the markup-literature framing
  paragraph, reuse map, data dictionary, stage map (0-5).

## Stage 0 — inventory
- Confirmed 36 cached months (202201-202412), row counts for every reused table (bid ladder,
  essentiality panel 315,646 rows, SRMC 432 rows, direction events 1,638, compensation-price series
  35 months, realised directed flags 375,264 rows).
- **Anomaly caught, not smoothed over:** the first timezone-check attempt picked a directed
  interval from 2021 (`treatment_panel.rds` spans back to 2021 and holds only directed rows,
  wider than the essentiality panel's 202201-202412 coverage) and correctly found 0 matching rows.
  Fixed by restricting the check to the confirmed sample window; documented in findings.md rather
  than just silently fixed in code.
- **Registered capacity gap, resolved:** `Direction/` never cached this. Confirmed AEMO's
  `DUDETAILSUMMARY` table (which the existing pipeline does query, for the DUID list only) has no
  capacity field at all; the field lives in a different table, `DUDETAIL`
  (`REGISTEREDCAPACITY`/`MAXCAPACITY`). Verified nemweb.com.au is reachable from this environment,
  reused the existing AEMO download mechanism (`sa_directions_feasibility.R`'s `read_mmsdm()`,
  sourced read-only — confirmed side-effect-free to source) to pull it for the 5 focal units at
  both ends of the sample window. Confirmed stable (TORRB2/3/4=200MW, PPCCGT=478MW, OSB-AG=180MW)
  — matches public knowledge of these plants, a good sanity check.

## Stage 1 — the withholding outcome
- Built both co-primary cheap-capacity definitions (fixed $300/MWh; cost-indexed 2xSRMC), both
  capped at declared availability, both as a share of registered capacity, over all 1,578,240
  focal-unit-interval rows. Zero join failures (no missing price ladder, no missing SRMC match).
- Threshold sweep, agreement rate ((a) vs (b) agree 96-100% per unit; worst case 3.9%, PPCCGT),
  and the monthly disagreement-vs-gas-price correlation (positive for TORRB2/3/4 as expected, near
  zero for PPCCGT, undefined for OSB-AG which never disagrees).
- Channel decomposition (physical "capacity withdrawn" vs. economic "capacity priced out" vs.
  both): physical withholding dominates for every unit, but 10-33% of withheld intervals also show
  a "both" signature — a real secondary economic-withholding channel, not purely a quantity story.
  Internal consistency check ("neither" category) passed at ~0% for every unit/definition.
- Distribution reconfirms the Torrens bimodality independently (69-77% of ALL intervals at the
  $0-floor), matching `Direction/`'s existing finding without copying the number.
- **Both reused essentiality-flag audits (leakage regression, non-degenerate bid-as-usual cell)
  re-run from scratch against this pipeline's own variables and closely reproduce
  `Direction/`'s numbers** (R² 0.0000-0.0028; same essential-interval counts, 4,083/4,083/4,083/
  267/18) — a strong independent cross-validation of the essentiality-flag reuse.
- **Bug caught before shipping:** the first "is disagreement near-empty" check used `min()` across
  units instead of `max()`, trivially picking OSB-AG's 100%-agreement case rather than
  characterizing the worst case. Fixed to report the correct worst-case number (3.9%, PPCCGT) and
  re-ran the full script to regenerate consistent findings.

## Status: Stage 0 + Stage 1 COMPLETE, verified, findings written in plain language (glossary
terms only, checked). Stopped here per the explicit gating instruction — awaiting review before
Stage 2 (residual-demand competition control) is planned.

## Open for the user
- Review `outputs/00_inventory/findings.md` and `outputs/01_outcome_withholding/findings.md`.
- Stage 2 (the priority next build — residual demand / competition control) needs its own plan;
  known gaps going into it: full SA1 rival roster is available (not cached as a single table, but
  reconstructable), region-wide demand is only partially available (would need summing per-unit
  dispatch across confirmed SA1 roster — not yet verified that dispatch cache covers the full
  roster vs. just the ~13 synchronous-fleet units), interconnector flow is not extracted at all.
- Housekeeping carried over from `Direction/`: still nothing committed there since 2026-06-21.
