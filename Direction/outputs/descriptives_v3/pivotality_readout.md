# Pivotality & strategic withholding — readout

**Date:** 2026-06-20 · Sample 202201–202412 (36 months DISPATCHLOAD), SA synchronous units.
**Question:** do units withhold more — and actively rebid to withhold — when they are pivotal for SA system strength, consistent with positioning to be directed and paid d_t?

---

## Measure: system-strength pivotality

From AEMO's acceptable minimum synchronous generator combinations (`sa_minimum_generator_combinations.csv`). System strength is secure iff the online synchronous fleet satisfies ≥1 acceptable combination at the prevailing non-synchronous penetration tier. **Pivotal_t(s) = 1** iff removing station s makes every applicable combination infeasible.

- **Realised** (`piv_*`): drops s from its *own realised online* set. Endogenous (a directed unit becomes online→pivotal).
- **Ex-ante** (`pex_*`): s essential given **rivals' availability only** — exogenous to s's own withholding. The clean treatment.

Online = synchronised (`TOTALCLEARED>0`). DISPATCHLOAD extracted for all 36 months (`extract_dispatchload.R`). Assumptions (BIPS engine count from MW; 4 syncons available post-2021; non-sync tier = combinations valid at/below observed non-sync; regime = system_normal) documented in `pivotality.R`.

### Prevalence (share of intervals pivotal)
| Station | Realised | Ex-ante |
|---|---|---|
| Torrens Island B | 42.4% | 1.3% |
| Pelican Point | 15.3% | 0.1% |
| Mintaro | 11.8% | ~0 |
| Quarantine 5 | 1.6% | ~0 |
| Osborne / Dry Creek / BIPS / Snapper | ~0 | ~0 |

TIB is the system-strength backbone; peakers are always substitutable. Ex-ante essentiality is rare (peakers sit ~100% available, so the available fleet rarely *needs* any single unit) but sharp.

### Validation: pivotality predicts directions
- P(TIB pivotal | TIB directed) = **0.65** vs 0.44 baseline.
- P(Pelican pivotal | Pelican directed) = **0.35** vs 0.17 baseline (2.1×).
AEMO directs units disproportionately when they are pivotal — the measure tracks genuine security need.

---

## Result 1 — pivotal units withhold much more (level), robust to endogeneity

Outcome `withheld_share` (MW priced above SRMC_marginal / MAXAVAIL); unit FE; +SRMC+spot controls; clustered by month. `Pivotality_level_effects.csv`.

| Treatment | Sample | Coef | t |
|---|---|---|---|
| Realised pivotal | all | +0.128 | 11.8 |
| Realised pivotal | undirected | +0.111 | 9.4 |
| **Ex-ante pivotal** | all | **+0.143** | 3.9 |
| **Ex-ante pivotal** | **undirected** | **+0.140** | 3.0 |
| Non-sync penetration (per +100 MW) | undirected | +0.0054 | 8.6 |

Within pivotal-capable units, undirected intervals (`Pivotality_withholding_bars.png`):
- **TORRB3: 70% → 88% withheld when pivotal**; TIB(all four) +0.175 (t 6.8); PPCCGT 60%→74% (+0.134, t 3.8). MINTARO ns.

**Reading.** Being pivotal raises withholding ~11–14 pp. The effect (i) survives restriction to *undirected, market-facing* intervals (so it is not the mechanical "directed units offer high because d_t pays regardless"), and (ii) holds for the **ex-ante** measure driven only by rivals' availability + non-sync — i.e. when units are made pivotal by forces outside their own control. The continuous exogenous driver (non-sync penetration, weather-driven) independently raises withholding (t 8.6). This is the direct test of the research question: units withhold more precisely when they are system-strength-essential and their offer determines dispatch — consistent with strategically positioning to be directed and collect d_t.

The pivotality **state** dominates the prize **size**: the d_t×pivotal interaction is insignificant (`Pivotality_interaction.csv`); the d_t slope (~+0.013) is a second-order margin. "Am I needed?" beats "how big is the rent?"

---

## Result 2 — pivotal units actively rebid to withhold capacity

