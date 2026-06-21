# Bid-data extraction — handoff brief for Claude Code

## What I'm trying to achieve
Empirical study of strategic withholding by South Australian synchronous generators around AEMO's directed-price mechanism for system-strength directions. The outcome variable is **out-of-merit MW**: for each 5-minute interval, the MW a unit offers in price bands priced **above the SA regional reference price (RRP)** — i.e. capacity offered but parked where it won't be dispatched. Headline question: does withholding rise/fall with the directed price `d_t` (the 90th percentile of trailing-365-day SA RRP). Unit of interest is Torrens Island B (TORRB1-4); full panel is all SA generators.

To compute out-of-merit MW I need, per interval: band **volumes** (BIDOFFERPERIOD), band **prices** (BIDDAYOFFER), and **RRP** (DISPATCHPRICE). I also want the full **rebid history** (all bid versions) for conduct analysis.

## The data-volume constraint (the whole reason the code looks the way it does)
- `BIDPEROFFER` is ~**55 GB uncompressed per month** (every 5-min bid, every DUID, every bid type). Cannot land it on disk.
- I'm on **Windows** — no shell `grep`/`funzip`/`unzip -p`; `fread(cmd=)` pipes don't work.
- Solution: **stream the CSV inside the zip with a base-R `unz()` connection**, read in line-chunks, keep only the rows I want, discard the rest. The 55 GB never exists on disk or in RAM. Then **cache the filtered slice to `.rds`** so reruns are instant.
- Decompression cost is identical regardless of how many rows I keep (the filter decides what is *retained*, not what is *streamed*), so keep **all SA generators** and **all bid versions** in one pass — widening *those* is free, and re-streaming later is the thing to avoid.
- **But filter `BIDTYPE=="ENERGY"` AT EXTRACTION** — this is the size lever. `BIDTYPE` takes ~11 values: `ENERGY` plus the FCAS markets `RAISE6SEC, RAISE60SEC, RAISE5MIN, RAISEREG, LOWER6SEC, LOWER60SEC, LOWER5MIN, LOWERREG` and (post-2023) `RAISE1SEC, LOWER1SEC`. Keeping all of them makes the cache **~8–11× larger** for no benefit: out-of-merit MW / withholding / the directed-price response all live entirely in the **energy** bid. So move the `ENERGY` filter from the Part-B analysis up into `extract_bids`, before the cache write. (FCAS would only matter for an energy/FCAS co-optimisation extension, which is not in the design — if ever needed, re-extract then.)
- **Sizing with energy-only:** ~30–40 SA DUIDs × 288 intervals × ~30 days × a few versions ≈ 10⁵–10⁶ rows/month in the volume table → tens of MB per month as `.rds`, comfortably **< 1 GB across the full 2021–2024 window**. All-bidtypes would push toward several GB and slow the per-month parse — energy-only is firmly laptop-workable.

## Hard-won schema facts (these cost a lot to discover — do not re-derive)
> **CRITICAL — the bid format is NOT stable across 2021–2024. Only Jan 2022 is confirmed.** The loop will cross at least one and possibly two transitions, so **read the `I` (header) row of each month's file and branch on what's actually there — never hard-code the Jan-2022 layout.** Known/likely transitions:
> - **5MS changeover (~Oct 2021)** sits at the very start of the window. Months *before* it may carry the genuinely old 30-minute `BIDPEROFFER` (`PERIODID` **1–48**, different columns, period = 30 min) rather than the 5-minute `BIDOFFERPERIOD` (`PERIODID` **1–288**) validated for Jan 2022.
> - **Possible later DVD/packaging change (2022–2024)**: the `_D`-named tables NEMOSIS expects exist *somewhere* for the recent period; AEMO may have re-migrated. Do not assume the legacy filename keeps returning `BIDOFFERPERIOD` for all of 2023–2024.
> - **Per-month guard the loop must apply:** detect the period column and its range (assert `max(PERIODID)` is 48 *or* 288 and set the interval-step to 1800 s or 300 s accordingly); detect whether an explicit `INTERVAL_DATETIME` column exists vs needing reconstruction from `TRADINGDATE`+`PERIODID`; detect the price table's key columns (`SETTLEMENTDATE`/`OFFERDATE`/`VERSIONNO` vs a new-schema equivalent). If a month's header doesn't match a known layout, **stop with a clear message** rather than silently mis-parsing.


- Under the **legacy DVD filename** `PUBLIC_DVD_BIDPEROFFER_<YYYYMM>...zip` the content is actually the **new 5MS table `BIDOFFERPERIOD`** (this is why NEMOSIS/nemwebR report the data "missing" for 2021–2024 — they look for `_D` names).
- `BIDOFFERPERIOD` (volumes) cols: `DUID, BIDTYPE, TRADINGDATE, OFFERDATETIME, PERIODID, MAXAVAIL, BANDAVAIL1..10, ...`
  - **`PERIODID` runs 1..288 = 5-MINUTE intervals** (NOT 30-min). Interval-ending time = `midnight(TRADINGDATE) + PERIODID*300s`. There is **no** trading-day offset.
