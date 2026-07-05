# Stage 0 — Inventory, grains, join keys, time alignment

Revealed-preference "withhold-to-be-directed" opportunity-set design. This document is written
BEFORE any computation, per the staged protocol. **It ends with one blocking decision (§5) that must
be resolved before Stage 2 can be built without circularity/look-ahead.**

Focus units: TORRB2, TORRB3, TORRB4, PPCCGT (primary); OSB-AG, BARKIPS1 (secondary).
Sample window: 202201–202412 (bid/dispatch caches present for all 36 months). Region SA1.

---

## 1. Input tables — grain, resolution, key columns, provenance

| Table | Grain | Time resolution | Key columns | Provenance / notes |
|---|---|---|---|---|
| `bid_cache/BIDOFFERPERIOD_YYYYMM.rds` | **per (DUID, target 5-min interval, bid version)** | 5-min | `DUID`, `INTERVAL_DATETIME` (interval-ending), `OFFERDATETIME` (submission), `TRADINGDATE`, `PERIODID`, `MAXAVAIL`, `BANDAVAIL1..10`, `PASAAVAILABILITY` | The quantity offer. 27.6M rows/month (all NEM DUIDs) — must filter to focus DUIDs first. `INTERVAL_DATETIME` tz = **Australia/Brisbane**. |
| `bid_cache/BIDDAYOFFER_YYYYMM.rds` | **per (DUID, trading day, bid version)** | daily | `DUID`, `SETTLEMENTDATE` (trading day), `OFFERDATE` (submission), `VERSIONNO`, `PRICEBAND1..10`, `REBID*` fields | The price ladder (10 bands, non-decreasing). Bands are daily; quantities (BIDOFFERPERIOD) vary intra-day. Join to quantities by (DUID, trading day). |
| `bid_cache/DISPATCHLOAD_YYYYMM.rds` | per (DUID, 5-min interval, intervention flag) | 5-min | `SETTLEMENTDATE` (interval-ending), `DUID`, `INTERVENTION`, `TOTALCLEARED`, `INITIALMW`, `AVAILABILITY`, `SEMIDISPATCHCAP`, `UIGF` | **Realised** dispatch. tz = Australia/Brisbane. |
| `bid_cache/DISPATCHPRICE_YYYYMM.rds` | per (region, 5-min interval, intervention) | 5-min | `SETTLEMENTDATE`, `REGIONID`, `RRP`, `INTERVENTION` | Realised SA1 spot. |
| `outputs/descriptives_v3/pivotality_panel.rds` | **per 5-min interval** (SA-wide, station columns) | 5-min | `SETTLEMENTDATE`, `nonsync_mw`, `short`, `piv_*` (realised), `pex_*` (ex-ante), `depth_ex_*`, `on_*` (online counts) | **All derived from REALISED dispatch** (see §5). tz = Australia/Brisbane. 315,646 rows. |
| `direction_data/parsed/direction_events.rds` | **per direction event × DUID** | event | `duid`, `issue_time`, `effective_time`, `cancellation_time`, `direction_instruction` (Synchronise/Remain), `reason`, `region` | Issue/effective/cancel timestamps. tz = **Etc/GMT-10**. 1,638 rows (incl. non-SA-focus + header NAs). |
| `direction_data/parsed/direction_costs.rds` | **per report_event** (may aggregate DUIDs/intervals) | event | `report_event`, `direction_start`, `direction_end`, `directed_mwh`, `compensation_payment`, `retained_trading_amount`, `additional_compensation`, `cra` | 121 rows. Episode-level $; implied $/MWh = compensation / directed_mwh (coarse). |
| `outputs/direction_rebid/episodes.rds` | **per episode × DUID** | event | `episode_id`, `duid`, `station`, `instruction`, `tau`(=issue), `s`(=effective), `c`(=cancel), `lead_h`, `dur_h` | Cleaned episode table (built from events). 1,492 rows (Synchronise+Remain, SA focal stations). |
| `direction_data/parsed/treatment_panel.rds` | **per (DUID, 5-min interval)** | 5-min | `duid`, `interval_datetime`, `directed`, `synchronise` | Realised directed/synchronise flags. tz = Etc/GMT-10. 375,264 rows. |
| `outputs/descriptives_v3/GateA_srmc_params.csv` | **per (DUID, yyyymm)** | monthly | `duid`, `yyyymm`, `srmc_marginal`, `srmc_allin`, `gas_gj`, `incr_hr`, `vom_mwh` | Engineering SRMC, maintained cost measure. ~$120 marginal for TORRB. 432 rows. |
| `sa_minimum_generator_combinations.csv` | **per acceptable combination** | structural | `combination`, `regime`, `non_sync_mw` (validity threshold), `syn_cons`, per-station required counts, `secure_for_island` | 122 combos; regimes {system_normal, risk_island_or_island}; non_sync_mw ∈ [1300,2500]; syn_cons ∈ {0,2,4}. **Exogenous/structural** — the security requirement. |

