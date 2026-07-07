# Test 4 findings — the make-whole payoff dose (NER 3.15.7B robustness check)

Registered: `07_round3/test4_preregistration.md` (before estimation). Script:
`07_round3/test4_payoff_dose.R`; log `outputs/07_round3/test4_run.log`; every number below is
from the test4_*.csv outputs. Framing fixed in advance: the d_t headline is not re-opened;
committed readings govern only the robustness subsection.

## VERDICT: the committed FAILS reading fires for the rent dose

The rent dose max(d_t − srmc_allin, 0) — the incentive-correct prize under the make-whole
assumption — produces **no dose response**: base reach interaction −0.039 (cluster se 0.090,
p = 0.670; WCB Rademacher p = 0.670, Webb p = 0.660; RI p = 0.652; month-grain slope +0.026,
p = 0.812 over 19 months, sign-flipped and null). The gross payment max(d_t, srmc_allin)
reproduces the headline in full: reach −0.093 (p = 0.0006; WCB p ≤ 0.0006; RI p = 0.011;
month-grain −0.114, p = 0.0001), stable across all four June treatments (−0.087 to −0.093,
p ≤ 0.0017), shares −0.048/−0.066 (WCB p ≤ 0.012). Per the registration: the headline survives
the formula dose but not the incentive-correct repricing; the author decides whether and how
headline language softens (STOP-AND-REPORT).

## Guards (all passed)

- Anchor: Test-1 base reach_a on comp_price_100 reproduced at −0.085521 (matches
  `test1_interaction.csv` to 6 decimals) before any new number was read.
- Assembly identical to Test 1: matched base sample 140,259 rows, 11,120 essential (12,513 is
  the count including the suspension window, per findings_test1).
- Binding geometry exactly as registered: 10 bound unit-months (TORRB2/3/4 × 202204/05/06,
  PPCCGT × 202204), rent = 0 in every bound cell, June TORRB gross = 322.19 (including under
  the APC treatment). Bound cells hold 1,062 of 11,120 base essential rows (9.6%; the
  registered ~19% figure counted the suspension-window rows that the base sample excludes).
- RI identity-permutation check reproduced b_obs exactly for both doses.

## Why the rent dose fails — two registered diagnostics, both bite

**1. Power (registered report, before coefficients).** Across essential rows the rent dose has
sd $41.6 and IQR **$11.8** against the old d_t dose's sd $81.2 and IQR $153.3. Rent is
hump-shaped — ~0 in the 2022 crisis cells (cost-bound), peaking in 2023H1 (d_t still at crisis
levels, gas fallen), compressed again in 2024 — and correlates with d_t at only 0.50 (rows) /
0.61 (months). Most of the cross-month variation the design identifies from is destroyed by
subtracting the cost series.

**2. The horse race rejects the make-whole restriction — informatively.** Unrestricted
essential×d_t + essential×allin (base sample):

| outcome | b(ess×d_t) | b(ess×allin) | restriction b_dt + b_allin = 0 |
|---|---|---|---|
| reach_a | −0.0406 | −0.0628 | −0.1034, p = 0.0008 |
| share_a | −0.0494 | −0.0026 | −0.0519, p = 0.0072 |
| share_b | −0.0056 | −0.0696 | −0.0752, p = 0.0025 |

Both interactions are **negative**: months with a higher compensation price and months with
higher fuel cost are both months where the essential-vs-matched gap is wider. The rent
construction assumes cost enters with the opposite sign to the payment (a higher cost shrinks
the prize); the data reject that on every outcome. Inside rent = d_t − cost the two negative
channels cancel, which is exactly the null observed. Per the registration, the rent coefficient
therefore inherits Test 3b's shared-variance ambiguity: the d_t gradient and the cost gradient
cannot be separated in this sample.

## Secondary registered results

- **Marginal-floor variant** (PPCCGT-degenerate, level-only): base reach −0.046 (p = 0.609);
  June-excluded −0.132 (p = 0.089). Reported, not interpreted (registered restriction).
  The rent dose generally strengthens when June 2022 is excluded (reach −0.114, p = 0.176)
  — June is a bound cell where rent = 0 sits on 19% of essential mass — but never reaches
  the committed significance threshold.
- **Interacted-FE variant (DUID^yyyymm):** interactions identical to the additive-FE spec to
  4+ decimals for both doses (rent −0.0390, gross −0.0933) — the near-collinear dose main
  effect and srmc control were doing no work on the interaction.
- **Unit-month grain:** rent +0.035 (p = 0.734, 60 cells), gross −0.114 (p < 0.0001) — same
  picture as the month grain.

## Adjudication against the committed readings

- ~~Confirms~~ — not met (rent p = 0.67 ≫ 0.10).
- **Fails — met.** Rent null on the base spec by every registered inference route (analytic,
  WCB, RI, month-grain).
- The Intermediate tiebreaker (horse-race restriction test) was also run and *rejects*
  make-whole pricing (p ≤ 0.007 on all outcomes), which sharpens the reading: it is not that
  the prize is measured and inert; it is that the cost side of the prize moves the gap the
  same way the payment does, so the make-whole prize is not identified separately from fuel
  stress in this sample.

## What this does and does not say (evidential status, carried from the registration)

The make-whole assumption itself is unmeasured where it binds: `additional_compensation` is
observed only Oct 2023+ (nonzero in 190/271 episodes but immaterial — d_t ≫ cost throughout
that window). If 3.15.7B top-ups are partial, delayed, or contested in practice, the effective
prize sits between d_t − cost and max(d_t − cost, 0) and the gross payment remains the relevant
dose — under which the headline stands unchanged. The registered conservative-bias note also
cuts the other way here: high gas lowers rent, so a fuel-stress gap pushes the rent coefficient
*positive*; the observed −0.039 is consistent with a modest true payment response masked by the
fuel channel, but the design cannot show it.

## Net effect on the manuscript (licensed by the registration)

1. §2 (setting) gains the 3.15.7B additional-compensation paragraph + evidential-status footnote
   (institutional completeness; unconditional per the approved plan).
2. §8 (robustness) gains the make-whole repricing subsection reporting: the repricing geometry,
   the gross-dose confirmation, the rent-dose null with the power caveat, the horse-race
   rejection with both-negative interactions, and the plain statement that the payment gradient
   and the cost gradient are not separable under the make-whole repricing.
3. **STOP:** any change to the abstract, introduction, or results headline language is the
   author's decision. The existing round-2 softening ("consistent with payment-seeking rather
   than proof") already anticipates non-separability evidence; whether Test 4 warrants further
   softening is not adjudicated here.
