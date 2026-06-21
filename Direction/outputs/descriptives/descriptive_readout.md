# Descriptive diagnostic readout — SA directions & strategic bidding

**Analysis date:** 2026-06-19  
**d_t exit month:** 202307 (July 2023)

---

## Gate 0: d_t validation — PASS

- Correlation (realised DCP/DQ vs reconstructed trailing-365d 90th-pct): **1.00** on 24 overlap months
- d_t plateau 2022Q3–2023Q1: ~**$348–352/MWh**; post-exit settling: ~**$162–225/MWh** (-54% from peak)
- Exit is sharp and clean: the 2022 spike prices roll out of the trailing window month by month from July 2023, exactly as the institutional description predicts
- June 2022 gap visible in the reconstructed series but doesn't affect the overlap comparison (old-format events bridge it)

**Verdict: SUPPORTS.** The identification variable is reconstructed from primitives with near-perfect fidelity. The cliff at July 2023 is mechanical, large (~$186/MWh from peak), and predetermined. The design is viable.

---

## Cut 1: Treatment variation — AMBIGUOUS

- **13 SA1 treated DUIDs** directed at least once over 202201–202412
- Dominant units: TORRB3 (101k intervals), TORRB4 (77k), TORRB2 (84k), MINTARO (40k), PPCCGT (34k)
- **Synchronise: 146,393 intervals; Remain: 227,117 intervals** (Synchronise = the offline-to-directed margin)
- Direction frequency vs d_t (monthly): **corr = −0.078** — no meaningful co-movement

**Verdict: AMBIGUOUS, expected.** Direction frequency is AEMO's decision (system security needs), not the generator's. The hypothesis doesn't predict that AEMO issues more directions when d_t is high — it predicts that generators are more likely to be offline and available to direct when d_t is high. Cross-unit variation is sufficient for identification. The DRYCGT cluster spiked right at/after the d_t exit (Cut 1 figure), which if anything is the opposite of the hypothesis, but these are peaking units with idiosyncratic outage patterns; don't over-read it.

---

## Cut 2: Directed-price rent — SUPPORTS

| Period | Type | Mean rent (d_t − spot) | Median | % positive | N intervals |
|--------|------|------------------------|--------|------------|-------------|
| Pre-exit (high d_t) | Remain | **$238.8/MWh** | $257.5 | 92.7% | 45,057 |
| Pre-exit (high d_t) | Synchronise | **$226.9/MWh** | $246.7 | 95.7% | 53,786 |
| Post-exit (low d_t) | Synchronise | **$162.7/MWh** | $163.4 | 97.2% | 75,328 |
| Post-exit (low d_t) | Remain | **$160.6/MWh** | $173.9 | 96.5% | 64,419 |

The rent distribution (Cut 2 figure) shows both pre- and post-exit densities tightly clustered to the right of zero, with the pre-exit tail extending further rightward. The ~$64/MWh decline in mean Synchronise rent maps directly onto the d_t fall (~$186/MWh from peak; the remainder reflects that spot also declined somewhat post-2022). Three observations stand out:

1. The **rent is large in absolute terms** at all times — even post-exit, $162/MWh is substantial relative to SA variable costs (~$80–120/MWh for gas)
2. The **fraction positive actually increases post-exit** (95.7% → 97.2% for Synchronise) — spot prices calm post-spike while d_t remains above marginal cost
3. **Remain and Synchronise rents are nearly identical** post-exit; the Synchronise premium pre-exit (~$12/MWh mean) is modest

**Verdict: SUPPORTS — strongly.** The incentive to be directed was large and real across the entire study window. The ~$64/MWh post-exit decline gives the design variation to work with, even though the rent never becomes zero. This is the strongest affirmative finding.

---

## Cut 3: Offer behaviour — UNINFORMATIVE AS DESIGNED

- **Control group = 33 wind/solar DUIDs** (AGLHAL, BLUFF1, BNGSF1/2, CATHROCK, CLEMGPWF, GSWF1A, HALLWF1/2, HDWF1-3, HPRG1, LGAPWF1/2, LKBONNY1/2, MTMILLAR, NBHWF1, PAREPS1, PAREPW1, PTSTAN1, SNAPPER1, SNOWNTH1/STH1/TWN1, SNUG1, TB2SF1, TBSF1, TIBG1, WATERLWF, WGWF1, WPWF)
- All 33 are wind or solar farms. **None are thermal generators.**
- Control high-band share: ~0–1% throughout (wind/solar always offer at low/negative prices)
- Treated high-band share: ~40–80% throughout (displayed as 4,000–8,000% due to a scale formatting bug — actual values are ~40–80%)

There are no never-directed SA thermal generators in the bid panel: every SA gas unit was directed at some point over 2022–2024. The treated-vs-control comparison here is gas-vs-renewables, not strategic-vs-non-strategic, and is therefore uninformative about the behavioral hypothesis. The within-treated time-series trend shows high-band share is flat to slightly increasing post-exit — if anything the opposite of what the hypothesis predicts, but with a metric that has known problems (see Cut 4).

**Note on chart scale:** share_high values are in 0–1 range; the y-axis percent formatter multiplied by 100 twice (values were passed as fractions, then `scales::percent` multiplied again). Actual treated mean share_high ≈ 40–80%. Does not affect the interpretation — the comparison is still gas vs wind/solar.

