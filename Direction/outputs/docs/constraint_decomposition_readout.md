# Directions constraint decomposition — readout

Implements `directions_constraint_decomposition_brief.md`. Script:
`04_market_power/constraint_decomposition.R`. Lookups (editable, all placeholder):
`04_market_power/lookups/`. Outputs: `outputs/descriptives_v3/constraint_decomposition_*`.

## Why: treatment misclassification

The pivotality moderator in the DDD is built from the fault-level combinations file
only. Directions that fire for inertia / voltage / locational / buffer reasons are
intervals where the `d_t` direction option is live but the fault-level pivotal
indicator reads zero — false negatives that attenuate the DDD. This decomposition
widens the security-binding indicator to a **union** of binding constraints and
reports, per directed 5-min interval × DUID, which one(s) bound.

## Key data finding — the AEMO `reason` field is unusable as a per-direction cause

The brief floated using AEMO's stated direction reason for the voltage flag. **We do
not.** The `reason` cell is report-template boilerplate, constant within each report,
that steps purely by report vintage:

| Label | Period | Driver |
|---|---|---|
| `System strength` | 2021-01 → 2021-10 | old report template |
| `System security` | 2021-11 → 2024-06 | template wording |
| `System security - voltage` | **2024-07** → 2025-01 | template wording |

Verified at the raw `.xlsx` level: the Jun-2024 report tags all 11 directions
"System security"; the Jul-2024 report tags all 19 "System security - voltage". The
new report template began Oct-2023 yet kept "System security" for nine more months,
so this is not the old/new format split — it is a later wording change. The directed
units are identical across the boundary (TORRB dominates both sides; no
voltage-specific units appear). Using `reason` as the voltage flag would inject a
pure time artifact perfectly collinear with the back half of the `d_t` window.

Real-world context (AEMO 2023/2024 NSCAS + Inertia Reports): SA *does* have a
declared voltage-control gap **under low demand**, SA directions are largely
voltage-driven, and AEMO found **no** system-strength or inertia shortfall in 2024.
So the voltage story is real at the *regime* level — but the `reason` column cannot
resolve it per direction. Hence the low-demand physical proxy below.

## Flags

The fault-level flag is the **secure (N-1)** standard, because that is the standard
AEMO operates to — not the bare satisfactory (N-0) minimum.

| Flag | Basis | Status |
|---|---|---|
| `fl_n0` | fault-level **satisfactory**: removing the directed unit breaks the SA minimum combination *now* (`piv_*`) | from `pivotality_panel.rds` |
| `fl_n1` | fault-level **secure**: unit needed after loss of the largest online unit (`piv_n1_*`; ⊇ `fl_n0`) | from `pivotality_panel.rds` |
| `inertia_binding` | online ΣH·MVA (incl. 4 syncons) − directed unit's contribution < period SA islanded-secure threshold | **PROXY, placeholder lookups** |
| `voltage_lowdemand` | low-demand / high-renewable voltage condition ≈ high SA non-sync penetration (`nonsync_mw ≥ threshold`) | **PROXY, editable threshold** |
| `network_outage` | transmission outage / locational | **STUB = NA — no data extracted**; excluded from union |

`security_binding_union = fl_n1 | inertia_binding | voltage_lowdemand`;
`residual = directed AND none bind`.

## Why generators are directed when they don't bind the N-0 minimum

The single biggest reason is the **security standard**. `fl_n0` tests *satisfactory*
(does removing the unit break a minimum acceptable combination now); AEMO operates to
*secure* — the system must survive loss of the largest online unit (N-1). **46.7% of
all in-sample intervals are not N-1-secure** yet pass the N-0 minimum. Mutually-exclusive
mechanism split of the **full directed mass** (240,516 interval-DUIDs):

| Mechanism | Share | Unit-hours | % "Remain" |
|---|---:|---:|---:|
| `n0_satisfactory` — breaks the present-state minimum | 60.3% | 12,076 | 48 |
| `n1_unit_incumbency` — unit pivotal under the credible contingency | 14.1% | 2,831 | 51 |
| `n1_collective_restore` — system not N-1 secure, directed to restore it | 9.1% | 1,825 | 26 |
| `voltage_lowdemand` (proxy, only binder) | 0.9% | 182 | 49 |
| **`residual`** — above every observable strength standard | **15.6%** | **3,128** | 42 |

- Moving the fault-level flag from satisfactory to **secure (N-1) lifts the explained
  share 60.3% → 83.5%**, absorbing ~58% of the former "non-pivotal" gap.
- **Inertia binds ~0%** — 4 syncons (placeholder 6000 MW·s) meet the floor without a
  directed generator; corroborates AEMO's no-inertia-shortfall finding (placeholder-driven).
- **Residual = 15.6% (~3,128 unit-hours).** Neither N-0 nor N-1 strength binds. It is
  concentrated in **TORRB (23,867) and MINTARO (10,225)** — electrically central units —
  and 42% of it is "Remain". This is the genuine *locational system strength / reactive
  (voltage) / pre-positioning* bucket that a system-wide headcount cannot capture, and
  the upper bound on what a transmission-outage flag could still attribute.

**TORRB:** N-0 64.9%, N-1 secure 86.4%, union 87.2%, **residual 12.8%** (pre `d_t` drop
12.4%, post 13.1%).

## Design implication

Build the DDD pivotal moderator on the **secure (N-1) envelope** (`fl_n1` / `piv_n1`),
not the satisfactory N-0 `piv`. This reclassifies ~58% of the current false-negatives,
materially de-attenuating the dose-response, and the 15.6% residual delimits the subset
of directions the `d_t` identification cannot cleanly speak to.

## Open questions — fill before citing any prevalence

1. **Inertia constants** (`sa_inertia_unit_constants.csv`): per-DUID MVA + H — confirm
   vs AEMO registration / syncon ratings. The syncon inertia drives the ~0% inertia
   result.
2. **Inertia thresholds** (`sa_inertia_thresholds.csv`): per-year SA islanded-secure
   inertia level — confirm vs AEMO 2022/2023/2024 Inertia Reports (rose over sample).
3. **Voltage threshold** (`voltage_lowdemand_proxy.csv`): calibrate the non-sync MW
   cut against SA minimum-operational-demand records; ideally refine with
   `DISPATCHREGIONSUM.TOTALDEMAND` (not yet extracted).
4. **Outage flag**: no transmission-outage records exist in the repo. Extracting
   planned + forced SA transmission outages would let `network_outage` attribute part
   of the 36.6% residual.
