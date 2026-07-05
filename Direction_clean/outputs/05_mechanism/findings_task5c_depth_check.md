# Depth check -- what the pre-direction evening withdrawal actually is

**Verdict (committed reading 1 holds, strongly): the pre-direction evening withdrawal is
genuine hour-specific exit declaration, not headroom trimming -- 90.1% of withdrawn evening
hours are floor-crossings (265 of 294), they run from full capacity to zero (median 200 MW ->
0 MW), and they occur at 24 times the quiet-window rate (0.651 vs 0.027 crossings per
rewrite-day). The paper's sentence stands, with one geometric correction below.**

Method as fixed: Torrens only; the 161/136/110 pre-direction rewrite-days (D-1/D-2/D-3) vs
1,075 Torrens quiet rewrite-days; evening hours 19:00-24:00; hourly mean availability from
consecutive midnight stances; withdrawal event = fall >= 1 MW; 40 MW floor. Script
`task5c_depth_check.R`; tables `task5c_{case_table,withdrawal_events}.csv`.

## The table (withdrawn evening hours; hour counts are the denominators)

| | Pre-direction (294 events / 407 days) | Quiet (39 events / 1,075 days) |
|---|---|---|
| Case 1 -- trim headroom (stays >= 40) | 9.9% (29) | 25.6% (10) |
| **Case 2 -- floor-crossing (>= 40 to < 40)** | **90.1% (265)** | 74.4% (29) |
| Case 3 -- deepen existing absence (< 40 falls further) | 0% (0) | 0% (0) |

Per unit, the case-2 share is 82.8 / 94.9 / 92.7% (TORRB2/3/4) -- consistent, not one unit.

## Case 2 detail
- **45 of the 161 D-1 rewrite-days (28.0%) contain at least one evening floor-crossing.**
- The crossings are not marginal dips below 40: median before-level 200 MW (the unit's full
  capacity), median after-level **0 MW**, median drop 200 MW (IQR degenerate at 200 -- the
  modal act is zeroing a fully-offered hour).
- Rate contrast: 0.651 crossings per pre-direction rewrite-day vs 0.027 quiet -- **24x**.
- Before-levels: 97.3% of withdrawn evening hours start from ample availability (>= 100 MW).
  Case 3 is empty for a mechanical reason worth stating: below-floor evening availability is
  almost always already zero -- there is nothing left to deepen.

## The one correction to the draft sentence
The crossings sit in 19:00-24:00 of the rewrite-day -- the evening and night LEADING INTO the
direction window (directions typically cover ~08:30-18:00 the following day) -- not the
direction-covered hours themselves. The accurate sentence is: **"ahead of a direction, the
units extend their absence into evening hours they had been offering at full capacity --
whole-unit exit declarations for the night before the order, at 24 times the background
rate."** "Deepens the absence the order will cover" overstates the overlap; "extends the
absence into the run-up" is what the record shows.

## Consequence for the framework note
Reading (1) held: the Stage-3 pre-direction behaviour is direction-relevant exit declaration,
not bookkeeping. Amendment recorded in `interpretation_staged_framework.md` (Amendment 2) with
the corrected geometry. The onset-stage re-timing (29 days) is no longer the only directional
availability behaviour in the record.

**STOP -- depth check complete. Framework note amended; Task B already complete
(`findings_task5b.md`); commit + regeneration close the phase.**
