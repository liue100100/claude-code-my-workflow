# The roster-vs-requirement test (registered) + the handover check

Pre-registration `task13_preregistration.md`, committed before estimation. Station grain,
1,096 days. Script `task13_roster_requirement.R`; tables `task13_{results,handover_check}.csv`,
requirement store `task13_minreq.rds`.

## The gate fact the cross-tab reveals: the requirement almost never asks anything
The minimum number of Torrens units needed to complete an applicable combination, GIVEN
rivals' declared availability, is **zero on 1,023 of 1,096 days (93.3%)** — the rest of the SA
fleet's availability usually covers the standard on its own. The ask is 1 unit on 70 days and
2 units on 3 days. **Committed reading 3 applies: the variation is nearly degenerate, and the
result is reported as a bound, not a forced estimate.**

| Peak requirement | Days | Mean roster | Days roster BELOW requirement |
|---|---|---|---|
| 0 units | 1,023 | 1.61 | — |
| 1 unit | 70 | 1.86 | **0** |
| 2 units | 3 | 2.00 | **0** |

Within the thin variation: the gradient is directionally positive (raw correlation 0.10), the
regression coefficient is +0.082–0.086 roster-units per requirement-unit (WCB p 0.10–0.13; M1
and M2 agree; the all-clean-day subset is −0.04, ns on 245 days) — **not significant; reading
2's null stands for the tracking claim.** The descriptive fact that survives with full force:
in all 73 days when the standard asked for Torrens units, the roster met or exceeded the ask —
**zero violations in 73 opportunities.** The station never declares itself short of what the
standard requires; equivalently, it always keeps itself *directable*. Whether that is
compliance-mindedness or eligibility-maintenance is the motive boundary again, and it is not
identified.

The structural point this puts on the record: at the AVAILABILITY level, South Australia's
fleet (rivals alone, 93% of days; rivals + the Torrens roster, always) satisfies the
combination standard essentially every day of the sample. The shortfalls that produce
directions are therefore at the COMMITMENT level — units available but not running — which is
the project's central object seen from one more angle.

## The handover check: the evening zeroings are real station exits
Of the 40 D−1 evening-zeroing days with full station data, **station-level evening
availability FELL on 39 (98%)**, with a median change of **−1,000 MWh — exactly one full
unit-evening**; a sister unit covered the gap on 1 day (2%). The depth-check act survives the
station-grain critique completely: the pre-direction evening zeroings are portfolio-level
reductions, not roster handovers.

**STOP — registered test complete (reading 3 primary, reading 2 for the tracking claim, the
zero-violations fact and the handover result carried as the descriptive findings).**
