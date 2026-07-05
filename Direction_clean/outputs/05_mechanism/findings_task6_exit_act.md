# Final regression -- does the exit act happen more on essential days?

**Honesty note, recorded as instructed:** the evening-cancellation act was found while
studying directions (the depth check); this task tested it against a different question
(essentiality). The three meanings below were written before running; the gate decided.

## Part 1 -- the count (Torrens, clean days, corrected clock)
Population: unit-days where yesterday's midnight stance offered a FULL evening (all five
hourly means 19:00-24:00 >= 40 MW) -- the only days on which an evening could be cancelled:
**492 of 1,744 clean Torrens unit-days (28%)**. Act = >= 1 of those hours crossing below 40 MW
in today's stance. Essential = same-day pex flag (system conditions only; nothing about this
unit's dispatch or directions enters anywhere, per the rule).

| | Cancelled the evening | Didn't | Rate |
|---|---|---|---|
| Essential day | 6 | 14 | 30.0% (6/20) |
| Ordinary day | 101 | 371 | 21.4% (101/472) |

**STOPPING RULE (fixed before counting): essential row = 20 days (< 30); essential
cancellations = 6 (< 10). STOP -- no test.** The thinness is structural, not bad luck: clean
essential Torrens days are scarce to begin with (~75 in three years), and only ~27% of them
follow a day with a full evening on offer -- the same share as ordinary days, but 27% of a
small number is 20.

## The answer in one sentence
Among days a cancellation was possible, essential days cancelled at 30.0% versus 21.4% on
ordinary days -- a gap of 8.6 percentage points on 20 essential days, which is far inside
noise, and the pre-committed stopping rule forbids dressing it as a test.

## Which pre-written meaning applies (quoted as written)
**"Too few events to tell -> say so, and say how big an effect we'd have been able to
detect."** With 20 essential days against 472 ordinary days at a 21.4% base rate, a
conventional test (80% power, 5% size) could only have detected a cancellation-rate difference
of roughly **26 percentage points or more** -- essential days would have needed to cancel at
approximately half again to double the ordinary rate (~47%+) to register. The observed +8.6 pp
is one third of the detectable minimum. The exit-act-vs-essentiality question is unanswerable
in this sample; the raw direction of the gap is noted for completeness and claims nothing.

Parts 2-3 as tests: not run, per the rule. This was the last test -- no follow-ups.

Script `task6_part1_gate.R`; tables `task6_2x2.csv`, population in `task6_population.rds`.

**STOP -- final regression closed at the gate. The behaviour-analysis record is complete.**
