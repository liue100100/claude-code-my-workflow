# PROJECT RECORD — South Australian Directions, Compensation, and Generator Bidding Behaviour

**Consolidated 2026-07-05 from the findings files in `Direction_clean/outputs/05_mechanism/`
and the stage findings in `Direction_clean/outputs/01–04`. No new analysis. Every number below
is carried from a named findings file. Superseded results appear only in Section 5 (the audit
trail) or where explicitly marked. This document is written to be self-contained: a reader
with no access to the repository, and no electricity-market background, should be able to
follow the project and discuss its results.**

---

## 1. The question and the setting

**The question.** South Australia pays certain gas-fired generators, by administrative order,
to be on the grid when the power system needs them for stability. The payments are generous.
The project set out to test a specific worry: do these generators *strategically make
themselves absent* — withholding capacity from the market — in order to be ordered on and
collect those payments? Or is their absence ordinary commercial behaviour (a plant that loses
money by running simply doesn't run), with the payment regime merely catching it?

**The setting, in plain terms.** South Australia runs on one of the world's highest shares of
wind and rooftop solar. Those sources don't provide the physical grid stability (inertia,
system strength, voltage control) that conventional spinning machines do, so the market
operator, AEMO, maintains a standard: at all times, some minimum combination of the state's
*synchronous* generators — big gas units — must be online. On sunny, windy days, market prices
collapse (often below zero) and those gas units cannot cover their fuel costs by selling
energy. If too few of them stay on voluntarily, AEMO issues a **direction**: a legal order to
a specific unit to synchronise (come online) or remain synchronised. A directed unit is
compensated. The compensation is not the market price: it is paid at a **directed price**
derived from a trailing average of high past prices (the 90th percentile of the previous 365
days of spot prices), which sits far above the low prices prevailing at the moments directions
happen. The mechanism therefore creates a channel in which *being needed while absent* pays,
and pays well.

**The focal units.** Three units of the Torrens Island B power station (TORRB2, TORRB3,
TORRB4; 200 MW each, minimum stable output 40 MW) — ageing gas-steam units, the incumbents of
the direction regime, whose owner announced in November 2022 that the station will close in
June 2026. And Pelican Point (PPCCGT; 478 MW), a modern combined-cycle plant that mostly
competes in the market, used throughout as the technological comparison. A cogeneration unit
(Osborne) is carried descriptively only.

**The data.** January 2022 – December 2024, at five-minute resolution: every **bid** the units
lodged (a daily ladder of ten price bands with quantities, plus a declared availability
profile for each five-minute interval, revisable by "rebids" up to real time); every dispatch
outcome; every direction event AEMO published, with per-event compensation dollars from
October 2023; spot prices, demand, interconnector flows; engineering fuel costs; and a
reconstruction of AEMO's minimum-combination requirement at every interval, from which the
project builds its "essentiality" measures — whether the system, at that moment, could not be
made secure without the unit in question. All event timestamps sit on a corrected clock after
a timestamp bug was found and fixed mid-project (Section 5).

---

## 2. The headline findings — the five-question spine

**Q1: Do they bid their costs?** No — not even approximately, and not even in fully
competitive periods. Offers are unresponsive to fuel costs on both the price and quantity
margins: the implied heat rate recovered from offers is 0.22 GJ/MWh against an engineering
7–11, and Torrens parks ~26% of its capacity below $150/MWh whether gas costs $10 or $30/GJ
(`Direction/facts_memo.md` [F3a]). The ladder is a fixed posture, not a cost schedule.

**Q2: What do they do instead?** They hold a **standing absence**. On roughly three quarters
of all clean days (72–77% across measurement choices), the Torrens units' day-ahead bids
either withdraw the megawatts that keep the unit online or price them near the market cap;
the posture persists in multi-day blocks (once absent, 93% chance of being absent tomorrow;
median run 5 days) (`findings_horizon_stance.md`). Pelican Point, by contrast, is absent *on a
schedule* — off through the solar hours, on for the evening — a duty cycle, not a state
(`findings_task3_part0.md`).

