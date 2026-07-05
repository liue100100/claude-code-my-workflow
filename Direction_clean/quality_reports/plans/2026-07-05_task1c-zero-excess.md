# Plan — Task 1c: why are zero-excess episodes directed? (gates Task 2)

**Status:** COMPLETED (user-specified checks (a)–(e) verbatim; contractor mode)
**Script:** `Direction_clean/05_mechanism/task1c_zero_excess_forensics.R`
**Outputs:** `Direction_clean/outputs/05_mechanism/task1c_*.csv`, `findings_task1c.md`

## Target set
The 69 zero/negative-excess episodes in `task1b_panel.rds` (`excess_over_floor <= 0`;
new-format comp window 2023-10 → 2024-12, n=271).

## Checks
- **(a) Duration:** rebuild the counterfactual over the FULL direction window [s, c] —
  per-interval in-force bid at issue tau (latest BIDOFFERPERIOD OFFERDATETIME ≤ tau per
  interval, incl. next-trading-day bids where they existed at tau; daily ladder = latest
  BIDDAYOFFER OFFERDATE ≤ tau per trading date). Window excess MWh = Σ(TOTALCLEARED −
  floor)/12. Survivors = window excess ≤ 0. Report intervals with no bid at tau
  separately (floor set 0 = conservative against the artifact reading). Supplementary
  price-aware floor (bands ≤ RRP, capped at MAXAVAIL) as a labelled extra column only.
- **(b) Sequencing (survivors):** BIDOFFERPERIOD versions + BIDDAYOFFER rebids in
  [tau−48h, c]. Exit signal = version setting MAXAVAIL to 0 (or < 40 MW TORRB floor) for
  ≥1h of future intervals; availability reduction = ≥20 MW cut vs prior version;
  reversal = later restoring version. Classify: no exit signal ever / signal→direction /
  signal after direction. Quote REBIDEXPLANATION samples.
- **(c) Combination (all 69):** at tau from `pivotality_panel.rds`: short/short_n1,
  piv/piv_n1 for the unit's station, on_* counts; sister-unit state from DISPATCHLOAD
  (TORRB1–4 for Torrens; station-level on_* deltas ±4h for cross-station members).
  Report share where directed unit was needed to complete a combination another unit
  put at risk (piv/short at tau AND sister offline or heading off within ±4h).
- **(d) Instrument text:** distribution of `direction_instruction` for the 69 (parsed
  from the raw report XLSX; values are the reports' own wording) + market-notice IDs;
  best-effort WebFetch of 2–3 notices for verbatim wording. No "increase output" text
  exists in the new-format reports (only Synchronise / Remain) — verify full strings.
- **(e) Anticipation (survivors vs 202 positive-excess):** directed in prior 1/3/7 days
  (episode table); share of [tau−24h, tau] intervals with short / short_n1 / station piv
  TRUE. LIMITATION stated: realised state, not pre-dispatch forecasts (no PREDISPATCH
  extraction in repo — [F21]).

## Findings file
`findings_task1c.md` ranks four explanations by episode share with explicit
denominators + overlap matrix: (1) window-measurement artifact, (2) exit-signal
sequencing, (3) combination completion, (4) predictable floor-in-and-wait vs surprise
pre-emption; closes with the implication for Task 2's pre-registration.