---

## 2. Join keys and the bid-time alignment logic

**Core alignment (the thing most likely to be silently wrong):**

1. **Bid version → 5-min interval.** BIDOFFERPERIOD is already exploded to (DUID, INTERVAL_DATETIME, OFFERDATETIME). The **offer in force for interval `T`** = the version with the largest `OFFERDATETIME ≤ (gate closure of T)`. In dispatch, gate closure ≈ the interval itself; operationally take `max(OFFERDATETIME) ≤ INTERVAL_DATETIME` for that interval. Rebids after the interval must never be used (that is the run-up look-ahead trap handled earlier).
2. **Quantity ↔ price.** Join BIDOFFERPERIOD (quantities, per interval-version) to BIDDAYOFFER (prices, per day-version) on `(DUID, trading day)`, taking the **latest** daily price version. Assert one price-ladder per (DUID, day) after picking latest; report any residual duplication.
3. **Interval → direction issue.** Each episode has `tau` (issue). For an interval `T`, the relevant *bid-time reference* is the version in force at `T`. Whether `T` is "in the opportunity window" is a function of forecast state at `T`, not of `tau` directly — `tau` is used only to (i) locate realised directions and (ii) define the Stage-4 outcome (was a direction issued for intervals overlapping `T`).
4. **SRMC.** Join by `(DUID, yyyymm)` — monthly SRMC applied to every interval in that month.
5. **Pivotality / state.** Join by `interval (SETTLEMENTDATE == INTERVAL_DATETIME)` and map station column → DUID.

**Grain of the analysis:** the unit of observation is the **(DUID, 5-min interval)**, with the in-force
bid version attached. Everything rolls up from there.

---

## 3. Timezone & interval-convention flags (must fix before any join)

- **Two tzone LABELS for the same clock.** `Etc/GMT-10` (direction_events, treatment_panel) and
  `Australia/Brisbane` (BIDOFFERPERIOD, DISPATCHLOAD, pivotality) are **both UTC+10 with no DST**, i.e.
  identical wall-clock. POSIXct joins compare underlying instants, so they align *if the parse was
  correct* — but I will **force a single tzone** (`Etc/GMT-10`) on every timestamp column before
  joining, and assert equality on a known direction interval, to rule out a silent parse offset.
- **Interval-ENDING convention.** AEMO `INTERVAL_DATETIME` / `SETTLEMENTDATE` label the interval by its
  **end**: `INTERVAL_DATETIME = 00:05` is the interval covering 00:00–00:05 (PERIODID 1 → +5 min,
  PERIODID 7 → 00:35). Direction `effective_time`/`cancellation_time` are instants. When flagging an
  interval as directed, an interval-ending timestamp `T` is inside `[effective, cancellation]` iff
  `effective < T ≤ cancellation` (verify the boundary convention against a known episode).
- **`OFFERDATETIME` tz** printed as POSIXct without an explicit label — will normalize and confirm it is
  NEM UTC+10 (a 10-hour error here would invert the run-up ordering).

---

## 4. SRMC and directed-price (d_t) sources