**Q3: Does the behaviour respond to anything?** At the day-ahead posture margin: essentially
nothing. Not to the system needing the unit (the essentiality effect on withdrawal collapsed
to zero once contaminated days were removed), not to what a direction pays (the registered
dose-response was null on every outcome), not to expected running losses at the daily-decision
level (`findings_job2_contamination.md`, `findings_task2.md`, `findings_task9_exit_act.md`).
One earlier interval-level result stands with stated caveats: the intraday withholding share
did widen with the compensation price (−5.1 percentage points of capacity per $100, p < 0.01;
`Direction_clean/outputs/04_rq2_compensation_price/findings.md`) — the single
prize-sensitivity in the record, at a different margin and grain.

**Q4: What happens when the system needs an absent unit?** AEMO directs it, it runs at exactly
its minimum stable output — median excess over its own offered floor block: 0.0 MW — and it is
paid on its whole output at the directed price: compensation = 0.95 × directed MWh × directed
price, R² = 0.99 (`findings_task1b.md`, `findings_job1_timestamp_fix.md`). Across 2022–2024
this paid the three Torrens units **$141.9M for output that would have earned $7.2M at market
prices — roughly $20 for every $1**, with the market value of the same output *negative* in
2023 (`findings_task5b.md`).

**Q5: What does it mean?** The absence is a **policy chosen once, not a daily decision** —
98% of directions on clean days landed on a stance that had already withdrawn or priced out
the floor megawatts across the operator's whole planning horizon
(`findings_horizon_stance.md`). Given payment rates of 20:1, absence dominates commitment
under essentially all conditions, so there is nothing left for the desk to calibrate daily —
which is exactly why the dose-response tests are null. The economic content is in the
mechanism's design, not in generator sophistication
(`interpretation_staged_framework.md`).

---

## 3. The evidence, finding by finding

### 3.1 Offers are not cost-reflective
**Claim:** the units' offers do not track fuel costs on any margin, even in competitive
periods. **Numbers:** over 9,295 competitive unit-days, the within-unit slope of the low offer
band on gas prices implies a heat rate of 0.22 GJ/MWh (engineering: 7–11; within-R² 0.003);
the price to clear the low tranche *falls* as gas rises (slope −110.7, t = −5.8); the share of
capacity offered below $150 is flat at ~26% across the whole gas range. **Method:** revealed-
cost regressions restricted to undirected, non-pivotal, system-secure intervals, so the
failure is not an artifact of strategic periods. **Source:** `Direction/facts_memo.md` [F3a];
withholding-share construction and channel decomposition in
`Direction_clean/outputs/01_outcome_withholding/findings.md` (physical withdrawal dominates:
51–69% of withheld intervals by unit, with a further 22–33% both withdrawn and priced out).

### 3.2 The standing absence: base rate, block structure, persistence
**Claim:** absence is the Torrens units' resting state, held in multi-day blocks. **Numbers:**
the day-ahead stance withdraws or prices out the floor megawatts on 72–77% of clean unit-days,
stable across horizon lengths (7 h / 10.5 h / 25 h) and threshold choices (`findings_horizon_
stance.md`, panel table); whole days are the unit of choice — ≥23 absent hours on 57–73% of
Torrens clean days, with only 8.0–11.5% of days partially absent (`findings_task3_part0.md`,
n = 640/530/577 clean days per unit); persistence P(absent tomorrow | absent today) = 92.8%
(93.3% on clean day-pairs, n = 2,799), with absent runs of median 5 days, P90 ≈ 32, P99 ≈ 114
(`findings_horizon_stance.md`). **Method:** midnight bid stances, availability measured
against the 40 MW floor, clean days classified as in Section 7. The 173 Torrens partial days
are mostly the entry/exit ramps of block spells (59% within one day of a state transition;
`findings_task3_gates_transitions.md`).

### 3.3 The payment mechanics: gross world
**Claim:** direction compensation pays the unit's whole directed output at the directed price
— not the increment over what its bids offered. **Numbers:** compensation = 0.948 × (directed
MWh × directed price), R² = 0.990 across 271 episodes with per-event dollars; the alternative
"increment" model collapses to R² 0.364; only 2 of 271 episodes (0.7%) deviate from the
formula; computed output matches AEMO's reported directed energy at correlation 0.992; on the
35 lowest-output episodes the fit is exact (R² = 1.000) (`findings_task1b.md`,
`findings_task1d.md`). **Method:** episode-level reconciliation of computed energy × the
monthly directed-price series against AEMO's published per-event compensation (available
2023-10 onward). Directed output itself equals the operating floor exactly: median excess over
the unit's own floor block 0.0 MW, IQR [−1.5, +0.2] (`findings_job1_timestamp_fix.md`, rows 1–2).

