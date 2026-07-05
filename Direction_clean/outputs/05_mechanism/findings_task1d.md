# Task 1d findings -- the 35 "zero-output" episodes with material payment (Direction_clean/)

## VERDICT (two findings; the second is the bigger one)
1. **The dollars are output payments, exactly.** Compensation = 0.998 x (event-reported directed
   MWh x directed price), through-origin R-squared = 1.000 across the 35 episodes (decision rule:
   fit at R-squared >= 0.6 -- cleared at the maximum). The cost-reimbursement shapes fit worse
   (flat $/hour R-squared 0.941 -- collinear with MWh; additional-compensation channel carries
   53.7% of dollars, below the 60% rule). No unexplained payment shape exists; nothing to flag
   under the neither-fits rule.
2. **"Zero output" was an artifact, and its diagnosis exposed a +10-hour timestamp bug in every
   direction-event time in the project.** These units DID run -- roughly 40 MW across the true
   direction windows, which sit 10 hours EARLIER than recorded. The payment is for real energy.

## The set, with denominators
The 35 Task-1c capped-survivor episodes (of 69 zero-excess, of 271 comp-matched, 2023-10 ->
2024-12): TORRB2 14, TORRB4 10, TORRB3 7, PPCCGT 4. Median payment $47,144 (IQR $37,859-$58,419),
total $1.66M. Median recorded-window output 0.0 MWh; median event-reported directed MWh ~260-294
per unit. 31 of 35 never synchronised inside the RECORDED window; 6 of 35 recorded windows < 2 h.
Issued-then-cancelled is NOT the story: cancellations are hours after effect in all 35.

## The timestamp bug (found here, verified three independent ways)
**`Direction/00_data_spine/parse_direction_reports.R` -> `excel_to_posix()` adds 10 hours to
every direction-report timestamp** (issue, effective, cancellation; old and new formats alike):
it converts the Excel clock as if it were UTC, then re-renders that instant in UTC+10 -- an
intended identity that instead shifts every event time +10 h. Every downstream episode window
(`episodes.rds` s/c/tau) inherits the shift.

Evidence:
1. **Code logic** (sufficient on its own): serial -> `as.POSIXct(tz="UTC")` -> `format(tz=
   "Etc/GMT-10")` -> `as.POSIXct(tz="Etc/GMT-10")` = clock + 10 h.
2. **Dispatch energy sits exactly one shift earlier.** For every one of the 6 largest "zero-
   output" payments: the unit ran a continuous ~40 MW block ending AT the recorded window start,
   and output inside the window shifted -10 h reproduces the event-reported MWh (e.g. episode
   1490: recorded window 2024-11-14 18:29->04:00, output 0; true window 08:29->18:00 sits inside
   a 40 MW run; reported 357 MWh = 9.5 h x ~40 MW). This is also why compensation fits reported
   MWh at R-squared 1.000 while fitting recorded-window MWh at 0.161.
3. **Diurnal alignment.** Recorded episode starts cluster 18:00-19:00 -- the HOUR-OF-DAY MINIMUM
   of the ex-ante essentiality flag (pex 0.4-0.5%, true market time). Shifted -10 h they land
   08:00-09:00, on the ramp into the 09:00-13:00 pex peak (2.0-2.1%). Directions cannot
   systematically start when the need is least; they can when the clock is 10 h late.

The fix is deterministic (subtract 10 h; or repair the parser's one function and re-parse).

## What the bug does and does not contaminate (assessed, not smoothed)
- **Unaffected:** the compensation dollars, event-reported MWh, market-notice IDs, instruction
  wording (no clock involved); the monthly d_t series; the Task 2 unit-day outcome pipeline
  (bids, pex, controls -- all in true market time, no episode windows involved); RQ1/RQ2.
- **Task 1b GROSS WORLD verdict: survives and strengthens.** It was carried by the lobe-payout
  table and formula fits on reported dollars; this task's R-squared = 1.000 on reported MWh x P
  is the cleanest gross-world statement yet. (1b's computed-Q fit of 0.94 was attenuated by the
  shifted windows.)
- **Task 1 (directed output = floor): direction right, measurement due a re-run.** The 40 MW
  floor-running is confirmed in the TRUE windows here, but Task 1's numbers were computed on
  shifted windows.
- **Task 1c: headline WITHDRAWN pending re-run on corrected windows.** "Availability withdrawn
  for the direction window at issue" was measured on windows sitting 10 h late -- i.e. the
  following evening/night, where MAXAVAIL = 0 is routine two-shifting. Whether exit-then-directed
  survives on true windows (typically ~08:00-18:00 daytime) is an open empirical question; the
  zero-excess lobe definition itself (Task 1 excess on shifted windows) must be rebuilt first.
- **Task 2 Steps 5-6** (episode durations, online-at-floor, episode reclassification) will apply
  the -10 h correction in-memory, labelled as such; durations are shift-invariant.

## One table
`task1d_payment_shapes.csv` (episode detail in `task1d_episode_table.csv`):

| Shape | Coef | R-squared | Share of dollars |
|---|---|---|---|
| Output payment: event MWh x directed price | 0.998 | **1.000** | 1.001 |
| Output payment: recorded-window MWh x price | 0.827 | 0.161 | 0.154 |
| Cost shape: flat $/hour of direction | $7,158/h | 0.941 | -- |
| Cost channel: additional_compensation | 1.455 | 0.666 | 0.537 |

**STOP -- Task 1d complete. The parser fix + Task 1/1b/1c re-run on corrected windows awaits
the user's go (it rewrites published mechanism findings). Task 2 continues: its pipeline is
unaffected, and Steps 5-6 will use the -10 h correction explicitly.**
