# Plan: Descriptive proposal figures — SA directions, prize, pivotality, rebidding

**Status:** DRAFT (awaiting approval)
**Date:** 2026-06-29
**Output target:** high-DPI PNG (300 dpi) for `outputs/docs/proposal.docx`

---

## Context

The research proposal needs descriptive figures that *motivate* the question — that the
directed-price (`d_t`) compensation mechanism creates a strategically exploitable rent, that
directed units are often pivotal, and that they actively rebid in anticipation. All the
underlying data already exists in `Direction/` from completed extraction and analysis work;
no new estimation is needed. This task assembles five publication-ready descriptive figures
from existing cached panels into one self-contained script.

The economic hook the figures must convey:
- `d_t` is the **trailing-365-day 90th percentile of SA spot** (`01_prize/descriptive_analysis.R`
  Gate 0). It is mechanically **backward-looking**, so it stays elevated after underlying fuel
  costs fall — opening a widening, predictable rent.
- Gas (Adelaide STTM) is the contemporaneous SRMC driver. The **temporal misalignment** between
  the lagged `d_t` and contemporaneous gas is the core motivating fact.

## Deliverable

One new script **`Direction/proposal_figures.R`** (self-contained, `setwd` to `Direction/`,
mirrors the style of `01_prize/descriptive_analysis.R`). Writes five PNGs + companion CSVs +
a short `readout.md` to a new **`Direction/outputs/proposal_figures/`**. Reuses existing
data; does not re-run extraction or estimation.

Libraries: `data.table`, `ggplot2`, `scales` (all already used in the repo). Dual-axis figures
reuse the `sec_axis(~./scale)` pattern from `descriptive_analysis.R` Cut 3 (lines 374–397).

---

## Figures

### F1 — Direction price `d_t` vs quarterly gas price (temporal misalignment)
- **d_t:** `outputs/descriptives/Gate0_dt_table.csv` (cols `yyyymm`, `dt_recon`, `dt_real`,
  blended `dt`). Use blended `dt` (prefers realised, falls back to reconstructed), monthly.
- **Gas:** parse `Quarterly_STTM_Price.CSV` (Adelaide $/GJ). **Reuse the exact parser** from
  `02_cost/gate_a_srmc.R` lines 39–64 (`MONTH_MAP`, quarter-end → 3 monthly rows step function);
  filter `202201`–`202412`.
- **Plot:** dual y-axis time series. Left = `d_t` ($/MWh) solid line; right = gas ($/GJ) step line.
  Caption states `d_t` = trailing-365-day 90th-pct ⇒ lagged. Annotate the gap where gas has fallen
  but `d_t` remains high (the rent window).

### F2 — Direction volume & cost over the sample
- **Source:** `direction_data/parsed/direction_events.rds` (has `source_format`, `issue_time`,
  `directed_mwh`, `compensation_payment`) and `direction_costs.rds` (old-format event-level).
- **Overlap guard (must verify in implementation):** old format (`source_format=="old"`,
  ~2021→2023H1) is event-level; new format (`=="new"`, 2023H2+) is per-DUID. Determine the format
  boundary month and sum old-format rows up to it, new-format after — replicating the no-overlap
  rbind in `descriptive_analysis.R` lines 88–106. Print a per-quarter row-source table to confirm
  no temporal double-count before plotting.
- **Plot:** quarterly bars = total directed MWh (left axis) + line = total compensation $ (right
  axis). Quarterly to align with the gas cadence.

### F3 — Pivotality composition of directed intervals (directly pivotal / N-1 / ex-ante / none)
- **Source:** directed interval-stations from `treatment_panel.rds` (`directed==1`) mapped to
  station via the `STAT` lookup (copy from `rebid_analysis.R` lines 18–23), merged with
  `outputs/descriptives_v3/pivotality_panel.rds` on `SETTLEMENTDATE`. **Reuse the merge pattern**
  from `pivotality_decomposition.R` lines ~100–110 (`dir_is` ⋈ `pl`).