**Verdict: UNINFORMATIVE.** Discard the treated-vs-control comparison for the behavioral margin. Focus Cut 5 and any regression on within-treated time variation. For a thermal control group, options are: (a) SA gas units in months before first direction (few such months), (b) NEM gas units outside SA (different market), or (c) treat the d_t exit as a within-unit shock with unit FE absorbing time-invariant strategy.

---

## Cut 4: Mechanism (pre-direction offer state) — UNINFORMATIVE

- Synchronise events by d_t group (median split at $220/MWh): high d_t = 373 events, low d_t = 360 events
- **% with PRICEBAND10 ≥ $5,000 day before: 100% in BOTH high-d_t and low-d_t periods, for every DUID**
- The chart is a wall of identical bars at 100% — no variation

**Verdict: UNINFORMATIVE — metric saturates.** All directed SA gas units always have their top price band ≥ $5,000 the day before any Synchronise event. This is consistent with chronic strategic positioning (all capacity routinely in high bands), but it cannot discriminate d_t-responsive variation from always-on withholding. The binary indicator (does any capacity sit ≥ $5,000?) is the wrong measure. The correct measure is quantity: what **share of MAXAVAIL** is offered at ≥ $5,000 (continuous version of Cut 3), and especially the **BANDAVAIL in the top one or two bands relative to MAXAVAIL**. That quantity can move even when the price threshold always crosses $5,000.

---

## Cut 5: Event-study preview — AMBIGUOUS

- t = 0 = July 2023 (d_t exit); window ±18 months; treated = 13, control = 33 DUIDs
- Treated high-band share: volatile (40–80%), no visible shift at t = 0; post-exit trend slightly upward if anything
- Control high-band share: flat near zero throughout — pre-trend for control is flat ✓
- **No differential shift visible for treated at t = 0**

**Verdict: AMBIGUOUS** for reasons inherited from Cut 3. The event study cannot identify an effect that isn't in the outcome variable, and the high-band binary/fraction metric as computed has (a) a structural mismatch (gas-vs-renewables control), (b) scale bug in display, and (c) may be capturing asset-type variation rather than strategic variation. Rebuild this cut with: (i) the continuous share-in-top-band quantity, (ii) within-treated comparison (treat Synchronise events as treated periods, Remain or non-directed intervals of same units as control), and (iii) rebid intensity as a second outcome.

Pre-trend for treated: visually flat in the shaded pre-exit window (t = −6 to −1), but noisy. Not a red flag, but not dispositive either given the outcome metric problems.

---

## Overall go/no-go

| Cut | Finding | Verdict |
|-----|---------|---------|
| Gate 0 | Corr = 1.00; d_t fall = −54% from peak; exit July 2023 is clean and predetermined | **SUPPORTS** |
| Cut 1 | Direction freq uncorrelated with d_t (corr −0.08) — expected, AEMO drives direction frequency | **AMBIGUOUS** |
| Cut 2 | Rent: Sync pre-exit $227/MWh (96% positive), post-exit $163/MWh (97% positive) | **SUPPORTS** |
| Cut 3 | Control = wind/solar; treated high-band share flat/rising post-exit | **UNINFORMATIVE** |
| Cut 4 | Binary PRICEBAND10 ≥ $5,000: 100% saturation in all periods | **UNINFORMATIVE** |
| Cut 5 | No visible differential shift at t=0; noisy; metric problems inherited | **AMBIGUOUS** |

### Decision: **CONDITIONAL GO**

**Go on:** The rent exists, is large ($163–238/MWh depending on period and instruction type), and persists even post-exit. The incentive to position for directions was material throughout the sample. The identification variable (d_t exit) is clean, predetermined, and reconstructable from primitives. The reduced-form design is viable.

**Conditional on:** The behavioral outcome measure needs to be rebuilt before any regression. The current high-band-share metric has three problems: (1) binary price indicator saturates at 100%; (2) continuous version (share of MAXAVAIL ≥ $5,000) is flat or slightly increasing post-exit, opposite to the hypothesis; (3) control group is structurally incomparable (wind/solar). None of these are data problems — they are measurement and design choices that need revision.

### Required before estimation

1. **New primary outcome:** Replace `share_high (price ≥ $5,000)` with `share_topband = BANDAVAIL10 / MAXAVAIL` — the fraction of available capacity offered in the top price band. This moves from a binary threshold indicator to a continuous quantity measure and is more directly interpretable as strategic capacity allocation.

2. **Secondary outcomes:** Rebid intensity (number of OFFERDATETIME versions per DUID-day), and `BANDAVAIL9 + BANDAVAIL10` / MAXAVAIL as a wider top-band share.

3. **Control group fix:** Drop wind/solar controls. Use within-unit variation: for units with both Synchronise and non-directed intervals in the same month, the non-directed intervals form a within-unit counterfactual. Alternatively, use Remain-directed intervals as a placebo (Remain units are already running — less strategic positioning expected pre-direction).

4. **The positive finding (Cut 2) does have an estimation analogue:** The directed-price rent per interval can be regressed on d_t and unit-month fixed effects to estimate whether the rent pass-through is 1:1 with d_t (mechanical) or attenuated (behavioral); that's a clean first-stage result even without the behavioral test.
