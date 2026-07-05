# Descriptive diagnostic readout — v3
# SA directions & strategic bidding: Cuts 2–6 with SRMC-relative withholding

**Analysis date:** 2026-06-19  
**d_t exit month:** 202307 (July 2023)  
**Outcome metric (v3):** `withheld_share = MW in bands priced > srmc_marginal / MAXAVAIL`  
**SRMC:** Real AER STTM Adelaide gas prices × AEMO workbook heat rates + Aurecon 2024 VOM

---

## Gate A: SRMC identification check — PASS (from gate_a_srmc.R)

- d_t is above `srmc_marginal` for **all 35 months for all units** except DRYCGT (Apr–May 2022, spike)
- No structural break in SRMC at Jul 2023 — the exit is cleanly in d_t, not in costs
- Pre-exit mean margins (d_t − srmc_marginal): TORRB ~$230/MWh, PPCCGT ~$275/MWh, MINTARO ~$150/MWh

---

## Cut 2: Net rent (d_t − spot) by d_t tercile × Synchronise/Remain — SUPPORTS

| d_t tercile | Instruction | Mean rent | Median | % positive | N intervals |
|-------------|-------------|-----------|--------|------------|-------------|
| Low d_t     | Remain      | $134.1    | $134.4 | 96.0%      | 32,905      |
| Low d_t     | Synchronise | $126.3    | $128.3 | 96.4%      | 56,081      |
| Mid d_t     | Remain      | $170.9    | $209.6 | 96.3%      | 39,837      |
| Mid d_t     | Synchronise | $195.0    | $218.7 | 97.4%      | 32,826      |
| High d_t    | Remain      | $274.7    | $289.1 | 94.5%      | 36,722      |
| High d_t    | Synchronise | $268.7    | $267.8 | 98.0%      | 40,176      |

**Direction rent is monotone in d_t.** High-d_t Synchronise events earn ~$142/MWh more than low-d_t events. The rent is positive >94% of all directed intervals in every cell. This confirms the incentive gradient is real and large: a generator positioned to receive a Synchronise direction when d_t is high receives roughly double the per-MWh rent compared to a low-d_t direction.

**Verdict: SUPPORTS.** The rent differential across terciles is ~$140/MWh, comparable to a generator's entire SRMC. The mechanism is financially meaningful at any realistic DQ.

---

## Cut 3: withheld_share vs d_t (binned scatter by unit) — MIXED

| Unit       | Slope (per $100 d_t) | R²    | Direction |
|------------|----------------------|-------|-----------|
| PPCCGT     | +0.060               | 0.094 | Positive  |
| TORRB2     | +0.028               | 0.066 | Positive  |
| OSB-AG     | +0.012               | 0.002 | ~Zero     |
| TORRB3     | −0.004               | 0.001 | ~Zero     |
| DRYCGT2    | −0.005               | 0.121 | Negative  |
| DRYCGT1    | −0.008               | 0.159 | Negative  |
| DRYCGT3    | −0.012               | 0.135 | Negative  |
| BARKIPS1   | −0.026               | 0.082 | Negative  |
| QPS5       | −0.033               | 0.242 | Negative  |
| TORRB4     | −0.039               | 0.060 | Negative  |
| MINTARO    | −0.046               | 0.234 | Negative  |

Note: TORRB1 dropped (insufficient variation in d_t bin counts).

The unit-level slopes are heterogeneous in sign. Most units show zero or negative slopes in the raw binned series, but this is confounded by the gas price shock: the high-d_t period (2022) also had the highest SRMC (gas at $27–30/GJ), which mechanically suppresses withheld_share even if strategy is unchanged (fewer bands clear SRMC threshold when SRMC is high). Cut 5 disentangles this.

**Verdict: UNINFORMATIVE AS STANDALONE** — the d_t and SRMC series are co-linear in the raw data. The regression in Cut 5 with SRMC controlled is the correct inference tool.

---

## Cut 4: Day-before mechanism for Synchronise events — SATURATED (again)

| d_t tercile | % PB10 > SRMC | Mean BA10 share | % near MPC | N events |
|-------------|---------------|-----------------|------------|----------|
| Low d_t     | 100%          | 99.7%           | 100%       | 53       |
| Mid d_t     | 100%          | 99.9%           | 100%       | 48       |
| High d_t    | 100%          | 100.0%          | 100%       | 49       |

190 Synchronise event starts identified across 35 months for 12 units.

**The saturation persists even with the corrected event-start detection.** All SA thermal units have ~100% of their MAXAVAIL in the top price band essentially every day, regardless of where d_t sits. This is consistent with chronic strategic positioning rather than d_t-responsive positioning. These units are always maximally offered above SRMC — the "mechanism" being tested (do they go to high bands when d_t is high?) can't be detected from this metric because they're always there.

This is an important finding in itself: withholding is not a sporadic response to high d_t — it is the default posture throughout the entire sample. The behavioral test is not "do they withhold more when d_t is high?" but "does the level or duration of withholding respond to d_t?" Cut 5 provides this.

**Verdict: CONSISTENT WITH CHRONIC WITHHOLDING, but the mechanism test is unsalvageable with this metric.** The day-before offer profile does not discriminate d_t-responsive from always-maximal behavior.

---

## Cut 5: Continuous d_t regression (unit FE + SRMC control) — SUPPORTS

| Specification                     | d_t coeff (std) | SE      | t-stat | N   |
|-----------------------------------|-----------------|---------|--------|-----|
| All intervals, no SRMC ctrl       | −0.00185        | 0.00651 | −0.28  | 361 |
| All intervals, + SRMC control     | +0.01981 **     | 0.00709 | +2.79  | 361 |
| Directed only, + SRMC control     | +0.01626        | 0.01259 | +1.29  | 180 |