### 3.4 The sequencing fact: directions land on pre-declared absence
**Claim:** when AEMO directs, the absence it is overriding was already declared in bids lodged
before the system acted. **Numbers:** of 740 direction episodes, 97.8% arrived on an issue-day
stance that had withdrawn (75.8%) or priced out (22.0%) the floor megawatts
(`findings_task2.md`, Step 6); restricted to the 280 clean-day first directions — where the
bid was formed with no direction anywhere in its formation window — the share is 95.4%, and
measured across the operator's full median direction horizon (10.5 h) with an at-issue
information cutoff it *rises* to 97.9% (98.6% at the 25-hour horizon), with the "not yet bid"
category empty: the whole horizon had been affirmatively bid absent, in every one of the 280
episodes (`findings_horizon_stance.md`). Exit announcements precede the direction's issue in
71% of the 121-episode zero-excess set and 77% of all 271 dollar-matched episodes, at a median
lead of 6.3 hours (`findings_job1_timestamp_fix.md`, rows 11–12).

### 3.5 The evening-zeroing act
**Claim:** the one dated, individual "exit act" in the record is real and dramatic: whole
offered evenings cancelled to zero. **Numbers:** in the two days before clean first
directions, 90.1% of withdrawn evening hours are floor-crossings (265 of 294 events) — from a
median 200 MW (full capacity) to a median 0 MW — at 24× the quiet-day rate (0.651 vs 0.027
crossings per rewrite-day); 45 of 161 D−1 rewrite-days (28.0%) contain at least one; the
"deepening an existing absence" category is empty because below-floor evening availability is
already zero (`findings_task5c_depth_check.md`). **Method:** hour-level availability compared
across consecutive midnight bid stances against the 40 MW floor, Torrens only, corrected
clock. Geometry note: the crossings zero the evening *leading into* the direction window, not
the direction-covered hours themselves.

### 3.6 Event-timed, not need-timed: the resolution of the exit act
**Claim:** the exit act tracks the approach of a direction event, not the security envelope,
and not the loss calendar. **Numbers:** the factorial: inside a direction-approach window the
cancellation rate is 32.9% on ordinary days (56/170) and 25.7% on N-1-essential days (9/35),
versus 14.6% (33/226) and 7.3% (3/41) outside — the event doubles-to-triples the rate in every
tier, while, window held fixed, essential days cancel *less* than ordinary days
(`findings_task8_four_checks.md`, Check 4a). The registered regression (473 clean evening-on-
offer days, 96 essential, 107 cancellations): the N-1 essentiality coefficient is **negative**
— −0.163 (wild-bootstrap p 0.017–0.019) unconditionally, −0.124 (p 0.058–0.065) with the loss
control; the newly-powered N-1-only tier is −0.190 (p 0.004) while the N-0 tier is exactly
zero; and the loss control itself enters with the *wrong sign* for loss-avoidance
(cancellations are less likely when the prior day implies running losses; −0.0003, p 0.005)
(`findings_task9_exit_act.md`). **Method:** linear probability model, unit and month effects,
directions never on the right-hand side, pre-registered readings. **Reading (committed):** the
envelope does not provoke exits — if anything it retains offered evenings; exits sit in the
direction run-up itself.

### 3.7 The pricing margin: flat at the floor band
**Claim:** when the floor megawatts are offered at all, their price does not respond to the
system needing the unit. **Numbers:** across 650 clean days with the floor offered, the
essential-day effect on the floor-megawatt's price is +$45 (wild-bootstrap p 0.86; 115
essential days); at hourly resolution, Pelican Point's offered floor price is a constant
−$998 within days — the within-day essential-hour effect is exactly $0.00 on 14,229 offered
unit-hours — and Torrens shows +$118 (p 0.39); the median offered floor price is −$998 to
−$1,000 in every cell of the essential-hours × essential-days × ordinary-days table
(`findings_task10_floor_pricing.md`). Separately, the floor block never migrates up the price
ladder: 1 up-band migration in 1,556 day-over-day windows — the offer is two-state (floor
price or gone), and repricing happens only by whole-day bid replacement (`findings_task5a.md`,
addendum). **Method:** the established effective-ladder floor-price measure (band quantities
cumulated, capped at declared availability), completed under the N-1 essentiality cells;
Section 5 records the small-cell suggestion this test retired.

