# Job 1 findings -- timestamp fix and re-establishment of the timing-dependent results

The +10-hour bug in `parse_direction_reports.R::excel_to_posix()` (found and three-way-verified
in Task 1d) is **fixed at source**: the parser is corrected, `direction_events.rds` and
`episodes.rds` are rebuilt (1,638 events; 1,492 episodes, identical counts and stable
episode_ids -- the shift is uniform, so nothing was added or dropped). Fix verified after
re-parse: episode starts now peak 08:00-09:00 (the ramp into the essentiality flag's
09:00-13:00 diurnal peak); the Task-1d spot-check episode lands exactly on its 40 MW dispatch
run. Pre-fix outputs archived in `outputs/05_mechanism/_pre_tzfix/`.

## BEFORE / AFTER -- every headline number

| # | Headline | Pre-fix | Corrected | Changed? |
|---|---|---|---|---|
| 1 | Task 1: Torrens directed output (median) | 40 MW | 40 MW | No |
| 2 | Task 1: Torrens excess over floor block, median [IQR] | +12 to +28 MW [wide] | **0.0 MW [-1.5, +0.2]** | Sharpened: directed output = the floor block, exactly |
| 3 | Task 1: episodes at/below zero excess (n=740) | 36.9% | **55.9%** | Yes |
| 4 | Task 1: episodes within 25 MW of floor block | 54.3% | **80.8%** | Yes |
| 5 | Task 1: PPCCGT directed output (median) vs floor block | 70 MW vs 0 | **167 MW vs 0** | Yes (excess +166: the CCGT genuinely runs high when directed) |
| 6 | Task 1b: corr(computed MWh, event-reported MWh) | 0.95 | **0.992** | Strengthened |
| 7 | Task 1b: gross-formula fit (coef / R-sq) | 0.88 / 0.943 | **0.948 / 0.990** | Strengthened |
| 8 | Task 1b: wedge-formula fit (R-sq) | 0.888 | **0.364** | Collapses -- the wedge never fit; the bug propped it up |
| 9 | Task 1b: episodes no formula fits | 41% (111/271) | **0.7% (2/271)** | Yes -- the misfit puzzle was the bug |
| 10 | Task 1b: zero-excess lobe size / comp-to-gross-value ratio | 69 of 271 / 3.12x | **121 of 271 / 0.93x** (= positive lobe's 0.93x) | Yes -- the "cost top-ups dominate" reading is dead |
| 11 | Task 1c: exit announced BEFORE direction issued | 91% (63/69, old lobe) | **71% (86/121, new lobe); 77% (208/271, all comp-matched)** | Yes -- survives as majority conduct, materially weaker |
| 12 | Task 1c: median exit lead before issue | 15.8 h | **6.3 h** | Yes |
| 13 | Task 1c: exit signal AFTER issue | 1 of 69 | **26 of 121 (21%)** | New material class -- post-issue rebids had masqueraded as pre-issue |
| 14 | Task 1c: no exit signal ever | 5/69 (7%) | 9/121 (7%) | No |
| 15 | Task 1c: availability withdrawn at issue (mean window MAXAVAIL < 5 MW) | 77% (53/69) | **71% (67/94 measurable)** | Broadly holds (27 of 121 in-force versions predate the 48-h lookback and are unmeasured -- reported, not imputed) |
| 16 | Task 1c: signals later reversed | 4/64 | 5/112 | No |
| 17 | Step 6: issue-day day-ahead stance, withdrawn / priced-out / committed-cheap (n=740) | 75.8 / 22.0 / 2.2% | 75.8 / 22.0 / 2.2% | No -- reproduced identically from source-corrected episodes (this run had already used the -10h correction; consistency check passed) |
| 18 | Step 5b: online when directed / at floor | 99.8% / 92-98% | 99.8% / 92-98% | No (same reason as #17) |

Flip accounting for the old 69 (`task1c_redux_flips.csv`): 15 of 69 changed sequencing class --
11 signal-then-direction -> signal-AFTER-direction, 3 -> no-signal-ever, 1 no-signal ->
signal-then. 43 of the old 69 remain in the new 121-episode lobe.

## What the corrected record says (plainly, per instruction)

1. **The institutional account of Task 1 is now exact.** A directed Torrens unit produces its
   $0-floor-block quantity to the megawatt (median excess 0.0, IQR -1.5 to +0.2). PPCCGT is the
   real contrast: no floor block offered, yet 167 MW median when directed.
2. **Gross world is no longer an inference; it is the ledger.** Payment = 0.95 x gross MWh x
   directed price, R-squared 0.99, two unexplained episodes in 271.
3. **The sequencing story survives, weaker, and we say so.** On corrected clocks, the exit
   announcement precedes the direction in 71% of the zero-excess lobe (121 episodes) and 77% of
   all 271 comp-matched episodes -- majority conduct, not the 91% previously claimed. The
   median lead falls from 15.8 h to 6.3 h before issue: exits are typically announced the
   morning-to-midday before AEMO issues (directions are issued ~a day ahead of ~08:30 windows),
   not two daily-bid cycles out. And 21% of episodes now show the exit rebid AFTER issue --
   under the broken clock those post-issue rebids (many of them direction-response rebids)
   looked pre-issue. The corrected sequence: **most exits are announced before AEMO acts, by
   hours not days; a fifth follow the direction rather than precede it.**
4. **The day-ahead fact is untouched and remains the strongest single number:** on the morning
   of the direction day, 97.8% of 740 episodes had already withdrawn (75.8%) or priced above
   $300 (22.0%) their floor megawatts in the day-ahead bid.

## Also affected upstream, NOT re-run here (queued; they consume the same event times)
`build_treatment_panel.R` (realised directed flags), the [F20] constraint decomposition
(directed-interval mass), the direction_rebid run-up analyses (A_depth / B_runup), [F5]/[F6]
rent-and-bidding descriptives, and any proposal figure built on directed windows. None feed
Task 2's panel (which uses bids + pex only). These need a scheduled re-run before the
manuscript cites them.

**STOP -- Job 1 complete. Awaiting review before Job 2 (contamination) per instruction.**
