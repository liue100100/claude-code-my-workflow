# Stage 5 registration — the expected-prize test: π × rent

**Committed BEFORE any estimation code is written or run (2026-07-07, author-approved).**
Child of two closed registrations, requiring this fresh one: `07_round3/test4_preregistration.md`
(the rent dose) and `08_propensity/registration.md` + Amendment 1 (the propensity). Both parents'
"Not licensed" sections bar new specifications without registration; this file licenses exactly
one composite test.

## The object

Under payment-seeking the incentive-correct dose is the **expected prize**: probability of a
direction times the net payment it delivers,

  EP_it = π_t × rent_im,  rent_im = max(d_t_m − srmc_allin_im, 0),

with π = the rivals-only conditions-only propensity (π2, 8-hour horizon; Stage 3 audits passed
under Amendment 1) and the rent as in Test 4 (unit-specific all-in SRMC floor; June 2022 at the
imputed $241.38 d_t component). The two prior nulls (essential × rent; π × d_t) do not
mechanically imply this composite is null: EP is a distinct regressor concentrated on
high-π/high-rent half-hours.

## Specification (fixed)

Exact Stage-4/Test-1 machinery: CEM-matched base sample, outcome reach_a, Stage-4 controls,
DUID + yyyymm FE, cluster by month.

1. **Anchor:** the pex spec must reproduce Table 4's −0.0855 (±1e-6) on the identical assembly.
2. **Power report before any coefficient:** sd/IQR/range of EP across essential rows and across
   all matched rows; cor(EP, d_t), cor(EP, π), cor(EP, rent); share of rows with EP = 0.
3. **Primary:** reach_a ~ π + EP_100 + controls | DUID + yyyymm. The EP coefficient is the
   rent response *holding the direction probability fixed* — the question as posed.
4. **Unrestricted companion (horse race):** reach_a ~ π + π:comp_price_100 + π:allin_100 +
   controls | FE; Wald test of the make-whole restriction β(π×d_t) = −β(π×allin) (off the kink,
   EP = π×d_t − π×allin under the restriction).
5. **Robustness:** the primary with the day-ahead (timing-immunized) π.
6. **Inference:** analytic cluster; WCB (vcovBS, Rademacher + Webb, R = 999) on EP_100;
   randomization inference permuting the **month labels of the unit×month rent map** (4-unit
   blocks jointly, as Test 4 S8; EP recomputed per draw with π fixed; 999 draws, seed 20260705,
   add-one two-sided p; identity-permutation check must reproduce the observed coefficient).

## Committed readings

- **Live margin** — EP negative, analytic p < 0.10, RI consistent: conduct scales with
  probability × prize; this repairs the interpretation of BOTH prior nulls (each tested a
  marginal component; the composite is the incentive object). STOP-AND-REPORT before any
  manuscript text: this would materially strengthen the payment-seeking reading and the author
  decides how far it travels.
- **Null** — p > 0.30 or wrong-signed: completes the triangulation. Conduct tracks exposure
  (π main effect) and the realized-flag × gross-price margin, and no ex-ante payment object —
  gross, rent, or expected prize — modulates it. Reported as reinforcing the Test-4/Stage-4
  boundary on the headline; no new manuscript claims.
- **Intermediate** (p 0.10–0.30): reported with the horse-race restriction test as the
  adjudicator, ambiguity stated plainly.

Power honesty, committed: the rent's essential-row IQR is ~$12 and π compresses it further; if
the power report shows EP variation is degenerate (e.g., IQR of EP across essential rows below
~$5/MWh-equivalent), the null reading is reported as a **bound**, not evidence of indifference.

## Not licensed

No other outcomes, no other floors, no gross-payoff composite (π × max(d_t, c) ≈ π × d_t,
already run), no sample changes. Follow-ups need a fresh registration.