### 3.8 The dollar comparison: sitting out versus running
**Claim:** the direction channel out-paid the market channel by roughly 20 to 1 on the same
megawatt-hours. **Numbers:** 683 Torrens episodes, 625,635 directed MWh, full dispatch and
price coverage: direction earnings $141.9M (actual per-event compensation where it exists,
the verified formula elsewhere; the two agree — the actual-compensation subset alone runs
$52.5M vs $2.4M, ~22:1) against $7.2M for the same output at realised spot prices — a gap of
$134.7M. Per MWh: $191–272 directed versus −$6 to +$28 at spot; 48.2% of directed MWh were
delivered at negative spot prices; in 2023 the market value of the directed output was
negative for all three units (`findings_task5b.md`). **Method and stated limit:** a comparison
of payment rates on the same output over the same corrected windows — not a full
counterfactual world (AEMO's behaviour could differ if the units bid differently).

### 3.9 The technology contrast
**Claim:** the two station types are absent in categorically different ways, and the
directions mechanism pays into one of them. **Numbers:** Torrens is absent as a *state*
(Section 3.2), and its state changes cluster in direction-saturated weeks (65–87% of its
~150 transitions had a direction within the prior 7 days, against base rates of 51–65%; absent
spells median 6–8 days, max 155). Pelican Point is absent on a *schedule* (58% of its 1,053
clean days are partial, absent 05:00–11:00 at 81–93% rates, day-to-day pattern correlation
0.78), its rare whole-day absences are brief (median 1 day, max 41) and loss-calendar-timed
(83% of its transition weeks had expected running losses; directions nearby at exactly its
13% base rate), and it offers its floor in 81% of its essential hours where Torrens offers in
15–21% (`findings_task3_part0.md`, `findings_task3_gates_transitions.md`, task10 gate). The
framing sentence recorded in the findings: *the incumbent steam station is absent as a state;
the CCGT is absent on a schedule; and the directions mechanism pays gross rates into the first
while the second mostly supplies the market.*

### 3.10 The vigilance result: the pre-direction churn and its content
**Claim:** the desks visibly see directions coming — the bid document becomes intensely active
in the 48 hours before one — but the activity is monitoring, not repositioning. **Numbers:**
churn (day-over-day rewriting of the lodged ladder) runs at median z of 22.0 and 24.5 against
the unit's own quiet baseline on D−2 and D−1 before clean first directions (n = 156, 185
clean days), while the floor-point outcome sits at z = 0.00 in the same windows; 99% of the
D−1 stances predate the direction's issue, so the ramp is pre-issue conduct
(`findings_task4_part3.md`). Its content: the ramp is extensive-margin — more days touched
(50.5% quiet → 76.9% at D−1) with *smaller* touches (median band churn ~2.8 vs 5.5 GWh on
quiet changed days), delivered through the routine daily lodgement; net displacement across
the approach is approximately zero (69.1% of 123 windows materially changed vs 36.3% quiet,
but up and down near-balanced, means ≈ 0) (`findings_task4_part3b.md`, `findings_task5a.md`).
Two thin directional edges ride on the routine: availability hours being reworked shift
toward the next day's stress window — in Torrens's own numbers, evening availability is pulled
at −22 to −32 MWh/hour before directions and re-timed *into* the day before essentiality
onsets (+19 to +26 MWh/hour, n = 29) — and the cheap end of the ladder drains slightly on the
final day (−81 MWh median) (`findings_task4_part3b.md` addendum;
`interpretation_staged_framework.md` Amendment 1). Inside the near-zero *average* sits the
real act of Section 3.5 — the depth check is what resolved the cancelling average into
whole-evening zeroings.

---

## 4. The tests that came back null, with their power

Nulls are results. Each row below is a registered or gated test; "could not rule out" states
the honest boundary of each.

