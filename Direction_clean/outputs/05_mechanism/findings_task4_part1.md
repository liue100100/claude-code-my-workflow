# Bidding-behaviour instrumentation -- Part 1: the five instruments, built

Test units, corrected clock, day-ahead (midnight) stance for the daily instruments, all lodged
versions for the rebid panel. Definitions fixed in `task4_part1_instruments.R` before any event
analysis; nothing here conditions on essentiality or directions (the type-vs-direction-approach
question is deferred to the registered Part 3). Stores: `task4_{ladder_shape,rebid_panel,
rebid_levers,churn}.rds`, `task4_absence_type.csv`; distributions `task4_part1_*.csv`.

## (a) Ladder shape -- five numbers for the whole ten-band offer
Per unit-day (median over the day's 288 effective ladders, quantities capped at MAXAVAIL;
n = 1,096 days per unit):

| Unit | MW-wtd mean price | MW <= 2xSRMC | MW <= $1,000 (shoulder) | Top-2-band share | P75-P25 price gap |
|---|---|---|---|---|---|
| TORRB2 | $12,915 | 0.0 | 0 | 0.80 | $0 |
| TORRB3 | $14,967 | 0.0 | 0 | 0.95 | $0 |
| TORRB4 | $13,797 | 0.0 | 0 | 0.80 | $0 |
| PPCCGT | −$659 | 233.5 | 241 | 0.00 | $1,119 |

The median Torrens day offers **zero megawatts below $1,000** and parks 80-95% of availability
in the top two bands (MW-weighted mean price $13-15k); the median PPCCGT day is the mirror
image (negative-priced base, 241 MW shoulder, nothing in the top bands). *What it sees that the
floor point cannot: the whole ladder above and below the floor megawatt -- how much is cheap,
where cheap ends, and how the rest is stacked.*

## (b) Rebid-event panel -- the intraday record
Rebids lodged per unit-day (denominator 1,096 days each): PPCCGT mean 6.4 (median 5, zero-rebid
days 9.6%); Torrens mean 2.2-2.8 (median 1-2, zero-rebid days 27.6-44.7%). Lodgement peaks at
12:00-18:00 for every unit. Lever mix over all post-first versions (per-version comparison of
future intervals vs the preceding version): Torrens ~17-23% MAXAVAIL-only, ~23-26% bands-only,
~19-24% both, and **~41-42% "none"** (neither margin moved >= 1 MW -- trivial edits or
non-energy content; flagged, and these should NOT register on energy instruments in Part 2).
PPCCGT: 46% both, 47% none, of 15,783 versions.

Explanation categories (coarse regex, precedence direction/RTS > plant > price/forecast;
20 random examples per category in `task4_part1_explanation_examples.csv` for the reader):
Torrens rebids are **direction/RTS-dominated (~60-65% of categorised text)**; PPCCGT is spread
(direction/RTS 2,271, price 936, plant 701, other 3,085 of 6,993). Two classification flaws
found by reading the examples, reported not smoothed: the "AEMO" token over-assigns
price-publication responses ("AEMO 5MPD vs 30MPD - SA Price Decrease...") to direction/RTS, and
bare price responses without keywords ("Respond to 30 MPD, $172.00") land in "other." The
scheme is serviceable for counts, not for fine claims. *What it sees that the floor point
cannot: everything lodged after midnight -- the entire intraday record the daily stance
discards.*

## (c) Absence taxonomy -- three kinds of "absent"
Exit-posture days (established definition), split (denominators = each unit's exit days):

| Unit | Full exit (MAXAVAIL ~ 0) | Partial (positive, below floor) | Priced-out |
|---|---|---|---|
| TORRB2 | 588 (62%) | 239 (25%) | 125 (13%) |
| TORRB3 | 398 (44%) | 304 (34%) | 201 (22%) |
| TORRB4 | 519 (55%) | 281 (30%) | 137 (15%) |
| PPCCGT | 186 (22%) | 646 (77%) | 10 (1%) |

Within-spell type transitions (consecutive exit days, pooled; 3,369 day-pairs): strongly
diagonal -- full->full 1,430, partial->partial 880, priced->priced 241. Type switches follow a
ladder: priced-out -> partial (159) -> full (220); **direct priced-out -> full-exit jumps are
rare (13)**. Whether that ladder runs on the approach to directions is exactly Part 3(iii) and
is not examined here. *What it sees that the floor point cannot: the floor point scores all
three types identically (~cap); the taxonomy separates a switched-off unit from a derated one
from a present-but-expensive one.*

## (d) Bid churn -- does the document move?
Day-pair comparison of midnight stances (1,095 pairs per unit): the ladder changed on 55.9-63.9%
of Torrens day-pairs (median moved volume ~0.9-1.5 GWh across bands+availability) and 91.1% of
PPCCGT pairs (median 8.3 GWh). **Within constant exit posture** -- both days absent, the thing
the state analysis reads as "no change" -- the document still moved on 46.9-53.8% of Torrens
pairs and 86.5% of PPCCGT pairs. *What it sees that the floor point cannot: reshuffling inside
an unchanged posture -- the bid living while the state stands still.*

## (e) The benchmark
The floor-point measure (composite / Component A / Component B) is carried unchanged from Task 2;
every Part 3 result will be read against "and the floor point showed nothing here."

## One anomaly worth carrying to Part 2
The Torrens intraday record is saturated with direction/RTS traffic (~60%+ of its categorised
rebid text), which means the rebid instrument on direction-adjacent days partly measures the
directions machinery itself -- the Part 2 validation (event class i and ii) will show whether
the instrument can be read AROUND that traffic, and the Job-2 contamination classes will do the
quarantining in Part 3.

**STOP -- Part 1 complete. Awaiting review before Part 2 (validation gate).**
