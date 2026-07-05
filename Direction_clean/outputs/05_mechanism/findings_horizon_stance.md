# Horizon-consistent stance measure -- descriptive upgrade (no adjudicated result re-run)

Scope, per instruction: upgrades the two surviving descriptive numbers only. No regressions, no
essentiality interactions, no compensation-price tests; RQ1/RQ2 stand as adjudicated in
`findings_job2_contamination.md`. Script: `task2_horizon_stance.R`; tables
`task2_horizon_*.csv`. All rules fixed in advance (horizon = pooled median duration, never
per-episode; information cutoff = before issue for episodes, before midnight for the panel;
"not yet bid" its own category).

## The duration table (the horizon choice, visible up front)
740 corrected episodes: P10 5.0 h, **P25 7.0 h, median 10.5 h, P75 25.0 h**, P90 55.5 h,
mean 21.9 h, max 231.5 h. Horizons used: 84 / **126** / 300 five-minute intervals.

## (a) The 95.4% sentence, upgraded -- the absence spans the operator's whole planning window
Denominator: the same 280 clean-day first directions as Job 2. Cutoff: every bid version used
was lodged strictly before the direction was issued. Stance measured over [start, start + H).

| Horizon | Rank threshold | Withdrawn | Priced-out | Committed-cheap | Exit share |
|---|---|---|---|---|---|
| Issue day, midnight cutoff (Job 2 benchmark) | 12 | 71.8% | 23.6% | 4.6% | **95.4%** |
| P25 (7 h) | 12 | 245 | 27 | 8 | **97.1%** |
| **Median (10.5 h)** | **12** | **250** | **24** | **6** | **97.9%** |
| Median | 6 / 24 / 36 (sweep) | -- | -- | -- | 98.6 / 95.7 / 93.2% |
| P75 (25 h) | 12 | 270 | 6 | 4 | **98.6%** |

Three things the table settles, plainly:
1. **The number goes up, not down, over the operator's horizon.** At issue, 274 of 280 clean
   first directions (97.9%) faced a stance that had already withdrawn or priced out the floor
   megawatts across the median direction horizon; at the 25-hour P75 horizon it is 276 of 280.
2. **It is not the one-hour cliff.** The rank sweep moves the share only between 93.2% and
   98.6%, and coverage is deep: the mean exit share of the bid horizon is 0.90; 85.0% of the
   280 episodes had an exit stance across at least 90% of the horizon they had bid
   (76.4% at the P75 horizon).
3. **The "not yet bid" category came back EMPTY -- itself a finding.** At the moment AEMO
   issued, the unit had lodged bids covering the entire median horizon in every one of the 280
   episodes (mean not-yet-bid share 0.000; zero episodes with insufficient bid coverage, even
   at the 25-hour horizon). The absence is not an artifact of unlodged days: the whole window
   the direction would need was affirmatively declared absent or near-cap, in bids lodged
   before the system acted.

(The issue-day 95.4% and the horizon 97.9% differ in both cutoff -- midnight vs at-issue -- and
window; they are reported alongside, not spliced.)

## (b) The base rate, upgraded -- a persistent multi-day state, not a rolling daily stance
Clean unit-days (n = 2,800), midnight cutoff, horizon [00:00, 00:00 + H) (within-day at these
horizons, so not-yet-bid cannot arise here):

| Horizon / threshold | Exit-stance rate |
|---|---|
| P25 (7 h) / 12 | 72.1% |
| Median (10.5 h) / 12 | 72.9% |
| Median / 6, 24, 36 (sweep) | 73.1 / 72.7 / 72.2% |
| P75 (25 h) / 12 | 76.8% |

The resting-absence base rate is 72-77% however the horizon or threshold is cut -- consistent
with the 76-80% full-day figure and insensitive to the one-hour convention.

**Persistence (the structure question answered):** using the full-day exit posture on
consecutive days -- P(exit posture tomorrow | exit posture today) = **92.8%** (93.3% on clean
day-pairs, n = 2,799) vs 35.1% if today was committed-cheap. Run lengths of consecutive
exit-posture days: median **5 days**, P75 12, P90 ~32, P99 ~114 days. The standing posture is a
**persistent multi-day state** -- once a unit parks its floor megawatts absent or near-cap, it
stays that way for days-to-weeks -- not a stance re-chosen each morning.

## Boundary note (one sentence, per instruction)
The horizon measure moves the descriptive levels up, not the essential-vs-ordinary or
price-sensitivity contrasts that RQ1/RQ2 adjudicated, so nothing here looks like it would
change an adjudicated result; any horizon-based re-test of those questions would need a new
pre-registration first.

**STOP -- horizon upgrade complete. Awaiting review.**
