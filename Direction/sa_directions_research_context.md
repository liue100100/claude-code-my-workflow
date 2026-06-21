# Research project context — SA directions & strategic bidding

> Handoff brief for Claude Code. Read this first at the start of a session. It captures the
> research question, the regulatory mechanism being studied, the identification strategy, the
> data assets and their landmines, and the current state of work. Filenames in §6 should be
> verified against the actual repo — confirm before assuming.

---

## 1. Research question

Do South Australian synchronous generators — Torrens Island B in particular — strategically
withhold energy so as to route themselves into AEMO directions and collect the directed-price
compensation (the per-MWh reference price `d_t`), and does that behaviour respond to the size of
`d_t`?

The hypothesis is that being directed on is a *rent* when the directed price exceeds what the
unit could earn (or its cost) in the prevailing market, so units have an incentive to position
themselves to be directed when that rent is large, and to stop when it shrinks.

---

## 2. The directed-price mechanism (institutional core)

This is the heart of the design — get it exactly right.

### 2.1 The compensation formula (NER clause 3.15.7(c))

A directed participant providing energy is compensated by a formula:

```
DCP = AMP × DQ
```

- **DCP** — Directed Participant Compensation (dollars). This is the `compensation_payment`
  column in the cost data.
- **AMP** — the **directed price `d_t`**. It is the price below which 90% of the relevant
  region's spot prices fell, over the **12 months immediately preceding the trading day on which
  the direction was issued**. i.e. a trailing-365-day **90th percentile** of the SA regional
  price, recomputed per direction by issue date.
- **DQ** — the *counterfactual* additional energy: actual energy delivered minus what the unit
  would have delivered had the direction not been issued. For a unit directed to **synchronise**
  (was offline / not market-dispatched), DQ ≈ its directed output.

Because `DCP = AMP × DQ`, the ratio `compensation_payment / directed_mwh` recovers **AMP
exactly** (up to aggregation across directions with different issue dates inside one reporting
event). So the implied $/MWh series *is* `d_t`, not an approximation of it.

### 2.2 Related quantities

- **RTA** — Retained Trading Amount (NER 3.15.6(b)): the spot settlement the unit already
  received for the additional energy. **Initial settlement compensation = DCP − RTA.** This is
  the `retained_trading_amount` column; it takes negative values (it nets the unit's market
  revenue). Net rent ≈ `(AMP − prevailing spot) × DQ`.
- **Additional compensation** (NER 3.15.7B): a second-stage claim for loss of revenue + net
  direct costs less amounts already received, assessed by an **independent expert** (e.g.
  Synergies). These are the `additional_compensation` and `ie_fee` columns.
- Cost recovery from the market is governed by NER 3.15.8 (`cra` column).

### 2.3 Why the mid-2023 drop is the identifying variation

AMP depends *only* on prices over the **preceding** 12 months, so it is **predetermined**
relative to today's bidding decision. The 2022 SA price spike (concentrated ~May–Jul 2022, plus
the June 2022 administered-price period) pushed the 90th percentile up to a plateau (~$348–352/MWh
across 2022Q3–2023Q1 in the data). As those high-priced intervals roll out of the trailing window
~mid-2023, AMP falls mechanically (~$232 in 2023Q3, ~$197 in 2023Q4). The decline is smooth and
appears across several independent monthly report files — the signature of intervals leaving the
window one day at a time, **not** a reporting artefact.

Key consequence: the drop date is **computable in advance from the price history alone**, and the
mid-2022 prices that drive it cannot plausibly be caused by mid-2023 strategic bidding. `d_t` is
therefore a clean, predetermined "prize" variable.

### 2.4 Rule changes inside the 2021–2024 window (for control-group construction)

The `DCP = AMP × DQ` / 90th-percentile formula itself was **unchanged** across 2021–2024. Two
framework changes land in-window but affect the *affected*-participant side, not the directed
price:

- **1 October 2021** ("Application of compensation in relation to AEMO interventions"):
  intervention pricing was **removed** for services not traded in the market — system strength and
  voltage control — and affected-participant compensation is no longer payable for interventions
  that don't trigger intervention pricing (e.g. system-strength directions). So for the
  system-strength/security directions that dominate this dataset, AEMO does **not** run the
  intervention-pricing counterfactual and "affected" units are not compensated. Genuine *energy*
  directions still trigger a second NEMDE "intervention pricing run" that excludes directed units.
- **1 August 2022** ("Compensation for market participants affected by intervention events"):
  folded FCAS into the automatic framework (3.12.2), introduced a volume-weighted energy
  compensation for scheduled loads, redefined "BidP", and required AEMO to publish a compensation
  methodology. **Did not change the directed 90th-percentile formula.** Note this in a footnote so
  a referee cannot claim the mid-2023 break coincides with a compensation-method change — the
  method change is a year earlier and on a different limb.

