# Session log — 2026-07-04 — Direction_clean/ Stage 3b (RQ1 close-out amendments)

## Goal
Four user-specified close-out amendments before Stage 3 is locked: (A) symmetric leave-one-month-
out fragility diagnostic on both headline unit results; (B) three-way June-2022 split of the
Torrens result; (C) correct the elimination logic in the findings; (D) name two underweighted
findings. Stop for review before Stage 4.

## Implementation choices
- Suspension window defined from AEMO's own per-interval `MARKETSUSPENDEDFLAG` (2022-06-15 14:10 →
  2022-06-24 14:00; contiguity verified, zero unflagged intervals inside), not hardcoded dates.
  The APC (administered-price) sub-period from 2022-06-05 reported as an overlay on the
  pre-suspension segment — those days aren't ordinary pricing either.
- LOMO run on BOTH units for full symmetry (36 re-estimates × 2 units × 2 outcomes = 144 fits,
  M3 spec), not just the Pelican Point one the amendment strictly required.

## Results
**(A) The LOMO inverts the apparent fragility ranking.** Raw flag counts mislead (Torrens 9
flagged months vs Pelican Point 3): every Torrens flag is p-threshold wobble in the 0.03–0.15
band with the coefficient NEGATIVE in all 72 re-estimates; Pelican Point's +0.18 FLIPS SIGN when
October 2023 alone is dropped (+0.184 → −0.083). **Pelican Point's positive response is a
one-month artifact — withdrawn as a substantive finding** (the Stage-3 "essential CCGT wants to
run" interpretation does not survive and was removed from the main findings). Torrens is the
stable result.

**(B) The Torrens result is NOT suspension-era pricing conduct.** June segments: pre-suspension
957 essential unit-rows (319 intervals), suspension window 1,365 (455), post-suspension 0.
Dropping the suspension window alone: −0.068, p=0.054 (cost-indexed) — holds. Dropping the
pre-suspension fortnight alone: −0.058, p=0.045 — holds. Only dropping ALL of June (19% of
essential unit-rows) degrades it to p=0.13. Refinement of the earlier caveat: the dependence is
on June's essential-interval MASS (statistical power), not administered-price confounding.

**(C) Elimination logic corrected** in findings.md: Stage 3 eliminated energy-market power AS
MEASURED; the remaining channels are payment-seeking OR presence-inelasticity conduct (bargaining
posture / avoiding uncompensated must-run / standing policy on the perfectly-inelastic security
position, which the energy-space measure cannot see because that channel IS the essentiality
flag). RQ2 is the test that splits those two.

**(D) Two named findings added** to findings.md: (a) essentiality-is-not-scarcity — the
market-power alternative predicts the WRONG SIGN of conditions (essential periods have MORE rival
supply near the clearing price, −5.04 vs −3.31 slope); (b) regime-not-dose — both measured
conduct margins are discrete regime responses (saturation −3.2pp p<0.001 vs continuous slope
p=0.99; essentiality state response), the pattern a regime-triggered "insurance" model predicts,
setting the pre-registered interpretive frame for Stage 4.

## Files
`03_rq1_essentiality/stage3b_closeout.R` → `outputs/03_rq1_essentiality/stage3b_{lomo_path.csv/
png, june_segment_counts.csv, june_split.csv}` + `findings_3b.md`; main `findings.md` regenerated
via the amended `finalize_findings.R` (reading paragraph, elimination logic, named findings all
consistent with 3b).

## Status: Stage 3b COMPLETE. STOPPED for review before Stage 4 (RQ2), per instruction.
Stage 4 spec (already received, on file in the plan): suspension-window-only base exclusion;
robustness = drop-all-June / ex-ante administered-price imputation (never ex-post) /
leave-one-cluster-out on the binding June segment; PRE-REGISTERED interpretation written before
estimation; power diagnostics before the coefficient, with demotion to descriptive if identifying
variation is concentrated.
