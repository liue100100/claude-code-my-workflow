# SRMC methodology and results — SA treated units

**Stage:** `02_cost` · **Producer:** `gate_a_srmc.R` · **Inputs doc:** `../../srmc_inputs_heatrate_vom.md`
**Outputs:** `outputs/descriptives_v3/GateA_srmc_params.csv`, `GateA_srmc_margin_summary.csv`, `GateA_srmc.png`
**Facts:** `facts_memo.md` [F3][F4] · **Sample:** 12 DUIDs × 36 months (202201–202412)

This document explains how we estimate short-run marginal cost (SRMC) for the South Australian
synchronous units in the direction study, records the parameter sources, and reports the estimated
levels and the resulting `d_t − SRMC` margins. SRMC is the cost floor the withholding test runs
against: capacity priced above SRMC is the numerator of `withheld_share`, and `d_t − SRMC` is the
rent that being directed on captures.

---

## 1. Definition and the two measures

Marginal cost of energy for a gas or dual-fuel unit is fuel cost plus variable O&M:

```
SRMC ($/MWh) = heat_rate (GJ/MWh) × fuel_price ($/GJ) + VOM ($/MWh)
```

Fixed O&M (FOM, $/MW/yr) does **not** enter SRMC — it is sunk against the marginal running
decision and is irrelevant to the offer floor that defines withholding.[^fom]

The AEMO heat-rate data encode a two-part fuel curve, `fuel (GJ/h) = no_load_base + incremental × MW`.
This yields two heat rates and therefore two SRMC measures, each answering a different question:

| Measure | Heat rate used | Question it answers |
|---|---|---|
| `srmc_marginal` | **incremental** (marginal GJ/MWh above min stable gen) | Cost of one more MWh while already running — the **offer-stack / above-cost withholding test**. No-load base is sunk once on, so it drops out. |
| `srmc_allin` | **static** (average GJ/MWh at capacity) | All-in cost per MWh — whether being on at all (the Synchronise on/off decision) is in the money. |

`srmc_marginal` is the primary measure for Gate A and for the `withheld_share` threshold. Both are
built and carried per unit-month.

[^fom]: FOM is carried in the inputs table for completeness and for any later entry/exit
profitability assessment, but never in the SRMC formula.

---

## 2. Data inputs

**Heat rates — AEMO heat-rate workbook**, as-generated, higher-heating-value (HHV) basis, applied
at station level (TORRB1–4 share Torrens Island B; DRYCGT1–3 share Dry Creek). One incremental and
one static rate per station.

**Variable O&M — Aurecon 2024, *Energy Technology Cost and Technical Parameter Review***, assigned
by technology class: CCGT $4.1/MWh; OCGT large-frame $8.1/MWh; reciprocating $8.51/MWh. These are
new-entrant representative costs; the SA units are old, so published VOM is treated as a **floor**.
VOM is small relative to fuel, so it barely moves the SRMC level — the heat rate and gas price
dominate.

**Gas price — AER STTM Quarterly Prices, Adelaide ex-ante** (`Quarterly_STTM_Price.CSV`). Ex-ante
$/GJ on an HHV basis, consistent with the as-generated HHV heat rates. Reported by quarter; each
month in a quarter receives that quarter's average as a step function.[^gas] Over the sample the
Adelaide gas price runs **$10.2–29.9/GJ (mean $15.6)** — the 2022 spike (mean $21.5/GJ, Russia–
Ukraine) unwinds to ~$12.5/GJ in 2023 and ~$13.0/GJ in 2024. This is the sole driver of within-unit
SRMC variation.

**Diesel — AIP wholesale proxy** (~$1.55–1.95/L → ~$41–51/GJ at 38 GJ/kL LHV) for the dual-fuel
units, entered as `min(gas, diesel)`. In the estimated sample diesel is **never cheaper than gas**,
so the distillate option never binds and does not affect any reported number.[^diesel]

[^gas]: Within-quarter intra-month variation is lost; adequate for a monthly SRMC panel.
[^diesel]: Kept in the build so the switch is auditable and so a future gas-spike scenario would
route dual-fuel units onto distillate automatically.

---

## 3. Conventions (get these right or the level is wrong)

- **HHV throughout.** As-generated HHV heat rates paired with HHV $/GJ gas. Do not mix in an LHV
  efficiency (~10% higher for gas) or a sent-out heat rate.
- **Auxiliary load ignored.** As-generated understates $/MWh-sent-out by each unit's auxiliary
  fraction (~2–5%); treated as a second-order adjustment, not applied.
