# Plan: Direction_clean/ rebuild — Stage 0 (inventory) + Stage 1 (outcome: withholding)

**Status:** DRAFT (awaiting approval)
**Date:** 2026-07-04
**Scope of this pass:** Stage 0 + Stage 1 ONLY, per the user's explicit gating instruction. Stages
2-5 (residual demand, RQ1/RQ2 regressions, appendix/figures) are designed at a high level below
for context but NOT built this pass — each future stage gets its own plan + approval.

---

## Context

The existing `Direction/` pipeline accumulated ~30 scripts across 6 numbered folders through
exploratory iteration (pivotality, SRMC, supply curves, the withhold-to-be-directed design just
built). It answers the RQ but the artifact trail is not something an outside economist could pick
up cold — internal jargon (`pex`, `d_t`, `piv_n1`) is undocumented outside scattered `facts_memo.md`
entries, and the design evolved rather than being specified upfront.

This rebuild starts a **parallel, clean pipeline** (`Direction_clean/`, sibling to `Direction/`,
which stays untouched) that (a) states the identification logic once, upfront, in a README; (b)
uses plain-language names everywhere a reader-facing artifact is produced; (c) reuses the expensive
cached data `Direction/` already built (bid ladder, essentiality flag, SRMC, direction/compensation
records) rather than re-extracting; and (d) adds the one genuinely new component, a residual-demand
competition control, which separates "responds to being essential" from "responds to the payment
size" — the core identification move the existing pipeline didn't have.

## Confirmed reuse map (verified this session, not guessed)

| Need | Source (read-only, from `Direction/`) | Notes |
|---|---|---|
| Bid ladder (quantities + price bands, latest in-force version/day) | `bid_cache/BIDOFFERPERIOD_YYYYMM.rds` + `bid_cache/BIDDAYOFFER_YYYYMM.rds` | Same join pattern as `wo_stage1_baseline.R`/`wo_stage2_opportunity.R`: latest `OFFERDATETIME`/`OFFERDATE` per (DUID, interval)/(DUID, day); one ladder per (DUID,day) asserted. Raw files hold **all NEM DUIDs** — filter to the relevant DUID list per stage. |
| Essentiality flag (rivals-only) | `outputs/descriptives_v3/pivotality_panel.rds`, columns `pex_torrens_island_b` / `pex_pelican_point_gt` / `pex_osborne_gt_st` | TORRB2/3/4 all read the same station column (confirmed identical timing across sisters — Stage 4b this session). Own offer/availability never enters. |
| Engineering SRMC | `outputs/descriptives_v3/GateA_srmc_params.csv` (`duid, yyyymm, srmc_marginal, srmc_allin, gas_gj, incr_hr, vom_mwh`) | Maintained cost measure, raw $/MWh, no rescaling. |
| Direction events + compensation price | `direction_data/parsed/direction_events.rds`, `direction_costs.rds`, `outputs/descriptives/gate0_dt_series.rds` (`dt_recon`) | `dt_recon` = the "compensation price" in plain-language outputs. |
| Realised directed/synchronise flags | `direction_data/parsed/treatment_panel.rds` | |
| Leakage audit + non-degenerate as-usual-cell code pattern | `04_market_power/wo_stage2_opportunity.R` lines ~98-108 | Reused as a pattern (re-run inside Direction_clean/, not sourced directly, since it's tied to Direction/'s own file layout) and re-reported in Direction_clean/'s Stage-0/1 findings, per the user's explicit instruction to carry both audits over. |
| Timezone convention | `force10()` helper (`as.POSIXct` + `attr(tzone)="Etc/GMT-10"`) used throughout `Direction/04_market_power/wo_stage*.R` | Both `Etc/GMT-10` and `Australia/Brisbane` labels appear in the source caches; both are UTC+10, no DST — force a single tzone and assert on a known directed interval, exactly as `stage0_inventory.md` already documented once. |

## Confirmed gaps (checked this session, not assumed)

