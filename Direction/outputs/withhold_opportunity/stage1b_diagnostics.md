# Stage 1b — pre-Stage-2 gating diagnostics (availability bias, trough, baseline floor rate)

## (1) MAXAVAIL ≥ 180 selects OUT the strategic intervals — DROP the availability condition
Mean of each variable for the intervals a `MAXAVAIL≥180` filter would DROP (`lo`, MAXAVAIL<180) vs KEEP
(`hi`, MAXAVAIL≥180), all regimes, focus units:

| Unit | %≥180 | d_t lo→hi | nonsync lo→hi | pivotal% lo→hi | directed% lo→hi |
|---|---|---|---|---|---|
| TORRB2 | 55.5 | 245→240 | **1060→689** | **78.5→18.5** | **56.4→16.8** |
| TORRB3 | 50.7 | 244→237 | **992→685** | **73.0→18.7** | **59.0→19.2** |
| TORRB4 | 55.6 | 243→259 | **1000→689** | **73.1→19.0** | **56.2→15.7** |
| PPCCGT | 92.8 | 246→249 | 872→687 | 25.1→20.8 | 6.8→0.8 |
| OSB-AG | 77.7 | 217→256 | 803→578 | 0.9→0.7 | 7.2→2.0 |

**d_t is NOT selected (lo≈hi), but pivotality, direction, and non-sync tightness are strongly selected:**
the low-availability (dropped) Torrens intervals are ~3–4× more often pivotal (73–78% vs ~19%),
~3× more often directed (56–59% vs ~17%), and sit at much higher non-sync. Requiring MAXAVAIL≥180 would
therefore **selectively delete exactly the strategic/tight intervals** (quantity withholding shows up as
low MAXAVAIL). Within clean competitive (undirected & non-pivotal) the bias is milder (pct≥180 = 80–93%),
though TORRB3 still shows d_t 272(lo)→235(hi).

**Decision (locked): no MAXAVAIL≥180 condition anywhere in the opportunity/classification path.** It is both
Threat-A leakage (own realised offer) and a strategic-interval selector. The cheap-tranche measure
(effective MW ≤ threshold, capped at MAXAVAIL) already absorbs quantity withholding — a min-load interval
lands on the withheld side automatically. The baseline distribution is taken over all available-UN
(MAXAVAIL>1) intervals.

## (2) Empirical trough of the bimodal cheap-tranche distribution
cheap≤$300 (MW), Torrens pooled, all available-UN intervals:
- Low mode ≈ **60 MW** ($0 floor tranche only), high mode ≈ **200 MW** (full cheap tranche).
- **Trough ≈ 167 MW** (all-UN) / 168 MW (full-avail) = ~70–75th percentile.
- Per-unit trough (full availability): TORRB2 ≈ 170 MW (74 pctile), TORRB3 ≈ 131 MW (63 pctile),
  TORRB4 ≈ 171 MW (70 pctile).
- Percentiles (full-avail): p10=40, p25=60, p40=60, p50=80, p60=110, p75=185, p90=200.

The mass is concentrated in the floor mode; the "full cheap tranche" state (cheap ≥ trough) is only the
top ~25–30%. **Withheld threshold (default): the per-unit empirical trough** (~131–171 MW). Stage 3 will
sweep the cutoff across MW values {80,100,120,150,170} and report classification sensitivity.

## (4) FIRST-CLASS FINDING — Torrens withholds to floor-only in the MAJORITY of clean competitive intervals
Share of *undirected, non-pivotal, available* intervals offering only the floor (cheap≤$300 < 100 MW):

| Unit | n clean-avail | floor-only (<100 MW) | (<120 MW) | median cheap MW |
|---|---|---|---|---|
| TORRB2 | 59,082 | **64.8%** | 69.9% | 60 |
| TORRB3 | 78,835 | **61.5%** | 66.3% | 60 |
| TORRB4 | 65,091 | **59.7%** | 65.4% | 65 |
| PPCCGT | 151,166 | 5.0% | 5.6% | 364 |
| OSB-AG | 90,776 | 3.2% | 3.3% | 185 |

The Torrens gas-steam units offer only their $0 floor tranche — withholding the rest — in **~60–65%** of
their cleanest competitive intervals (undirected, non-pivotal, available). This is the competitive
*baseline* withholding rate. Consequence for identification: a high withheld rate on opportunity intervals
is **near-uninformative** for Torrens (it barely exceeds the 60–65% baseline), so the raw Stage-4(i)
consistency count cannot speak to directions-seeking. **All identifying weight falls on (a) the Stage-4(ii)
d_t sort and (b) the opportunity vs matched-non-opportunity contrast (Stage 2 addition (3)).** By contrast
PPCCGT/OSB-AG almost never withhold competitively (3–5%), so for them withholding *is* unusual — but PPCCGT
has few directed intervals and OSB-AG is near-must-run. Recorded as facts_memo [F6a].

## Locked design going into Stage 2
- Units: TORRB2, TORRB3, TORRB4, PPCCGT (primary); OSB-AG (descriptive, near-must-run); BARKIPS1 excluded.
- No realised-MAXAVAIL condition. Cheap-tranche measure carries both withholding margins.
- Withheld threshold = per-unit empirical trough (default), swept.
- Stage 2 will build BOTH the opportunity set and a matched non-opportunity comparison set.
