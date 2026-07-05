# Job 2 findings -- the "already under direction" problem

**Committed reading (stated before running):** if the headline results hold on clean days
alone, the contamination worry is closed; if they weaken materially, the clean-day estimates
become the headline and the findings say why. **They weaken materially. The clean-day estimates
now govern, and this file says why.** All classifications use corrected (Job 1) direction times;
the record is now all one clock. Script: `task2_job2_contamination.R`; tables `task2_job2_*.csv`.

## (a) The contamination table (test units; bid-formation window = [lodgement, midnight])

| Group | Unit-days | Essential days |
|---|---|---|
| Clean (no direction touching the window) | 2,800 | **80** |
| Continuation-active (direction running in the window) | 991 | 73 |
| Issued-pending (issued by midnight, effective on the outcome day) | 446 | 28 |
| Boundary (direction ended earlier on lodgement day) | 147 | 5 |
| **Post-issue-exit episodes (the 26)** -- episode-level named row, see (b) | 26 episodes | -- |
| Total | 4,384 | 186 |

The feared clustering is real: 33% of all unit-days are contaminated (continuation + pending),
but **54% of essential days are** (101 of 186). Only 80 essential days survive as clean choices.

## (b) The 26 post-issue-exit episodes: participant-lodged, direction-response rebids
Metadata matched for 26 of 26 exit versions. **PARTICIPANTID = TIPSCO (the Torrens participant)
on all 26** -- these are participant-lodged, not AEMO-lodged. ENTRYTYPE carries only
DAILY (11) / REBID (15) across the whole bid table -- **no AEMO-variation marker exists in the
bid metadata**; the participant-ID check is the strongest identification available, and the
residual limitation is stated: if AEMO varied a bid in-place under the participant's ID, these
fields cannot see it. 17 of 26 explanations reference the direction ("AEMO direction - RTS
profile...") -- the post-issue "exits" are largely compliance/return-to-service reshaping after
the direction, not strategic exits. They are excluded from the clean-day sequencing claim and
carried as their own row above.

## (c) Step-6 split -- the honest number holds
Of 740 episodes (issue-day classification, the episode itself excluded from the touch test):
clean-day first directions 280; continuation-active 182; issued-pending 36; boundary 216
(boundary is large here because back-to-back daily directions end in the early evening before
the next day-ahead bid); the 26 post-issue-exit episodes separated.

**Clean-day first directions: 95.4% arrived at a day-ahead stance that had already withdrawn
(71.8%) or priced out (23.6%) the floor megawatts (267 of 280).** The number that can honestly
claim "the absence was chosen before the system acted" barely moves from the naive 97.8%.
Contaminated groups sit at 99-100%, as expected (direction-period bids are reshaped).

## (d) RQ1 on clean days -- the headline moves (committed rule applied)

| Outcome | Full sample (old headline) | Clean days only | Verdict |
|---|---|---|---|
| Component A (withdrawal) | −0.127 (WCB p 0.0004) | **−0.015 (p 0.71; WCB 0.71), n=2,800** | **Gone -- contamination artifact** |
| Component B (price of offered floor) | +1,983 (WCB p 0.020) | **+2,414 (p 0.18; WCB 0.17), n=669** | Size intact, significance gone; rests on 16 clean essential B-days -- suggestive only |
| Composite rank | −0.027 (p 0.014) | −0.011 (p 0.63) | Gone |
| Composite raw | null | null | Unchanged |

Why A was an artifact, shown directly: the raw withdrawal rate is 80.0% on clean essential days
vs 75.9% on clean ordinary days (no response, if anything higher) vs **42.5% on contaminated
essential days** -- units under or awaiting direction mechanically show availability in their
bids. The full-sample interaction confirms it: essential x contaminated = −0.259 (p 0.005) on
top of a contaminated main effect of −0.173 (p < 0.0001); and on the pricing side the
contaminated main effect is +$11,455 (p < 0.0001) -- direction-period bids park the floor MW at
the cap. The old "stays when needed" finding was substantially the direction itself sitting in
the measured bids.

**The corrected RQ1 statement:** on cleanly-formed day-ahead bids there is **no significant
essential-day response on either margin**. The pricing margin points the right way at the same
magnitude but 16 essential days cannot carry a claim. (Gate note: A-events among clean
essential days = 64, still past the ≥30 rule; the B-side thinness is the binding constraint.)

## (e) RQ2 on clean matched days -- null, unchanged
49 essential days over 14 months (137 matched unit-days): all four interactions null
(p 0.50-0.96). The dose-response conclusion is unchanged: none detectable, now on clean days too.

## What the all-one-clock, decontaminated record now supports (plainly)
1. **The standing-absence fact (strongest, untouched):** these units' day-ahead bids withhold or
   price out the floor megawatts on ~76-80% of ALL clean days -- essential or not -- and 95.4%
   of 280 clean-day first directions landed on such a stance. AEMO directs into a posture that
   is the units' everyday default, and (Task 1b corrected) pays gross for it, at 0.95 x MWh x
   directed price, R² 0.99.
2. **The state-dependence claim is NOT re-established.** What looked like "commits more, prices
   higher when essential" was, on the withdrawal margin, the direction contaminating the bid;
   on the pricing margin it survives in size but not in significance (16 clean essential days).
3. **No dose-response anywhere** (RQ2 null, full and clean samples; Stage 4's interval-level
   result remains the one prize-sensitivity in the project, at a different margin and grain).
4. Sequencing (Job 1): exits precede the direction in 71% of the corrected lobe / 77% of 271,
   median lead 6.3 h; the 26 post-issue cases are participant direction-responses.

The mechanism paragraph for the paper becomes simpler and harder: the absence is not provoked
by essentiality, nor priced to the direction prize -- it is a standing posture. The direction
regime pays that posture whenever the system needs the unit, which is exactly the incentive
structure the compensation-design section should critique.

**STOP -- Job 2 complete. Awaiting review before Job 3 (rank-statistic sweep + lead-time
distribution) per instruction.**
