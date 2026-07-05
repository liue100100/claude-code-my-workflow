# Stage 4b — TORRB3 sign-flip diagnostic (compositional check)

Script: `04_market_power/wo_stage4b_torrb3_check.R`. Question: is TORRB3's negative, wrong-signed
`dt:opp` coefficient (Stage 4) driven by a compositionally different opportunity/matched sample
relative to its sister units TORRB2/TORRB4, or is it genuine within-sample heterogeneity in a
single desk's per-unit bidding?

## Result: composition is IDENTICAL across all three sisters -- ruled out as the explanation

- **Opportunity-interval timing:** TORRB2/TORRB3/TORRB4 opportunity sets are byte-identical
  (symmetric difference = 0 on all three pairwise comparisons, n=4,083 each) -- expected, since all
  three share one station-level `pex_torrens_island_b` essentiality flag; confirmed empirically
  rather than just assumed from the code.
- **SRMC:** literally identical across the trio (mean $157.93/MWh, 0 NA) -- same cost input, no
  cost-side heterogeneity.
- **Data completeness:** identical row counts per year across all three (105,120 / 105,120 /
  105,408 in 2022/2023/2024) -- no bid-record gaps specific to TORRB3.
- **Matched-sample coverage:** 100% of each sister's opportunity intervals are matched (n_matched =
  n_opp = 4,083 for all three) -- no stratum-availability asymmetry.
- **Month/tightness mix of the matched opportunity set:** identical year-by-year counts (2022:
  2,385; 2023: 544; 2024: 1,154 for all three); identical mean non-sync (1,148 MW) and short-share
  (0.1%) per sister.
- **Common-support intersection:** the set of intervals matched for all three sisters
  simultaneously (61,253) exactly reproduces each sister's own matched sample -- re-running the
  `dt:opp` regression on this explicit intersection gives **identical coefficients** to the
  original per-unit Stage 4 run (TORRB2 +0.000206, TORRB3 −0.000184, TORRB4 +0.000554 — unchanged
  to the reported precision), confirming the original per-unit estimates were already apples-to-
  apples.

## Reading
The three sister units face literally the same opportunity conditions, timing, and cost — there is
no compositional confound to blame. TORRB3's wrong sign is therefore genuine within-sample
heterogeneity in that unit's own bidding response, not an artifact of a different sample. Given
it is not significant (p=0.51, wide SE relative to the coefficient), the most parsimonious reading
remains noise around a small effect — but the diagnostic rules out the alternative explanation
(a different information/tightness environment for TORRB3) that would have undermined pooling.
**This does not change the Stage 4 headline** (largely null, TORRB4 marginal); it strengthens
confidence that the per-unit heterogeneity reported there is not a sample-construction artifact.