- **Mutually-exclusive tiers** (most→least binding hierarchy):
  1. **Directly pivotal (N-0):** `piv == 1`
  2. else **N-1 secure pivotal:** `piv_n1 == 1 & short_n1 == 0` (the `piv_n1_clean` definition,
     `pivotality_decomposition.R` line 44 — the literal `piv_n1` is trivially TRUE so the secure
     filter is required; see memory `project-constraint-decomposition`)
  3. else **ex-ante pivotal:** `pex == 1`
  4. else **non-pivotal**
- **Plot:** stacked bar of directed-interval share in each tier, by year (plus an "all years"
  total bar). Directly answers "how many were directly pivotal, N-1 pivotal…".

### F4 — Rebidding across three samples (3-panel small-multiple)
- **Source:** `outputs/descriptives_v3/rebid_pivotality_daily.rds` (unit-day level; cols
  `n_versions`, `quan_withheld`, `ws_escalation`, `piv_share`, `directed_day`).
- **Three samples:** (a) whole sample = all unit-days; (b) all direction intervals =
  `directed_day==1`; (c) directly-pivotal direction intervals = `directed_day==1 & piv_share>0`.
- **Metrics (default = all three, one panel each):** rebid frequency (`n_versions`), capacity
  withheld (`quan_withheld`, MW), price escalation (`ws_escalation`). Grouped bars: mean per sample
  with n labels.
- **Caveat (stated on the figure):** rebidding is measured at the **unit-day** granularity (the
  dataset's natural unit, = distinct offer versions per day), not the 5-min interval.

### F5 (extra, user-selected) — Pivotality vs non-synchronous penetration
- **Source:** `pivotality_panel.rds` — per quarter compute mean `piv_torrens_island_b` (pivotal
  share of the key unit) and mean `nonsync_mw`.
- **Plot:** dual-axis time series. Left = Torrens B pivotal share; right = SA non-sync MW. Shows the
  exogenous (wind+solar) driver of direction need co-moving with pivotality.

---

## Output conventions
- PNG at `dpi=300`, sized ~9×4.5 in (single) / ~11×4 in (3-panel), to `outputs/proposal_figures/`.
- Each figure writes a companion `Fn_*.csv` of the plotted data (matches existing repo pattern).
- A short `outputs/proposal_figures/readout.md` lists each figure + its one-line motivating takeaway.

## Files
- **New:** `Direction/proposal_figures.R`, `Direction/outputs/proposal_figures/` (5 PNG + CSVs + readout).
- **Read-only reuse:** `Gate0_dt_table.csv`, `Quarterly_STTM_Price.CSV`, `direction_events.rds`,
  `direction_costs.rds`, `treatment_panel.rds`, `pivotality_panel.rds`, `rebid_pivotality_daily.rds`;
  parser/merge/lookup snippets from `gate_a_srmc.R`, `pivotality_decomposition.R`, `rebid_analysis.R`.

## Verification
1. Run: `Rscript proposal_figures.R` from `Direction/` (Rscript at
   `C:\Program Files\R\R-4.4.1\bin\Rscript.exe`). Expect clean exit, console prints the F2
   overlap-source table and F3 tier counts.
2. Confirm 5 non-empty PNGs in `outputs/proposal_figures/`.
3. `Read` each PNG to eyeball: axes labelled, dual-axis scaling sane, no overflow, the F1 gas/d_t
   gap and F3 tier stack render as intended.
4. Sanity cross-checks against known facts: F3 directly-pivotal share should track the
   `pivotal_shares_base_n1_exante.csv` magnitudes; F1 d_t peak ≈ \$378/MWh (Aug 2022) decaying to
   ≈ \$175/MWh (mid-2024) per `gate0_dt_series.rds`.

## Open defaults (proceeding unless told otherwise)
- F4 shows all three rebid metrics (user left that question open).
- Volume/cost in F2 and pivotality/non-sync in F5 aggregated **quarterly**; `d_t` in F1 **monthly**.
