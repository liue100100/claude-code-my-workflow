# Four checks before the final regression under N-1 essentiality (no regression run)

**Sequence note, recorded up front per instruction:** the N-0 version of the exit-act test was
run FIRST and came back too thin (20 evening-on-offer essential days, 6 cancellations --
reported as such in `findings_task6_exit_act.md`, stopped at its gate). The N-1 definition was
adopted AFTERWARD, on the argument that it is the operator's actual standard (secure N-1
explains 98.4% of directions on the corrected clock). Both results will be shown side by side
in the paper. This note exists so the sequence is on the record.

Script `task8_four_checks.R`; tables `task8_check{1_months,2_monotonicity,4_gate}.csv`.
Clean days per Job 2, corrected clock throughout.

## Check 1 -- is 606 really 606? Mostly, yes.
The 606 clean essential unit-days spread across **34 of 36 months** (top 3 months hold 21.6%,
top 6 hold 37.0% -- much flatter than the old label's 39-42% top-3 concentration). N-1 spells
are short, not seasonal blocks: median 2 consecutive days, P90 7, max 15. The honest effective
count, deduplicating the shared Torrens station flag: **454 station-days** (344 Torrens + 110
PPCCGT). Call it ~450 independent days over ~34 month-clusters -- a real sample, stated plainly.

## Check 2 -- does N-1 mean what it claims? Yes: the middle column sits in the middle.

| | Ordinary (3,094) | N-1 only (1,104) | N-0 (186) |
|---|---|---|---|
| Days with a direction starting | 10.6% | 27.2% | 24.2% |
| Renewable share of demand | 0.61 | 0.75 | 0.80 |
| Net imports into SA (MW) | +93 | +38 | **-3** |
| Competition slope (steeper = more rival response) | -3.12 | -3.68 | -4.61 |
| Saturated share | 0.072 | 0.078 | 0.085 |
| Mean spot price ($/MWh) | 131 | 66 | 71 |

Monotone on renewables, imports, competition, saturation; direction incidence jumps 2.6x from
ordinary to N-1-only and plateaus into N-0 (both essential tiers are direction-dense -- N-0's
slightly lower start-rate reflects its days being deep inside multi-day direction spells).
Essential days are cheap, high-renewables, import-light days -- consistent with Stage 3's
essentiality-is-not-scarcity finding. **The measure captures real proximity to trouble; the
stop condition (N-1-only looking like ordinary) does not bind.**

## Check 3 -- contamination survival
N-1-only unit-days before the screen: **1,104; clean after the Job-2 screen: 526 (52.4%
lost)** -- the same ~53% contamination clustering as every essential label in this project.
Per unit: TORRB2 168/332 clean, TORRB3 110/332, TORRB4 142/332, PPCCGT 106/108 (98% -- its
essential days rarely coincide with its own direction exposure). Note for the record: the
"526 newly-essential days" cited going in was already the post-screen count; the pre-screen
population is the 1,104 above.

## Check 4 -- the count table that gates the regression (Torrens, clean days)

| | Evening on offer | Cancelled | Rate |
|---|---|---|---|
| Ordinary day | 396 | 89 | 22.5% |
| **N-1 only** | **76** | **12** | **15.8%** |
| N-0 | 20 | 6 | 30.0% |

**GATE: the N-1-only row is TESTABLE** (76 >= 30 days, 12 >= 10 cancellations). The N-0 row
remains counts-only, as before. A raw pattern is visible and deliberately NOT interpreted
here: the N-1-only cancellation rate sits BELOW the ordinary rate (15.8 vs 22.5%), opposite in
sign to the noise-level N-0 row -- whether that survives the running-loss control is exactly
what the registered regression exists to decide, and nothing about it is read until then.

## Check 4a -- does the act track the envelope or the event? THE EVENT.
Same population, split envelope x direction-approach window (within D-3..D-1 of any of the
unit's direction starts; `task8_check4a.csv`):

| | Inside approach window | Outside |
|---|---|---|
| Ordinary | 32.9% (56/170) | 14.6% (33/226) |
| N-1 only | 25.7% (9/35) | 7.3% (3/41) |
| N-0 | 12.5% (1/8) | 41.7% (5/12) |

Two facts, read descriptively and not tested:
1. **The event dominates.** Within every envelope tier, being inside a direction-approach
   window roughly doubles-to-triples the cancellation rate (14.6 -> 32.9 ordinary;
   7.3 -> 25.7 N-1-only). The N-0 cells are 8- and 12-day noise.
2. **Holding the window fixed, the envelope adds nothing positive** -- N-1-only days cancel
   LESS than ordinary days both outside (7.3 vs 14.6) and inside (25.7 vs 32.9). Check 4's
   pooled 15.8%-below-22.5% pattern decomposes into this, not into composition.

**Expectation set for the registered regression, before registration:** the approach-window
variable CANNOT enter the regression (it is defined off subsequent direction starts, which
cancellations themselves trigger -- the no-directions rule applies with full force), so the
registered essential-day coefficient will pool these cells and should be EXPECTED to come out
null-or-negative even before the loss control; the loss control then decides whether the
event-timed cancellations are loss-avoidance. The committed readings in the pre-registration
must be written against that expectation, not against a naive "essential means more exits"
prior -- the descriptive record already says the act is event-timed, not envelope-timed.

## Verdict
All four checks pass or resolve favourably: the label has usable structure (~450 effective
days, 34 months), demonstrable validity (monotone trouble gradient), known contamination
behaviour (53%, familiar), and a testable gate row (76/12). **The final regression can run --
under its own pre-registration, written before estimation, with the N-0 side-by-side
presentation committed there.**

**STOP -- checks complete. Awaiting the registration decision.**
