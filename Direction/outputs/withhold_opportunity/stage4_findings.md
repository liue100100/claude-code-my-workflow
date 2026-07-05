# Stage 4 findings -- consistency count + the identifying dt-sort test

Script: `04_market_power/wo_stage4_identification.R`. Matched sample (opp|comparison, CEM strata
with common support): 190313 rows.

## (i) Consistency count -- DESCRIPTIVE ONLY (see `stage4_consistency.csv`)
Withheld% at the trough-default threshold, opportunity vs. matched comparison, per unit:
TORRB2 96.7% (opp) vs. 94.2% (comparison); TORRB3 98.7% vs. 90.3%; TORRB4 97.2% vs. 93.7%; PPCCGT
31.8% vs. 51.3% (opposite sign, small n); OSB-AG 0.0% vs. 32.5% (n=18, opposite sign). For TORRB
the opportunity set is modestly *more* withheld than its own matched comparison (+2.5 to +8.4 pp),
but per the Stage-2 guardrail this is NOT the identifying result on its own -- the *matched*
comparison rate is itself already 90-94% (Torrens's baseline competitive withholding is ~60-65%
[F6a], but the CEM match selects comparison intervals from the same tight non-sync/hour strata as
the opportunity set, which pushes the comparison rate up too). The small residual gap is
suggestive but not dispositive; part (ii) is where the identifying weight falls.

## (ii) THE IDENTIFYING TEST (see `stage4_did_results.csv`, `stage4_dt_sort.png`)
`withheld ~ dt*opp + srmc | duid + nsq + hour_block`, matched sample, clustered by month (35
clusters; wild-cluster bootstrap remains an OPEN project-wide item [G8], not resolved here).

**Pooled TORRB2/3/4+PPCCGT (base dt, 202206 excluded):** dt:opp coef = 0.000242 (se 0.000156, t 1.55,
p 0.137, n=177854).
**Pooled, dt_robust (202206 imputed at \$164.38/MWh):** dt:opp coef = 0.000194 (se 0.00013, t 1.49,
p 0.152, n=189274).

**Per-unit (base dt):**
- **TORRB2** (base dt): coef=0.000206, se=0.000267, t=0.77, p=0.449, n=57677
- **TORRB3** (base dt): coef=-0.000184, se=0.000271, t=-0.68, p=0.506, n=57677
- **TORRB4** (base dt): coef=0.000554, se=0.000291, t=1.91, p=0.073, n=57677
- **PPCCGT** (base dt): coef=0.00061, se=0.00129, t=0.47, p=0.682, n=4823

## Reading
[TO BE INTERPRETED BY THE USER -- sign/significance stated plainly above, framing (headline vs.
robustness vs. footnote) deferred, same as the F3a decision this session.] A positive, significant
dt:opp coefficient says withholding intensifies with the predetermined prize *specifically* on
opportunity intervals relative to the matched comparison set -- the revealed-preference complement
to the `rq_and_id.md` Design-2 triple-diff. A null or negative coefficient says the opportunity-set
withholding (part (i)) is driven by pivotality/market power alone, not a d_t-specific channel.

## Caveats carried forward
- Look-ahead in state variables (Threat B, `stage0_inventory.md` §5) is unresolved -- `pex`/
  `nonsync`/`short` are realised-state proxies, not bid-time forecasts.
- OSB-AG excluded from all regressions (n_opp=18 < MIN_TEST_N=30) -- descriptive only, see
  Stage 2/3 outputs.
- Threshold sensitivity (Stage 3(A)) shows the withheld% classification for TORRB is fairly stable
  across the sweep (all >=94%), so the classification choice is not doing the work in part (i);
  PPCCGT and OSB-AG are more threshold-sensitive and should be read with that in mind.
- **PPCCGT's matched sample has almost no d_t variation** -- visible in `stage4_dt_sort.png` as a
  near-empty facet (2 points, d_t clustered ~$182.6-182.8/MWh). Its opportunity intervals
  (n=267) fall in a narrow calendar window, so the dt:opp coefficient for PPCCGT (n=4,823) is
  essentially unidentified off d_t variation and should be read as uninformative, not as evidence
  against the channel.