The `reason` field (System security / System strength / System security - voltage) effectively
flags which regime applied, and hence whether an intervention-price counterfactual and
affected-participant records exist for that event.

### 2.5 Caveats to hold

- **June 2022 is its own regime.** Market suspension + APC + directions compensation overlap
  (~$148.8M across the three schemes that month); bidding was administrative, not strategic. Drop
  or dummy it.
- **The ~$348–352 plateau** reflects the 90th percentile sitting in the spike-inflated tail; treat
  the drop as a cap-like-to-uncapped transition when describing magnitude, not a free-floating
  price decline.
- **Out of sample (context only):** in late 2025 AEMO proposed replacing this with a
  technology-specific VWAP-based preliminary-compensation methodology, citing June 2022. The paper
  studies the 90th-percentile regime in what may be its final years — a policy hook, not an
  estimation concern.

---

## 3. Identification strategy

- **Reduced-form event study** centred on relative time to the mid-2023 spike-exit date, comparing
  directed-eligible SA synchronous units against a control set. Scrutinise pre-trends hardest here.
- **Triple-difference**: interact `d_t` × pivotality × requirement-active status.
- **Inference**: wild-cluster bootstrap (few clusters).
- The first stage to demonstrate: directed intervals / `d_t` visibly jump as the spike enters and
  drop at the window-exit date. If `d_t` doesn't move, the design loses power.

Candidate **outcomes** (all from the bid panel): offer-price level, fraction of capacity offered
near the price cap, withheld MW, and rebid intensity. Keep clear which margin each measures —
bidding *while directed* (constrained on) is mechanically distinct from bidding that *anticipates*
the directed-price incentive, which is the behaviour of interest.

---

## 4. Data assets

### 4.1 Bid panel (extracted, 202201–202412)

Built by the month-by-month extraction pipeline (see §6). Energy-only (`BIDTYPE == "ENERGY"`), SA
generators only, 5-minute resolution (`PERIODID` up to 288), all bid versions retained. Per-month
RDS caches in `bid_cache/`:

- `BIDOFFERPERIOD_<YYYYMM>.rds` — per-band MW volumes (the large stream).
- `BIDDAYOFFER_<YYYYMM>.rds` — the ten price bands per unit-day.
- `DISPATCHPRICE_<YYYYMM>.rds` — regional dispatch prices.

Notes / landmines:
- Reconstruct the marginal offer curve by joining BIDDAYOFFER's price bands to BIDOFFERPERIOD's
  per-band MW (one-to-many; verify the join).
- All bid versions are present — **collapse to the binding (latest) version per
  DUID-interval-settlement-date** before analysis, or rebids will double-count. Keep a rebid count
  per unit-day as its own series (candidate outcome).
- `DISPATCHPRICE` is the input for **reconstructing `d_t` from primitives** (see §7).

### 4.2 `direction_events.csv` — treatment timing (1,638 rows; 1 blank row to drop)

Event log of individual directions. **Per-DUID** granularity (`report_event` + `duid`). Columns:
`report_event, duid, participant, region, issue_time, effective_time, cancellation_time,
directed_resource_type, reason, direction_instruction, market_notice, directed_mwh,
compensation_payment, retained_trading_amount, additional_compensation, ie_fee, cra,
source_format, source_file`.

- Coverage: effective_time 2021-01 → 2025-01; **1,168 events inside 202201–202412**, plus 2021 as
  a pre-buffer.
- Concentration confirms the target: TORRB3 (353), TORRB4 (287), TORRB2 (266), TORRB1 (55), then
  MINTARO (236), PPCCGT (212). Mostly SA1 (1,629); a few VIC1/QLD1/NSW1 rows to filter out.
- **`direction_instruction` is the key behavioural split**: Synchronise (822) vs Remain (814).
  "Synchronise" = a unit the market wasn't dispatching gets directed on (the sharp
  withhold-then-directed margin); "Remain" = keep an already-running unit on (weaker / placebo).
  **Do not pool them.**
- `reason`: System security (1,089), System strength (386), System security - voltage (162) — maps
  to the §2.4 regime distinction.
- **Financial columns here are populated only for the "new" per-DUID reports (2023H2 onward; 443
  rows).** For 2021–early-2023 they are null — those dollars live in `direction_costs.csv`.
- Cleaning: negative event durations exist (cancellation before effective on some rows) — inspect
  and fix/drop. Messy DUIDs (`TORRB35`, `TORRB46`, `MINTARO1`) need reconciling to real DUIDs.
  Events overlap within a DUID across market notices.

