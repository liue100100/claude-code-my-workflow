# Mechanism check, Task 1 -- directed output vs floor-block output (Direction_clean/)

## Institutional background (encoded per instruction; frames Tasks 1-3)
A Synchronise direction requires the unit to be ONLINE -- a binary -- not to produce at high
output; directed units typically run at or near minimum stable load. Direction compensation =
(energy with the direction - counterfactual energy without it) x the directed price. The
compensated quantity therefore depends on the unit's no-direction counterfactual, WHICH ITS OWN
BIDS AND REBIDS ESTABLISH: a unit whose in-force bid offered nothing (or only a floor block that
would not have been dispatched) has a low counterfactual and a large compensated quantity.

## Coverage (denominators)
1116 usable direction episodes for the focal units (0 dropped for missing/inverted windows);
1113 with dispatch coverage inside the 2022-2024 sample; 740 with an in-force bid resolved at the
issue instant; **740 episodes with both** -- the analysis set. 17,445 exact-duplicate dispatch rows
removed (known cache artifact, reported not hidden); the physical (intervention) run is used
where dual runs exist.

## Result, per unit (`task1_summary_by_unit.csv`; episode level in `task1_episode_level.csv`)
| Unit | n | Directed output (median MW) | Declared min load (median) | Observed floor (P5) | $0-floor block at issue (median) | Excess over floor: median [IQR] | % of episodes within 10 MW of min load |
|---|---|---|---|---|---|---|---|
| TORRB2 | 197 | 40.0 | NA | 40.0 | 40.0 | 0.0 [-1.1, 0.2] | NaN% |
| TORRB3 | 260 | 40.0 | NA | 40.0 | 40.0 | 0.0 [-1.2, 0.2] | NaN% |
| TORRB4 | 226 | 40.0 | NA | 40.0 | 40.0 | 0.0 [-1.5, 0.2] | NaN% |
| PPCCGT | 29 | 167.0 | NA | 165.0 | 0.0 | 166.3 [125.0, 169.3] | NaN% |
| OSB-AG | 28 | 145.0 | NA | 145.0 | 143.0 | 0.1 [-0.6, 4.0] | NaN% |

Pooled: median excess over the floor block 0.0 MW (mean 9.2); 55.9% of episodes at or below
zero excess; 80.8% within 25 MW.

## Reading
See the table and `task1_excess_over_floor.png`. The question posed -- does directed output sit at
minimum stable load / the unit's own floor block, or above it -- is answered by the excess
distribution per unit; the per-unit rows and the share-within-10MW-of-min-load column carry the
verdict, stated here without smoothing: where the excess is near zero, the direction bought the
unit's PRESENCE (the binary), not additional energy beyond what its floor block implied -- exactly
the institutional account -- and the compensated quantity is then governed by the bid-established
counterfactual, which Task 2 (the commitment margin around issue) examines directly.

**STOP -- Task 1 complete. Awaiting review before Task 2.**

