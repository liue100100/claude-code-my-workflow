# Session log — 2026-07-04 — Direction_clean/ Stage 3 (RQ1: withholding on essentiality)

## Goal
Estimate RQ1 per the approved plan: cheap-capacity share on the essentiality flag with unit +
month FE, SRMC, market-state controls, and the Stage-2 competition measure; headline = the
essentiality coefficient with vs. without the competition control; wild cluster bootstrap given
36 month-clusters. Stop before Stage 4.

## Pre-work: Stage-2 sign correction
Working through the regression's expected signs exposed an inverted interpretation in the Stage-2
gate outputs: the residual-demand slope (MW per $/MWh, ≤0) had been captioned "more negative =
less competition" — backwards. More negative = rivals more price-responsive = MORE competition;
zero = rivals saturated = LEAST competition (consistent with the markup diverging exactly there).
Corrected the gate figure + report and re-ran. The corrected reading is economically sharper:
essential intervals show MORE local energy-market competition on average — essentiality is a
security condition, not an energy-scarcity condition, which is exactly why the two are nearly
orthogonal and why RQ1 needs the control.

## Inference tooling
`fwildclusterboot` cannot be installed (archived from CRAN → no Windows binary; no Rtools for
source). Used `sandwich::vcovBS` wild cluster bootstrap instead (canonical package, not
hand-rolled): Rademacher primary + Webb sensitivity, R=999 (not 9,999 — each replicate is O(n) in
pure R on 1.26M rows; 999 is the standard applied choice), t with 35 df. Caveat documented: this
is the UNRESTRICTED variant, not boottest's null-imposed WCR; second-order at 36 clusters.

## Three bugs caught, fixed, documented (none shipped)
1. **Zero-crossing denominator in a control.** The spec's non-sync SHARE uses TOTALDEMAND as
   denominator, but SA demand crosses zero in-sample (rooftop solar; 1,524 rows ≤0), so the share
   ranged [-24,529, +9,041]. With the broken control the essentiality coefficients were ~10x
   inflated (-0.062/-0.107, p≈0.09-0.13) — extreme-leverage rows doing the work. Switched to the
   non-sync LEVEL (share kept as a demand>500 robustness row); documented as a deviation.
2. **Silent argument swallowing in sandwich.** Passed `wild="webb"` to vcovBS; the weight family
   is actually selected via `type=` ("wild-webb"), and the bogus argument vanished into `...` —
   caught because Rademacher and Webb rows came back bit-identical. Webb rows recomputed with
   `type="wild-webb"` (`_fix_webb_rows.R`). Lesson: the earlier smoke test "passed" only because
   the seed wasn't reset between calls.
3. **Findings sprintf crash after the 1-hour estimation run.** Split report generation into
   `finalize_findings.R`, which reads the saved CSVs, asserts numeric class + length-1 on every
   numeric argument, and never requires re-estimation.

## Results
- **Pooled (4 units): near-null.** Essentiality moves the cheap share by -0.004 (fixed-$300,
  WCB p=0.86) / -0.048 (cost-indexed, WCB p=0.21). M1→M3 movement tiny (0.7-6.2%) — the
  essentiality response, such as it is, is NOT absorbed by energy-market competition.
- **The pooled null masks opposite-signed unit responses:** Torrens withholds MORE when essential
  (-0.076 cost-indexed, p=0.04); Pelican Point offers MORE cheaply when essential (+0.18, p=0.07 —
  an essential CCGT is one that wants to run). A heterogeneity finding, not a null.
- **Load-bearing cross cut run immediately** (`_addendum_torrens_no202206.R`): Torrens-only
  without June-2022 stays negative (~-0.042) but significance dies (p≈0.13 both definitions). The
  Torrens 5%-result leans on the market-suspension month.
- **Saturated indicator is the strongest conduct correlate in the model** (-0.032, p<0.001): units
  offer ~3.2pp less cheaply exactly when rivals are locally saturated. The continuous slope
  carries nothing (p=0.99) — vindicates the Stage-2 gate flag that the action is at the mass point.

## Status: Stage 3 COMPLETE, all outputs final. Webb recomputation finished and validated: Webb
SEs now properly differ from Rademacher (~2-5% larger; p-values move trivially, e.g. 0.208→0.217
cost-indexed M1) — the sensitivity corroborates every conclusion. STOPPED per plan — Stage 4 (RQ2)
needs its own plan, and must carry the June-2022 exclude-base/impute-robustness treatment given
its role in the Torrens result.

## Open for the user
- Review `outputs/03_rq1_essentiality/findings.md` (esp. the heterogeneity + June-2022 reading).
- Stage 4 planning decision inherited from the old pipeline: same hybrid June-2022 handling.
- Housekeeping: still nothing committed (Direction/ since 2026-06-21; Direction_clean/ ever).