Unit FE absorb time-invariant unit-level strategy. SRMC is measured in $/MWh.

**The sign flips when SRMC is controlled.** Without SRMC: d_t is negatively (near-zero) correlated with withheld_share within units. With SRMC added: d_t is positively associated (β ≈ 0.020, p < 0.01). The interpretation: the 2022 gas price spike drove d_t and SRMC up simultaneously. Higher SRMC raised the bar for what counts as "above SRMC" withholding, mechanically suppressing withheld_share even if strategic behavior was unchanged. Once SRMC is partialled out, the residual d_t variation is positively correlated with withheld_share — when d_t is high *relative to* the cost environment, units withhold more.

The SRMC coefficient is strongly negative (β ≈ −0.00084, p < 0.001): holding d_t fixed, higher marginal costs mean fewer bands clear the SRMC threshold — the mechanical effect, correctly signed and significant.

On directed intervals only, the d_t coefficient is +0.016 (p = 0.20): directionally consistent but noisier with half the observations.

**Verdict: SUPPORTS the hypothesis.** A one-standard-deviation increase in d_t (within unit, after controlling for SRMC) is associated with ~2 percentage points more of MAXAVAIL offered above SRMC. The effect is economically small but statistically reliable.

---

## Cut 6: Within-day rent responsiveness (withheld_share ~ rent | unit×month FE) — SUPPORTS

| Specification                | rent coeff | SE       | t-stat | N          |
|------------------------------|------------|----------|--------|------------|
| withheld_share ~ rent \| FE  | +1.4e-05 **| 3.0e-06  | +4.5   | 2,298,025  |

Unit × month FE absorb all monthly-level strategy. Identification from within-day rent variation (spot varies; d_t fixed per month; rent = d_t − spot).

When spot is lower within a given day-unit cell (rent is higher), units offer a slightly larger share of capacity above SRMC. The coefficient is small in magnitude (1.4e-5 per $/MWh rent) but precisely estimated with 2.3M observations. A $100/MWh increase in the instantaneous rent (e.g., a low-spot period within the day) is associated with a 0.14 percentage point increase in withheld_share.

This is the cleanest identification in the v3 set: purely within-unit-month variation, no confounding from seasonal effects or cost changes.

**Verdict: SUPPORTS.** The within-day variation confirms the mechanism: withheld share responds positively to instantaneous rent, not just to the monthly d_t level.

---

## Heterogeneity: slopes by unit

Units with larger pre-exit direction margins (d_t − SRMC) show more variation in withheld_share over time. PPCCGT and TORRB2 have the two most positive d_t slopes in Cut 3 (+0.060 and +0.028). MINTARO and QPS5 show the most negative. The heterogeneity pattern does not clearly align with direction margin size — the dominant factor is probably technology type and baseload vs peaking role in the AEMO dispatch stack.

---

## Overall v3 verdict

| Cut | Finding | Verdict |
|-----|---------|---------|
| Gate A | No SRMC break at exit; margins large and positive throughout | SUPPORTS design |
| Cut 2 | Rent monotone in d_t tercile; $268–$275 at high d_t vs $126–$134 at low d_t | SUPPORTS |
| Cut 3 | Raw slopes heterogeneous; confounded by SRMC co-movement | UNINFORMATIVE standalone |
| Cut 4 | Saturation at 100% — chronic withholding, not d_t-responsive at this metric | CONSISTENT WITH CHRONIC WITHHOLDING |
| Cut 5 | d_t coeff +0.020 (p < 0.01) after SRMC control; sign reversal is the finding | SUPPORTS |
| Cut 6 | rent coeff +1.4e-5 (p < 0.001, N = 2.3M) within unit×month | SUPPORTS |

### Decision: **GO — advance to estimation**

The descriptive v3 diagnostic confirms:

1. The incentive (direction rent) is large, real, and monotone in d_t throughout the sample.
2. The behavioral response exists but is modest: ~2pp per SD(d_t), ~0.14pp per $100 instantaneous rent. The signal is real but small relative to the chronic ~95-100% withholding baseline. This is consistent with the strategic position being "always maximal" rather than dynamically adjusted — the marginal response to d_t is detectable but not the dominant story.
3. The design is viable: the SRMC control is essential (Cut 5 shows the sign reversal), and the within-unit-month identification (Cut 6) is the cleanest available. The formal estimation should use unit × time FE with SRMC as a control.

### Required for estimation

1. **Primary outcome:** `withheld_share` (from v3 panel) — ready.
2. **Regression design:** Two-way FE (unit + month or unit × quarter), SRMC control, d_t as the continuous variable. The d_t exit month (202307) can be used as an event study anchor for robustness.
3. **Robustness rows:** (a) `withheld_share_allin` (using static/all-in SRMC threshold instead of marginal); (b) ~~revealed-cost SRMC for BARKIPS1 and TORRB~~ — the revealed-cost anchor (§7) was tested (`gate_a_revealed_cost.R`) and **rejected**: offers are not gas-indexed cost bids [F3a], so engineering SRMC is maintained and the proxies stand.
4. **Secondary outcomes:** rebid count per unit-day (measures strategic flexibility), share of time in the top two bands combined.
5. **Identification concern to address:** d_t is not exogenous to the firm's strategy if the direction mechanism itself affects spot prices. The RKD/RDD using the trailing-365d 90th-pct formula as a discontinuity instrument is the preferred design; document the first-stage.
