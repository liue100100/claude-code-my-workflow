# Proposal descriptive figures — readout
Generated: 2026-06-29

| Figure | File | Plain-language takeaway |
|---|---|---|
| F1 | F1_compensation_vs_fuel.png | The compensation price is fixed to the previous 12 months of electricity prices, so it keeps paying 2022 levels into 2024 — the margin over fuel cost (rent) is small in the 2022 fuel spike and large once fuel falls. |
| F2 | F2_volume_cost.png | A small directed volume in late-2022/early-2023 was the costliest per MWh, because each MWh was paid the inflated compensation price (F1's high-rent period). Cost = the NER 3.15.8 recovery amount (compensation + additional compensation + expert fees, net of retained market earnings) — the same cost concept AEMO plots in QED. The CSV also holds pct_time_directed (share of the quarter under an active direction; reproduces AEMO's QED percentage-of-time series to ~0.1pp): directed time peaks in Q4-21 and Q4-23/Q1-24, not in the costliest-per-MWh window — cost tracks the lagged compensation price, not direction frequency. |
| F2b | F2b_volume_vs_time.png | Directed volume vs share of the quarter under direction, plus their ratio (average MW while directed). From 2022 on the two series are interchangeable (r = 0.98; a steady 50-75 MW whenever directed); in 2021 the same directed hour carried 115-200 MW. The regime break coincides with the synchronous condensers entering service. |
| F3 | F3_pivotal_composition.png | Most directed units were pivotal: no combination of the other available SA units could meet the requirement without them. |
| F4 | F4_rebidding_by_sample.png | As units go from ordinary days to direction days to pivotal-direction days, they offer a rising share of capacity at very high prices. |
| F5 | F5_runup.png | In the run-up to a direction (first bid version -> last version before issue), units shift more of their offered capacity above $300/MWh; shown for the full directed period and its first hour, Synchronise vs Remain. |

All figures: 300 dpi PNG. Companion CSV holds the plotted data for each.
Coverage: F1 and F3 use the 2022-2024 panel; F2 uses the full 2021-2024 directions cost record. F5 run-up uses the 2022-2024 bid cache.
