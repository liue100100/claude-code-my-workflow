# Bidding-behaviour instrumentation -- Part 2: the validation gate

Script `task4_part2_validation.R` (+ count supplement `task4_part2_rebid_rates.csv`); cells in
`task4_part2_hit_{table,cells}.csv`. Moved rule, continuous instruments: |median z| > 0.5
against the unit's own quiet-clean baseline (clean days, >2 days from any episode boundary,
>1 day from transitions; 1,841 of 4,384 unit-days), n >= 10. **Written measurement note (within
Part 2, documented not silent):** the z-rule degenerates for count instruments (quiet-day IQR = 0
inflates z into the millions), so the three rebid streams are judged on a rate-ratio rule --
event-day mean vs quiet mean, registered if the rate at least doubles or halves with an
absolute change >= 0.5 rebids/day. No instrument was redefined; only the yardstick for counts.

**Amendment executed first -- the AEMO dual definition:** 3,538 of the old category's 7,546
rebids (47%) leave direction/RTS under the tightened tag (RTS / "direction" / market-notice
numbers); bare-AEMO price strings go to price/forecast. The tightened tag keeps 4,008 rebids.
Lever match rate for rebid versions: 15,006 of 15,006.

## The hit table (final verdicts; med-z or rate ratio in brackets; BC = by construction)

| Instrument | RTS-26 (D / D+1) | Dir START | Dir END | Transitions | Closure week 2022-11-24 | Mothball spells (>=14d) |
|---|---|---|---|---|---|---|
| Shape: MW-wtd mean price | MOVED (2.70) | MOVED (1.77) | MOVED (1.31) | MOVED (0.52) | **MOVED (0.88)** | untestable* |
| Shape: top-2-band share | MOVED (2.19) | MOVED (1.41) | MOVED (1.08) | flat (0.28) | **MOVED (0.73)** | untestable* |
| Shape: steepness (P75-P25) | MOVED (-5.04) | MOVED (-3.01) | flat | flat | flat | untestable* |
| Shape: MW<=2xSRMC / MW<=$1,000 | flat | flat | flat | MOVED (mech.) | flat | untestable* |
| Rebids, direction-tagged (quarantined) | MOVED (RR 4.3) | MOVED (RR 3.9) | MOVED (RR 3.8) | MOVED (RR 2.0) | MOVED | untestable (n<10) |
| **Rebids, non-tagged (the conduct row)** | **suppressed (RR 0.2)** | flat (RR 0.7) | flat (RR 0.8) | elevated, sub-bar (RR 1.4, +0.61/d) | flat | untestable |
| Rebids, "none" lever (descriptive) | flat (RR 0.5) | flat | flat | flat (RR 1.2) | flat | untestable |
| Churn | MOVED (10.0) | MOVED (34.8) | MOVED (38.8) | MOVED (48.2, BC) | **MOVED (28.9)** | flat** |
| Absence taxonomy (full-exit share) | -- | -- | -- | BC | -- | **MOVED: 100% (n=156) vs 70% quiet exit days** |
| Floor point (benchmark) | MOVED (1.0) | flat | flat | MOVED (BC) | flat | untestable |

\* Shape is undefined when MAXAVAIL = 0 all day -- domain emptiness, not blindness.
\** The ladder collapses AT spell entry (captured in the transitions column); inside the spell
there is nothing left to move -- reported, and consistent with what a mothballing is.
B1 mothballing (Oct 2021): pre-sample, untestable, recorded.

## The held prediction: PASSED
The shape instrument was required to register the plant-regime events. In the closure-
announcement week (2022-11-24 +6d, 21 Torrens unit-days) the MW-weighted mean price and the
top-2-band share both moved (+0.88 / +0.73 median z) and churn spiked (28.9) -- the stack
visibly changed when the closure was announced. No blindness finding.

## Verdicts under the committed rules
- **VALIDATED for Part 3:** churn (moves on every event class it can); shape wmean/top2/steep
  (move on direction events and the announcement); absence taxonomy (mothball windows 100%
  full-exit vs 70% baseline); direction-tagged rebids (quarantined row -- moves everywhere, and
  is excluded from conduct claims per the amendment).
- **DECLARED BLIND for Torrens, kept for PPCCGT only:** MW<=2xSRMC and MW<=$1,000 (shoulder).
  On Torrens quiet days both are zero with zero variance -- there is no cheap quantity whose
  movement they could see inside the standing state. They move only when the state itself flips
  (mechanical). Listed as required, not quietly dropped.
- **The two rows that decide Part 3's worth, exactly as they came out:** **churn validates
  strongly.** **Non-tagged rebids validate PARTIALLY:** the row registers movement -- a strong
  SUPPRESSION on RTS-handling days (0.27 vs 1.43/day, RR 0.2: ordinary rebidding stops while
  direction traffic is handled) and a sub-threshold elevation on transition days (2.04 vs
  1.43/day, RR 1.4) -- but it clears the doubling bar on no event class. It enters Part 3
  eligible-with-flag: capable of registering activity, weak as a detector, and its strongest
  validated behaviour is going quiet during direction handling.
- **Specificity checks passed:** the "none"-lever stream is flat on every event class (as it
  must be), and the non-tagged row does NOT false-fire on tagged traffic (flat-to-suppressed on
  RTS days).
- **The benchmark's blindness is now measured, not asserted:** the floor point is flat at
  direction starts, ends, and the announcement week because its baseline already sits at the
  cap -- there is no headroom for it to move. The gate confirms the motivating concern of this
  whole pass.

**STOP -- Part 2 complete. Churn, shape (3 of 5 sub-measures), taxonomy, and flagged non-tagged
rebids proceed to Part 3; the two quantity-shoulder sub-measures proceed for PPCCGT only;
tagged rebids quarantined; "none" stream descriptive. Awaiting review before the Part 3
pre-registration.**
