# Test 4 pre-registration — the make-whole payoff dose (NER 3.15.7B robustness check)

**Committed BEFORE any estimation code for this test is written or run.** Plan of record:
`quality_reports/plans/encapsulated-coalescing-hammock.md` (approved 2026-07-07). **Framing fixed
in the plan: the paper's headline stands regardless of outcome.** The primary dose (d_t), the
headline numbers (reach interaction −0.0855, WCB p < 0.01, RI p = 0.046), and the abstract/intro/
results text are not re-opened by this registration. Test 4 is a robustness check; committed
readings below govern only how the new robustness subsection reads.

## The institutional claim and its evidential status

NER 3.15.7B entitles a directed participant to additional compensation — loss of revenue plus net
direct costs, less amounts already received — assessed by an independent expert, with
determinations routinely accepting claims in full. The effective payment for a direction is
therefore approximately max(DCP amount, cost recovery): a make-whole floor under the formula
payment. The incentive-relevant prize of being directed is then not d_t but the **rent**
max(d_t − cost, 0): in months where cost exceeds d_t, the direction makes the unit whole and
leaves zero rent.

Evidential status, stated plainly: in the only window with unit-level dollars (Oct 2023 – Dec
2024), `additional_compensation` is nonzero in 190 of 271 unit-episodes but immaterial in
magnitude — compensation reconciles as ~0.95 × gross output × d_t with R² 0.99 (Task 1b) —
exactly as expected, since d_t far exceeded cost throughout that window and the floor never
bound. The 2022 period where the floor binds is **unmeasured** (unit-level dollars begin Oct
2023). The repriced dose therefore rests on the make-whole institutional assumption, not on
measurement, and the robustness subsection will say so.

## Binding geometry (computed from existing outputs before estimation; fixes predictions)

Floor = unit-specific all-in SRMC (static heat rate × quarterly Adelaide STTM gas + VOM,
`GateA_srmc_params.csv`). Against the monthly d_t series:

| Cell | d_t | srmc_allin | bound? |
|---|---|---|---|
| TORRB2/3/4, 202204 | 156.55 | 322.19 | yes |
| TORRB2/3/4, 202205 | 252.62 | 322.19 | yes |
| TORRB2/3/4, 202206 | 241.38 (imputed) | 322.19 | yes |
| PPCCGT, 202204 | 156.55 | 223.50 | yes |
| all other unit-months | d_t > allin | — | no |

Ten bound unit-months. June 2022 alone holds ~19% of essential unit-rows, and April 2022 flips
from the lowest-d_t essential month to the highest-cost cell — the repricing is not cosmetic.
The rent dose zeroes exactly the Q2-2022 crisis cells, which makes it the payment-vs-fuel-stress
separator: **high gas lowers the rent, so fuel-stress-driven gap widening biases the rent
coefficient toward positive — against the payment-seeking prediction.** A negative rent
coefficient is evidence net of the paper's main confound.

## The doses (committed)

1. **Primary: rent** `rent_im = max(d_t_m − srmc_allin_im, 0)`, unit×month, in $100/MWh units.
2. **Companion: gross payoff** `payoff_im = max(d_t_m, srmc_allin_im)`. The gross measure is what
   flows through the meter, not the prize; the rent-vs-gross divergence is itself a diagnostic
   (gross contains cost in the bound cells, so a fuel story can mimic a gross-dose response).
3. **Robustness floor: marginal SRMC** `max(d_t − srmc_marginal, 0)`. Known degeneracy, stated in
   advance: PPCCGT has srmc_marginal ≡ srmc_allin in all 36 months, so this variant moves only
   the TORRB floor (299.21 vs 322.19 in Q2-2022) and the bound-cell set is unchanged — a
   level-only sensitivity, not an independent check.

Committed caveats. (a) The dose is unit×month, so month fixed effects no longer absorb its level;
the dose main effect is near-collinear with the panel's srmc control conditional on month FE
(identified only off the kinked cells and the TORRB static-vs-incremental heat-rate wedge). The
main effect is **reported and never interpreted**. (b) SRMC measurement error (quarterly gas
step, engineering heat rates, proxy VOM) now enters the dose directly, not only a control; the
marginal-floor variant covers the heat-rate choice. (c) The srmc control stays in the
specification unchanged — the registered Stage-4 controls are not re-opened.

