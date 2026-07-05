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

## Where the evidence for each stage lives
Stage 1: `findings_horizon_stance.md` (base rate, persistence), `findings_task3_part0.md`.
Stage 2: `findings_task4_part3.md` §3 (steepness, fragile), `task5a3` addendum in
`findings_task4_part3b.md` (onset band tilt, 32 events). Stage 3: `findings_task4_part3.md` §1
(churn ramp), `findings_task4_part3b.md` + addendum (re-timing content), `findings_task5a.md`
(net displacement ~0, floor-block addendum). Stage 4: `findings_job1_timestamp_fix.md` rows 1-2
(directed output = floor, gross payment), `findings_task1b.md`. The adjudicated regressions
(RQ1/RQ2 nulls on clean days): `findings_task2.md`, `findings_job2_contamination.md`.
