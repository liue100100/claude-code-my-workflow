# Stage 1–3 record — NER 3.15.7B additional-compensation claims audit, focal units 2022–2024

Task: resolve the make-whole premise behind Test 4's rent dose. Constraints honored: no
estimation code or headline outputs touched; scratch computations only
(`stage23_make_whole.R`, session scratchpad; all numbers below reproduced from
`Direction/direction_data/parsed/direction_costs.rds` / `direction_events.rds`,
`GateA_srmc_params.csv`, `gate0_dt_series.rds`).

## Stage 1 — the claims record

### 1a. The pipeline's own source IS the primary documentary record

The old-format workbook parsed into `direction_costs.rds` — AEMO, *"NEM Event System security
energy directions to SA generators 1 January 2021 to 7 January 2023.xlsx"* (extended by monthly
vintages to Oct 2023) — carries per-event columns `additional_compensation` and `ie_fee`. These
are **determined outcomes, not claims**: they populate after the independent-expert process
concludes. Coverage: 121 events, 2021-01 → 2023-10 vintages.

**Headline: 105 of 121 events (87%) carry a positive additional-compensation amount; 94 carry an
independent-expert fee.** Top-ups under 3.15.7B were routine across the whole sample, not
exceptional.

### 1b. The bound window (Apr–Jun 2022), every event, verbatim from the record

| start | end | MWh | DCP comp | RTA | **additional (3.15.7B)** | IE fee | implied DCP $/MWh |
|---|---|---|---|---|---|---|---|
| 04-06 | 04-16 | 3,694 | 475,399 | 214,913 | **538,278** | 6,000 | 128.7 |
| 04-16 | 04-23 | 2,053 | 288,895 | −77,102 | **307,238** | 2,850 | 140.7 |
| 04-23 | 04-25 | 2,146 | 314,194 | 186,236 | **469,907** | 2,850 | 146.4 |
| 05-02 | 05-14 | 949 | 180,922 | 25,758 | **44,729** | 0 | 190.7 |
| 05-14 | 05-20 | 1,917 | 390,320 | 177,835 | **369,839** | 3,800 | 203.6 |
| 05-20 | 05-25 | 3,721 | 818,484 | 800,812 | **272,189** | 3,562 | 220.0 |
| 05-28 | 05-31 | 1,323 | 327,766 | 82,014 | **373,731** | 2,375 | 247.7 |
| 06-03 | 06-06 | 3,139 | 817,920 | 487,851 | **946,240** | 3,562 | 260.6 |
| 06-14 | 06-16 | 2,411 | 66,296 | −12,050 | **358,767** | 7,267 | 27.5 |
| 06-24 | 06-25 | 225 | 65,174 | 497 | **74,328** | 3,633 | 289.3 |

Totals: 21,578 MWh; DCP compensation **$3.75M**; additional compensation **$3.76M** (ratio
1.003); IE fees $0.04M. Every bound-window event received a top-up. Combined payment ≈
$348/MWh of directed energy against a TORRB all-in SRMC of $322/MWh — the make-whole floor,
delivered. Negative RTAs appear (06-14 event: −12,050), consistent with market-revenue netting
raising settlement above the DCP. Note: the 06-14→06-16 window sits inside the market
suspension; part of its top-up may run through suspension compensation (3.14.5A) rather than
3.15.7B — flagged, not reconciled.

No later-vintage amendments to Apr–Jun 2022 windows exist in the record (0 rows).

### 1c. The regime split — the top-up signature

| regime (TORRB all-in vs d_t, event month) | events | DCP comp | additional | addl/comp |
|---|---|---|---|---|
| normal (d_t > cost) | 70 | $109.9M | $19.3M | **0.175** |
| floor binds (cost > d_t) | 10 | $3.75M | $3.76M | **1.003** |

The additional-compensation share jumps from ~18% to ~100% exactly when the formula price falls
below cost. This is the make-whole signature, in-sample, in the window that matters.

### 1d. Public determinations (web record)

AEMO publishes the independent-expert determinations as market event reports. Verified pages
(AEMO blocks automated retrieval, HTTP 403, so page titles/URLs only; amounts above come from
the parsed workbook):

