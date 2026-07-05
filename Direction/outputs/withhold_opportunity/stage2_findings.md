# Stage 2 findings — opportunity set, leakage audit, matched comparison

Script: `04_market_power/wo_stage2_opportunity.R`. Opportunity = ex-ante essentiality `pex_station==TRUE`
(system infeasible without the station given RIVALS' realised online status + realised non-sync; focal
station removed → its own offer never enters). Full focus panel: 1,578,240 (DUID×interval) rows.

## LEAKAGE AUDIT — PASSES (the critical circularity gate)
Regressing the opportunity indicator on the focal unit's realised offer:

| Unit | opp~MAXAVAIL R² | cor(opp,MAXAVAIL) | opp~cheap300 R² | cor(opp,cheap300) |
|---|---|---|---|---|
| TORRB2 | 0.0000 | −0.005 | 0.0006 | −0.024 |
| TORRB3 | 0.0012 | −0.035 | 0.0028 | −0.053 |
| TORRB4 | 0.0004 | −0.020 | 0.0011 | −0.033 |
| PPCCGT | 0.0002 | 0.014 | 0.0001 | 0.012 |
| OSB-AG | 0.0001 | 0.008 | 0.0001 | 0.009 |

All R² ≈ 0, |cor| ≤ 0.05. **The opportunity set is NOT a function of the unit's realised MAXAVAIL or
realised cheap tranche** — Threat-A (own-offer leakage) is guarded. This is expected: `pex` removes the
whole focal station, so the unit's own offer cannot enter its own essentiality.

## Opportunity set size + (a)/(b) input distribution
| Unit | n opp (pex) | opp rate | nonsync med | depth med | directed% of opp | verdict |
|---|---|---|---|---|---|---|
| TORRB2 | 4,083 (3,309 w/ d_t) | 1.29% | 1,136 MW | 0 | 26.6% | TEST |
| TORRB3 | 4,083 (w/ d_t sim.) | 1.29% | 1,136 | 0 | 30.8% | TEST |
| TORRB4 | 4,083 | 1.29% | 1,136 | 0 | 48.4% | TEST |
| PPCCGT | 267 | 0.08% | 1,043 | 0 | 25.5% | TEST (small) |
| OSB-AG | 18 | 0.01% | 1,935 | 0 | 100% | **DESCRIPTIVE ONLY (<30)** |

Opportunity intervals are the genuinely tight/essential ones: high non-sync (median 1,136 MW), ex-ante
depth 0 (essential by construction), and 27–48% actually received a direction.

## Sense-check — opportunity set is NOT degenerate (2nd, independent circularity check)
Share of opportunity intervals where the unit **bid as usual** (cheap tranche ≥ provisional per-unit
trough) vs **withheld**:

| Unit | withheld% | as-usual% (n) |
|---|---|---|
| TORRB2 | 96.7 | 3.3% (135) |
| TORRB3 | 98.7 | 1.3% (53) |
| TORRB4 | 97.2 | 2.8% (114) |
| PPCCGT | 31.8 | 68.2% (182) |

The as-usual cell is non-empty for every testable unit → the set is not "withheld by construction."
Together with the leakage audit, both circularity checks pass.

## Reading (with the mandated guardrails)
- **Torrens withholds ~97% on opportunity intervals** vs the ~62% clean-competitive baseline [F6a]. Higher,
  but the as-usual cell is tiny → withholding is **near-universal** on pivotal/essential intervals. Per
  the guardrail this **supports systematic withholding but does NOT identify a directions motive** —
  pivotality *is* market power, and always-withhold-when-pivotal is exactly what pure market power
  predicts. Not to be reported as directions-seeking.
- **PPCCGT bids as usual on 68% of its opportunity intervals** — it passes up the opportunity most of the
  time. By the revealed-preference (H&P) logic this cuts **against** systematic directions-seeking for
  PPCCGT (the opportunity was on the table and left there).
- The identifying content is therefore entirely in **Stage 4(ii)**: does withholding sort on d_t, and is
  that sort **specific to opportunity intervals** vs the matched comparison set?

## (3) Matched non-opportunity comparison set (CEM: unit × month × non-sync-quintile × hour-block)
| Unit | opp matched | comparison n | strata |
|---|---|---|---|
| TORRB2/3/4 | 4,083 (100%) | 57,170 | 128 |
| PPCCGT | 267 (100%) | 5,248 | 13 |
| OSB-AG | 18 | 1,021 | 3 |

All opportunity intervals fall in strata that also contain non-opportunity intervals → full common support
for the Stage-4 specificity test.

## Issues to resolve before Stage 4 (d_t sort)
1. **d_t missing for 202206 (June-2022 market suspension / APC).** It is the *only* NA month in the gate0
   `dt_recon` series, but it holds **774 of 4,083 (19%)** of Torrens opportunity intervals — market
   suspension is precisely when TIB was most often essential. Decision needed: (i) drop 202206 (lose 19%
   of the strategically richest opportunity intervals); (ii) impute d_t for 202206 from the June-2022 APC
   ($300/MWh administered cap) or the realised compensation `direction_costs` $/MWh; (iii) use an
   alternative d_t defined in that month. My lean: run Stage 4 with 202206 **excluded as the base case**
   and **included via the APC/compensation imputation as a robustness row**, reporting both.
2. Cosmetic: `median()` without na.rm produced NA in the summary `dt_med_opp` (real usable counts above);
   and the comparison-summary `n_opp` column mis-merged (n_opp_matched is correct). Both trivial; will fix
   on the Stage-4 build.

**STOP — Stage 2 complete, both circularity checks pass. Awaiting the 202206/d_t decision before Stage 3/4.**
