# SRMC inputs — heat rates & O&M for the SA treated units

> Companion to `sa_directions_research_context.md`. This is the parameter set for Gate A
> (per-unit SRMC). It records the heat-rate and O&M numbers, their conventions, the two data
> gaps, and how to wire them into `SRMC_{i,t}`. Heat rates are sourced from an AEMO heat-rate
> workbook; O&M from the Aurecon 2024 *Energy Technology Cost and Parameters Review*. Both are
> provided as uploads. Treat the numbers below as the current assumption set — the revealed-cost
> regression (see §6) is the preferred unit-specific anchor and should override these where it
> disagrees.

---

## 1. Parameter table (per DUID)

| DUID | Plant | Tech | Incremental HR (GJ/MWh) | Static HR (GJ/MWh) | No-load base (GJ/h) | VOM ($/MWh) | FOM ($/MW/yr) |
|---|---|---|---|---|---|---|---|
| TORRB1 | Torrens Island B u1 | Gas-steam | 9.94 | 10.71 | 154.13 | gap (see §5) | — |
| TORRB2 | Torrens Island B u2 | Gas-steam | 9.94 | 10.71 | 154.13 | gap | — |
| TORRB3 | Torrens Island B u3 | Gas-steam | 9.94 | 10.71 | 154.13 | gap | — |
| TORRB4 | Torrens Island B u4 | Gas-steam | 9.94 | 10.71 | 154.13 | gap | — |
| PPCCGT | Pelican Point | CCGT | 8.45 | 7.35 | 436.33 | 4.1 | 15,028 |
| OSB-AG | Osborne | Cogen | 9.92 | 8.16 | 299.02 | ~4.1 (CCGT proxy) | ~15,000 |
| MINTARO | Mintaro | OCGT | 10.00 | 12.72 | 244.78 | 8.1–16.1 | 14,066–17,368 |
| DRYCGT1 | Dry Creek u1 | OCGT | 10.97 | 13.69 | 141.43 | 8.1–16.1 | 14,066–17,368 |
| DRYCGT2 | Dry Creek u2 | OCGT | 10.97 | 13.69 | 141.43 | 8.1–16.1 | 14,066–17,368 |
| DRYCGT3 | Dry Creek u3 | OCGT | 10.97 | 13.69 | 141.43 | 8.1–16.1 | 14,066–17,368 |
| QPS5 | Quarantine u5 | OCGT | 8.00 | 10.71 | 78.87 | 8.1–16.1 | 14,066–17,368 |
| BARKIPS1 | Barker Inlet | Reciprocating | gap (~7.9–8.8) | — | — | 8.51 | 29,383 |

Heat rates: one station-level row applied to all units at that station (TORRB1–4 share Torrens
Island B; DRYCGT1–3 share Dry Creek). VOM/FOM: assigned by technology class (see §4).

---

## 2. Conventions (get these right or the SRMC level is wrong)

- Heat rates are **as-generated, HHV**. Pair them with an **HHV $/GJ** gas price (STTM Adelaide
  ex-ante is HHV $/GJ — consistent). Do NOT mix in an LHV efficiency (~10% higher for gas) or a
  sent-out heat rate. As-generated understates $/MWh-**sent-out** by each unit's auxiliary
  fraction (~2–5%); ignore for now, note as a second-order adjustment.
- Unit chain: `SRMC ($/MWh) = heat_rate (GJ/MWh) × gas_price ($/GJ) + VOM ($/MWh)`.
- **FOM does NOT enter SRMC.** FOM is a fixed annual cost ($/MW/yr); it's irrelevant to the
  marginal/running cost that defines withholding. Use FOM only if/when assessing longer-run
  entry/exit profitability. The table carries it for completeness, not for the SRMC formula.

---

## 3. Which heat rate for which question

The AEMO sheet encodes a two-part fuel curve: `fuel (GJ/h) = base + incremental × MW`.

- **Marginal cost of one more MWh while the unit is already running** → use **incremental**:
  `SRMC_marginal = incremental_HR × gas + VOM`. The no-load `base` is sunk once the unit is on,
  so it does not enter. **This is the one for the offer-stack / above-cost withholding test**
  (is the marginal offer band priced above marginal cost?).
