# Test 1 pre-registration — floor-reach decomposition of RQ2 (Direction_clean/06_round2)

**Committed BEFORE any estimation code for this test is written or run.** Plan of record:
`quality_reports/plans/2026-07-06_round2-referee-response.md` (approved 2026-07-06). Motivation:
the RQ2 outcome (cheap-capacity share) mixes the direction-eligibility margin — whether the
unit's minimum-stable-load quantum is within dispatch's reach — with intensive-margin depth that
direction economics do not touch. The closest existing test of the eligibility margin (Task 2
Component A x comp price, day grain) is null but unpowered (140 essential days). This test fills
the missing cell: the eligibility margin at the interval grain, on the exact Stage-4 design.

## Outcomes (constructed from `outputs/01_outcome_withholding/outcome_panel.rds`, MW levels)

- `reach_a` = 1{cheap_a >= floor MW} (fixed-$300 threshold); `reach_b` = 1{cheap_b >= floor MW}
  (2xSRMC threshold). Co-primary, mirroring Stages 1/4.
- Floors (Task 2 frozen values, reused as-is): TORRB2/3/4 = 40 MW. PPCCGT: 42 MW on
  single-turbine days, 125 MW on dual-turbine days, resolved by the Task-2 rule (unit-day
  MAXAVAIL ceiling <= 239 MW = single). OSB-AG excluded (descriptive-only throughout).
- Intensive margin: `cheap_a_share` (and `_b_`) on the `reach_a = 1` (resp. `_b_`) subsample.
  STATED LIMITATION (committed now): the intensive regression conditions on an outcome and is a
  decomposition aid, not a causal estimate on its own.

## Design — identical to Stage 4, nothing re-chosen

Same CEM strata (unit x month x nonsync-quintile x hour-block x competition-bin), same matched
sample, same controls and fixed effects (unit + month), same four June-2022 treatments (base:
exclude suspension window; (i) drop all June; (ii) window at APC $300; (iii) base minus
pre-suspension June), same June ex-ante comp price ($241.38), same clustering (month), same wild
cluster bootstrap (sandwich::vcovBS, Rademacher + Webb, R = 999) on the base-case interaction,
same seed (20260705). The only change is the dependent variable.

## Power gate (reported BEFORE any coefficient; Task-13 precedent)

Report, per unit and pooled, on the matched sample: (a) the reach rate among essential rows and
among comparison rows; (b) the number of essential-bearing months in which essential rows show
BOTH reach states. **Degeneracy rule:** if the pooled essential-row reach rate is < 5% or > 95%,
or fewer than 8 essential-bearing months show within-month variation on the essential side, the
eligibility-margin estimate is reported as a BOUND (point estimate + CI, no headline claim), not
a forced estimate.

## Committed interpretations (fixed now; the headline decision rule of the approved plan applies)

1. **Interaction negative and significant on `reach`** (both definitions, surviving WCB, stable
   across June treatments): the dose response lives on the direction-eligibility margin — the
   payment-seeking reading is confirmed on exactly the margin the mechanism requires. The paper
   keeps its headline and adds the mechanical stance paragraph (S5.1).
2. **Null on `reach`, negative only on the intensive margin:** the payment-seeking reading is NOT
   supported where direction economics live. The manuscript headline moves to the
   mechanism-design accounting; the Stage-4 share result is reported with this decomposition as
   the stated reason for caution. This interpretation applies even though it weakens the paper.
3. **Both margins negative and significant:** the share stands as the primary summary (it
   integrates both); the decomposition goes to an appendix as confirmation.
4. **Gate-degenerate:** reported as a bound; the share result stands but the manuscript must
   state that the eligibility margin is untestable at this grain — no stronger claim.

Sign convention: reach/share are presence measures; payment-seeking appears as NEGATIVE
interactions. Attenuation caveat carries over unchanged from the Stage-4 registration.

## What is NOT licensed by this registration

No re-specification after seeing results; no alternative floors, thresholds, strata, or sample
windows beyond those fixed above; any follow-up requires a fresh registration.
