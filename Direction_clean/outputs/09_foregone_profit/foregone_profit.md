# Foregone-profit findings — where the absence sits relative to the commitment margin

Registration: `09_foregone_profit/registration.md` + dated addendum (p̂ = previous-trading-day
realized profile, the pipeline's bid-formation convention; base SRMC = as-built marginal on
quarterly-step gas, pessimistic = all-in; absence = the day-ahead stance keeps the floor out of
$300-reach all day). Script `foregone_profit.R`; occupancy report written to disk before any
rate or dollar figure, per the binding order. Panel: 2,796 clean unit-days (4 of the 2,800
clean days lack a previous-day price or d_t input; flagged, not imputed).

**Signed biases, restated:** M_d excludes start costs and price impact — both inflate region B
and the foregone-profit figure. Every region-B number below is an upper bound; the p̂
substitution (previous-day realized profile) is unsigned.

## Occupancy (the gate)

| calibration | A: M ≤ 0 | B: 0 < M < V | C: M ≥ V |
|---|---|---|---|
| base | 1,987 (71.1%) | **136 (4.9%)** | 673 (24.1%) |
| pessimistic (all-in SRMC, H̄ = 7 h) | 2,034 | 81 | 681 |
| fixed-boundary (d_t at median $221) | 1,987 | 114 | 695 |

Gate passes (136 ≥ 30). The discriminating cell exists but is thin: even built to be as large
as the assumptions allow, days where commitment was profitable *and* the direction option paid
more are 4.9% of clean unit-days, and stable across the circularity guard.

## Absence rates by region

Pooled (base): **A 56.6% | B 33.8% | C 29.7%** (absent50 variant: 66.9 / 42.6 / 34.5; pessimistic
and fixed-boundary within 2 pp throughout).

**The drop sits at the A/B boundary** — absence falls by 23 pp the moment commitment becomes
profitable, and B is nearly flat against C. Under the committed monotonicity reading this is the
commercial account's signature: the desk's presence tracks whether running pays, not whether
the option out-pays it.

Per unit, the picture splits and both halves are reported:

| unit | A | B | C |
|---|---|---|---|
| PPCCGT | 22.4% | 6.9% | 8.4% |
| TORRB2 | 82.8% | 70.8% | 47.1% |
| TORRB3 | 67.8% | 60.0% | 37.8% |
| TORRB4 | 75.3% | 60.0% | 45.0% |

Pelican Point is flat-low across B and C (reading (b)'s friction-consistent shape) and holds 72
of the 136 pooled B-days, which is what flattens the pooled B/C contrast. The three Torrens
units each show absence **15–24 pp higher in B than C** — the reading-(a)-shaped gradient — on
20–24 B-days per unit. With cells that thin the within-Torrens contrast is suggestive, not
load-bearing, and is reported as such.

## The dollars (absent region-B days; upper bounds by construction)

On the 46 absent region-B unit-days: the desk declined **$0.78M** of floor-level spot margin
while holding a direction option worth **$1.60M** on the same days — "declined X to hold an
option worth Y" at roughly 1:2. Pessimistic calibration: $0.27M declined against $0.52M. Scale
context the registration's reading (c) anticipated: even at its most generous, the entire
three-year discriminating cell involves under $1M of foregone spot profit against a $141.9M
direction transfer — the commercial running these units gave up to stay directable was, in
dollars, almost nothing.

## Direction proximity within absent profitable days (n = 246)

Region-B membership concentrates where the direction channel is live: 24.5% of absent
profitable days are region-B when the day contains an N−1 event versus 1.6% when it does not;
36.1% above the region-B median propensity versus 13.0% below. Partly mechanical (V rises with
π); reported per the registration, no mechanism claim.

## Robustness rows

Realized-price M_d (**flagged endogenous** — realized prices embed the units' own absence):
occupancy A/B/C = 1,987/120/689, absence in B 29.2% — same shape as the base row.

## Adjudication

Region B is material by count (gate passed) but the pooled absence pattern is **reading (b)**:
absence is not concentrated in B relative to C, the drop sits at the A/B boundary, and the
~200 absent unit-days in region C — where commitment dominated the option and the units sat out
anyway — are affirmative evidence against payment-seeking, as committed. Two qualifications
carry equal weight: the Torrens-only B/C gradient runs the other way on thin cells, and the
dollar magnitude of the entire discriminating region is trivial, which hardens §7.1's "there
was little commercial running to forgo" into a measured, conservatively-constructed fact
(reading (c) at the dollar margin even though the count gate passed). No manuscript edits under
this task; the same-clock caveat applies — nothing here establishes daily intent.