- Independent Expert Report — Directions to a SA generator, billing weeks 1–4, 5–8, 9–12,
  29–32, 33–36 **2022** (and 29–32, 33–36, 37–40, 41–44 **2021**), aemo.com.au market event
  reports.
- Independent Expert Report — **Additional compensation to generators during billing weeks
  25–26 2022** (the June-2022 crisis window).
- Expert: Sami Aoude, IES Advisory Services, appointed under NER 3.15.7B(c)(1) (thresholds:
  claims > $20k individual / $100k aggregate trigger the expert process).

**No-record list (explicit, per task):** dedicated IE-report pages for billing weeks 13–16,
17–20, 21–24 of 2022 (≈ April–early June) were not directly traceable in search results —
only the market-event-reports index page. The determined amounts for those windows nonetheless
appear in the parsed AEMO workbook (table 1b), so the determinations exist; the individual
report pages are simply not link-resolvable from here. Post-2024 determinations: not searched
(out of window).

## Stage 2 — reconciliation against the pipeline's dollars

**Which case obtained: (c), with the documentary record then answering the question.**

- The post-Oct-2023 unit-episode window contains **zero** focal episodes with SRMC > d_t (264 of
  264 sit in the normal regime; 2 episodes with Jan-2025 issue dates fall outside the 2022–2024
  SRMC/d_t coverage and were dropped, reported here). The registered fit-split test is therefore
  uninformative for that window, exactly as pre-registered under case (c).
- In the normal group the DCP fit is `comp = 0.999 × (MWh × d_t)`, R² = 1.000 (mean residual
  $62) — the `compensation_payment` column is **DCP-stage (3.15.7(c))**, clean.
- But the top-ups are not absent post-Oct-2023 — they sit in the separate
  `additional_compensation` column: nonzero in 190 of 264 focal episodes, totalling **$11.1M
  against $56.9M of DCP compensation (19.5%)**; median addl/comp ratio 0.42 among nonzero rows.
- The question then falls to the documentary record for Apr–Jun 2022 (Stage 1), which shows
  top-ups present, material, and equal to ~100% of the formula payment where the floor binds.

**⚠ Contradictions with prior pipeline characterizations (flagged, not silently reconciled):**

1. `findings_task1b.md` and the Test-4 registration describe additional compensation as
   "immaterial" and the 2022 binding period as "unmeasured." Both statements are wrong at the
   event grain: the old-format record carries determined additional-compensation dollars back
   to 2021, including the bound window, and the amounts are material (17.5% of comp overall;
   100% where the floor binds). Task 1b's formula-fit conclusion (comp ≈ gross × d_t) remains
   correct — it describes the DCP column only.
2. The manuscript text added for Test 4 (§2 footnote: "the channel is unmeasured" in the bound
   months; §8: "if 3.15.7B top-ups are complete where they bind…") is now partly superseded:
   the channel IS measured at event grain and the top-ups were paid. Correction is a
   manuscript decision (Case B mapping in the memo).
3. The paper's $141.9M headline transfer: if it is built from `compensation_payment` (DCP) only,
   settled payments including 3.15.7B run ~17–20% higher in normal months. Not resolved here;
   follow-up item for the transfer-accounting passages.

## Stage 3 — the sub-cost exposure bound

Directed MWh × (TORRB all-in SRMC − d_t) over the ten bound unit-months, all bound-window MWh
priced at the Torrens cost (upper bound):

| month | MWh | d_t | all-in | gap dollars |
|---|---|---|---|---|
| 2022-04 | 7,893 | 156.5 | 322.2 | $1.31M |
| 2022-05 | 7,909 | 252.6 | 322.2 | $0.55M |
| 2022-06 | 5,776 | 241.4 | 322.2 | $0.47M |

**Bound: $2.32M = 1.64% of the $141.9M headline.** Cross-check against the record: actual
bound-window top-ups paid were $3.76M (the excess over the pure fuel-gap bound is loss-of-revenue
and start-cost components the engineering SRMC bound does not price). Either number is < 3% of
the headline. **Pre-registered reading applies: the make-whole question is immaterial to the
transfer accounting; it matters only for the choice of dose variable.**