- `BIDDAYOFFER` (prices) is the **legacy schema**: `DUID, BIDTYPE, SETTLEMENTDATE, OFFERDATE, VERSIONNO, PRICEBAND1..10`, plus rebid fields (`REBIDEXPLANATION, REBID_CATEGORY, REBID_EVENT_TIME, REBID_AWARE_TIME, REBID_DECISION_TIME, ENTRYTYPE`).
- The two tables **share no version key** (`OFFERDATETIME` vs `OFFERDATE`+`VERSIONNO`). So: collapse each to its **final state independently** — latest `OFFERDATETIME` per (DUID, interval) for volumes; latest `OFFERDATE,VERSIONNO` per (DUID, trading-day) for prices — then **join on (DUID, trading-day, band)**. (Day-final prices × interval-final volumes is a mild approximation, fine for the reduced form.)
- `DISPATCHPRICE`: filter `INTERVENTION==0`, `unique` by interval; `SETTLEMENTDATE` is the 5-min interval-ending stamp → joins directly to `INTERVAL_DATETIME`.
- Parsing details: AEMO datetime is `"%Y/%m/%d %H:%M:%S"`, tz `Australia/Brisbane`. The MMSDM `I` row has **4 leading metadata fields**; column names = `I-row[-(1:4)]`, data (`D`) rows start at field 5.
- **`unz()` quirk:** must be opened as `con <- unz(zip, inner); open(con, "rt")`. Opening via `unz(..., open="rt")` directly throws `"seek not enabled for this connection"` on chunked `readLines`.
- Bid tables have **no region column** — select SA units by **DUID list**, obtained from `DUDETAILSUMMARY` (filter `REGIONID=="SA1"`, `DISPATCHTYPE=="GENERATOR"`).

## What I've already validated (single month = 202201)
Script `gate3_202201.R`, structured in three parts, runs clean on Jan 2022:
- **A0 — discover** SA generator DUIDs from `DUDETAILSUMMARY` (cached).
- **A — extract + cache** the bid slice for all SA generators: `unz()` streaming + in-R DUID filter, `BIDTYPE=="ENERGY"` filtered, typed, all columns and all bid versions kept, with reconstructed 5-min `INTERVAL_DATETIME`. Caches `bid_cache/BIDOFFERPERIOD_202201.rds`, `BIDDAYOFFER_202201.rds`, `DISPATCHPRICE_202201.rds`.
  - *Note:* the validated Jan-2022 script currently keeps all bidtypes and filters ENERGY in Part B; per the size decision above, move that filter into Part A (`extract_bids`) when looping.
- **B — analyse** (reads cache): filter ENERGY, resolve as-dispatched version, melt bands long, join prices + RRP, compute out-of-merit MW.
- Result sanity-checked: offered = flat 840 MW (4×210 MW units, full availability), daily out-of-merit ~490–740 MW, and OOM **dips on the days RRP spiked** (Jan 10, 31) exactly as the withholding mechanism predicts. `na_rrp ≈ 0` after the 5-min fix.

## What I need Claude Code to help build next
1. **Loop the extraction over 2021-01 … 2024-12.** Wrap Part A in a month loop, one cached `.rds` per table per month, skip-if-cached. Keep per-month memory bounded (`rm()` + `gc()` after each month; only the streamed chunk + filtered slice should ever be in RAM).
2. **Stitch into a panel** from the cached slices; handle the **month-boundary interval** (PERIODID 288 → next day 00:00, whose RRP is in the next month's price file).
3. **Preserve rebid history**: the *cache* keeps all versions; only Part B dedups. Rebid/conduct analysis must read the full-version cache, not the deduped analysis output. (A version-differencing step to flag price-rebid vs volume-rebid per unit-day is a planned add.)
4. **Generalise the same stream+filter+cache pattern to the other panel tables**: `DISPATCHLOAD` / `DISPATCH_UNIT_SCADA` (per-unit dispatch, for the online set + pivotality), `DISPATCHCONSTRAINT` + `GENCONDATA` (system-strength constraint binding flag — filter to the SS CONSTRAINTIDs in the stream), `DISPATCHREGIONSUM` (SA demand + VRE), and Adelaide STTM gas. Same DUID-or-key filter, same monthly cache.

## Environment / dependencies
- Windows; **R + data.table** only (no shell tools, no NEMWEB access assumptions beyond HTTPS download).
- Download + URL helpers come from my existing `sa_directions_feasibility.R` (`read_mmsdm`, `url_dvd`, `download_try`, `RAW_CACHE`, `POLITE_DELAY`); it is guarded by `if (sys.nframe()==0L)` so `source()` only loads functions.
- Streaming reader, `fetch_zip_paths`, `stream_named`, `type_table`, `get_sa_duids`, `extract_bids` are all defined in `gate3_202201.R` — reuse them; don't rewrite the streaming logic.