### 4.3 `direction_costs.csv` — early-period financials (121 rows)

**Event-level** (per `report_event`), not per-DUID; each event bundles ~3.6 DUIDs over ~7-day
windows. Columns: `report_year, report_month, report_event, direction_start, direction_end,
directed_mwh, compensation_payment, retained_trading_amount, additional_compensation, ie_fee, cra,
source_file`.

- Coverage: 2021 → ~October 2023 (the consolidated Jan-2021→2023 workbook plus a run of monthly
  reports). This **fills the financial gap** that `direction_events.csv` leaves before 2023H2.
- This is the source of the realised `d_t` (= `compensation_payment / directed_mwh`) series that
  shows the build-up and the mid-2023 drop.
- Because it's event-level, **do not attempt to split early-period dollars per DUID** — and you
  don't need to: `d_t` is a common (region-level) reference price, with cross-unit variation coming
  from the pivotality × requirement-active interactions, not from unit-specific compensation.

### 4.4 Stitching the two financial sources

- Join key is `report_event` (matches between files for the 121 cost events).
- The two sources share **zero** `report_event` values — they're sequential, not overlapping
  (costs to ~Oct 2023; events-"new" per-DUID from 2023H2). So there's **no same-event
  cross-check.** Instead: aggregate the events-"new" per-DUID rows up to `report_event` (sum
  compensation, sum MWh), compute `$/MWh`, and confirm the series joins **smoothly across the
  late-2023 seam**.
- Crucially, that seam falls **after** the drop completes, so the old→new format change does not
  contaminate the identifying variation. State this explicitly in the paper.

---

## 5. Treatment construction

Turn the event log into interval-level treatment flags on the 5-minute grid:

1. Filter to SA1; drop the blank row and non-SA rows; reconcile DUIDs.
2. Expand each event from `effective_time` to `cancellation_time` onto 5-minute intervals, per
   DUID.
3. Take the **union** of directed intervals per DUID (overlapping notices → don't sum), yielding
   `directed_{i,t}` and a separate `synchronise_{i,t}` flag.
4. Merge onto the bid panel by DUID × interval.

---

## 6. Pipeline & environment (verify filenames against repo)

- Language/stack: **R + data.table on Windows 11**. Streaming zip reads via `unz()`.
- Extraction pipeline (as designed): `run_all.R` (driver, generates the month vector and loops),
  `run_month.R` (per-month CLI wrapper with skip-if-done, atomic caching, manifest + `.done_<M>`
  markers, per-month logs), `extract_core.R` (`extract_month(M)` with the energy filter and schema
  guard), sourcing download helpers from `sa_directions_feasibility.R`. Reuse the existing helpers
  (`read_zip_streaming`, `fetch_zip_paths`, `stream_named`, `type_table`, `get_sa_duids`,
  `extract_bids`); don't rewrite the streaming logic.
- Resume is **skip-driven off `.done_<M>` markers**, not a start-pointer — fills non-contiguous
  gaps.
- Prior brief: `bid_extraction_handoff.md`. Validated single-month reference: the 202201 script.
- Working files under `/mnt/user-data/outputs/` and `/mnt/user-data/uploads/`.

---

## 7. Immediate next tasks

1. **Reconstruct `d_t` from primitives.** From `DISPATCHPRICE`, compute the trailing-12-month 90th
   percentile of the SA regional price by direction-issue date, and **validate against the realised
   `DCP/DQ`** in `direction_costs.csv`. Agreement confirms both the price extraction and the `d_t`
   definition. Resolve definitional questions surfaced by any mismatch: 5-minute dispatch vs
   trading-interval price; treatment of capped intervals during the June-2022 APC period; exact
   price series the percentile is taken over.
2. **Build the treatment panel** per §5; produce the first-stage descriptive — directed intervals
   per SA synchronous unit per month, split Synchronise vs Remain, across the window with the
   mid-2023 `d_t`-exit date marked.
3. **Collapse the bid panel to binding versions**, reconstruct the offer stack, and build the
   candidate outcomes (offer-price level, capacity-at-cap, withheld MW, rebid intensity).
4. Then the reduced-form event study and the triple-difference.

---

## 8. Working conventions

- Concise, declarative prose; **slope-not-level** reasoning. Footnotes over body detail in
  academic writing.
- **Minimal, surgical code changes** over structural rewrites. Don't refactor working code without
  a reason.
- On schema or data surprises: **halt loudly** (assert / stop with a clear message) rather than
  silently coerce or proceed.
- Flag assumptions explicitly; don't present unverified definitions (e.g. the exact AMP price
  series) as settled until validated against the realised compensation.