Rebid intensity = distinct `OFFERDATETIME` versions per unit-day (mean 14.5/day; PPCCGT up to 51). Quantity-withholding = interval-fixed first-version minus last-version MAXAVAIL, averaged over the day (>0 = capacity withdrawn intraday). Unit+month FE, clustered by month. `rebid_pivotality_daily.csv`, `Rebid_vs_pivotality.png`.

| Outcome | Treatment | Sample | Coef | t |
|---|---|---|---|---|
| Rebid count / day | realised pivotal | all | −0.65 | ns |
| Rebid count / day | realised pivotal | undirected | −2.52 | −4.2 |
| **MAXAVAIL withdrawn (MW)** | realised pivotal | all | **+39.3** | 6.0 |
| **MAXAVAIL withdrawn (MW)** | **realised pivotal** | **undirected** | **+40.2** | **5.3** |
| **Above-SRMC escalation (pp)** | realised pivotal | all | **+0.093** | 6.3 |
| Above-SRMC escalation (pp) | realised pivotal | undirected | +0.042 | 2.4 |
| **Above-SRMC escalation (pp)** | **ex-ante pivotal** | all | **+0.183** | 5.3 |
| Above-SRMC escalation (pp) | non-sync (per +100 MW) | undirected | +0.0057 | 8.1 |

