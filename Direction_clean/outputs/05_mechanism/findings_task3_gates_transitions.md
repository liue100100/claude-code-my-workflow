# Within-bid profile analysis -- Part 1 (the two gates) and Part 4 (transition event study)

Clean days per Job 2, corrected clock, thresholds carried from prior jobs. Script:
`task3_gates_and_transitions.R`; tables `task3_*.csv`. Per the amended instruction: Gate 1 run
formally, Gate 2 reports the decoupled-day census, Part 4 runs with split state definitions
plus the Torrens partial-day table.

## Part 1, Gate 1 -- variation: TORRENS FAILED (recorded), PPCCGT PASSES
Clean bid-days with both committed and absent hours in the same lodged profile:
PPCCGT 611 (190/220/201 by year, of 1,053 clean days) -- **passes** the ~200 rule.
Torrens pooled **173 < 200 -- failed, recorded** (TORRB2 51, TORRB3 62, TORRB4 60; 9-27 per
unit-year). Anomaly note, not smoothed: Part 0 reported 172 with a strictly-below-23h boundary;
the formal gate's <=23h boundary adds one day. Both sides of 200 by a wide margin either way.

## Part 1, Gate 2 -- separability: INFEASIBLE, and the reason is sharper than pre-committed
Denominators first: of PPCCGT's 1,052 clean days with expected-price coverage, **4 days carry
any essential hour; 20 essential hours in three years** (essential hour = >=30 min of the
station's ex-ante flag). Pooled hour-level correlation between essentiality and the expected
price profile: **-0.004**. Decoupled hours (outside the 05:00-11:00 morning-ramp window):
**15 of 20, on 3 days** (2022-06-15 afternoon/evening; 2023-10-26/27 overnight blocks).

**The paragraph the infeasibility earns (amended from the pre-committed version by what the
data showed):** the pre-committed reason expected the essentiality clock and the CCGT's
mid-merit duty cycle to coincide hour-for-hour. The system-level version of that is true -- the
essentiality clock peaks at 09:00-13:00, exactly the solar trough where the CCGT schedules
itself off -- and it is why this question needed a gate. But the binding fact is one level
deeper: the ex-ante minimum-combination flag almost never selects Pelican Point at all (4
clean days in three years; Torrens carries the combinations), and on the rare days it does,
the hours are event-driven evenings and overnights, uncorrelated with the price curve
(r = -0.004). So profile-level positioning is unidentifiable **in principle, from both sides**:
for Torrens the posture has no intraday variation to test (Gate 1); for the CCGT, essentiality
never arrives on its clock (Gate 2). That two-sided impossibility -- the incumbent's absence
has no shape, and the shaped unit has no essentiality -- is the finding.

**Parts 2-3 are ruled out: no pre-registration written, no estimation run**, per the
no-estimation-past-a-failed-gate rule. What was ruled out: any within-bid test of whether
absent hours track essential hours, for any focal unit, in this sample and flag design.

## Part 4 -- transition event study (descriptive; no significance tests, no causal language)
State definitions, split per Part 0: Torrens = the horizon-job daily exit posture; PPCCGT =
whole-day absence (>=23 h below floor -- its partial mornings are the normal duty cycle).
Stated deviation: transitions identified on ALL days (a clean-pair restriction would censor
direction-adjacent switches, which the descriptors exist to describe); each transition carries
its contamination class as a column instead.

**Spell structure.** Torrens absent spells: median 6-8 days, P75 16-22, max 112-155 days, with
15-18 spells >= 14 days per unit (extended-outage-like; no maintenance register exists in the
repo to confirm -- proxy stated). PPCCGT whole-day-absent spells: median 1 day, P75 2, max 41,
only 2 spells >= 14 days -- its full-day absences are brief interruptions, not parked states.

**Transition descriptor table** (`task3_part4_transition_summary.csv`; per-transition rows in
`task3_part4_transitions.csv`):

| Unit | Transitions (enter/exit) | Median week exp. loss ($/MWh) | Weeks loss-positive | Direction in prior 7d | Base rate, all days | On a clean day |
|---|---|---|---|---|---|---|
| PPCCGT | 76 / 76 | +58 / +57 | 83% | 8-13% | 13.0% | 95-97% |
| TORRB2 | 47 / 46 | +11 / +17 | 60-63% | 70 / 80% | 51.4% | 53 / 37% |
| TORRB3 | 54 / 54 | +24 / +36 | 59-74% | 70 / 87% | 65.1% | 70 / 39% |
| TORRB4 | 46 / 46 | +36 / +31 | 61-67% | 65 / 83% | 58.2% | 59 / 37% |

What the world looks like when the unit changes state, plainly: **PPCCGT's switches are
loss-calendar events** -- 83% of transition weeks had expected running losses, directions
nearby at exactly its base rate (8-13% vs 13.0%), and 95%+ of switches on clean days.
**Torrens's switches happen in direction-saturated weeks** -- 65-87% had a direction in the
prior 7 days, above already-high base rates of 51-65%, and only 37-70% of its transition days
are clean. Reported as counts, not causes: for Torrens, state changes and the directions
machinery co-occur too densely for this small-N table to separate.

**Torrens partial-day table** (amendment; `task3_part4_torrens_partial.csv`): the 173 clean
partial days have median 5-11 absent hours and **59.0% sit within one day of a state
transition** -- they are substantially the entry/exit ramp days of block spells, consistent
with Part 0's world-(a) reading, not a hidden intraday pattern.

## Framing note for the write-up (set down now, per instruction)
Whatever any pending estimation returns, Part 0 has already made the paper's heterogeneity
conclusion symmetrical and complete: **the incumbent steam station is absent as a state; the
CCGT is absent on a schedule; and the directions mechanism pays gross rates into the first
while the second mostly supplies the market.** That contrast rests on descriptive tables on
corrected, decontaminated foundations and no longer depends on any estimation outcome.

**STOP -- Parts 1 and 4 complete; Parts 2-3 ruled out at the gates. Awaiting review.**