- **Station-level heat rates, technology-class VOM** — no unit-specific engineering below the
  station level.

---

## 4. Unit-specific adjustments

Three departures from a naive "incremental heat rate × gas + class VOM" build, each flagged in the
code and the inputs doc:

1. **PPCCGT and OSB-AG anomaly.** The AEMO sheet lists incremental > static for the CCGT and cogen
   (8.45 > 7.35; 9.92 > 8.16), which is physically backwards. AEMO calibrates the static and
   variable representations separately, so they don't reconcile. The **static** value is the
   thermodynamically correct one (Pelican Point 7.35 GJ/MWh ≈ 49% HHV, right for a CCGT), so for
   these two units the static heat rate is used for **both** SRMC measures.
2. **BARKIPS1 heat-rate gap.** Barker Inlet (2019, Wärtsilä 50DF reciprocating) is absent from the
   AEMO sheet. Proxied at the reciprocating-engine class rate **~7.9 GJ/MWh** (full-load gas).
   Flagged `source = proxy`.
3. **Torrens B VOM gap.** No Aurecon class exists for old gas-steam. Proxied at **$2.5/MWh** (mid of
   the $1–4 range). Flagged `source = proxy`. Low sensitivity, but earmarked for the revealed-cost
   anchor (§7 below).

Dual-fuel capability (`min(gas, diesel)` applied): BARKIPS1 (designed dual-fuel), DRYCGT1–3 and QPS5
(originally dual-fuel). All others gas-only.

---

## 5. Estimated results — SRMC levels

Per-unit SRMC, mean and range across the 36-month sample (`srmc_marginal`, sorted low to high):

| DUID | Technology | Incr. HR | VOM | SRMC mean | SRMC range | All-in mean |
|---|---|---:|---:|---:|---:|---:|
| PPCCGT | CCGT (Pelican Pt) | 7.35 | 4.1 | **$119** | 79–223 | 119 |
| OSB-AG | Cogen (Osborne) | 8.16 | 4.1 | **$132** | 87–248 | 132 |
| BARKIPS1 | Recip. (Barker Inlet) | 7.90 | 8.51 | **$132** | 89–244 | 132 |
| QPS5 | OCGT (Quarantine) | 8.00 | 8.1 | **$133** | 89–247 | 175 |
| TORRB1–4 | Gas-steam (Torrens B) | 9.94 | 2.5 | **$158** | 104–299 | 170 |
| MINTARO | OCGT (Mintaro) | 10.00 | 12.0 | **$168** | 114–310 | 211 |
| DRYCGT1–3 | OCGT (Dry Creek) | 10.97 | 8.1 | **$180** | 120–336 | 222 |

Levels are gas-price driven and peak in 2022. The 202201 anchor used in `facts_memo.md` [F3]:
TORRB ~$104, PPCCGT ~$79, OSB-AG ~$87, MINTARO ~$114, BARKIPS1 ~$89, DRYCGT ~$120, QPS5 ~$89.
`srmc_allin` exceeds `srmc_marginal` for the OCGTs (large no-load base) and equals it for
PPCCGT/OSB-AG (static used for both) and — by construction of the proxy — for BARKIPS1.

The ordering is intuitive: the efficient CCGT/cogen sit lowest, the old high-heat-rate peakers
(Dry Creek, Mintaro) highest, Torrens B in between.

---

## 6. What the results establish (the two facts)

**[F3] No cost-side break at the `d_t` exit.** SRMC glides smoothly with the gas price and shows no
structural break at July 2023, the month the directed price `d_t` falls. The variation being
studied is in the **prize, not the cost** — ruling out the concern that the `d_t` drop coincides
with a marginal-cost shock. (`GateA_srmc.png` overlays SRMC and `d_t` per unit; the dotted line marks
the exit.)

**[F4] `d_t` exceeds SRMC in 33–34 of 35 months for every unit.** From
`GateA_srmc_margin_summary.csv`, mean `d_t − srmc_marginal`:

| DUID | Pre-exit margin | Post-exit margin | Months `d_t > SRMC` |
|---|---:|---:|---:|
| PPCCGT | $147.9 | $108.6 | 34/35 |
| BARKIPS1 | $133.4 | $97.4 | 34/35 |
| OSB-AG | $133.0 | $98.6 | 34/35 |
| QPS5 | $132.0 | $96.6 | 34/35 |
| TORRB1–4 | $102.1 | $78.3 | 33/35 |
| MINTARO | $91.5 | $68.1 | 33/35 |
| DRYCGT1–3 | $77.6 | $60.0 | 33/35 |

