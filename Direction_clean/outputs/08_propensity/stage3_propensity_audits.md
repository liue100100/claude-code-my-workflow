# Stage 3 findings — propensity audits: one construction failure caught and fixed, one gate that measures the wrong object

Registration: `08_propensity/registration.md`. Scripts: `stage3_propensity_audits.R` (audits on
the Stage-2 π), `stage3b_conditions_pi.R` (conditions-only rebuild + re-audit). Outputs:
`stage3_audits.csv`, `stage3_nesting.csv`, `stage3b_audits_pi2.csv`, `stage3b_nesting_pi2.csv`;
π2 columns appended to `stage2_panel.rds`.

## Audit of the Stage-2 π: FAIL, diagnosed as a genuine constraint violation

- Leakage: R² = 0.088 (> 0.01), loading on focal availability (+).
- Nesting: inverted — mean π lowest exactly where pex and the N−1 flag fire.

Diagnosis (one cause for both): the Stage-2 hazard embeds the **direction record** — `log_tsl`
(time since last direction) as a regressor, and hazard mechanically zeroed inside spells and
8-hour cool-downs. Directions are focal-heavy, so this injects the focal station's directed
status into π, which the registration's hard constraint forbids. (The registration listed
time-since-last-direction in the spec while also barring focal directed status from all inputs —
an internal contradiction; the audit did its job and caught it.) The nesting inversion is the
same artifact: π was zeroed precisely in the tight, directed states.

## The conditions-only rebuild (π2): constraint enforcement, not amendment

Hazard refit without `log_tsl` (8 parameters), predicted over all half-hours with no
direction-record zeroing; month-out CV throughout; π2 accumulated as registered. Predictive
cost: CV AUC 0.847 (vs 0.863 with the direction-history terms).

- **Nesting: PASS, monotone and strong.** Mean π2: pex = 1 → **0.560**; N−1 = 1 → **0.347**;
  rest → **0.138**. The registered expectation exactly.
- **Variance split:** slow (30-day) component 22.6%, fast 76.5%.
- **Leakage regression: R² = 0.130 — above the 0.01 threshold, but the object has changed.**
  The loading is now dominated by the focal cheap share with a large **negative** coefficient
  (−0.367, t = −53.8): half-hours with high direction propensity are half-hours where Torrens'
  cheap share is low. π2's inputs contain no focal availability, no focal bids, no focal
  directed status, and no spot price — enumerable from the construction code. What the
  regression detects is therefore not construction leakage; it is the **equilibrium conduct
  relationship** — withholding co-moving with ex-ante direction exposure — which is the object
  Stage 4 is registered to estimate.

## The gate problem, stated plainly

The leakage stop condition (R² > 0.01 on focal availability + cheap share) cannot distinguish
construction leakage from the focal desk responding to the same public conditions the propensity
is built from. Taken literally it is self-defeating: under the paper's own hypothesis, any valid
π must correlate with focal conduct — a π that passed this audit would mechanically guarantee a
null Stage 4. The audit's *intent* — no focal data in the construction — is satisfied by π2 and
verifiable by code inspection; the audit's *letter* fails for the reason the project exists.

**The registered stop condition has fired. Whether to adjudicate the gate as
satisfied-in-intent (run Stage 4 on π2) or to halt is the author's decision, not the
pipeline's.** No Stage-4 estimation code has been written or run.

---

## AMENDMENT 1 resolution (author-directed, 2026-07-07; registration.md Amendment 1;
## script `stage3c_amended_audits.R`; recorded before any Stage-4 code)

The author replaced the outcome-correlation gate with construction-based verification. Results:

### (1) Provenance manifest — the leakage check proper

| π2 input | source table(s) | focal content |
|---|---|---|
| min forecast slack (1/4/8h) | `RIVAL_BOP_*.rds` — BIDOFFERPERIOD filtered **at source** to the nine rival DUIDs (PPCCGT, OSB-AG, QPS5, DRYCGT1–3, MINTARO, BARKIPS1, SNAPPER1); slow-start commitment rule from DISPATCHLOAD rows for PPCCGT/OSB-AG only; AEMO TLA combination tables; PDPASA_RS SA1 UIGF | none — no Torrens DUID upstream; the depth search zeroes the Torrens column before it runs |
| current slack (commitment) | pivotality `depth_rl`: rival online counts from DISPATCHLOAD, Torrens zeroed; non-sync tier from semi-scheduled TOTALCLEARED | none in the counts; the tier is weather/UIGF-driven semi-scheduled output (a constraint-curtailment channel exists in principle and is noted, not material at the tier grain) |
| demand trough | PDPASA `DEMAND50` (SA1 regional demand forecast) | load-side only |
| non-sync share forecast | PDPASA SS_WIND_UIGF + SS_SOLAR_UIGF / DEMAND50 | weather-driven |
| hour blocks | clock | none |
| *(removed)* time-since-last-direction; in-spell/cool-down zeroing | direction record | **excluded** — hard-constraint enforcement (the Stage-2 π violation) |

### (2) Incremental-R² tripwire: PASS

π2 on focal availability + cheap share **controlling for the Layer-1/hazard conditions**:
incremental R² = **0.0042** (vs 0.130 unconditional); on the day-ahead variant **0.0024**. The
focal terms retain statistical significance at n = 52,555 but explain ~0.4% of variance beyond
the conditions — consistent with the linear controls not fully spanning the nonlinear,
16-half-hour-accumulated π rather than with any construction path. Adjudicated ≈ 0.

### (3) Reflection checks: bounded and idle

- **Day-ahead π** (rival availability from the bid version in force at 00:00 of the target
  trading day — timing breaks same-day reflection): correlation with π2 = **0.937**. Carried
  into Stage 4 as the timing-immunized robustness dose.
- **Lagged-absence regression** (rival daily declared availability on lagged focal
  availability, own lag + month effects, 1,095 days): b = −0.0025, se 0.047, **p = 0.96**.
  Rivals' availability does not respond to focal absence; the reflection channel is empirically
  idle.

**Amended-gate verdict: PASS. Stage 4 is licensed on π2 (primary) with π_da (timing-immunized)
and the thresholded-π variant as registered robustness.**
