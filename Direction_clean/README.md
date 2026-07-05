# Strategic bidding around system-security directions in South Australia

This is a clean rebuild of the analysis in the sibling `Direction/` folder. `Direction/` is left
untouched — this pipeline reads its cached data read-only and does not modify or re-extract it.
Written so an economist with no electricity-market background can follow every step: every domain
term is defined once, below, and used consistently in every finding, table, and figure this
pipeline produces.

## Research questions

- **RQ1:** Do generators withhold more capacity when they are essential for system security?
- **RQ2:** Conditional on being essential, does withholding respond to the size of the direction
  compensation price?

## Identification logic

Being **essential** bundles two things: eligibility for direction compensation, and ordinary market
power (the system needs the unit, so it can charge more even absent any compensation scheme). RQ1
alone cannot distinguish them — both predict the same behaviour: an essential generator withholds
more capacity either because withholding raises its odds of being paid to come on, or simply
because the market has no substitute for it that day.

RQ2 is what separates them. Ordinary market power does not care what the compensation price is —
a unit exploiting its essentiality would charge whatever the market bears regardless of the
compensation formula. Payment-seeking does care: if withholding is partly a bet on being directed
and paid, it should intensify specifically when the payment is larger. The two objects that carry
the paper's identifying content are therefore:

1. **The essentiality coefficient in the RQ1 regression, before and after the competition control
   enters** (Stage 3) — the comparison shows how much of the essentiality response is ordinary
   market power versus something beyond it.
2. **The compensation-price coefficient in the RQ2 regression, on essential intervals versus a
   matched comparison set** (Stage 4) — whether withholding's sensitivity to the payment size is
   specific to essential intervals.

## Where this outcome measure sits in the literature

Markup-based conduct measures (Wolfram 1999; Borenstein, Bushnell & Wolak 2002; Hortaçsu & Puller
2008) evaluate offers against energy-market profit maximisation — do generators price above what
competition in the *energy* market alone would rationalise? The conduct studied here operates on a
different margin: how much capacity a generator makes *available* at all, not just how it prices
the capacity it does offer. So the primary outcome in this pipeline is capacity-based (a share of
registered capacity withheld), with the literature-standard markup benchmark reported as an
appendix cross-check (Stage 5) — evaluating the same offers against energy-market optimisation
alone, so a reader can see both lenses side by side.

## Glossary

| Term | Meaning |
|---|---|
| **Direction** | An instruction from the market operator (AEMO) telling a generator to start up or keep running, issued for system-security reasons, outside the normal market-dispatch process. |
| **Essential / essentiality** | Whether the electricity system would fail a minimum security requirement without this specific generator, evaluated using **only its rivals'** state — the generator's own bidding and availability never enter this test (Stage 0/1 carries over this construction and its audits from `Direction/`, see below). |
| **Compensation price** | The regulated reference price used to compensate a directed generator for the energy it's told to supply. Internal short name: `dt` / `comp_price`. (Called "d_t" in `Direction/`.) |
| **Offer curve** | The schedule of price/quantity pairs a generator submits to the market: how much capacity it makes available at each price level. |
| **SRMC (short-run marginal cost)** | The engineering-estimated cost of running a unit for one more MWh — built from fuel price, heat rate, and variable operating cost. Independent of what the unit actually bids; the maintained cost benchmark throughout. |
| **Residual demand** | The demand left over for one generator once every rival's offered supply is subtracted — a direct, generator-specific measure of how much competitive pressure it faces at a given moment. (Built in Stage 2, not yet in this pipeline pass.) |
| **Capacity withdrawn (physical withholding)** | Withholding by cutting *declared availability* below the unit's normal level — the capacity simply isn't offered to the market at all. |
| **Capacity priced out (economic withholding)** | Withholding by *pricing* capacity above a threshold while declared availability stays normal — the capacity is offered, but at a price unlikely to be needed. These two channels have different treatment under the market rules and are reported separately throughout. |
| **Registered capacity** | The generator's nameplate/registered maximum output (MW), used as the denominator for withholding shares. |

## Reuse map — what this pipeline reads from `Direction/`, read-only

