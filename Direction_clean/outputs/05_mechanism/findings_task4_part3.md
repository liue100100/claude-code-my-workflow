# Bidding-behaviour instrumentation -- Part 3: the registered test

Pre-registration `task4_part3_preregistration.md` (committed 5d0451b before estimation).
Script `task4_part3_estimation.R`; tables `task4_part3_*.csv`. Clean days, corrected clock,
suspension days excluded from regressions. Counts first: 2,765 clean regression days, **68
essential** (the 80 clean essential days minus suspension-window and control-coverage
exclusions); PPCCGT essential 3; 264 clean first directions with lodgement data; quiet
baseline 1,841 unit-days.

## VERDICT (committed reading applied): PARTIAL MOVEMENT -- two margins moved where the floor
## point is flat; described exactly, no stretching toward either headline.

### 1. The clean finding -- bid churn concentrates ahead of directions (registered question iv)
Median churn z against the unit's own quiet baseline (which sits at 0 by construction), with
the floor-point composite over the same windows:

| Days before clean first direction | n (clean days only) | churn median z | composite median z |
|---|---|---|---|
| D−3 | 139 | 4.5 | −0.36 |
| D−2 | 156 | **22.0** | −0.32 |
| D−1 | 185 | **24.5** | 0.00 |
| D (direction day) | 264 | 57.2 | 0.00 |
| D+1 | 264 | 36.8 | 0.00 |

Timing integrity, checked not assumed: the D−1 and D−2 midnight stances predate the direction's
ISSUE in 99% and 100% of episodes respectively (median issue-to-effect lead 15 h) -- the
pre-direction ramp is pre-issue conduct, not paperwork echo. The same profile appears, smaller,
before essentiality onsets (D−1 z = 8.6, D−2 z = 3.3; n = 26 day-cells, thin but past the
registered n >= 10). **Per the committed reading: a behavioural response existed at a margin
the original outcome could not see -- the DOCUMENT margin. In the 48 hours before the system
acts, the units rework their lodged ladders at 20-25 baseline-IQRs of intensity while the
floor-megawatt price moves not at all.** What this does and does not say: the churn tracks the
approach of the conditions that produce directions; whether it anticipates the direction or the
weather that causes the direction is not separable in this data (Part 4 boundary).

### 2. Movement with a caveat -- the absence type hardens on approach (registered question iii)
Priced-out day, next-day outcome (within-spell, denominators in brackets):

| Next-day outcome | Direction starts within 2d (172) | Between (195) | No direction within 7d (105) |
|---|---|---|---|
| Stays priced-out | 31% | 65% | 58% |
| **Converts to partial (physical withdrawal)** | **62%** | 15% | 23% |
| Converts to full exit | 1% (n=2) | 4% | 4% |
| Spell ends (recommits) | 6% | 17% | 15% |

The registered particular -- priced-out converting to FULL exit -- stays rare everywhere (2 vs
4 events; the pre-registered bound, as expected). What moves instead: on direction approach the
priced-out posture converts to *physical* below-floor withdrawal at nearly three times the
far-from-directions rate, and recommitment nearly stops. **Caveat attached, not smoothed:**
this count table was registered without a clean-day restriction, and with a median issue lead
of 15 h the second day of a within-2d pair often postdates the issue -- part of this hardening
can be direction-shaped bidding rather than pre-issue conduct. It is reported as registered,
with that boundary stated; it corroborates, but cannot independently carry, the churn finding.

### 3. One fragile edge -- ladder steepness on essential days (registered question i)
Of the three all-unit shape measures: MW-weighted mean price flat (−270, WCB p 0.79), top-2
share flat (−0.02, p 0.74), **steepness −$1,437 (analytic p 0.046, WCB p 0.046)** -- the
P25-to-P75 price gap of the offered ladder compresses on essential days. One of nine registered
outcomes at exactly p ≈ 0.046, resting on 68 essential days, with no multiplicity adjustment
registered: reported exactly as that -- suggestive, fragile, not a headline. PPCCGT q-measures:
bounds only (3 essential days; +33 / +20 MW, p 0.71/0.84).

### 4. Nothing -- the rebid record (registered question ii)
Non-tagged rebid intensity flat on essential days (−0.05, WCB p 0.85), flat in the morning
count and lever mix, and sub-bar in the 48h approach window (RR 1.2-1.3). The only approach
movement is the QUARANTINED tagged row (RR 3.6 at D−1) -- direction traffic starting with
issue, descriptive only. The flagged instrument stayed quiet where it was allowed to speak.

### 5. The benchmark line held everywhere
"And the floor point showed nothing here" is true in every design above: composite −445
(p 0.53) on essential days; median z 0.00 in every event window. The blindness measured in
Part 2 is the blindness observed in Part 3.

**STOP -- Part 3 complete. Awaiting review before Part 4 (honest synthesis).**
