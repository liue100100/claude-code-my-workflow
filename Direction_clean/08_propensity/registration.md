# Registration — Direction propensity: rivals-only two-layer trigger model + conduct test

**Committed as received from the author, 2026-07-07, before any Stage-0 code.** Verbatim task
text below; execution notes at the end. Findings paths map to
`Direction_clean/outputs/08_propensity/`.

---

Task: Direction propensity — a rivals-only, two-layer model of the direction trigger, and the
conduct test rebuilt on it

Motivation. Directed time exceeds pex-essential time by an order of magnitude (375,264 directed
unit-intervals vs ~1.3% essentiality). The realized N−0 flag understates the desk's ex-ante
exposure to the direction channel. This task (1) decomposes the gap, (2) builds a continuous,
rivals-only direction propensity matching the operator's information set, and (3) re-runs the
payment-sensitivity test on it. Each stage writes a findings file and stops before
interpretation drifts into the next.

Hard constraint, all stages. No input may embed the focal station's own availability, bids,
directed status, or the SA spot price (bad control; downstream of focal conduct). The propensity
means: probability the system will need a Torrens unit, given rivals and system state. The
propensity must be a transparent function of public information — part of the argument is that
a desk could compute it.

Stage 0 — Data gate. Confirm: (a) PREDISPATCH regional demand and non-synchronous forecast
coverage (horizons, months); (b) transfer-limit-advice minimum-combination tables with vintages
— list each version in force during 2022–2024 with effective dates (syncon commissioning and
any later revisions change the tables); (c) direction issue times net of extension chaining —
count independent onsets: a new direction with no direction active or pending in the prior N
hours, sensitivity N ∈ {4, 8, 24} (if the parsed record already distinguishes re-issues
cleanly, use that and report both counts). Stop conditions: independent onsets < 150, or
PREDISPATCH coverage < 24 months, or onsets/15 < the planned parameter count → write
findings/stage0_gate.md and halt; fallback is Layer 1 only.

Stage 1 — Requirement state (deterministic, no regression). From vintage-correct combination
tables and rivals-only inputs — declared availability, physical commitment state (a combination
needing an offline steam rival is infeasible within lead time), and the tables' own conditioning
variables (demand bands, Heywood flow/limit state, synchronous condensers in service, declared
rival outages) — compute per 30-min interval: (i) requirement met by rivals alone; (ii) focal
units needed; (iii) slack: minimum credible rival departures separating the system from needing
a focal unit. Also compute forecast slack at pre-dispatch horizons (1h, 4h, 8h) by pushing
rivals' pre-dispatch availability and forecast conditions through the same tables. Validation,
committed now: slack = 0 reproduces pex to close tolerance (confusion matrix; investigate any
cell > 5% disagreement, do not smooth over it); slack ≤ 1 approximates the Appendix C N−1 day
flag. Output findings/stage1_requirement_state.md.

Stage 2 — Operator response: discrete-time hazard (logit on onsets).
- Risk set: 30-min intervals with no direction active or pending. Excluded intervals feed the
  decomposition, not the trigger model.
- Outcome: independent direction onset in the interval.
- Specification, ~10 parameters, fixed in advance: minimum forecast slack over the commitment
  lead window (expected workhorse); current slack; forecast demand trough depth; forecast
  non-synchronous share; time-since-last-direction (log or 2-knot spline); 3–4 hour-of-day
  blocks. Outages, interconnector limits, syncon status enter only upstream through Layer 1's
  slack — no separate coefficients. No additional regressors without amending this
  registration; L1 with month-out CV only as a registered fallback if the fixed spec fails
  diagnostics.
- Outputs: (i) fit and calibration (month-out cross-validated, not in-sample); (ii) lead-time
  distribution (issue to first slack = 0); (iii) five-bucket decomposition of all directed time
  — core need (slack = 0), forecast buffer (issue-to-need), persistence (post-need trailing
  time), extension chaining (re-issues without fresh requirement events), unexplained residual
  (episodes with no requirement failure anywhere in window). Committed readings: the residual
  bucket is the model's diagnostic — small validates the two-layer trigger, large means the
  requirement layer is mis-specified and Stage 4 does not run until diagnosed. A dominant
  persistence + buffer share is itself a finding (compensated time no one needs) and is
  reported to feed §9 regardless of Stage 4.
- Propensity: π(t) = 1 − Π(1 − hazard) accumulated over horizon h (primary h = 8h; report 4h
  and 24h). Decompose into π_slow (30-day moving component: seasonal renewables, outage
  calendar, table vintages) and π_fast (residual daily innovations).
