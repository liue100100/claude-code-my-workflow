# Mechanism check, Task 1c -- why are zero-excess episodes directed? (Direction_clean/)

> **SUPERSEDED (2026-07-05).** Every number below was computed on direction windows carrying the
> +10-hour timestamp bug found in Task 1d (`findings_task1d.md`). Cite nothing from this file.
> The corrected re-run is `findings_job1_timestamp_fix.md` (Job 1 before/after table).

## VERDICT (up top): EXIT-THEN-DIRECTED, with bands parked at the floor
The zero-excess lobe is not a measurement artifact and not AEMO surprise pre-emption. It is
dominated by episodes where the unit's own bids had **withdrawn availability for the direction
window (MAXAVAIL = 0) while leaving the cheap price bands in place**, and AEMO then directed the
unit into that declared absence. The "floor block" that made these episodes look zero-excess in
Task 1 was an offer the unit had simultaneously made undispatchable: in 77% of the 69 episodes
(53/69) the in-force bid at issue declared under 5 MW of mean availability over the window it was
directed for. Ranked explanations below; the Task 2 implication is at the end.

## Target set and denominators
The 69 zero/negative-excess episodes of the 271 comp-matched episodes (2023-10 -> 2024-12;
`task1b_panel.rds`): TORRB2 26, TORRB4 19, TORRB3 17, PPCCGT 6, OSB-AG 1. Median direction window
8.0 h (IQR 6.5-9.5). All five checks run on all 69; sequencing/combination/anticipation shares
also reported on the 45 window-consistent survivors from check (a).

**Data-convention bug found and fixed en route** (validated, does not affect Tasks 1/1b): in
`bid_cache`, the `TRADINGDATE`/`SETTLEMENTDATE` label is one calendar day behind the day of the
bids' own intervals. Task 1 matched on `INTERVAL_DATETIME` directly (label-free) and is
unaffected; Task 1c re-keys on the interval day and reproduces Task 1's issue-instant floor
exactly (69/69, corr 1.000).

## (a) Duration check (`task1c_a_window_counterfactual.csv`)
Window-consistent counterfactual: for every 5-min interval in [s, c], the bid version and daily
ladder in force at issue tau (next-trading-day bids included where they existed at tau -- and
they always did: **0 of 8,290 intervals lacked an in-force bid at issue**; the counterfactual is
fully bid-established over every window).

| Counterfactual | Still zero-excess | Share of 69 |
|---|---|---|
| Task 1 (at-issue snapshot) | 69 | 100% |
| Window-consistent floor (Task-1 definition, uncapped) | **45** | **65.2%** |
| Window floor capped at declared MAXAVAIL | 35 | 50.7% |
| Price-aware (bands <= RRP, capped; supplementary only) | 35 | 50.7% |

24 episodes (34.8%) flip to positive excess over the full window (median flip +61 MWh) -- the
duration artifact is real but minority. The uncapped-vs-capped gap is the tell: 10 of the 45
survivors ran ~210 MWh median against a 660 MWh "floor block" that their own MAXAVAIL had zeroed
out. And the 35 capped survivors have **median window output 0 MWh** -- the direction produced
essentially no energy at all; under Task 1b's gross-world finding they were still paid (the lobe's
median $57k at 3.1x gross energy value is cost top-ups on near-zero energy).

## (b) Sequencing check (`task1c_b_sequencing.csv`, `task1c_b_rebid_explanations.csv`)
Exit signal = a bid version in [tau-48h, c] declaring MAXAVAIL = 0 for >= 1 h of intervals INSIDE
the direction window (a zero block elsewhere in the day is routine two-shifting, not a signal).

| Class | All 69 | 45 survivors |
|---|---|---|
| Signal then direction | **63 (91%)** | **40 (89%)** |
| No exit signal ever | 5 | 4 |
| Signal after direction | 1 | 1 |

