# Stage 4 findings -- RQ2: does withholding respond to the size of the compensation price?

## PRE-REGISTERED INTERPRETATION (written before estimation; committed 2026-07-05)
- A POSITIVE, SIGNIFICANT interaction (essential x compensation price, on withholding) specific to
  essential intervals = the payment-seeking signature: the Torrens RQ1 response is at least partly
  prize-driven. (Sign note: the outcome is the cheap-capacity share, higher = less withholding, so
  payment-seeking withholding appears as a NEGATIVE interaction coefficient on the share -- i.e.
  the essential-vs-matched gap in the share widens downward as the compensation price rises.)
- A NULL = regime-triggered conduct consistent with the presence-inelasticity / insurance account:
  the unit responds to BEING essential, not to what essentiality pays this period. Given that both
  measured margins in Stage 3 (essentiality, saturation) show regime responses rather than
  dose-responses, a null here completes a consistent pattern and is reported as an INFORMATIVE
  BOUND, not a failed test.
- ATTENUATION CAVEAT (applies to the result either way): essentiality is classified on realised
  rather than forecast system state, so misclassification relative to the generator's bid-time
  information biases the dose-response toward zero. The test bounds large effects, not small ones.


## POWER DIAGNOSTICS (reported before the coefficient, per the amendment)
- Essential unit-rows in the matched sample: 12,513 (of 12,516 candidates; 100%/100% matched for
  Torrens/PPCCGT -- see `rq2_match_summary.csv`; CEM strata = unit x month x non-sync-quintile x
  hour-block x competition-bin, the Stage-2 measure entering the matching per the amendment).
- Spread over **21 month-clusters**; the top 3 months hold **50.8%** of the essential mass
  (`rq2_power_by_month.csv` has the full month x compensation-price table).
- Compensation price across essential rows: sd $76.6, IQR $113.5, month-level range $121-378.
- The compensation price is MONTHLY: net of month effects it has no within-month variation by
  construction. The interaction is identified off CROSS-month variation in the essential-vs-
  matched withholding gap; the effective clusters for that comparison are the 21 essential-bearing
  months, not the 36 calendar months. With half the mass in 3 months this is real but concentrated
  variation -- reported before the estimate, as committed. The estimate below clears conventional
  significance by a wide margin under both analytic and bootstrap inference, so it is NOT demoted
  to descriptive; the concentration stands as a stated limitation.

## RESULT: the essential x compensation-price interaction (per $100/MWh of compensation price)
| June-2022 treatment | Fixed $300 (p) | Cost-indexed 2xSRMC (p) | n |
|---|---|---|---|
| BASE: exclude suspension window only | -0.0512 (0.005) | -0.0554 (0.007) | 140,259 |
| (i) exclude all June 2022 | -0.0512 (0.006) | -0.0581 (0.001) | 134,636 |
| (ii) include window at APC $300 | -0.0442 (0.029) | -0.0496 (0.023) | 144,358 |
| (iii) base minus pre-suspension June | -0.0512 (0.005) | -0.0582 (0.001) | 135,269 |

Wild cluster bootstrap, base case (R=999, 35 df): fixed-$300 -0.0512 (Rademacher p=0.0041, Webb
p=0.0040); cost-indexed -0.0554 (Rademacher p=0.0073, Webb p=0.0061).

## INTERPRETATION (applying the pre-registered mapping above)
**The payment-seeking signature is present.** The interaction is negative on the cheap-capacity
share -- i.e. the essential-vs-matched withholding gap WIDENS as the compensation price rises --
at about **5.1 percentage points of registered capacity per $100/MWh** of compensation price
(~10 MW per 200-MW Torrens unit per $100; across the observed $121-378 month-level range, a
widening of ~0.13 of registered capacity). It is significant at the 1% level under analytic and
both wild-cluster-bootstrap inferences, on both outcome definitions, and -- unlike the RQ1 level
result -- it is STABLE across every June-2022 treatment: excluding the suspension window (base),
excluding all of June, including the window at the $300 APC imputation, and excluding
pre-suspension June all give -0.044 to -0.058 (p 0.001-0.029). This test owes nothing to June
2022.

Per the committed mapping: the Torrens RQ1 response is at least partly prize-driven. Combined
with Stage 3's elimination results, the ranking of channels for withholding-when-essential is:
energy-market power as measured -- eliminated (wrong sign of conditions); pure
presence-inelasticity conduct with no payment sensitivity -- rejected on this pre-committed test
(it predicted a null); payment-seeking -- the account the data support. One refinement to the
Stage-3 'regime-not-dose' frame survives alongside: conduct is regime-triggered on the
COMPETITION margin (saturation, not slope), but on the PAYMENT margin the essential-state response
does scale with the prize.

## Caveats (stated with the result, as committed)
- **Attenuation (pre-registered):** essentiality is classified on realised rather than forecast
  state; misclassification biases the dose-response toward zero, so the true payment-sensitivity
  is if anything LARGER than estimated.
- **Cross-month confounding is not excluded by month effects:** anything that widens the
  essential-vs-matched gap AND co-moves with the compensation price across months (e.g.
  fuel-supply stress in 2022H2, when the price peaked) could contribute. Mitigation, not proof:
  the 2024 mid-price months carry ~27% of the essential mass and the drop-all-June row is
  unchanged, so the result is not a gas-crisis artifact alone; a fuel-stress-specific control is
  a natural Stage-5 extension.
- Cluster concentration as above: 21 effective months, top-3 = 50.8%.