| Need (for which future stage) | Status | Resolution |
|---|---|---|
| **Registered capacity per DUID** (Stage 1 denominator, needed NOW) | Not cached anywhere. `00_data_spine/extract_core.R`'s `get_sa_duids()` fetches AEMO's `DUDETAILSUMMARY` table but discards every column except DUID once `SA_DUIDS_YYYYMM.rds` exists. | **Small, in-scope fix.** `nem_cache/` has no leftover raw archive (cleaned up after original extraction), but AEMO NEMWEB is reachable from this environment (verified: `curl nemweb.com.au` → HTTP 301, i.e. reachable). Stage 0 does one targeted live pull of `DUDETAILSUMMARY` for a single representative month, keeps the capacity column (name TBD — will be asserted/reported once pulled, not guessed) for the 5 focal DUIDs only (TORRB2/3/4, PPCCGT, OSB-AG — not the full ~128-DUID SA roster). This reuses the AEMO download mechanism conceptually (URL pattern + streaming unzip, `sa_directions_feasibility.R`/`extract_core.R`) without sourcing/modifying `Direction/`'s scripts — a small ~20-line standalone fetch in `Direction_clean/`, since sourcing the original file wholesale would carry unwanted side effects (its own `setwd`, big-table DuckDB logic). |
| Full SA1 rival roster (Stage 2) | Available, not blocking now: `get_sa_duids()` / `bid_cache/SA_DUIDS_YYYYMM.rds`, ~128 DUIDs/month, dynamic (fleet changes over the sample). | Deferred to Stage 2's own plan. |
| Regional (SA1) demand (Stage 2/3) | Partial: no `DISPATCHREGIONSUM` cache; can be summed from `DISPATCHLOAD_YYYYMM.rds` `TOTALCLEARED` across all SA1 DUIDs (realised dispatch, not full demand incl. any unmet load — caveat to carry). **Must verify `DISPATCHLOAD_*.rds` actually holds all ~128 SA1 DUIDs and not just the 13 synchronous-fleet DUIDs used for pivotality** — not yet confirmed, flagged for Stage 2's own inventory check. | Deferred to Stage 2. |
| Interconnector flow, realised (Stage 2) | **Not extracted at all** — confirmed absent from both `bid_cache/` and `nem_cache/` (no `DISPATCHINTERCONNECTORRES`). Forecast flow was already ruled out as unextracted in the prior design (`stage0_inventory.md` §5). | Deferred to Stage 2 — will need a new small extraction (realised flow only; forecast is out of reach without a much bigger PREDISPATCH/P5MIN pipeline, consistent with the prior design's Threat-B discussion). Stage 2's own plan will size this. |

Everything Stage 0+1 in this pass actually needs is fully available or fixable with the one small
capacity pull above — the bigger gaps (interconnector, region-wide demand, full rival roster) only
matter for Stage 2, which is correctly gated to its own future pass.

---

## Folder structure — `Direction_clean/` (sibling to `Direction/`, which is untouched)

```
Direction_clean/
  README.md                        <- glossary, identification logic, markup-literature paragraph,
                                       reuse map, data dictionary (short name -> glossary term), stage map
  00_inventory/
    inventory_check.R              <- live checks: row counts, tz assertion, focal-unit registered
                                       capacity pull, sample window + focal-unit list confirmation
  01_outcome_withholding/
    build_outcome.R                <- cheap capacity (a) $300 fixed / (b) 2xSRMC cost-indexed,
                                       both capped at declared availability, both as share of
                                       registered capacity; threshold sweep; agreement rate;
                                       channel decomposition; distributions
  outputs/
    00_inventory/
      findings.md
      focal_unit_registered_capacity.csv
    01_outcome_withholding/
      findings.md
      cheap_capacity_panel.rds
      threshold_sensitivity.csv
      ab_agreement_by_month.csv
      channel_decomposition_<unit>.csv   (one per focal unit, or one combined csv with a unit column)
      distribution_by_unit.png
  quality_reports/
    plans/2026-07-04_direction-clean-stage0-1.md
    session_logs/
```

`02_competition_control/`, `03_rq1_essentiality/`, `04_rq2_compensation_price/`,
`05_supporting_figures/` are named in the README's stage map (so the intended structure is visible
upfront) but not created as working folders until their own stage is planned and approved.