Median signal lead 15.8 h before issue (IQR 11.2-18.9, min 6.1) -- the exit typically arrives
with the previous day's daily bid, not a last-minute pull. Signals later reversed: only 4 of 64.
Rebid explanations for signal versions are mostly scheduling language ("Daily Bid SL", "Change in
avail - Unit RTS profile Revised SL", "Correct bid - P Plant conditions"), with post-direction
versions marked "AEMO direction - RTS profile" (RTS = return to service). Whether these exits are
passive cycling or price-responsive positioning is exactly Task 2's question -- 1c establishes
the sequence, not the intent.

## (c) Combination check (`task1c_c_combination.csv`)
At issue (5-min pivotality panel + sister-unit dispatch, +-4 h):

- The N-0 minimum combination was **never** short at issue (0/69) -- consistent with [F20]: N-0
  is not the operating margin.
- N-1 (secure) shortfall at issue: 29/69; directed unit N-1-pivotal at issue: 51/69 (74%).
- A sister unit (or another combination station) offline-bound or freshly offline within +-4 h:
  13/69.
- **Needed-to-complete** (binding N-1 state AND a sister at risk): **11/69 (16%); 9/45 survivors
  (20%)**. It overlaps the exit-signal class almost entirely (8 of 9 survivor cases also
  signalled exit) -- combination risk is a co-factor, not a separate carrier.

## (d) Instrument text (`task1c_d_instrument.csv`)
The AEMO report instrument column carries exactly two operative wordings -- no "increase output"
instruction exists anywhere in the new-format reports:

| Wording | 69 zero-excess | 202 positive-excess |
|---|---|---|
| Synchronise | 39 (57%) | 85 (42%) |
| Remain (synchronised) | 30 (43%) | 117 (58%) |

Zero-excess episodes skew toward **Synchronise** (57% vs 42%), and toward 60% among the 45
survivors -- the instrument itself says these units were off or leaving, told to be present, not
to produce. 57 distinct market-notice IDs are referenced; 2 episodes state "No Market Notices
were issued advising of a possible intervention." Verbatim notice text is not retrievable
offline (NEMWeb retains only current notices; AEMO's notice API blocks non-browser clients) --
the instrument column above is the reports' own operative wording.

## (e) Anticipation probe (`task1c_e_anticipation.csv`; realised-state proxy, stated limitation)
No PREDISPATCH/P5MIN extraction exists in the repo ([F21]), so forecastability is proxied by
direction history and the realised security state pre-issue, zero- vs positive-excess:

- Directed within the prior 7 days: 79.7% vs 81.2% (p=0.47) -- directions are routine for both
  lobes; history does not discriminate.
- Pre-issue 24 h N-1 pivotality share of the directed unit: median **0.806 vs 0.731 (p=0.022)**;
  N-1 shortfall share 0.562 vs 0.495 (p=0.18).

Zero-excess episodes are the marginally MORE predictable ones -- the security need was visibly
binding before issue -- **consistent with floor-in-and-wait, inconsistent with surprise
pre-emption**. Of the 5 survivor episodes with no pre-issue exit signal, only 2 look genuinely
unforecastable (no direction in prior 7 days and low pre-issue pivotality).

## Ranking of the four explanations
Denominators: all-69 shares first, 45 window-consistent survivors in brackets. Categories
overlap; the overlap matrix is `task1c_ranking_inputs.csv`.

| Rank | Explanation | Share |
|---|---|---|
| 1 | **Exit-then-directed** (own bids declared absence for the window before issue) | 63/69 = 91% [40/45 = 89%]; availability already withdrawn at issue in 53/69 = 77% |
| 2 | **Duration artifact** (zero-excess dissolves over the full window) | 24/69 = 35% resolved; +10 more under MAXAVAIL capping |
| 3 | **Combination completion** (needed to complete a combination a sister put at risk) | 11/69 = 16% [9/45 = 20%]; 8 of 9 survivor cases also signalled exit |
| 4 | **Pure AEMO pre-emption** (no signal, no combination risk, unforecastable) | 4/45 = 9% candidates, of which ~2 genuinely surprising |

## Implication for the Task 2 pre-registration
The zero-excess lobe is the **heading-offline / already-absent commitment margin in action**:
bands parked at the floor, MAXAVAIL withdrawn, direction follows into a predictable N-1 need,
and (per Task 1b's gross-world verdict) payment accrues on gross MWh plus cost top-ups even when
window output is ~0. Task 2 should therefore pre-register:

1. **Treatment margin = declared availability (MAXAVAIL), not price bands.** The bands are
   parked; the strategic action, if any, is the exit rebid. Episode classification
   (heading-offline / online-at-floor / offline-brought-on) should key on MAXAVAIL over the
   prospective direction window at issue -- the 77%-withdrawn figure says heading-offline is the
   modal class, so the classification will have mass where the payment-seeking prediction needs it.
2. **Outcome = direction receipt/eligibility** (gross world: every directed episode pays
   regardless of counterfactual), tested for sensitivity to the direction price d_t.
3. **The identifying contrast 1c cannot deliver:** exits arrive on the daily-bid cycle (median
   lead ~16 h) and look like scheduling language. Passive two-shifting and strategic
   floor-in-and-wait produce the SAME 1c sequence; they separate only in whether exit propensity
   (or its non-reversal) responds to d_t conditional on the predictable-need state (pre-issue
   piv_n1) -- that regression is Task 2's job, and the pre-issue piv_n1 share (higher in the
   zero-excess lobe, p=0.022) is the conditioning variable this task validates.

**STOP -- Task 1c complete. Task 2 pre-registration next, on the user's go.**
