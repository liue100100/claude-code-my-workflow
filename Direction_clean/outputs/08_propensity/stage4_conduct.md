# Stage 4 findings — the conduct test on the rivals-only propensity: the null reading obtains

Registration: `08_propensity/registration.md` (+ Amendment 1). Script: `stage4_conduct.R`;
outputs `stage4_{results, wcb, ri, ri_draws}.csv`; log `stage4_run.log`. Licensed by the
Stage-2 residual gate (2.8%) and the Stage-3 amended-gate PASS.

## Anchor

The pex specification reproduces Table 4 exactly on the identical assembly: −0.085521 vs
−0.085521. Every number below is estimated on the same matched base sample (140,259 rows).

## Results

| object | interaction with d_t (per $100/MWh) | p (cluster) | main effect | p |
|---|---|---|---|---|
| **π (primary, 8h)** | **+0.021** | 0.56 | **−0.395** | **0.002** |
| π_slow × d_t | +0.282 | 0.74 | −2.01 | 0.42 |
| π_fast × d_t | +0.007 | 0.88 | −0.336 | 0.014 |
| π thresholded at pex-matched incidence (π > 0.855, 7.9%) | −0.019 | 0.26 | −0.045 | 0.44 |
| day-ahead π (timing-immunized) | −0.029 | 0.39 | −0.318 | 0.009 |

Inference on the primary interaction: WCB Rademacher/Webb p ≈ 0.556; randomization inference
permuting the month-to-d_t assignment p = **0.828** (827 of 999 permuted |coefficients| exceed
the observed).

## Adjudication against the committed interpretations

- π × d_t < 0 (conduct scales with the ex-ante prize): **not observed** — the interaction is
  wrong-signed, tiny, and null under every inference route.
- π_slow × d_t < 0 with π_fast ≈ 0 (the preferred standing-posture shape): **not observed** —
  both components null. The Stage-2 power note applies to the slow component (sd 0.039), but
  the fast component had ample variance and is equally null.
- π_fast × d_t < 0 (daily responsiveness): not observed.
- **Null throughout — the committed reading:** *the pex-based headline does not generalize off
  the realized-state flag; reported as a limitation of the headline.*

Two facts sharpen the limitation:

1. **Conduct does load on the exposure level.** The π main effects are negative and significant
   (−0.395, p = 0.002; day-ahead −0.318, p = 0.009): the desk's floor-reach falls as the
   rivals-only direction propensity rises. The exposure–conduct relationship is real and
   survives the timing-immunized dose. What is absent is any modulation by the payment: the
   posture responds to *whether* a direction is likely, not to *what it pays*, anywhere on the
   continuous exposure margin.
2. **The thresholded check is the sharp version.** A binary flag at exactly pex-matched
   incidence (π > 0.855, 7.9% of rows) gives an interaction of −0.019 (p = 0.26) against the
   pex flag's −0.0855 (p < 0.001) on the identical design. The payment-sensitivity result is
   specific to the *realized* N−0 state — moments when the system in fact could not do without
   the units — and does not transfer to ex-ante exposure however measured.

## What this does and does not say

It does not remove the headline: on the realized essentiality margin the −8.6 pp/$100 gradient
stands with its committed inference. It bounds the headline's scope: the payment-gradient is a
property of realized-essential moments, not of the desk's ex-ante exposure to the direction
channel — under a payment-seeking account one would have expected the ex-ante prize
(π × d_t) to carry at least part of the gradient, and it carries none. Combined with the Test-4
rent null (07_round3), the payment-sensitivity evidence is confined to: realized-state flag,
gross administered price. Manuscript treatment of this boundary is the author's decision; per
the registration it is reported as a limitation of the headline.

**STOP — Stage 4 adjudicated. See propensity_summary.md for the one-page synthesis.**
