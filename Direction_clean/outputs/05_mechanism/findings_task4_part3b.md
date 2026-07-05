# Part 3b -- the anatomy of the pre-direction churn ramp (descriptive; reads the record)

Windows: D-3/D-2/D-1 before the clean first directions, days themselves clean, deduplicated
where one day approaches several episodes (184 / 156 / 130 rewrite-days; quiet baseline 1,761).
A rewrite on day d = midnight stance d-1 -> midnight stance d, lodged during d-1 (pre-issue in
99-100% of episodes, checked in Part 3). Script `task4_part3b_ramp_anatomy.R`; tables
`task4_part3b_*.csv`. No significance machinery, per instruction.

## The headline revision the anatomy forces
**The ramp is mostly more-frequent touching, not harder touching.** The share of days with any
rewrite climbs quiet 50.5% -> D-3 66.2% -> D-2 71.6% -> D-1 76.9%; but conditional on changing,
the approach rewrites are SMALLER than ordinary ones -- median band churn 2,730-2,830 MWh vs
5,494 on quiet changed days, availability churn 192-1,005 vs 1,447, expensive-side reshuffle
volume 1,166-1,325 vs 2,060. Part 3's z-ramp (22-24 at D-2/D-1) is real, but its content is the
extensive margin: against a quiet baseline where half of days do not move at all, the approach
windows are days when the document is touched almost every day, in ordinary-or-smaller sizes.

## (a) Composition
Band-quantity changes dominate everywhere: the availability share of churn magnitude is
5-25% by window (median over changed days), 24% on quiet days. No composition flip on approach.

## (b) The availability moves
Median NET availability change is zero in every window, and median deepening mass (downward
moves ending below the floor) is zero -- the typical availability touch re-profiles rather than
withdraws. Where the mass sits differs: approach-day availability movement concentrates in the
afternoon/evening blocks (12-24h holds 60-63% of |dMA| mass vs 45% quiet; quiet moves tilt
overnight). The hours being reworked are the hours the next day's direction will cover.

## (c) The band flows
- Expensive-side inflows settle at the top: MW-weighted receiving price of expensive-class
  inflows is $15,098-15,491 -- the cap-adjacent bands, in every window including quiet.
- The one directional signature in the flows: **at D-1 the cheap class (<= $300) LOSES a median
  81 MWh** (net_cheap -81 on 140 changed days), against +10 / +30 at D-2/D-3 and 0.0 on quiet
  days. Modest in size (gross cheap-side movement is ~1,080 MWh, so the net is ~8% of the
  gross), but it is the only window with a negative median -- the day before a direction, what
  little cheap quantity moves, moves out.
- Honesty note on the typology: the pre-set "posture-relevant" bucket (cheap moved >= 5 MWh or
  absence deepened >= 5 MWh) captures ~92% of changed days in EVERY window including quiet --
  the threshold is too loose to discriminate and the type-mix table is uninformative; the
  medians above carry the description. Reported, not repaired after the fact.

## (d) The lodgement record behind the rewrites
Rebid lodgements per rewrite-day are LOWER on approach (1.35-1.73) than quiet (1.88) even as
more days change -- the approach rewrites arrive disproportionately through the DAILY bid
lodgement rather than intraday rebids. Lodgement hours are the ordinary 12-18h block (79-91%).
Category mix of the rebids that do occur: the direction/RTS-tagged share doubles at D-1 (68 of
233, 29%, vs 13% quiet) -- some of this is residual RTS-profile housekeeping from earlier
episodes appearing in ostensibly quiet-of-direction windows; flagged, not interpreted further.

## The four candidate readings, against the counts
| Reading | Verdict |
|---|---|
| Re-profiling (availability, net ~ 0) | Present but minor: availability is 5-25% of churn, net zero; its hour-profile does shift toward the direction-relevant afternoon/evening. |
| Reshuffling (expensive <-> expensive) | The bulk of all rewriting everywhere -- but SMALLER on approach than quiet; not what distinguishes the ramp. |
| Hardening mechanics (cheap out / absence deepening) | Present as a thin directional edge at D-1 only: median -81 MWh of cheap, ~8% of gross cheap movement; deepening mass median zero. Consistent with Part 3's taxonomy table, and equally modest. |
| Housekeeping (frequent small routine touches) | **The best single description of the ramp.** More days touched, smaller touches, delivered through the daily bid, ordinary lodgement hours. |

## Plain-language close
Before a direction arrives, these units do not tear up their offers -- they tend them more
often. The rewrites are smaller than ordinary ones, flow through the routine daily lodgement,
and reshuffle quantity among cap-adjacent bands as always. Two thin directional edges sit on
top of that routine: the availability hours being touched shift toward the window tomorrow's
direction will cover, and on the final day the cheap end of the ladder drains slightly rather
than filling. The ramp, read closely, is vigilance rather than repositioning -- the document is
watched more closely as conditions tighten, while the posture itself (Part 3's flat floor
point, flat shape, flat rebid intensity) stands still.

## Addendum (requested follow-up): what exactly changes in the pre-event rewrites
Band-level, hour-level, and lodgement-text decomposition (`task5a3_rewrite_content.R`;
tables `task5a3_*.csv`; pooled across units -- band 3-7 content is largely PPCCGT's ladder,
Torrens quantity lives in bands 1 and 9-10; pre-essential-onset group is 32 rewrite-days, thin).

1. **They re-time tomorrow's availability within the day.** On D-1 before directions the
   declared-availability profile loses 13-28 MWh per late-evening hour (20:00-24:00) and gains
   6-10 MWh per afternoon hour (13:00-18:00); before essentiality onsets it loses 13-28 MWh per
   overnight hour (00:00-08:00) and gains 8-11 midday-to-evening. Quiet-day hourly nets are
   +-1.5 MWh. Availability is being concentrated into the daytime window where the conditions
   will bite -- WHEN they will be present changes; how much (Task A: net ~ 0) does not.
2. **The band work is cap-band re-sizing plus small opposite tilts.** Band 10 (~$15.5-16.6k)
   carries roughly half of all band churn in every window including quiet (~1,000-1,150 MWh
   gross per rewrite-day) -- routine top-band housekeeping. The net tilts are 5-15% of gross:
   before directions, ~150 MWh/day shifts OUT of the cap-adjacent bands INTO the $176-350
   mid-merit bands (a slight softening of tomorrow's stack); before essentiality onsets the
   tilt runs the other way (floor band -169 MWh/day into $561-12,900 bands). Neither touches
   the floor block's band position (the earlier addendum: 1 migration in 1,556 windows).
3. **The paperwork calls it dispatch response.** Rebids behind the pre-event rewrites are
   price/dispatch-response text in 63-71% of cases (vs 55% quiet); fuel/tolling housekeeping
   collapses from 27% (quiet) to 5-9%; residual RTS traffic 14-21%. And a large share of
   rewrite content arrives via the next DAILY lodgement, which carries no explanation text.

Plain reading: what changes before an essential day is scheduling, not posture -- the desk
re-times when the unit will be available toward the daytime stress window and re-sizes the top
of the ladder in response to price forecasts, while the totals, the floor block, and the
absent state stay where they were.

**STOP -- Part 3b complete (with addendum). Awaiting review (Part 4 synthesis remains queued).**