---

## README.md content (written this pass)

1. **Glossary** (defined once, used consistently in every plain-language output):
   - **Direction** — an AEMO instruction to a generator to start up or keep running, for system
     security reasons, outside the normal market dispatch process.
   - **Essential / essentiality** — whether the system would fail a minimum-security requirement
     without this unit, based on rivals' state only (the unit's own bidding never enters this test).
   - **Compensation price** — the regulated reference price used to compensate a directed generator
     (internal short name `dt`/`comp_price`; formerly "d_t").
   - **Offer curve** — the schedule of price/quantity pairs a generator submits, showing how much
     capacity it makes available at each price.
   - **SRMC** — short-run marginal cost; the engineering-estimated cost of running the unit,
     independent of what it bids.
   - **Residual demand** — the demand left over for one generator after subtracting all rivals'
     offered supply; a direct measure of how much competitive pressure that generator faces.
   - **Capacity withdrawn (physical withholding)** — declared availability cut below the unit's
     normal level.
   - **Capacity priced out (economic withholding)** — availability unchanged, but capacity offered
     above the withholding threshold price.
2. **Identification logic** (verbatim structure from the user's brief): essentiality bundles
   compensation-eligibility and ordinary market power; RQ1 alone can't separate them; RQ2's
   payment-size variation is the separating instrument; the two identifying objects are (i) the
   essentiality coefficient in RQ1 after the competition control enters, (ii) the payment-size
   coefficient in RQ2.
3. **Outcome-measure framing paragraph** (markup literature: Wolfram 1999; Borenstein, Bushnell &
   Wolak 2002; Hortaçsu & Puller 2008 evaluate energy-market markups; this pipeline's primary
   outcome is capacity-based because the conduct under study operates on the availability margin;
   markup benchmark reported in the Stage-5 appendix as the literature-standard cross-check).
4. **Reuse map + gaps** (the two tables above, condensed).
5. **Data dictionary** — every internal column name used in any output, mapped to its glossary term
   (e.g. `pex` -> "essential", `dt`/`comp_price` -> "compensation price", `cheap_a`/`cheap_b` ->
   "cheap capacity, fixed-threshold / cost-indexed definition", `withdrawn`/`priced_out` -> the two
   channels).
6. **Stage map** — all 6 stages (0-5) named in plain language with one-line descriptions and status
   (DONE / this pass / planned), so the intended full pipeline is visible even though only Stage 0-1
   exist as code this pass.
7. **Focal units** — TORRB2, TORRB3, TORRB4, PPCCGT (primary); OSB-AG (descriptive only — near-must-
   run, no withholding contrast); BARKIPS1 excluded (no cheap tranche exists even competitively).

---

## Stage 0 — `00_inventory/inventory_check.R` + `outputs/00_inventory/findings.md`

One page. For every table in the reuse map: grain, time resolution, join keys, provenance. States
the sample window (202201-202412) and the focal-unit list. Documents the interval-ending convention
(AEMO timestamps label the interval by its end) and the tz fix (force `Etc/GMT-10` everywhere,
assert on one known directed interval — reusing the exact check pattern from
`Direction/outputs/withhold_opportunity/stage0_inventory.md` §3, since that page already got this
right and there's no reason to re-derive it).

**New work this stage:** the one live AEMO pull for registered capacity (5 focal DUIDs, one
representative month — capacity doesn't change often, but the script will pull 2-3 months and
assert they agree, flagging any capacity change as a finding rather than assuming it's static).
Output: `focal_unit_registered_capacity.csv` (duid, capacity_mw, source_month, column_name_as_found).

Includes the gap table above (registered capacity RESOLVED this stage; region demand and
interconnector flow explicitly flagged as NOT YET AVAILABLE / deferred to Stage 2, so the reader
sees the known limitation upfront rather than discovering it later).

## Stage 1 — `01_outcome_withholding/build_outcome.R` + `outputs/01_outcome_withholding/findings.md`

Per focal unit-interval (TORRB2/3/4, PPCCGT; OSB-AG descriptive only), reusing the exact bid-ladder
join pattern from `wo_stage1_baseline.R`/`wo_stage2_opportunity.R` (latest in-force version,
BANDAVAIL x PRICEBAND cumulative-capped-at-MAXAVAIL construction — same arithmetic, renamed
variables):

1. **Cheap capacity, two co-primary definitions**, both capped at declared availability
   (`MAXAVAIL`), both expressed as **share of registered capacity** (using Stage 0's lookup):
   - (a) fixed-threshold: MW effectively offered at or below $300/MWh.
   - (b) cost-indexed: MW effectively offered at or below 2x that unit-month's `srmc_marginal`.
2. **Threshold sweep**: (a) at $150/$500; (b) at 1.5x/3x SRMC. Report per unit.
3. **Agreement rate between (a) and (b)**: share of intervals where the two definitions classify
   the same way; where they disagree, break down by month and flag whether disagreement
   concentrates in high-gas months (expected) or is spread evenly (would be a surprise worth
   investigating, not smoothing over) — if the disagreement set is near-empty, state plainly that
   this is itself evidence the threshold choice is innocuous, per the user's instruction.
4. **Channel decomposition** (physical vs. economic withholding), one table per unit: among
   withheld intervals, share where (i) availability is cut below normal ("capacity withdrawn"),
   (ii) availability is normal but price is high ("capacity priced out"), (iii) both.
5. **Distribution per unit** — report the Torrens bimodality (large share of ordinary competitive
   intervals sitting at the $0-floor tranche only) as a **finding**, carried over from
   `Direction/outputs/withhold_opportunity/stage1b_diagnostics.md`'s [F6a]-equivalent result, not
   re-derived from scratch as if new, but re-verified independently in this cleaner pipeline (the
   numbers should closely match; if they don't, that's itself a finding to report, not silently
   reconcile).

**Reused audits, re-reported here per the user's explicit instruction:** the leakage regression
(essentiality flag on the unit's own `MAXAVAIL` and own cheap-capacity measure, expect R²≈0) and the
non-empty "bid as usual" cell check — both re-run against Stage 1's own outcome construction (not
just copy-pasted from `Direction/`'s numbers), so a genuine discrepancy would surface.

---

## What this pass does NOT do (explicitly out of scope, per the user's gating instruction)

- Stage 2 (residual demand / competition control) — the priority next build, but its own plan.
- Stage 3 (RQ1 regression), Stage 4 (RQ2 regression, CEM matching, June-2022 handling).
- Stage 5 (offer-curve figures, cost figure, markup-benchmark appendix, plain-language summary).
- Any modification to `Direction/` — read-only reuse only.

## Verification

1. Run `Rscript 00_inventory/inventory_check.R` then `Rscript 01_outcome_withholding/build_outcome.R`
   from `Direction_clean/`. Both must exit cleanly with row-count assertions passing.
2. Confirm `focal_unit_registered_capacity.csv` has 5 rows, one per focal DUID, with a real MW value
   (sanity-checked against the known plant sizes already documented in `Direction/`'s SRMC docs —
   e.g. Torrens B units, Pelican Point CCGT, Osborne cogen — flag any implausible value rather than
   accept it silently).
3. Confirm the two audits (leakage regression, non-degenerate as-usual cell) reproduce results
   consistent with `Direction/outputs/withhold_opportunity/stage2_findings.md` (R²≈0; non-empty
   as-usual cell for every testable unit) — a material discrepancy is a bug to chase, not a
   footnote.
4. `Read` `outputs/01_outcome_withholding/findings.md` and confirm it uses only glossary terms
   (no `pex`, `d_t`, `piv_n1` etc. leaking into the plain-language findings prose) and that every
   rate is reported with its denominator.
5. Present both findings files to the user for review before touching Stage 2, per the explicit
   "stop after each stage" instruction.