Quantity-withholding = interval-fixed first−last MAXAVAIL; escalation = above-SRMC capacity share in last version minus first (>0 = rebids move MW up the price ladder; price ladder held at the day's latest bands).

**Reading.** Pivotal units do **not** churn more bid versions (if anything fewer). But the *direction* of their rebidding is unambiguous on **two levers**: they **withdraw ~40 MW of MAXAVAIL** (≈20% of a TIB unit, survives undirected-only) *and* **move ~4–18 pp of capacity above SRMC** across the day. The price-escalation result holds undirected and is **strongest for the exogenous ex-ante measure** (+18 pp, t 5.3) and the weather-driven non-sync driver (t 8.1) — so the dynamic rebid conduct, like the static level effect, is not a mechanical consequence of the direction. Withholding runs on quantity *and* price margins, actively, through intraday rebids.

---

## Why are non-pivotal units directed? (`reason_pivotality.R`)

P(pivotal | directed) is well below 1 (TIB 0.65, Pelican 0.35 per-interval). That is expected, not a defect. Three forces tested; the data verdict:

**Driver 1 — spell dilution (verified, largest).** Directions are multi-hour spells (median 9.0 h, mean 18.7 h, max 241 h); pivotality is a 5-min flag. Per-direction (event-level) vs per-interval, 2022–24 (`perinterval_vs_perdirection.csv`):

| Station | per-interval P(pivotal) | per-direction hit-any | mean fraction of spell pivotal |
|---|---|---|---|
| Torrens Island B | 0.648 | **0.703** | **0.399** |
| Pelican Point | 0.604 | 0.586 | 0.397 |
| Mintaro | 0.497 | 0.488 | 0.236 |
| Quarantine 5 | 0.330 | 0.311 | 0.126 |

A TIB direction touches a pivotal interval 70% of the time but is pivotal only ~40% of its duration — so ~60% of a directed spell's intervals are mechanically non-pivotal. This is the bulk of non-pivotal directed *intervals*.

**Driver 2 — individual vs collective pivotality (verified).** The measure flags s pivotal only if removing *s alone* breaks every combination. Substitutable peakers are directed yet rarely individually essential: per-direction hit-any QPS5 0.31, Mintaro 0.49, BIPS 0.00, Osborne 0.07; ex-ante ≈0. AEMO directs one unit from a feasible set, so directions land on individually-non-pivotal units by construction. Non-pivotal = not *uniquely* needed.

**Driver 3 — reason-construct mismatch (logical, not empirically separable here).** Pivotality encodes only the system-strength standard; directions also cover voltage/inertia/network. The directed set is descriptively a superset: "System strength" is a **2021-only label**; 202201–202412 is uniformly "System security" (+ a 2024 "voltage" subcategory). But the cross-year test to *quantify* this fails — 2021 pivotality is ≈0 (Jan–Oct = 0%) because the combinations standard assumes 4 syncons (commissioned *through* 2021) and 2021 non-sync penetration was low, so P(pivotal | 2021 strength directions) = 0.000 is an artifact, not signal. And the one clean in-sample split runs the wrong way for the naive story: 2024 **voltage** directions are *more* pivotal (LPM +0.10 interval t 4.0; +0.22 per-direction t 5.5), because reason and pivotality are positively correlated through the unit/state. The reason field cannot separate strength from non-strength need in this sample.

**Verdict:** drivers 1–2 explain non-pivotal directions and are verified; driver 3 is real in principle but unquantified. None of this touches Results 1–2, which condition on the pivotal *state* (incl. exogenous ex-ante). Artifacts: `reason_pivotal_interval.csv`, `perdirection_hitrate_{station,reason}.csv`, `perinterval_vs_perdirection.csv`, `reason_pivotal_by_year.csv`, `reason_pivotal_eventlevel.csv`.

### N-1 contingency variant + decomposition (`pivotality.R`, `pivotality_decomposition.R`)

`pivotality.R` gains an **N-1** measure (base `piv` and ex-ante `pex` unchanged): per interval, remove the single largest online synchronous unit (the credible contingency), then test each station's pivotality on the post-contingency fleet (`piv_n1_*`); the online vector (`on_*`) and a `short_n1` (system not N-1-secure) flag are stored.

**Headline N-1 finding — `short_n1 = 46.6%`:** SA cannot survive loss of its single largest online synchronous unit, without further commitment, **nearly half of all intervals** (vs base `short` = 0.3%). This is the dominant N-1 signal and a first-order reason AEMO commits units beyond the bare base requirement.

Station-level shares (`pivotal_shares_base_n1_exante.csv`). **Pivotality is monotone — removing the largest unit can only make *more* units pivotal, never fewer** (verified: 0 intervals where a station is base-pivotal-and-N-1-secure but not N-1-pivotal). To compare like with like, the right N-1 column is the share **on N-1-secure intervals** (same denominator), where N-1 ≫ base as expected:

| Station | base (all int.) | N-1 literal² | N-1 \| N-1-secure³ | base \| N-1-secure | ex-ante |
|---|---|---|---|---|---|
| Torrens Island B | 42.4% | 64.4% | **33.4%** | 2.7% | 1.3% |
| Pelican Point | 15.3% | 57.0% | 19.5% | 0.1% | 0.1% |
| Mintaro | 11.8% | 49.4% | 5.2% | 1.8% | ~0 |
| Quarantine 5 | 1.6% | 47.3% | 1.3% | 0.0% | ~0 |
| others | ~0 | ~47% | ≤5% | ~0 | ~0 |

² **Literal `piv_n1`** = remove largest online unit, then remove i. Identity: `literal = short_n1 + clean`, where on the 46.6% `short_n1` (not-N-1-secure) intervals **every** station is trivially flagged (removing any unit keeps an already-infeasible state infeasible). So the literal share has a ~47% floor for all stations, incl. never-base-pivotal BIPS/Snapper — it is not a clean per-unit-essentiality measure.
³ **N-1 | N-1-secure** = the meaningful incumbency measure: among intervals that survive the contingency, is i still essential? This is **far above base on the same subsample** (TIB 33.4% vs 2.7%) — the contingency-robustness requirement. (Earlier drafts reported "clean N-1" as a share of *all* intervals = 17.8% for TIB; that number is `N-1 | secure × P(secure)` and looks below base only because it zeroes the `short_n1` half where base pivotality is concentrated — 41 of TIB's 42 base-pivotal pp sit on `short_n1` intervals. It is not a decrease in pivotality.)

**Decomposition of the directed-but-base-non-pivotal mass** (`directed_nonpivotal_waterfall.csv`; 76,489 directed interval-stations, 2022–24). Residual after each successive cut:

| Cut | Residual | % of P0 |
|---|---|---|
| P0: directed & base-non-pivotal | 76,489 | 100.0 |
| − drop Remain (keep Synchronise) | 51,042 | 66.7 |
| − drop voltage reason (strength-relevant only) | 44,661 | 58.4 |
| − drop `short_n1` (system not N-1-secure → directed to restore it) | 31,508 | 41.2 |
| − drop clean N-1-pivotal unit (incumbency post-contingency) | 19,339 | 25.3 |
| − drop near-margin (≤2 combos survive removing i); keep ≥3 | 15,711 | 20.5 |

Reading: **~80% of the directed-but-non-pivotal mass is accounted for** — Remain directions (already-running, 33 pp), voltage-service directions (8 pp), N-1 insecurity (17 pp), clean N-1 pivotality (16 pp), and near-margin proximity (5 pp). The final **20.5% residual** (15,711 interval-stations) is directed, Synchronise, strength-reason, N-1-secure, the directed unit not N-1-pivotal, and ≥3 combinations survive removing it — genuinely "comfortably redundant" directions, dominated by **Mintaro (8,279 intervals ≈ 690 unit-hours)** and **TIB (5,391)**. This residual is the substitutable-unit / operational-discretion case (`why_directed_nonpivotal.md` reasons 1, 5): AEMO selecting one peaker from a feasible set, not a uniquely-needed unit.

### Depth of pivotality — distance-to-essential (`pivotality.R`, `depth_report.R`)

The binary pivotal flag is knife-edge. **Depth `k_i`** generalises it: the minimum number of rival units to remove (unit i excluded) before the fleet satisfies no applicable combination. **k=0 ⟺ pivotal**; higher k = more redundant. Two versions parallel `pex`/`piv`: **depth_ex** (primary, over rivals' *available* fleet) and **depth_rl** (over rivals' *online* fleet). Exact memoized solver, validated against brute force (400 random states, 0 failures); regression test `depth_ex==0 ⟺ pex` passes on all 8 stations × 36 months. (A DISPATCHLOAD `(SETTLEMENTDATE,DUID)` dedup fix was applied first — some early months had 4× duplicate rows inflating counts; base `piv`/`pex` unchanged after.)

Mean depth (median in parentheses):

| Station | ex-ante (available rivals) | realised (online rivals) |
|---|---|---|
| Torrens Island B | **3.1** (3) | **1.0** (1) |
| Pelican Point | 3.6 (3) | 1.3 (1) |
| Quarantine 5 | 3.6 (3) | 2.1 (2) |
| Mintaro | 4.3 (4) | 2.0 (1) |

Two readings: (i) TIB is the **shallowest ex-ante** (closest to essential) — the system-strength backbone; Mintaro the deepest (most redundant). (ii) **Realised depth ≈ 2 units shallower than ex-ante** — the online fleet sits much closer to the security edge than the available fleet, the structural footprint of withholding (capacity available but not online).

**Depth falls monotonically as non-sync penetration rises** (`depth_by_nonsync_tier.csv`) — TIB ex-ante depth 3.3 (<1300 MW non-sync) → 1.7 (1900–2100 MW); TIB ex-ante pivotal share 0.9% → 7.0%. As renewables crowd out synchronous headroom, TIB moves continuously toward essential. This is the smooth, graded form of the tightness mechanism behind Result 1 — and a better right-hand-side variable for the bidding regressions than the binary flag.

## Caveats / next
- Ex-ante measure is sparse (1.3% TIB) → lower power; the continuous non-sync driver is the higher-powered exogenous instrument and agrees. **Depth `k_i` ([F19]) is the graded replacement** — non-sparse, monotone in tightness.
- 2021 DISPATCHLOAD now extracted (`bid_cache/DISPATCHLOAD_2021*.rds`) but 2021 pivotality is unreliable (syncon commissioning + 4-syncon assumption); used only for the [F17] reason test, excluded from the headline 2022–24 panel.
- Quantity-withholding (h1) pools directed days; an undirected-only and a directed-mid-day-removed version would sharpen it.
- Non-sync tier mapping and BIPS engine approximation are documented assumptions; robustness to a binary-station variant and to risk-island combinations is open.
- Rebid *price-band* escalation (moving MW to higher bands across versions) not yet built — needs per-version BIDDAYOFFER price join; complements the MAXAVAIL-withdrawal measure.

## Resolves facts-memo gaps
- **[G1] pivotality** — built (realised + ex-ante), validated against directions.
- **[G2] requirement-active** — system-strength need proxied by pivotality + non-sync tier.
- **[G5] rebid intensity** — built; pivotal units withdraw capacity via rebids.
