# Interpretation note -- the staged framework (fixed before further analysis)

**Recorded 2026-07-05, BEFORE the station-split table and Task B. This is the pre-registration
discipline applied to interpretation: the reading of the results is fixed here; if the open
checks below come back against it, this note is amended visibly -- with what changed and why --
never silently.**

## The framework

The generator has three levers: where its capacity sits on the price ladder, when it declares
itself available (hourly profile), and whether its floor megawatts are committed. It faces two
payment channels: the market (run, earn spot -- usually poor on tight days, since tightness
comes with high solar and low prices) and the direction channel (be absent when needed, get
ordered on, earn ~0.95 x full output x the directed price).

The results map onto four stages of a tight day:

- **Stage 1, ordinary days:** absence is the resting state (76-80% of days, multi-day blocks).
  Matches the intuition that running at a loss is worse than sitting out.
- **Stage 2, tightness possible but not yet resolved:** the stage-appropriate lever is
  pricing -- band repositioning observed (mass off the floor band toward expensive bands).
  Carry the caveat: 32 events, suggestive only.
- **Stage 3, need concrete, direction likely:** the stage-appropriate lever is scheduling --
  availability re-timed into the daytime stress window (13-28 MWh/hour out of
  evening/overnight, into the stress block), totals unchanged, floor untouched, bid checked
  twice as often as quiet days. 123 windows, well-powered. **This is the load-bearing
  behavioural result.**
- **Stage 4, order arrives:** comply at minimum -- directed output equals the operating floor
  exactly, paid gross.

## The two-sided reading

1. **What the staged pattern establishes:** the desk is informed and stage-aware -- it
   forecasts the stress, uses the right lever at each phase, and holds the absence through the
   entire arc. The nulls are not inattention.
2. **What it does not establish: motive.** The staged activity is equally consistent with a
   desk watching the weather and a desk watching the direction calendar -- the two are the same
   clock in this system. This boundary stands.
3. **Why the dose-response nulls and the staged activity coexist:** the standing absence is a
   policy chosen once, not a daily decision -- given how the direction channel pays, absence
   dominates commitment across essentially all conditions, so there is nothing left to
   calibrate daily. The observed activity is stage-appropriate housekeeping around a fixed
   choice. The economic content is in the mechanism's design, not in generator sophistication.

## Open checks this interpretation is conditional on (cannot be quietly skipped)

- **(i) The station-split table:** the hourly re-timing must be shown in Torrens's OWN numbers
  -- the claim is about Torrens, and part of the band result was flagged as PPCCGT-driven.
- **(ii) Task B:** the dollar comparison that makes the "absence dominates" claim quantitative
  rather than asserted.

**Amendment rule:** if the re-timing is not present in Torrens alone, or absence is not
dominant in dollars, this note is amended with what changed and why -- visibly, not silently.

## AMENDMENT 1 (2026-07-05, same day; open check (i) resolved — the rule in action)
The station-split table (`task5a4_*.csv`; counts: Torrens 161/136/110 rewrite-days at
D-1/D-2/D-3, 29 at pre-essential-onset; PPCCGT 21/19/20/3) resolves check (i) with a PARTIAL
PASS that changes two sentences of the framework, recorded here visibly:

1. **Stage 3 held, with its shape corrected.** The re-timing IS present in Torrens's own
   numbers, but it differs by event: before ESSENTIALITY ONSETS Torrens does exactly what the
   framework says — availability out of the overnight (−13.6 MWh/hour, 00:00–06:00) and into
   the daytime-and-evening stress block (+19 to +26 MWh/hour from 11:00, n=29 rewrite-days).
   Before DIRECTIONS, Torrens does only the withdrawal half — evening availability pulled at
   −22 to −32 MWh/hour (19:00–24:00, n=161) with NO daytime addition (≈0); the pooled
   "into the day" component on direction approach was PPCCGT's (+376 MWh/day, n=21).
   Stage 3's corrected sentence: *Torrens re-times into the stress window ahead of
   essentiality onsets, and deepens the pre-direction night ahead of directions; the
   daytime-add before directions is the CCGT's behaviour.*
2. **Stage 2 downgraded from "suggestive" to "anecdotal, PPCCGT-only."** The onset band
   repositioning (floor-band drain toward expensive bands) sits almost entirely in PPCCGT's
   3 onset rewrite-days (−2,105 MWh/day from its −$999 band); Torrens's onset band nets are
   small (+31 floor band, +77 band 9, −332 band 10, the last tracking its overnight MAXAVAIL
   cut). Stage 2 should not be cited for Torrens at all.

The framework's architecture (levers, stages, two-sided reading, policy-chosen-once) stands;
the load-bearing Stage-3 claim survives in Torrens's own numbers with the event-specific shape
above. Check (ii), Task B, remains open.

## CHECK (ii) RESOLVED (2026-07-05, same day): PASSED, no amendment required
Task B (`findings_task5b.md`): the direction channel paid the three Torrens units $141.9M for
625,635 directed MWh that would have earned $7.2M at spot -- a $134.7M gap, ~20:1, every unit,
every year, with the market alternative NEGATIVE in 2023 (48.2% of directed MWh at negative
spot prices). "Absence dominates commitment" is now quantitative. Both open checks are closed;
the framework stands as amended (Amendment 1 only).

## AMENDMENT 2 (2026-07-05, same day): the depth check upgrades Stage 3's pre-direction clause
The depth check (`findings_task5c_depth_check.md`) resolves the last open item: the
pre-direction evening withdrawal is **genuine hour-specific exit declaration** -- 90.1% of
withdrawn evening hours are floor-crossings (265/294), from full capacity to zero (median
200 MW -> 0), at 24x the quiet rate; 45 of 161 D-1 rewrite-days contain at least one. One
geometric correction to the draft sentence: the crossings zero the evening/night LEADING INTO
the direction window, not the direction-covered hours -- the accurate sentence is "ahead of a
direction, the units extend their absence into evening hours they had been offering at full
capacity." Stage 3's corrected clause now reads: *before directions, Torrens extends the
absence into the run-up night with whole-unit exit declarations (well-powered, 24x background);
before essentiality onsets, it re-times availability into the daytime stress block (n=29).*
This STRENGTHENS the framework: the pre-direction behaviour is direction-relevant conduct, not
bookkeeping. Both prior checks remain as resolved (Amendment 1; check (ii) passed).

## Where the evidence for each stage lives
Stage 1: `findings_horizon_stance.md` (base rate, persistence), `findings_task3_part0.md`.
Stage 2: `findings_task4_part3.md` §3 (steepness, fragile), `task5a3` addendum in
`findings_task4_part3b.md` (onset band tilt, 32 events). Stage 3: `findings_task4_part3.md` §1
(churn ramp), `findings_task4_part3b.md` + addendum (re-timing content), `findings_task5a.md`
(net displacement ~0, floor-block addendum). Stage 4: `findings_job1_timestamp_fix.md` rows 1-2
(directed output = floor, gross payment), `findings_task1b.md`. The adjudicated regressions
(RQ1/RQ2 nulls on clean days): `findings_task2.md`, `findings_job2_contamination.md`.
