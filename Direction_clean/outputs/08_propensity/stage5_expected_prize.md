# Stage 5 findings — the expected-prize test: a well-powered wrong-signed null

Registration: `08_propensity/stage5_expected_prize_registration.md` (committed first). Script:
`stage5_expected_prize.R`; outputs `stage5_{results, wcb, ri, ri_draws}.csv`; log
`stage5_run.log`. Anchor reproduced (−0.085521). Identity-permutation check passed.

## Power: the composite dose is NOT degenerate

EP = π × rent across essential rows: **IQR $46.8/MWh** (sd $26.8, range $0–136) — nine times
the committed $5 degeneracy screen and four times the raw rent's $12 IQR. Multiplying by π
*restores* identifying variation because π moves at the 30-minute grain within months.
Correlations: EP with d_t only 0.25 (largely independent of the headline dose), with π 0.77,
with rent 0.57. This null cannot be attributed to a flat regressor.

## Results

| term | estimate | cluster p | WCB p (Rad/Webb) | RI p |
|---|---|---|---|---|
| π (exposure, held in the model) | −0.451 | < 0.0001 | — | — |
| **EP = π × rent (per $100/MWh)** | **+0.147** | 0.101 | 0.110 / 0.100 | **0.185** |
| day-ahead variant: EP_da | +0.121 | 0.308 | — | — |

Horse race: π×d_t = +0.118, π×cost = −0.145; the make-whole (equal-and-opposite) restriction is
**accepted** (sum −0.027, p = 0.56) — on the exposure margin the data are content with the
rent's functional form; the composite simply points the wrong way.

## Adjudication (committed readings)

**The null reading obtains, via the wrong-sign clause.** The expected prize enters *positive* —
directly counter to payment-seeking, which requires conduct to intensify (reach to fall) as
probability × prize rises — and marginal at best under the analytic and bootstrap routes,
p = 0.185 under randomization inference. The "live margin" reading (negative, p < 0.10, RI
consistent) fails on sign before it fails on significance. The intermediate clause does not
rescue a directional hypothesis with the wrong sign. Per the registration: this completes the
triangulation and adds no new manuscript claims.

## What the triangulation now says, in one place

| dose | margin | result |
|---|---|---|
| d_t (gross formula price) | realized essential flag | **−0.086, p < 0.001** (the headline) |
| max(d_t, cost) (effective payment) | realized essential flag | −0.093, p < 0.001 (Test 4) |
| max(d_t − cost, 0) (rent) | realized essential flag | null (Test 4, Case B) |
| d_t | ex-ante propensity π | null, wrong sign (Stage 4) |
| **π × rent (expected prize)** | probability held fixed | **null, wrong sign, well-powered (this test)** |
| π itself (exposure level) | — | **−0.45, p < 0.0001** (Stages 4–5, day-ahead robust) |

Conduct responds strongly and robustly to *whether* the direction channel is live, on every
measurement of exposure. It responds to no ex-ante payment object — gross, net, or
probability-weighted — on any margin where one is identified. The payment gradient exists only
where realized essentiality and the gross administered price meet. The manuscript boundary this
draws is the author's to word; the pipeline's registered readings are exhausted.

**STOP — Stage 5 adjudicated.**
