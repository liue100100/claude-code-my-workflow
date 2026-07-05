# Stage 1 findings -- the withholding outcome (Direction_clean/)

Per-interval, for TORRB2/3/4, PPCCGT (primary) and OSB-AG (descriptive only), over all 36 cached
months (202201 to 202412). See `README.md` glossary for every term below.

## Join integrity
1578240 bid-ladder rows resolved to the in-force version; 0 missing a price ladder, 0 missing an SRMC
match, across every month (see `join_report.csv`). MAXAVAIL exceeds registered capacity by more
than 2% in 7.71% of rows (ambient uprate above nameplate rating) -- not clipped, carried through
as-is.

## Cheap capacity -- two co-primary definitions, agreement rate
Definition (a): capacity offered at or below $300/MWh (fixed). Definition (b): capacity offered at
or below 2x that month's short-run marginal cost (cost-indexed). Both capped at declared
availability, both expressed as a share of registered capacity.

| Generator | Agreement rate between (a) and (b) |
|---|---|
| TORRB2 | 96.4% |
| TORRB3 | 96.7% |
| TORRB4 | 98% |
| PPCCGT | 96.1% |
| OSB-AG | 100% |

Worst-case disagreement across the five generators: 3.9% of intervals (PPCCGT).

Monthly disagreement correlates with gas price for the three Torrens units (r = 0.54-0.74) -- as
expected, since the cost-indexed definition moves with gas while the fixed definition doesn't; for
PPCCGT the correlation is near zero (-0.11); for OSB-AG agreement is 100% every month (no variation
to correlate). Full breakdown in `ab_agreement_by_month.csv`.

## Threshold sensitivity
Swept (a) at $150/$500 and (b) at 1.5x/3x SRMC (`threshold_sensitivity.csv`). For the three Torrens
units the withheld-interval share stays in a narrow band (roughly 82-96%) across every threshold
tested -- the classification is not sensitive to exactly where the line is drawn. PPCCGT is more
threshold-sensitive (53-64% across the sweep) and should be read with that in mind.

## Channel decomposition -- among withheld intervals, why
Physical withholding ("capacity withdrawn": declared availability cut) versus economic
withholding ("capacity priced out": availability normal, price above threshold) versus both.

**Fixed-threshold definition (a):**

| Generator | n withheld | Capacity withdrawn only | Capacity priced out only | Both | Neither (flag) |
|---|---|---|---|---|---|
| TORRB2 | 285966 | 66.9% | 10.4% | 22.7% | 0% |
| TORRB3 | 272577 | 51% | 16.6% | 32.4% | 0% |
| TORRB4 | 280492 | 63.6% | 14.5% | 21.9% | 0% |
| PPCCGT | 167136 | 91.3% | 0.9% | 7.8% | 0% |
| OSB-AG | 224846 | 99.4% | 0% | 0.6% | 0% |

**Cost-indexed definition (b):**

| Generator | n withheld | Capacity withdrawn only | Capacity priced out only | Both | Neither (flag) |
|---|---|---|---|---|---|
| TORRB2 | 275478 | 69.4% | 9.9% | 20.7% | 0% |
| TORRB3 | 264895 | 52.5% | 14.2% | 33.3% | 0% |
| TORRB4 | 276395 | 64.6% | 13.8% | 21.7% | 0% |
| PPCCGT | 176181 | 84.8% | 0.8% | 14.4% | 0% |
| OSB-AG | 224846 | 99.4% | 0% | 0.6% | 0% |

Both definitions agree on the story: physical withholding (availability cuts) dominates for every
unit, but a material secondary share (10-33%) additionally prices the *remaining* available
capacity above the threshold ("both") -- withholding is not purely a quantity phenomenon. The
'neither' column is essentially zero for every unit and definition, which is the expected internal
consistency check (an interval classified 'withheld' should always show up in at least one
channel) -- it passed without needing any adjustment.

## Distribution per unit -- the Torrens bimodality, reconfirmed
| Generator | Mean share | Median share | Share of intervals at floor (<10%) | Share of intervals near-full (>75%) |
|---|---|---|---|---|
| TORRB2 | 0.117 | 0 | 77.4 | 6.6 |
| TORRB3 | 0.164 | 0 | 69.1 | 9.7 |
| TORRB4 | 0.136 | 0 | 74.4 | 7.9 |
| PPCCGT | 0.429 | 0.485 | 41.9 | 29.2 |
| OSB-AG | 0.28 | 0 | 71 | 28.5 |

TORRB2/3/4 sit at the $0-floor tranche (near-zero cheap capacity) in roughly 69-77% of ALL
intervals -- this is the unit's ordinary competitive behaviour, not something specific to
essential or directed periods (that comparison is Stage 3's job). This reconfirms, independently,
the bimodality already documented in the existing `Direction/` pipeline
(`outputs/withhold_opportunity/stage1b_diagnostics.md`) -- built here from scratch against this
pipeline's own registered-capacity-share outcome, not copied. See `distribution_by_unit.png`.

## Reused audits of the essentiality flag (re-run against this pipeline's own variables)
**Leakage audit** -- regressing the essentiality flag on the generator's own realised availability
and own cheap capacity: R^2 is at or near 0 for every unit (0.0000-0.0028) -- the flag is not
predicted by the generator's own offer, confirming it is a genuine rivals-only construction, not
circular. **Bid-as-usual audit** -- among essential intervals, every testable generator has a
non-empty share still bidding as usual (TORRB2/3/4: 2-6%; PPCCGT: 66%; OSB-AG: 100%) -- essential
does not mean 'withheld by construction.' Both checks pass and closely reproduce the equivalent
numbers already on record in `Direction/outputs/withhold_opportunity/stage2_findings.md`, despite
being rebuilt independently here -- a strong cross-validation of the essentiality-flag reuse.

## Not yet done (correctly out of scope this pass)
No competition/residual-demand control, no RQ1/RQ2 regression, no compensation-price analysis --
all Stage 2+. This stage only builds and validates the outcome measure.

