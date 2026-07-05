# Stage 2 gate report -- competition measure vs. essentiality (STOP HERE for review)

This is the decision point the approved plan calls for before any regression is attempted. It
reports how much the competition measure and the essentiality flag move together -- their
collinearity determines how much INDEPENDENT variation is left for Stage 3 to attribute to
essentiality once the competition control enters.

## Correlation, per station and pooled (6 rows missing essentiality flag, excluded)
Index: <grp>
                       grp      n corr_slope_kernel_essential
                    <char>  <int>                       <num>
1:           osborne_gt_st 315394                      -0.015
2:        pelican_point_gt 315394                       0.013
3:        torrens_island_b 315394                      -0.036
4: POOLED (all 3 stations) 946182                      -0.018
   corr_slope_direct20_essential corr_markup_kernel_essential n_markup_trimmed
                           <num>                        <num>            <int>
1:                        -0.014                        0.006           117501
2:                         0.012                        0.001           102765
3:                        -0.030                        0.076           108987
4:                        -0.015                        0.041           329253
   markup_trim_exclusion_pct
                       <num>
1:                      62.7
2:                      67.4
3:                      65.4
4:                      65.2

## Distribution of the competition measure inside vs. outside essential intervals
See `distribution_by_essentiality.csv` and `.png`. Sign convention (corrected -- an earlier draft of this report had it inverted): more NEGATIVE slope = rivals more price-responsive = MORE competition faced; near-zero slope = rivals saturated = LEAST competition. Torrens Island B: essential intervals have a mean slope of -5.04 vs. -3.31 non-essential. Pelican Point: -0.82 vs. -3.32. Osborne: -14.45 vs. -3.51.

## Numerical caveat on the implied markup (found and fixed this session)
The implied-markup column (`markup_kernel_noimport = -residual_demand / (RRP * slope)`) explodes
numerically wherever the slope is close to (but not exactly) zero -- checked directly: values up to
~1e22 in magnitude, with **37.5% of finite values exceeding |100|**, economically meaningless for a
Lerner-index-style quantity. A raw correlation against essentiality on the untrimmed markup column
produced a suspicious exact 0.000 for every station -- degenerate, not a real null, because a
handful of astronomical outliers dominate the Pearson calculation. Trimmed to |markup|<=10 (a
generous, documented band) before computing `corr_markup_kernel_essential` above;
`markup_trim_exclusion_pct` reports how much was excluded, per station, rather than hiding it.
**This is a first-order methodological flag for Stage 5's markup-benchmark appendix**, which will
need the same trim (or a better-behaved functional form) before reporting any markup summary.

## Reading
**Not the collinearity risk the plan flagged -- and the direction of the difference is itself a finding.** Torrens Island B's linear correlation between the competition measure and essentiality is small (-0.04, pooled -0.02) -- nowhere near collinear, so Stage 3 has plenty of independent variation to work with. The conditional means differ in a direction that looks surprising until the two concepts are kept distinct: essential intervals average a slope of -5.04 vs. -3.31 non-essential -- i.e. essential periods show MORE-price-responsive rival supply near the clearing price (MORE energy-market competition), not less. That is economically coherent: essentiality is a system-SECURITY condition (high-renewables, low-demand periods when few synchronous units are online), not an energy-scarcity condition -- these are often cheap-energy periods with plenty of rival capacity near the (low) clearing price. Being needed for security and having energy-market power are different states, which is exactly why RQ1 needs the competition control to separate them, and why this gate found them uncorrelated. Also flagged: the competition measure has a large point mass at exactly zero (6.7% of Torrens intervals -- rivals saturated within the local $50 window = maximum local market power), which flattens the Pearson correlation and needs explicit handling in Stage 3 (a separate indicator), not treatment as ordinary continuous variation.

## What happens next
This script does not proceed to Stage 3. Per the approved plan, Stage 3 (the RQ1 regression, run
with and without this competition control) needs its own plan and approval, informed by the
collinearity picture surfaced here.