| Need | Source | Reused as-is |
|---|---|---|
| Bid ladder (offer quantities + price bands) | `Direction/bid_cache/BIDOFFERPERIOD_YYYYMM.rds`, `BIDDAYOFFER_YYYYMM.rds` | Same latest-in-force-version join logic as `Direction/04_market_power/wo_stage1_baseline.R` |
| Essentiality flag | `Direction/outputs/descriptives_v3/pivotality_panel.rds` (`pex_torrens_island_b`, `pex_pelican_point_gt`, `pex_osborne_gt_st`) | Rivals-only ex-ante essentiality; TORRB2/3/4 read the same station column (confirmed identical timing across the three sister units) |
| Engineering SRMC | `Direction/outputs/descriptives_v3/GateA_srmc_params.csv` | Raw $/MWh, no rescaling |
| Direction events + compensation price | `Direction/direction_data/parsed/{direction_events,direction_costs}.rds`, `Direction/outputs/descriptives/gate0_dt_series.rds` | `dt_recon` = the compensation price in plain-language outputs |
| Realised directed/synchronise flags | `Direction/direction_data/parsed/treatment_panel.rds` | |
| Leakage audit + non-degenerate "bid as usual" audit | Pattern from `Direction/04_market_power/wo_stage2_opportunity.R` | Re-run against this pipeline's own outcome construction, not copy-pasted |
| Timezone convention | `Etc/GMT-10` forced on every timestamp (both `Etc/GMT-10` and `Australia/Brisbane` labels appear in source caches; both are UTC+10, no DST) | |

**Known gaps** (checked directly, not assumed): registered capacity per DUID is not cached anywhere
in `Direction/` — Stage 0 does one small, targeted live pull from AEMO to fill it for the 5 focal
units. Region-wide demand and interconnector flow are not extracted at all and are **not needed
until Stage 2** (residual demand) — see Stage 0 findings for the full gap inventory.

## Focal units

- **Primary:** TORRB2, TORRB3, TORRB4 (Torrens Island B, three of its four units), PPCCGT (Pelican
  Point CCGT).
- **Descriptive only:** OSB-AG (Osborne cogeneration) — near-must-run, offers almost all capacity
  cheap almost always, so there's no withholding contrast to test.
- **Excluded:** BARKIPS1 (Barker Inlet) — has no cheap tranche to withhold even in fully competitive
  intervals, so the withholding precondition fails for this unit.
- TORRB1 and other SA synchronous units are outside this design's focal set (see `Direction/`'s
  broader pivotality work for the full fleet).

## Data dictionary — internal short names, mapped to the glossary

| Internal name | Glossary term |
|---|---|
| `essential` (from `pex_*`) | Essential / essentiality |
| `comp_price` (from `dt_recon`) | Compensation price |
| `cheap_a` | Cheap capacity, fixed-threshold definition ($300/MWh) |
| `cheap_b` | Cheap capacity, cost-indexed definition (2x SRMC) |
| `withdrawn` | Capacity withdrawn (physical withholding) |
| `priced_out` | Capacity priced out (economic withholding) |
| `srmc` | Short-run marginal cost |
| `maxavail` | Declared availability |
| `reg_cap` | Registered capacity |
| `duid` | The generator's market identifier (e.g. `TORRB2`) |
| `yyyymm` | Calendar month (YYYYMM integer) |

## Stage map

| Stage | What it does | Status |
|---|---|---|
| 0 — Inventory | Every input table, its grain/keys/timezone; the one new data pull needed (registered capacity) | **Done this pass** |
| 1 — Outcome: withholding | Cheap capacity (fixed + cost-indexed), threshold sensitivity, physical/economic channel decomposition, distributions | **Done this pass** |
| 2 — Competition faced (residual demand) | Rivals' offer stack minus rival availability, interconnector treatment, the competition measure — the priority new build | Planned (own future approval) |
| 3 — RQ1 regression | Withholding on essentiality, with and without the competition control | Planned |
| 4 — RQ2 regression | Withholding on the compensation price, essential vs. matched comparison, June-2022 handling | Planned |
| 5 — Figures + appendix + write-up skeleton | Offer-curve figure, cost figure, markup-benchmark appendix, plain-language summary | Planned |

## How to run this pass

```
cd Direction_clean
Rscript 00_inventory/inventory_check.R
Rscript 01_outcome_withholding/build_outcome.R
```

Findings are written to `outputs/00_inventory/findings.md` and
`outputs/01_outcome_withholding/findings.md` in plain language, per the glossary above. Stop and
review both before Stage 2 is planned.