- findings/stage2_operator_model.md.

Stage 3 — Propensity audits. (i) Leakage: regress π on the focal station's own availability and
cheap share; stop condition R² > 0.01. (ii) Nesting: mean π by tier — should be near maximum
where pex = 1, elevated where N−1 = 1, low elsewhere. (iii) Report the slow/fast variance
split. findings/stage3_propensity_audits.md.

Stage 4 — Conduct test, pre-registered. Outcome: floor-within-reach. Replace pex with π in the
matched design; objects: π × d_t, then π_slow × d_t and π_fast × d_t. Committed
interpretations:
- π × d_t < 0: conduct scales with the ex-ante prize; repairs the §5.2 attenuation caveat.
- π_slow × d_t < 0, π_fast × d_t ≈ 0: the standing-posture account sharpened — the policy tilts
  toward the payment environment at the operating calendar and does not chase daily forecasts.
  Preferred shape, stated now so a matching result cannot be called post-hoc.
- π_fast × d_t < 0: daily responsiveness; contradicts §7 and is reported as tension, not
  absorbed.
- Null throughout: the pex-based headline does not generalize off the realized-state flag;
  reported as a limitation of the headline.
Robustness: original pex specification must reproduce Table 4; π thresholded at pex-matched
incidence. Inference: month-clustered wild bootstrap + randomization inference permuting
month-to-d_t, as in the existing pipeline. findings/stage4_conduct.md, plus one-page
findings/propensity_summary.md in plain declarative prose: what triggers directions (bucket
shares), how predictable the trigger is from public information, what conduct loads on and does
not.

---

## AMENDMENT 1 (2026-07-07, author-directed, recorded BEFORE any Stage-4 estimation code)

**What is amended:** the Stage-3 leakage gate ("regress π on the focal station's own
availability and cheap share; stop condition R² > 0.01").

**Why:** the gate fired on the conditions-only π2 (R² = 0.130) with the loading on the focal
cheap share at a large negative coefficient. The gate as written tests *outcome correlation*,
not *construction provenance*: under the project's own hypothesis any π capable of producing a
non-null Stage 4 must correlate with focal conduct, so the gate cannot pass for any valid dose.
The firing coefficient is the hypothesized conduct relationship and is not evidence of
contamination.

**Replacement (author's wording, adopted):**
1. **Provenance audit** — the leakage check is on the inputs: an input manifest recording every
   variable entering π2, its source table, and the assertion that no focal DUID appears
   upstream. Recorded in the Stage-3 findings.
2. **Amended regression tripwire** — regress π2 on the focal cheap share *controlling for* the
   Layer-1 slack variables and the hazard covariates; the **incremental R² of the focal terms
   must be ≈ 0**. Focal conduct may explain π only through the conditions that legitimately
   drive it.
3. **Reflection checks** (rivals responding to focal posture — behavioral feedback, not
   construction leakage; bounded, not gated): (a) rebuild π with rivals' **day-ahead** declared
   availability only (bid version in force at 00:00 of the target trading day, the project's
   day-ahead-stance convention), breaking same-day reflection by timing; report its agreement
   with π2 and its tripwire result; (b) test whether rivals' declared availability responds to
   **lagged focal absence** (daily grain, rival availability on lagged focal availability with
   own lag and month effects); an idle channel is dispatched with the estimate.

Stage 4 runs only if the tripwire is ≈ 0 and the reflection checks are reported. All other
registration content unchanged; the Stage-2 hazard's `log_tsl` and direction-record zeroing
remain excluded from the *dose* per the hard constraint (see Stage-3 findings — that exclusion
is constraint enforcement, not part of this amendment).

## Execution notes (added at registration save; not amendments)

- Findings files: `Direction_clean/outputs/08_propensity/{stage0_gate,stage1_requirement_state,
  stage2_operator_model,stage3_propensity_audits,stage4_conduct,propensity_summary}.md`.
- Combination machinery seed: `Direction/sa_minimum_generator_combinations.csv` (122 rows,
  regimes system_normal / risk_island_or_island, syn_cons column) + the Task-13 feasibility
  functions (`task13_roster_requirement.R`), which already compute per-5-min minimum Torrens
  requirement from rivals' declared availability. Stage 1 extends to 30-min grain, commitment
  awareness, slack in rival-departure units, and vintage correctness.
- Known at save time: no PREDISPATCH tables exist in the pipeline cache (gate item (a) at risk);
  the combination CSV is single-vintage with no effective dates (gate item (b) needs provenance
  + vintage research).
