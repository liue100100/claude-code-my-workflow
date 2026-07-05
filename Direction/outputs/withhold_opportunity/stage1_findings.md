# Stage 1 findings — counterfactual "normal" bid

Script: `04_market_power/wo_stage1_baseline.R`. Regime = undirected & realised-non-pivotal & available
(MAXAVAIL>1). Cheap capacity = effective MW offered at ≤ threshold (default $300). Raw $/MWh.

## Join integrity (self-check contract)
- In-force bid rows across 36 months: **1,893,888**. `no_ladder = 0` (every interval matched a price
  ladder), `no_srmc = 0`. One ladder per (DUID, day) asserted — no duplication. No join blowups.
- tz forced to Etc/GMT-10 on all timestamp columns before joining.

## Baseline cheap capacity per unit (median MW ≤ $300, [IQR])
| Unit | n UN-avail intervals | MAXAVAIL med | cheap≤300 med | IQR (Q1–Q3) | IQR/med | %UN cheap=0 | verdict |
|---|---|---|---|---|---|---|---|
| TORRB2 | 59,082 | 200 | 60 | 110 (40–150) | 1.83 | 14.0% | **noisy/bimodal** |
| TORRB3 | 78,835 | 200 | 60 | 125 (40–165) | 2.08 | 14.0% | **noisy/bimodal** |
| TORRB4 | 65,091 | 200 | 65 | 135 (40–175) | 2.08 | 11.8% | **noisy/bimodal** |
| PPCCGT | 151,166 | 465 | 364 | 243 (243–486) | 0.67 | 1.3% | usable |
| OSB-AG | 90,776 | 188 | 185 | 43 (148–191) | 0.23 | 0.9% | stable but near-must-run |
| BARKIPS1 | 306,719 | 176 | **0** | 96 (0–96) | ∞ | **68.4%** | **EXCLUDE — no cheap tranche** |

Interval counts are ample for every unit; none excluded for *too few* intervals.

## Diagnosis of the Torrens instability (is it availability/commitment, or real bidding noise?)
Both, but mostly real bidding heterogeneity:
- **Min-load mode.** ~11–14% of Torrens UN intervals sit at MAXAVAIL ≤ 60 MW (min load); in 94% of
  those, cheap≤300 = 0. This adds a zero-cheap mode (the 14% cheap=0 above).
- **Bimodality persists at FULL availability.** Restricting to MAXAVAIL ≥ 180 MW, cheap≤300 is still
  median 60–90 MW with IQR 120–140 (Q1 50–60, Q3 180–200). About **half** the full-availability UN
  intervals offer ≥100 MW cheap; the other half offer only the ~60 MW $0-floor tranche
  (share cheap≥100: TORRB2 41%, TORRB3 46%, TORRB4 48%). So even competitive, fully-available Torrens
  bidding swings between "big cheap tranche (~180–200 MW)" and "floor only (~60 MW)."

## Flags / decisions this forces before Stage 2
1. **BARKIPS1 — exclude** from opportunity-set construction: it has no cheap tranche to withhold even
   in the competitive regime (median 0; 68% of UN intervals fully high-priced). The withhold precondition
   fails. (Consistent with it being a secondary unit.)
2. **OSB-AG — keep with caveat:** near-must-run cogen, offers ~all capacity cheap almost always
   (IQR 43, <1% zero). It essentially never withholds → in Stages 3–4 it will be almost entirely
   "bid as usual," giving little contrast. Descriptive only.
3. **PPCCGT — proceed:** the cleanest big-cheap-tranche unit; a point baseline (~364 MW) is defensible.
4. **TORRB2/3/4 — proceed BUT the point baseline is a weak counterfactual.** Because normal behaviour
   is bimodal, classifying "withheld vs bid-as-usual" against a single median is fragile and would be
   sensitive to the cutoff. Recommended handling (carry into Stage 3, threshold tunable per the global
   constraints):
   - (b) **Condition on operating state**: restrict the analysis to intervals where the unit is at/near
     full availability (MAXAVAIL ≥ 180) so the min-load zero-cheap mode is removed and like is compared
     with like; and
   - (a) **Distributional "withheld" definition**: classify an opportunity interval as "withheld" if its
     cheap tranche falls below a low percentile of the unit's own full-availability UN distribution
     (e.g. ≤ its UN 25th percentile ≈ floor-only), rather than below a point median. Show sensitivity to
     the percentile.

## Substantive foreshadowing (interpretation guardrail, noted early)
The Torrens units withhold the cheap tranche to floor-only in **~half** of their *undirected,
non-pivotal, fully-available* intervals. So "withheld on an opportunity interval" is not, by itself,
unusual behaviour for these units — this is exactly the pattern under which universal/frequent
withholding cannot be read as directions-specific (per the Stage-4 guardrails). The identifying content
will have to come from the d_t sort (Stage 4ii), not the raw withholding rate.

**STOP — Stage 1 complete. Decision needed on the Torrens "withheld" definition (point vs distributional,
and full-availability conditioning) before building Stage 2.**