| Test (source) | What it ruled out | Power / cells | What it could NOT rule out |
|---|---|---|---|
| Competition slope on withholding (`03_rq1_essentiality/findings.md`) | Withholding responding to the *degree* of local competition (slope coefficient p = 0.99) | 1.26M intervals | The *regime* matters: the saturated-rivals indicator is −3.2 pp, p < 0.001 — conduct responds to facing no competition at all |
| Day-ahead dose-response: commitment price on the compensation price (`findings_task2.md`) | Any large scaling of the day-ahead posture with what a direction pays (all four outcomes, all June-2022 treatments, with/without loss control) | 458 matched days, 140 essential, 16 months; composite CI ≈ −$300 to +$1,630 per $100 | Small effects; and the interval-level Stage-4 result (−5.1 pp/$100, p < 0.01) stands at its own margin with cross-month caveats |
| Essentiality effect on the standing posture, clean days (`findings_job2_contamination.md`) | The "commits more when needed" reading — the −12.7 pp full-sample effect was direction contamination (clean-day rates: 80.0% essential vs 75.9% ordinary) | 2,800 clean days, 80 essential | A pricing-side response was left suggestive (+$2,414, 16 days) — later completed and retired (Section 5) |
| Mechanical-break backstop (`findings_task2.md`, Step 4) | Nothing — infeasible as registered | 0 matched essential days in the PRE window (2023 has ~7 essential station-days) | Everything; moot for a null dose-response |
| Within-bid profile positioning (`findings_task3_gates_transitions.md`) | Testability itself: Torrens has no intraday variation (173 partial days < 200 gate); PPCCGT has almost no essentiality (4 essential-bearing clean days, 20 hours, price-correlation −0.004) | Gates, not estimates | Ruled out *in principle* for this sample and flag design — a two-sided impossibility reported as the finding |
| Exit act on N-0 essentiality (`findings_task6_exit_act.md`) | Nothing — stopped at its gate | 20 essential evening-on-offer days, 6 cancellations; minimum detectable difference ≈ 26 pp vs the +8.6 pp observed | Everything; superseded by the powered N-1 version (which found retention, Section 3.6) |
| Floor pricing on essential days, completed (`findings_task10_floor_pricing.md`) | An essential-day premium on the offered floor price (+$45, WCB p 0.86, 115 days; PPCCGT within-day exactly $0) | 650 B-days; 26,502 offered hours | Premia expressed through channels other than the lodged ladder (none exist in this data) |
| Direction duration on the compensation price (`findings_task2.md`, Step 5) | Duration scaling with the prize (−1.6 h/$100, p 0.38; non-monotone terciles) | 740 episodes | — |
| Rebid intensity / lever mix on essential days and approaches (`findings_task4_part3.md`) | Conduct signal in the non-direction-tagged rebid stream (flat everywhere it was allowed to speak) | Flagged-weak instrument (validated partially) | — |

---

## 5. The reversals and corrections — the audit trail

This section is the record of the project catching its own errors, in order. Superseded
numbers live here and nowhere else.

