# Mechanism check, Task 1b -- dollar reconciliation of the compensation formula (Direction_clean/)

## VERDICT (up top, per instruction): GROSS WORLD
Direction compensation tracks **gross directed output x the directed price**, not the increment
over the unit's bid-established floor-block counterfactual. Implication for the Task 2
pre-registration, per the committed mapping: **payment-seeking predicts sensitivity of
direction-receipt/eligibility itself to the price** -- the strategic margin is being directed at
all (every directed MWh pays, regardless of what the unit's bid would have delivered), not
engineering a low counterfactual through floor-pulling. Task 2's episode classification
(heading-offline / online-at-floor / offline-brought-on) should be pre-registered against that
prediction.

## Grain (documented before any join, per instruction)
- **`direction_events`, new format (2023-10 -> 2025-01): per DUID x event**, with per-unit
  directed MWh, compensation, retained trading amount (RTA), and additional compensation. This is
  unit-episode grain -- the PRIMARY source; **no allocation assumption needed**.
- `direction_events`, old format (<= 2023-09): carries NO dollars or MWh (0 of 1,194 rows).
- `direction_costs` (2021 -> 2023-10): per REPORT EVENT, aggregating across units and episodes.
  It cannot be allocated to unit-episodes without assuming how dollars split across units inside
  a report event -- NOT joined at unit-episode grain (risk stated, not taken); used only as an
  aggregate scale cross-check ($180M over 121 report events there vs $58.8M over the 271 focal
  unit-episodes here -- consistent orders of magnitude).
- **Match rates:** 271 of the 297 Task-1 episodes starting 2023-10 onward matched a comp-bearing
  event (91.2%); 3 had multiple candidate events (first taken). Construction validated:
  corr(computed gross MWh, event-reported MWh) = 0.95.

## (1) The deciding table -- payouts in the zero-excess lobe (`task1b_lobe_payouts.csv`)
| Lobe | n | Median compensation | % below $5k | Median comp / gross energy value |
|---|---|---|---|---|
| Positive excess | 202 | $138,695 | 2.0% | 0.75 |
| Zero/negative excess (floor block >= directed output) | 69 | $57,069 | 1.4% | **3.12** |

In wedge world the zero-excess lobe is paid ~nothing -- these are episodes where the unit's own
floor block already covered the directed output. They are in fact paid a median **$57k**, with
only 1.4% below $5k, and their payments run at **3.1x their gross energy value** at the directed
price -- for small episodes the cost-based components (start/fuel/O&M top-ups) dominate even the
gross energy payment. **Wedge world is rejected by this table alone.**

## (2) Which formula tracks the dollars (`task1b_fit_comparison.csv`, `task1b_formula_fit.png`)
| Model | Coefficient (1 = dollar-for-dollar) | R^2 |
|---|---|---|
| Gross: Q_gross x P | 0.88 | **0.943** |
| DCP form: Q_gross x P - RTA | 0.90 | 0.936 |
| Wedge: Q_wedge x P | 0.90 | 0.888 |
| Joint (wedge + gross) | 0.13 / 0.77 | 0.945 |

Gross fits best; in the joint regression the dollars load on gross (0.77) not wedge (0.13). The
figure shows why: the wedge model leaves a vertical column of well-paid episodes at predicted
~$0. Practical reading of the coefficients: payment ~ gross energy at the directed price, less
partial netting of retained market revenue, plus cost top-ups.

## (3) Episodes where no formula fits (`task1b_misfit_{summary,episodes}.csv`)
**41% of episodes (111 of 271)** deviate from the best formula by more than 50% of
max(payment, $10k) -- a substantial share, stated plainly. The additional-compensation provision
is the likely carrier: 75.7% of misfit episodes have additional_compensation > 0 -- but so do 70%
of ALL episodes, so top-ups are PERVASIVE in this window rather than misfit-specific. The
loss-making-conditions test lacks contrast here: mean gas price is essentially identical for
misfit vs fitting episodes (12.8 vs 12.5 $/GJ) because 2023-24 gas was low and stable -- there is
no high-gas variation in the new-format window to test concentration against. Reported as an
untestable-in-this-window limitation, not as evidence of absence.

## Caveat
The reconciliation window is 2023-10 -> 2024-12 (the only period with unit-episode dollars). The
formula's behaviour during the 2022 high-price period is not directly verified; the DCP
methodology did not change over the sample, so the gross-world verdict is assumed to carry back,
but that is an institutional assumption, not a measured one.

**STOP -- Task 1b complete. Task 2's pre-registration should encode the gross-world prediction.**
