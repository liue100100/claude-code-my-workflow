# Session log — 2026-07-04 — Withhold-to-be-directed Stage 3/4 (threshold + identifying test)

## Goal
Continue from the 2026-07-01 session, which left the withhold-to-be-directed design stopped after
Stage 2 (both circularity checks passed) pending one blocking decision: how to handle the 202206
gap in `d_t` (19% of TORRB's opportunity intervals). Resolve it, then build Stage 3 (threshold
sensitivity + `d_t` finalisation) and Stage 4 (the identifying test).

## Decisions (user, this session)
1. **202206 handling:** hybrid — base case excludes 202206 (`dt` NA, dropped via `!is.na(dt)`);
   robustness row imputes `d_t` from `direction_costs`-implied $/MWh, reported alongside the base
   case. (Matches last session's own lean.)
2. **F3a (revealed-cost anchor) write-up framing:** deferred, not decided this session.

## What was built
1. `04_market_power/wo_stage3_threshold_dt.R` — threshold sweep {80,100,120,150,170} MW alongside
   each unit's empirical trough on the opportunity set (verified: trough-default row reproduces
   Stage 2's `stage2_opportunity_summary.csv` exactly); finalized `dt`/`dt_robust`/`dt_imputed`.
   202206 imputed at **$164.38/MWh** (directed_mwh-weighted mean across 3 June-2022
   `direction_costs` events: $260.6, $27.5, $289.3 per event).
2. `04_market_power/wo_stage4_identification.R` — (i) descriptive consistency count (opportunity
   vs. matched comparison, per unit); (ii) the identifying test, `withheld ~ dt*opp + srmc |
   duid+nsq+hour_block` on the matched (CEM) sample, clustered by month, run pooled + per-unit +
   both `dt` variants.

## Key result
**Largely null.** Pooled `dt:opp` coefficient positive but not significant (t 1.55 base dt, t 1.49
robust dt). Per-unit: only TORRB4 marginal (t 1.91, p 0.073); TORRB2 positive/ns, TORRB3
negative/ns, PPCCGT ns (and underpowered — its matched sample has almost no `d_t` variation, n
opp=267 clustered in a narrow calendar window). Descriptive consistency (part i) shows opportunity
intervals modestly more withheld than matched comparison for TORRB (+2.5 to +8.4pp), but the
comparison baseline is already 90-94% (CEM selects tight strata), so this doesn't by itself
distinguish market power from directions-seeking.

Recorded as `facts_memo.md` [F21]. This design complements rather than replaces the `rq_and_id.md`
Design-2 triple-diff (which already has a significant ex-ante pivotality level effect, [F14]-[F15],
as its primary evidence) — flagged explicitly as an open framing question for the user, same
treatment as [F3a].

## Docs updated
`facts_memo.md` (+[F21]), `INDEX.md` (04_market_power table: added `constraint_decomposition.R`
[F20] which was also missing, plus the four `wo_stage*` scripts).

## Open / for user
- How (or whether) to feature the withhold-to-be-directed design in the write-up given the largely
  null Stage-4(ii) result — present as a robustness/complementary design, footnote, or drop.
- F3a framing (deferred last time) still open.
- Housekeeping: nothing committed since the 2026-06-21 reorg — now ~10+ days of verified work
  (SRMC methodology, supply-curve figures, F5b, constraint decomposition, this whole design)
  sitting uncommitted. Worth a checkpoint commit soon.
