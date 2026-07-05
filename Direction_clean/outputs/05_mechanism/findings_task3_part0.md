# Within-bid profile analysis -- Part 0: resolution check (decides everything downstream)

Clean days only (Job 2 classification, n = 2,800 test unit-days), corrected clock, day-ahead
stance. Absence = declared availability below the unit's floor for that hour (withdrawal only).
OSB-AG excluded (no clean-day classification exists; descriptive-only unit throughout).
Script: `task3_part0_resolution.R`; tables `task3_part0_*.csv`.

## VERDICT: a meaningful mixed case -- the two worlds split cleanly by unit type

**Torrens (TORRB2/3/4): world (a), block-like.** Absent hours per clean day are bimodal at the
poles: >=23 h absent on 73.3 / 57.5 / 67.2% of days and <1 h on 18.8 / 30.9 / 22.4% (denominators
640 / 530 / 577 clean days). The middle holds only **8.0-11.5%** of days -- 51 / 61 / 60 partial
days per unit over three years, **172 pooled**. The Torrens posture is whole days absent or
whole days committed; a within-bid test has almost no material for these units (172 < the ~200
Gate-1 threshold, noted here ahead of the formal gate).

**PPCCGT: world (b), genuine intraday shape.** 58.0% of its 1,053 clean days sit in the middle
(median 9.1 absent hours), with a crisp recurring pattern: on partial days the unit is absent
through the morning solar ramp -- **05:00-11:00 at 81-93% absence rates** -- and committed in
the afternoon and evening (11-14% absence, 14:00-18:00). Recurrence is high: each partial day's
hourly profile correlates with the unit's mean profile at median r = 0.78, and 78.9% of its 611
partial days correlate above 0.5. The pattern direction is worth stating: the CCGT's absent
hours are the high-solar, cheap, essentiality-prone hours -- exactly the confound Gate 2 exists
to measure.

A side observation, reported not smoothed: on the rare Torrens partial days the shape is the
OPPOSITE of PPCCGT's -- absent overnight (67-80% at 21:00-02:00), committed through the day
(9-22% at 10:00-17:00). Torrens two-shifts around the evening; Pelican Point shapes around the
solar trough.

## The stated consequence for the persistence finding
The horizon job's "median 5-day absent runs" needs a split footnote: for **Torrens** the runs
are genuine unbroken whole-day absence (world a -- no intraday pattern to adjust for). For
**PPCCGT** the daily exit-posture runs are substantially daily recurrences of an intraday
pattern (absent mornings, committed evenings), not continuous absence -- the PPCCGT rows of the
persistence table overstate "absence" as a continuous state.

## What this means for the downstream parts
- Parts 1-3 (gates, registration, estimation) have content **for PPCCGT only**; Torrens enters
  Gate 1 with 172 pooled partial days, below the ~200 rule fixed in the instruction. The formal
  gates will be run on that basis if this Part-0 reading is accepted.
- Gate 2 is now the live question: PPCCGT's absent hours sit exactly where essentiality fires
  (high-solar mornings), so the essentiality-vs-price separability check decides feasibility.
- Part 4 (transition event study) runs regardless; per the instruction it will define
  transitions on the intraday-pattern-adjusted state for PPCCGT and the plain daily state for
  Torrens, and will say so.

**STOP -- Part 0 complete. Awaiting review before Part 1 (the two gates).**