**5.1 The +10-hour timestamp bug (found in Task 1d; fixed in Job 1).** Every direction-event
timestamp in the pipeline was 10 hours late — a timezone double-conversion in the report
parser, verified three independent ways (code logic; dispatch energy matching the −10h windows
exactly where recorded windows showed zero; episode start-times clustering at the essentiality
clock's *minimum* as recorded and at its ramp once shifted). What it contaminated and what
survived (`findings_task1d.md`, `findings_job1_timestamp_fix.md`): the payment-formula verdict
*strengthened* (misfit episodes 41% → 0.7%; the increment model's R² fell from a spurious
0.888 to 0.364); directed-output-equals-floor sharpened (median excess +12 to +28 MW → 0.0);
but the sequencing headline was rewritten — "exit announced before the direction in 91% of
episodes" became **71% of the corrected 121-episode set / 77% of all 271, at a median lead of
6.3 h not 15.8 h, with a new 21% class of post-issue rebids** that the broken clock had made
look pre-issue. Downstream, the constraint-decomposition residual collapsed from 15.6% to
1.6% on the corrected clock — the security flags explain 98.4% of directed intervals
(regeneration log; memory note `project_direction_timestamp_fix`).

**5.2 The contamination discovery (Job 2).** Bids lodged while a direction was running, or
with one issued for the next day, are not clean choices — and 54% of essential days carried
exactly that exposure. On clean days, the adjudicated RQ1 result reversed: the "withdraws
less when essential" coefficient (−12.7 pp, p 0.0004) collapsed to −1.5 pp (p 0.71); the raw
rates showed why (withdrawal 80.0% on clean essential days vs 75.9% ordinary vs 42.5% on
*contaminated* essential days — the direction itself was sitting in the measured bids). The
pricing-side component kept its size (+$2,414 vs +$1,983) but lost significance on 16 clean
essential days (`findings_job2_contamination.md`). The clean-day classification became a
standing filter for everything after.

**5.3 The N-0 → N-1 essentiality sequence.** The original essentiality flag (N-0: the system
infeasible *right now* without the station) proved stricter than the standard AEMO itself
operates (secure against the next contingency), and produced cells too thin to test (80 clean
essential days; 20 in the exit-act gate; 0 in the break window). The N-1 flag was built as the
ex-ante mirror of the operator's standard — *after* the N-0 exit-act test returned too-thin,
a sequence recorded in the findings at the time with a side-by-side rule: every N-1 result is
published next to its N-0 counterpart (`findings_task7_pex_n1_census.md`,
`findings_task8_four_checks.md`). The new label validated (recomputed N-0 flag matched the
panel 100%; monotone "trouble gradient" across ordinary → N-1-only → N-0 on renewables,
imports, competition; leakage audit R² 0.004–0.034) and multiplied clean essential days
80 → 606.

**5.4 The Component B suggestion, retired by its completed test.** The rebuild left one
suggestive positive: the floor-megawatt price looked +$2,414 higher on essential days, wild-
bootstrap p 0.17, on 16 clean essential days — explicitly reported as unpowered. Completed
under N-1 cells (115 essential B-days): **+$45, p 0.86**; its own N-0 tier in the completed
test: −$256, not significant; hourly medians at the floor band in every cell. The suggestion
was small-cell noise riding rare near-cap hours in the daily maximum-type statistic
(`findings_task10_floor_pricing.md`).

**5.5 The vigilance chain: ramp → housekeeping → the real act inside the average.** The churn
ramp before directions (z ≈ 22–24) initially read as pre-direction repositioning. The anatomy
(Part 3b) corrected this: the ramp is more-frequent but *smaller* touches through the routine
daily lodgement — vigilance, not repositioning — with net displacement ≈ 0 (Task A). The
depth check then refined the correction itself: hiding inside that cancelling average is a
genuine, dated act — whole offered evenings zeroed from full capacity at 24× the background
rate (Section 3.5). The final sequence of readings: not "repositioning," not merely
"housekeeping," but *a stable posture, closely watched, with occasional whole-evening exit
declarations concentrated into the direction run-up* (`findings_task4_part3b.md`,
`findings_task5a.md`, `findings_task5c_depth_check.md`). The interpretation note's two
amendments (station-split shape of the re-timing; check resolutions) are recorded in
`interpretation_staged_framework.md` under its visible-amendment rule.

---

## 6. What remains unknowable in this data

**Motive.** The payment and the weather arrive on the same clock. Directions, their generous
compensation, and the meteorological conditions that make the system tight are one bundle in
this sample: a desk watching the weather and a desk watching the direction calendar behave
identically in every observable we have. The project's strongest behavioural facts — the
pre-direction vigilance, the evening zeroings in the run-up — are timing facts, and timing
cannot separate anticipation of an order from anticipation of the conditions that produce the
order. This boundary is stated in the interpretation note and held in every findings file that
touches it.

**Expectations.** No pre-dispatch forecast archive was extracted, so the units' *bid-time
information* is proxied throughout by realised system state and by the previous day's realised
prices. Two consequences are on the record: essentiality classified on realised state biases
dose-response tests toward zero (the registered attenuation caveat), and the running-loss
control — previous-day day-mean price against fuel cost — represents evening-block economics
poorly on high-solar days, a weakness restated wherever the control appears (including where
it returned a wrong-signed coefficient that was reported, not re-specified).

**The thin cells no definition could fix.** Under the strict N-0 standard the sample contains
only ~75–80 clean essential Torrens days in three years, ~16 with the floor offered, ~20 with
an evening on offer — and 2023 is nearly empty of essentiality entirely (~7 station-days),
which also killed the mechanical-break design. The N-1 relaxation fixed power where the
operator's own standard justified it; nothing can manufacture strict-standard cells that the
sample does not contain, and every N-0 result is bounded accordingly.

**Intent behind the standing posture.** The posture predates and outlasts everything the data
can condition on; the owner announced the station's closure in November 2022, inside the
sample, so the final two years are the conduct of an incumbent that had already decided to
leave. Whether the standing absence is a strategy *for* the direction channel, a wind-down
policy, or ordinary economics of a loss-making plant is not identified — what is identified is
that the mechanism pays gross rates into it at 20:1 regardless.

---

## 7. The methodological record

- **Pre-registration with committed readings before estimation:** the Task 2 header (commit
  `405ef65`), the instrument-test header (`5d0451b`), the exit-act registration
  (`task9_preregistration.md`), and the floor-pricing completion (readings fixed in the
  instruction); each findings file quotes its applicable reading verbatim.
- **Interpretation fixed like a registration:** `interpretation_staged_framework.md`, committed
  before its two open checks ran, amended only visibly (Amendments 1–2) under its own rule.
- **Gates that stopped underpowered tests:** the Task 2 frequency gate; the within-bid gates
  (Parts 1–2 of the instrumentation pass); the N-0 exit-act stopping rule (enforced at 20/6);
  the four checks before the N-1 regression; the floor-pricing gate.
- **The contamination classification:** every unit-day classed by direction exposure in its
  bid-formation window (`findings_job2_contamination.md`); clean days only, thereafter.
- **Leakage audits:** the essentiality flags regressed on the unit's own offers — R² ≈ 0
  (Stage 1 for N-0; `findings_task7_pex_n1_census.md` for N-1, PPCCGT's 0.034 flagged).
- **Corrected clock:** all event times re-based after the Job-1 fix; pre-fix outputs archived
  in `_pre_tzfix/` and citable nowhere; upstream artifacts regenerated with forced cache
  rebuilds.
- **Side-by-side rule:** superseded and thin-cell results published next to their replacements
  (N-0 next to N-1 throughout; the Component B suggestion next to its completed null).
- **Inference:** month-clustered errors with wild cluster bootstrap (Rademacher and Webb,
  R = 999) on every headline coefficient; the vcovBS-not-boottest deviation documented in
  `03_rq1_essentiality/findings.md`.

---

## 8. Open items and paper skeleton

**Open items.** (1) The hand-written constraint-decomposition readout
(`Direction/outputs/docs/constraint_decomposition_readout.md`) still carries pre-fix numbers;
the corrected headline (residual 1.6%, flags explain 98.4%) is in the regeneration log and
memory — refresh the text when drafting. (2) The 2025 sample extension is a standing decision:
feasible (all data published), recommended only as a separately-flagged regime-exit segment
(Project EnergyConnect at full capacity; Torrens in its closure wind-down), not pooled into
registered results. (3) The Stage-4 interval-level dose-response carries a stated cross-month
caveat; a fuel-stress control was noted there as the natural robustness extension if that
result is featured. All artifact regeneration is otherwise complete and verified on the
corrected clock.

**Paper skeleton as it stands.**
- **Structure:** the five-question spine of Section 2, with Section 3's findings as the
  evidence sections and Section 4's nulls table presented as results.
- **The three load-bearing numbers for the abstract:** 98% of directions land on pre-declared
  absence (97.9% across the operator's planning horizon, with the bid record complete);
  compensation = 0.95 × output × directed price (R² 0.99); and $141.9M versus $7.2M — the
  20:1 payment gap.
- **The mechanism section:** the staged framework note verbatim — three levers, four stages
  of a tight day, the two-sided reading, and the resolution: a policy chosen once, with
  stage-appropriate housekeeping around it; the desk is informed, the nulls are not
  inattention, and motive is explicitly not established.
- **Positioning:** an incentive-design critique, not a conduct accusation. The record shows a
  compensation mechanism that pays a standing absence at gross rates whenever the system
  needs the unit — sustained by design, whatever its intent — and the policy conclusion
  addresses the design: the counterfactual payment basis, not the generator.

---

*Sources: all findings files under `Direction_clean/outputs/05_mechanism/` and
`Direction_clean/outputs/01–04`; `Direction/facts_memo.md` for pre-rebuild descriptives
([F3a], [F20] as corrected). Session log:
`Direction_clean/quality_reports/session_logs/2026-07-05_task2-and-1d.md`.*