- **SRMC:** engineering `srmc_marginal` (raw $/MWh, monthly, per DUID). Maintained cost measure; no rescaling. ~$120 for TORRB.
- **d_t (needed at Stage 3/4):** two candidate sources, to be chosen at Stage 3 and reported both ways:
  1. **Reconstructed d_t** — trailing-365-day 90th percentile of SA spot (`outputs/descriptives/gate0_dt_series.rds`, monthly) — the DCP compensation reference price; predetermined, smooth (this is the "prize" used throughout the prior work, [F1]).
  2. **Realised episode $/MWh** — `direction_costs`: `compensation_payment / directed_mwh` per report_event (coarse, event-level).
  Default for the payoff-sorting test (Stage 4ii): the reconstructed d_t, because it is predetermined and available for every interval.

---

## 5. BLOCKING ISSUE — the "known at bid time" state variables do not exist as forecasts

Stage 2(b) requires the direction-probability / tightness inputs to be **exogenous state known at bid
time**: min-sync constraint binding/near-binding **in pre-dispatch**, **non-sync share forecast**,
**interconnector flow forecast**. 

**None of these forecast tables are extracted in the repo.** `nem_cache/` holds only raw *bid*
archives (ARCHIVE_BIDDAYOFFER / ARCHIVE_BIDOFFERPERIOD zips); `bid_cache/` holds only BID*, DISPATCH*,
and the pivotality panel. Confirmed: no PREDISPATCH, P5MIN, STPASA/MTPASA, SS_SOLUTION, CONSTRAINTSOLUTION,
or INTERCONNECTORRES.

Consequently every tightness/pivotality variable currently available is built from **REALISED
dispatch**:
- `nonsync_mw` = realised `TOTALCLEARED` of SA semi-scheduled units (`pivotality.R`).
- `short`, `piv_*`, `pex_*`, `depth_*` = realised online status + realised nonsync vs the min-combo file.
- `pex_*` ("ex-ante") only removes the **focal unit's own realised online indicator**; it still uses
  **rivals' realised online status and realised nonsync** — i.e. it guards *own-offer* leakage
  (Threat A) but NOT *look-ahead timing* (Threat B: the target interval's realised system state was not
  fully known when the bid was submitted).

**Two distinct circularity threats to keep separate:**
- **Threat A — own-offer leakage:** opportunity set must not depend on the unit's realised MAXAVAIL /
  withheld quantity. Addressable now via the Stage-1 counterfactual-normal-bid imputation + `pex`-style
  removal of the unit's own contribution. The mandated post-Stage-2 audit (regress opportunity
  indicator on realised MAXAVAIL) tests exactly this.
- **Threat B — look-ahead timing:** "known at bid time" strictly requires *forecast* state. With only
  realised data, any tightness variable uses information not available at submission. This cannot be
  fully fixed without extracting forecast tables.

**Decision required before Stage 2 (options):**
- **(1) Extract forecasts** — pull PREDISPATCH/P5MIN region solution (nonsync & demand forecast),
  INTERCONNECTORRES (flow forecast), and CONSTRAINTSOLUTION for the SA system-strength constraint(s)
  from NEMWEB archive, aligned to each interval's bid-time snapshot. Clean "known at bid time," but a
  real extraction effort (new pipeline, ~the size of the existing dispatch extraction).
- **(2) Proceed with a realised-state proxy** — build (a) from the counterfactual-normal bid + rivals'
  realised offers (guards Threat A), and (b) from realised `nonsync_mw`/`short` + structural min-combo
  membership. Explicitly label the design as carrying **look-ahead in the state variables** (Threat B
  unresolved) — a consistency/descriptive test, not a clean bid-time-information test. Report it as such.
- **(3) Hybrid** — proceed with (2) now to get the structure and the leakage audit working, and treat
  forecast extraction as a robustness upgrade for the identifying Stage-4ii result only.

I recommend stating a choice here explicitly rather than defaulting, because it changes what Stage 2's
"opportunity" means and how strongly Stage 4 can be worded.

---

## 6. Assertions to run at each join (self-check contract)
- After latest-version pick: exactly one price ladder per (DUID, day); one in-force quantity version per (DUID, interval). Report duplicates.
- Row counts reported at every filter/join; no rate without a denominator.
- Flag any many-to-one / one-to-many blowup vs expected.
- tzone forced identical on all timestamp columns; assert on a known directed interval.

**STOP — Stage 0 complete. Awaiting the §5 decision before constructing Stage 1/2.**
