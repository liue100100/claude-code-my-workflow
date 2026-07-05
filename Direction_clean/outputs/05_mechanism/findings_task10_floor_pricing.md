# Final exception task -- completing the floor-pricing (Component B) test with N-1 cells

**Why this ran after the Task 9 closure, stated up front per instruction:** the floor-pricing
question was registered and run in the rebuild (Component B of Task 2), returned "suggestive,
unpowered" (+$2,414, WCB p 0.17, on 16 clean essential days -- `findings_job2_contamination.md`),
and the N-1 label now provides the cells to complete it. This completes an existing
registration; it does not open a new question. Nothing runs after it regardless of result.

## The gate (passed; `task10_gate_{daylevel,hours}.csv`)
Clean B-days (floor MW offered, no imputation): **115 essential_n1 pooled** (PPCCGT 30, TORRB4
31, TORRB3 28, TORRB2 26) vs 556 ordinary -- against the N-0 benchmark of 16. Hours level: all
four units past 30 offered-days (PPCCGT 549 offered essential hours / 109 days; Torrens 199-249
hours / 36-40 days). Composition stated before results: PPCCGT offers its floor in 81% of its
essential hours; Torrens in 15-21% -- both outcomes condition on being offered, and for
Torrens that is the minority of tight hours.

## The answer in one sentence
**When these units offer their floor megawatts at all, they offer them at the floor-band price
-- essentially minus $1,000 -- in essential hours, in non-essential hours of essential days,
and on ordinary days alike; the day is the unit of pricing and the envelope does not move it.**

## The committed reading that applies (verbatim)
**"No different: the floor price is part of the standing posture -- set by the day-block,
indifferent to the envelope. The state account extends to the pricing margin."**

## Results (script `task10_part2_test.R`; tables `task10_{day,hour}_results.csv`)
(i) Day level (650 clean B-days, suspension excluded; cluster month + WCB):
essential_n1 **+$45 (se 265; WCB p 0.86)**; with the loss control +$42 (WCB p 0.87); the loss
control itself dead zero (its registered day-mean weakness restated, moot here). Three-tier:
N-1-only +$78 (p 0.79); N-0 tier -$256 (p 0.18).

(ii) Hours level (26,502 offered unit-hours; 193 identifying unit-days with both essential and
non-essential offered hours): within-day essential-hour effect **+$65 (p 0.40)** pooled;
**PPCCGT exactly $0.0** -- its offered floor price is a constant -$998 within days, so the
first measurable answer to "what does the CCGT charge for its floor when the system is tight?"
is: *the same negative floor-band price it charges every other hour*; Torrens +$118 (p 0.39),
the day-level consistency expected of a block bidder. Median offered floor price by cell:
-$998 to -$1,000 in every cell, every unit.

## The N-0 / N-1 side-by-side (per the sequence rule)

| | N-0 label (original) | N-1 label (completed test) |
|---|---|---|
| Clean essential B-days | 16 | 115 |
| Essential-day effect on the floor price | +$2,414 (WCB p 0.17) -- suggestive | **+$45 (WCB p 0.86) -- null** |

The 16-day suggestion does not survive power: it was riding the rare near-cap hours that the
day-level 12th-highest statistic picks up in a small cell, and both its own tier in the
completed test (-$256, ns) and the hours-level medians (floor-band everywhere) say the same
thing -- there is no essential-day premium on the offered floor.

## Closing line
This completes the last unpowered registration. **The analysis phase is closed, by rule, with
no further exceptions.** The pricing margin joins the availability margin, the exit act, the
ladder shape, the rebid record, and the churn content in one statement: the posture -- absent
or present, and the price of presence -- is a standing choice, indifferent to the essentiality
envelope and to what the direction channel pays; the mechanism's economics live in its design,
which pays gross rates into that standing choice, ~20 dollars to 1.
