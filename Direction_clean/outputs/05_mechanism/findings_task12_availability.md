# Torrens declared availability -- how often withdrawn, when, and the station roster

Descriptive; midnight day-ahead stances, corrected clock, all 1,096 days x 3 units. Script
`task12_availability_profile.R`; tables `task12_{hour_year,station_config}.csv`.

## 1. How often: withdrawal is the majority state, and it is always total
Declared availability is exactly ZERO in 47.5% (TORRB3), 58.8% (TORRB4) and 62.7% (TORRB2) of
all five-minute intervals -- and the sub-floor share is the same to within 0.2 points: **when
these units withdraw, they do not derate, they vanish** (positive-but-below-40 MW declarations
are ~0.2% of intervals; whole-day sub-floor-but-positive days number 0-2 per unit in three
years). At the day level the modal state is all-day zero (588 / 398 / 519 days per unit),
against 269-394 days at-or-above floor all day and 239-303 partial days. By year, 2023 is the
deep year (66-75% of intervals at zero) vs 2022 (37-57%) and 2024 (39-62%, with TORRB4
deepening to 62% -- consistent with wind-down).

## 2. When, within the day: availability is declared for the DAYTIME
The share of intervals with availability >= 40 MW peaks at 08:00-10:00 (48-53% in 2022/2024)
and declines monotonically to a 21:00-24:00 trough (17-34%) in every year. The units put their
availability where the day is -- morning-through-afternoon -- and pull the night; the evening-
zeroing act of the depth check is the marginal, dated version of this standing shape. The
hour-shape is modest next to the level shifts across years and seasons: the STATE dominates.

## 3. When, across the year: winter-available, autumn-absent
July is the most-available month of every year that has one (74% of intervals in 2022, 62% in
2024); March-May is the least (16-28% in 2023 -- the literal-zero quarter of the supply-curve
history). The pattern is market seasonality: available when winter demand and prices want the
units, absent through the renewables-rich shoulder seasons -- which are exactly when
directions happen. Day-of-week is flat (52.1-56.0% across all seven days): no weekly
schedule, confirming state-not-roster at the weekly frequency.

## 4. Spells: multi-day blocks on both sides
Unavailability spells: median 2-4 days, P90 19-23, maxima 43 / 82 / **100** days (TORRB2's
hundred-day outage is the sample's longest). Availability spells: median 5-7 days, maxima
40-86. Both sides of the switch are lumpy operational blocks.

## 5. The station roster -- the new fact
Counting units with any availability per station-day: **three units are offered together on
only 44 of 1,096 days (4%); zero units on 36; ONE unit on 381; TWO units on 635.** The station
runs a 1-to-2-of-3 roster essentially always (mean units available: 1.92 in 2022, 1.29 in
2023, 1.67 in 2024). The roster ROTATES: all six 1- and 2-unit configurations appear in bulk
(TORRB3+TORRB4 on 276 days, TORRB2+TORRB3 on 221, TORRB3 alone 157, TORRB2+TORRB4 138 ...),
the configuration changes on 28.8% of day-pairs with a median run of 2 days, and single-unit
duty is shared (TORRB3 157 days, TORRB4 119, TORRB2 105). Pairwise same-day availability
agreement is 0.34-0.42 -- BELOW the ~0.5 expected if units were independent at their base
rates: the units are deliberately anti-correlated. **"Withdrawal" at the unit level is
substantially the complement of a rotating station roster.**

Two implications, stated descriptively:
- The unit-level absence numbers overstate station-level absence: the station keeps 1-2 units
  on the books nearly every day, which is also roughly what the minimum-combination standard
  asks of Torrens in its strict tiers. Whether the roster level is chosen with the combination
  requirement in view is not identified here -- noted as an open observation, not a claim.
- Any future unit-level analysis of "who withdraws" is partly analysing roster assignment;
  station-day is the more natural grain for the absence state (as the shared essentiality flag
  already implied).

## What is interesting and what it changes
Nothing here reopens an adjudicated result; it sharpens the reading. The withdrawal behaviour
is: total (never derated), day-shaped (daytime on offer, nights pulled), winter-loaded,
block-structured, and organised as a rotating 1-2-of-3 station roster whose depth moved with
the operating calendar (deepest in 2023) rather than with the compensation price (the era and
lag-wedge results). The one thread flagged for possible future registration: the roster level
hovers near the combination requirement's Torrens ask, and 2023's roster thinning coincided
with the sample's lowest essentiality -- a station-day roster-vs-requirement comparison would
be the registered way to examine whether the roster tracks the security standard.

**Descriptive examination complete.**