Being directed on is a rent for the entire sample, and the rent never vanishes — even post-exit the
directed price clears marginal cost for every unit.

---

## 7. The revealed-cost anchor — tested and rejected

The estimate is an **engineering cost stack** — station-level published heat rates and class-level
VOM, not unit-specific estimates. Two proxies (BARKIPS1 heat rate, Torrens B VOM) are flagged. The
inputs doc (§7) proposed a **revealed-cost anchor** as the preferred unit-specific refinement:
regress each unit's low (cost-reflective) offer band on the contemporaneous gas price over
**competitive intervals only** (undirected, non-pivotal, system not short); the slope should recover
an implied incremental heat rate and the intercept an implied VOM, on the unit's own scale, filling
both proxy gaps. To avoid circularity it is estimated on the competitive subsample only, never on the
periods tested for withholding.

**This has now been run (`gate_a_revealed_cost.R`), and it fails.** The identifying assumption — that
the low offer band tracks gas-indexed marginal cost — does not hold in this market. [F3a]

The offer stacks reveal why. Every treated unit posts a near-static price ladder with a
guaranteed-dispatch floor tranche (PB1 ≈ −$1000, PB2 = $0), a low "cost-reflective" band around
$100 (PB3), and withholding bands above. The test was run on **two margins**, both restricted to
competitive intervals so the result is not a circularity artefact.

**Margin 1 — the offer price** (`gate_a_revealed_cost.R`). Regress the low band on gas; the units
rebid quantities not the low price band, so the low band does not move with gas:

| | Value |
|---|---|
| Competitive unit-days (comp_share ≥ 0.80) | 9,295 |
| Pooled within-unit slope (implied heat rate) | **0.22 GJ/MWh** (t 3.6), within-R² **0.003** |
| Engineering heat rates, for comparison | 7.4–11.0 GJ/MWh |
| Per-unit implied heat rates | near-zero, wrong-signed (PPCCGT −1.61, R² 0.36; MINTARO/Dry Creek ≈ −0.6), or implausible (QPS5 3.61) |
| Per-unit implied "VOM" intercepts | $52–143 (true VOM $2–16) |

**Margin 2 — the quantity** (`gate_a_revealed_cost_qty.R`). Because conduct runs on the quantity
lever, the sharper test is whether the capacity offered at low / cost-relevant prices responds to
gas. It does not (competitive unit-months, n=432):

| | Value |
|---|---|
| Price to clear the low tranche (`p_at_25`) on gas | pooled slope **−110.7** (t −5.8) — *wrong-signed*: the low tranche gets **cheaper** as gas rises |
| Share of offered capacity ≤ $150 on gas | pooled slope **−0.0002** (t −0.23), within-R² **0.0002** — dead flat |
| e.g. Torrens B share ≤ $150 | ~26% whether gas is $10 or $30/GJ (SRMC $110 vs $300) — cost bidding requires this to collapse as gas rises |

The low band sits at a near-gas-invariant ~$100, and the quantity parked below cost-relevant
thresholds is likewise gas-invariant. In 2022, with gas at ~$21/GJ (engineering SRMC ~$300 for the
OCGTs), the low band still sat at ~$110 — **below** SRMC — and Torrens B still offered ~26% below
$150. Units run a fixed base tranche at fixed low ladder prices and dump the rest near the market
price cap, invariant to fuel cost. Offers therefore do not reveal a gas-indexed heat rate on either
margin, even conditioning on competitive intervals.

**Consequences.** (i) The engineering SRMC of §1–§6 is the maintained cost measure; there is no
credible revealed-cost estimate to override it. (ii) The two proxy gaps (BARKIPS1 heat rate, Torrens
B VOM) cannot be filled this way and stay flagged. (iii) The negative result is itself substantive:
that the low band is not cost-reflective — even on competitive intervals — reinforces the paper's
conduct story (withholding runs on quantity rebids and high bands, [F16]), and can serve as a
robustness point rather than a gap. A parallel `withheld_share_allin` robustness (static-heat-rate
threshold) remains on the v3 list.

*Outputs: `outputs/descriptives_v3/GateA_revealed_cost{,_qty}.csv` and `.png`. Regenerate with
`Rscript 02_cost/gate_a_revealed_cost.R` (price margin) and `gate_a_revealed_cost_qty.R` (quantity
margin) from the `Direction/` root.*

---

*Traceability: every number above traces to `outputs/descriptives_v3/GateA_srmc_params.csv` (levels,
432 unit-months) and `GateA_srmc_margin_summary.csv` (margins). Regenerate with
`Rscript 02_cost/gate_a_srmc.R` from the `Direction/` root.*