- **All-in cost per MWh / whether to be on at all (the Synchronise & on/off decision)** → use
  **static** (average) heat rate, and account for the `base` no-load burn over the hours online.
  Relevant to whether being directed-on is in the money.

Build and carry both `srmc_marginal_{i,t}` and `srmc_allin_{i,t}`.

---

## 4. O&M provenance and the caveat that matters

VOM/FOM are from Aurecon 2024, by technology class:
- CCGT (no CCS): VOM $4.1/MWh, FOM $15,028/MW/yr.
- OCGT: VOM $8.1/MWh (large frame) to $16.1/MWh (small frame); FOM $14,066–17,368/MW/yr. The SA
  OCGTs are older E-class frames — use the middle of the range or pin from revealed cost.
- Reciprocating engine: VOM $8.51/MWh, FOM $29,383/MW/yr.
- Cogen (Osborne): no dedicated class; CCGT proxy.

**These are new-entrant representative costs.** The SA units are old (Torrens B 1970s; Dry
Creek/Mintaro/Quarantine vintage peakers), and old plant carries higher maintenance cost, so
treat published VOM as a **floor**. VOM is small relative to fuel, so it barely moves the SRMC
level — do not over-invest in precision here; the heat rate and gas price dominate.

---

## 5. Two data gaps to fill (do not fabricate)

- **Barker Inlet (BARKIPS1)** is absent from the AEMO heat-rate sheet (it's a 2019 plant; the
  sheet's vintage still lists Torrens Island A and Liddell, i.e. early-2020s — which is fine for
  the 2021–2024 sample, it just predates BARKIPS1). Use the reciprocating-engine class heat rate
  (~7.9 GJ/MWh at full load on gas, rising to ~8.8 at minimum) **or** back it out from NGER /
  revealed cost.
- **Torrens Island B VOM** has no Aurecon class (gas-steam isn't a new-build technology). Old
  gas-steam VOM is modest (~$1–4/MWh). **Pin it from revealed cost; do not guess in the headline.**

---

## 6. Two quirks in the heat-rate sheet

- **Pelican Point and Osborne have incremental > static** (8.45 > 7.35; 9.92 > 8.16), which is
  backwards — marginal shouldn't exceed average. AEMO calibrates the static (Note 1) and variable
  (Note 2) representations separately, so they don't reconcile. For these two, the **static**
  implies the physically correct efficiency (Pelican 7.35 ≈ 49% HHV, right for a CCGT; incremental
  implies ~43%). **Do not trust the incremental column for the CCGT/cogen pair** — validate
  against revealed cost.
- The OCGTs are internally consistent (static > incremental, as expected for a two-part curve with
  a large no-load base). For them, incremental-as-marginal is fine.

---

## 7. Revealed-cost anchor (preferred, and fills both gaps)

For each unit, regress the marginal (low/marginal-band) offer price on the contemporaneous gas
price over **competitive intervals only** (low demand, non-pivotal, undirected): the slope ≈
implied incremental heat rate, the intercept ≈ implied VOM, in exactly the units the SRMC build
needs.
- Estimate on a competitive subsample, then APPLY to the intervals of interest — never estimate on
  the periods being tested for withholding (circularity).
- This recovers Barker Inlet's missing heat rate and Torrens B's missing VOM jointly, on the
  units' own scale, without relying on new-entrant assumptions.

---

## 8. How to apply / update

1. Store the table above as a DUID-keyed lookup, with a `source` flag per cell
   (`aemo_sheet` / `aurecon2024` / `revealed` / `proxy`) and a `vintage` field, so swaps are
   auditable.
2. Build `SRMC_{i,t}` per §2–§3 using the STTM Adelaide ex-ante gas price (with distillate-parity
   `min(gas, distillate)` for the switchable OCGTs — confirm which can burn distillate).
3. Produce both `srmc_marginal` and `srmc_allin`.
4. Run the revealed-cost regression (§7); where it gives a credible unit estimate, prefer it and
   flip the cell's `source` to `revealed`. Fill the two §5 gaps this way.
5. Report the withholding result under BOTH the assumption-based and revealed-cost heat rates as a
   robustness row — show the finding isn't an artefact of which heat rate was chosen.
