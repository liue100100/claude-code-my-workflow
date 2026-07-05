# Brief: Decompose SA AEMO directions by binding security constraint

## Problem

Directions in South Australia fire more often than the fault-level minimum
synchronous combination requires. We observe directed intervals where
`sa_minimum_generator_combinations.csv` (a *system-strength / fault-level*
constraint) is already satisfied, yet a unit — notably TORRB1–4 — is still
directed.

This is not noise. That file encodes only one of several distinct security
services AEMO directs against. The others can bind independently:

1. **Inertia** — a separate, additive constraint, computed assuming SA *islands*
   (loss of Heywood/PEC). Can require an extra synchronous unit even when the
   fault-level minimum is met. The islanded-secure inertia *level* moved upward
   over 2023–24, so it is time-varying.
2. **Voltage control / reactive support (NSCAS)** — locational, unrelated to the
   fault-level count. A voltage-control gap was declared in AEMO's 2023 NSCAS
   Report.
3. **Locational system strength** — the requirement is nodal (per fault-level
   node), not a system-wide headcount. A given count can satisfy the system-wide
   minimum while a *specific* unit is needed at a node, especially under a
   transmission outage.
4. **Secure-vs-satisfactory buffer** — AEMO holds the system *secure* (survives a
   credible contingency), above *satisfactory* (within limits now). Directing to
   the secure level looks like "more than the minimum" by construction. Note also
   a standing "≥2 synchronous units" planning assumption for SA in the earlier
   sample period, eased toward single-unit operation only from Sep 2025.

## Why it matters for the research design

The pivotality moderator in the triple-difference is built from the fault-level
file only. Directions driven by inertia/voltage/locational/buffer reasons are
intervals where the d_t direction option (which drives TORRB's withholding
incentive) is live, but the pivotal indicator reads zero. That is **treatment
misclassification**, not measurement error — false negatives in the "pivotal"
leg that attenuate the DDD toward null and weaken the dose-response.

Fix: widen the security-binding indicator from fault-level pivotality to a
**union** of binding constraints, and produce a decomposition of *which*
constraint bound in each directed interval. The decomposition is itself a
publishable diagnostic and delimits the exact subset of directions the d_t
identification applies to.

## Tasks for Claude Code

Work in R, consistent with the existing extraction pipeline (5-min NEM data,
`BIDOFFERPERIOD_*.rds`, 65 SA DUIDs). Build incrementally; validate each piece
on a single month before scaling.

### 1. Assemble the directed-interval panel
- Identify all SA direction intervals in-sample from the dispatch/intervention
  records (AEMO DISPATCH intervention flag + directions records). One row per
  5-min interval per directed DUID.
- Join the realised online synchronous fleet per interval.

### 2. Fault-level constraint flag
- For each interval, evaluate whether the online synchronous set satisfies
  `sa_minimum_generator_combinations.csv` *without* the directed unit.
- `fl_binding = TRUE` if removing the directed unit would break the minimum
  combination; else `FALSE`.

### 3. Inertia constraint flag (proxy)
- Compute online synchronous inertia per interval: `sum(H_i * MVA_i)` over online
  synchronous units, with H constants tabled per DUID (source from registration /
  standard values; expose as an editable lookup, do not hardcode inline).
- Compare to the **period-appropriate** SA islanded-secure inertia level. Pull
  the threshold per year from the relevant AEMO Inertia Report (2022/2023/2024) —
  store as a small date-keyed lookup table, NOT a single constant, because the
  threshold rose over the sample and the pre/post d_t window is the
  identification window.
- `inertia_binding = TRUE` if online inertia minus the directed unit's
  contribution would fall below the period threshold.

### 4. Voltage / NSCAS flag
- Date-stamp intervals falling inside declared voltage-control NSCAS gap windows
  (2023 NSCAS Report onward). Coarse but sufficient: `voltage_window = TRUE/FALSE`.

### 5. Outage / locational flag
- Join planned + forced transmission outage records. `network_outage = TRUE` if a
  relevant SA transmission element was out during the interval.

### 6. Classification + residual
- Classify each directed interval by the binding set (a unit may hit several).
- Define `security_binding_union = fl_binding | inertia_binding | voltage_window
  | network_outage`.
- Residual bucket: directed AND none of the above — flag for manual inspection
  (likely locational sub-cases or conservative pre-dispatch buffer).

### 7. Outputs
- A tidy panel: interval, DUID, each flag, the union, the binding-set label.
- A summary table: share of TORRB directions by binding reason (fault-level /
  inertia / voltage / outage / residual), overall and split pre/post the
  mid-2023 d_t drop.
- Save intermediate `.rds` and a `.csv` summary to the outputs dir.

## Constraints / style
- Slope-not-level: the deliverable is the *classification*, not a welfare or cost
  level.
- Do not overclaim the proxies. The inertia flag is a proxy (H constants + a
  period threshold); the voltage flag is a coarse date window. Label them as such
  in comments and in the summary, and keep thresholds/constants in editable
  lookups so assumptions are auditable.
- Validate on one month, print row counts and flag prevalences, then scale.

## Open question to resolve before scaling
Inertia H constants and the exact per-year SA islanded-secure inertia thresholds
need to be confirmed against source documents. Stub the lookup tables with
clearly-marked placeholder values and flag them for me to fill, rather than
guessing.