## Specification grid (committed; exact Stage-4/Test-1 machinery, only the price variable changes)

- **Main grid:** {rent, gross} × outcomes {reach_a, reach_b, cheap_a_share, cheap_b_share,
  intensive_a, intensive_b} × the four June-2022 treatments (base = exclude suspension window;
  (i) exclude all June; (ii) window at APC; (iii) base minus pre-suspension June). Marginal-floor
  variant restricted to {reach_a, cheap_a_share, cheap_b_share} × four treatments.
- **June composition:** the floor composes with each treatment. Base/(i)/(iii): June rows in
  sample carry rent = max(241.38 − allin, 0) (TORRB → 0, PPCCGT → 17.88) and gross =
  max(241.38, allin). Treatment (ii): the APC replaces the d_t component and the floor still
  applies — rent = max(300 − allin, 0) (TORRB → 0, PPCCGT → 76.50), gross = max(300, allin)
  (TORRB → 322.19, not 300).
- **Interacted-FE variant:** DUID^yyyymm fixed effects (absorbing all unit×month levels including
  the dose main effect and the srmc control; interval-level controls retained), rent + gross ×
  {reach_a, cheap_a_share, cheap_b_share}, base sample. This is the cleanest spec for a
  unit×month dose and is natural here because the CEM strata are within unit×month.
- **Unrestricted horse race:** `essential×comp_price_100 + essential×allin_100` (+ Stage-4
  controls, DUID + yyyymm FE, base sample, reach_a + shares). Off the kink the rent spec is this
  regression with coefficients constrained equal-and-opposite; a Wald test of
  β(ess×d_t) = −β(ess×allin) is reported. Restriction accepted → independent support for
  make-whole pricing; rejected → the rent coefficient inherits Test 3b's shared-variance
  ambiguity and the robustness text says so plainly.
- **Inference:** analytic cluster (month); WCB (sandwich::vcovBS, Rademacher + Webb, R = 999) on
  rent + gross × {reach_a, cheap_a_share, cheap_b_share}, base case; randomization inference
  re-run under the new dose — permutation object is the month-indexed **vector of unit doses**
  (permute month labels carrying each month's 4-unit block jointly, preserving cross-unit
  structure; 999 draws, seed 20260705, add-one two-sided p; identity-permutation check must
  reproduce the observed coefficient exactly). Month-grain companion (Test 3a analogue): monthly
  essential-vs-matched gap in reach on the **essential-row-weighted mean dose**, WLS by essential
  rows, HC1, months with ≥ 30 essential rows; unit×month-grain alternative reported if the two
  disagree in sign.
- **Anchor:** before any new number is read, the exact Test-1 base reach spec with comp_price_100
  must reproduce −0.0855 (±5e-4) against `outputs/06_round2/test1_interaction.csv`, proving the
  assembly is identical.
- **Power report before coefficients:** bound-cell count and essential mass, sd/IQR/range of rent
  and gross across essential rows next to the old d_t dose (sd $76.6, range $121–378), and
  cor(rent, d_t), cor(gross, d_t) at the essential-row and month grains.

## Committed readings (govern the robustness subsection only)

- **Confirms** — rent-dose reach interaction negative, analytic p < 0.10, RI consistent (p < 0.10):
  the headline is robust to repricing the dose to the make-whole prize; reported with the note
  that the fuel confound biases this check against the result.
- **Fails** — rent-dose reach interaction null or positive (p > 0.30, or wrong sign): the headline
  survives the formula dose but not the incentive-correct repricing. STOP-AND-REPORT to the
  author before any manuscript text beyond the robustness subsection is drafted; the author
  decides whether and how headline language softens. The gross-dose result is reported alongside
  but cannot rescue the reading (gross conflates cost recovery with prize).
- **Intermediate** — marginal p (0.10–0.30), or rent and gross disagree materially: both reported
  with equal prominence; the horse-race restriction test adjudicates whether make-whole pricing
  is accepted by the data; ambiguity stated plainly.

## Not licensed

No outcome or window changes; no floors beyond the three named; no re-opening of the Stage-4
controls, CEM strata, or the June treatments; no test2 (era contrast) rerun; no interpretation of
dose main effects. Follow-ups need a fresh registration.
