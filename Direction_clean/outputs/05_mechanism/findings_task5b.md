# Task B -- did sitting out pay better than running?

**The sentence: over 2022-2024, the direction channel paid the three Torrens units $141.9M for
625,635 directed MWh that would have earned $7.2M at market prices -- sitting out paid $134.7M
more than running would have, roughly 20 dollars for every 1, and in 2023 the market value of
the same output was negative.**

Method as specified: direction earnings = actual per-event compensation where it exists (243
episodes, 2023-10 onward) else the verified formula 0.95 x directed MWh x directed price (440
episodes); counterfactual = the SAME output valued at realised SA1 spot prices over the same
corrected windows. Coverage: 683 of 683 Torrens episodes. Assumption stated plainly: a
committed unit doesn't get directed, so it earns spot only -- this compares payment rates, not
a full what-if (AEMO's behaviour might differ in that world). Script
`task5b_sitting_out_vs_running.R`; tables `task5b_{unit_year_table,episode_level}.csv`.
This resolves open check (ii) of `interpretation_staged_framework.md`: **absence dominates in
dollars -- no amendment required.**

## Per unit, per year

| Unit | Year | Episodes | MWh | Direction earnings | Same output at spot | Gap | $/MWh dir | $/MWh spot |
|---|---|---|---|---|---|---|---|---|
| TORRB2 | 2022 | 67 | 47,740 | $12.99M | $1.06M | $11.9M | 272 | 22 |
| TORRB2 | 2023 | 60 | 54,671 | $13.54M | **−$0.27M** | $13.8M | 248 | −5 |
| TORRB2 | 2024 | 70 | 70,934 | $13.70M | $0.76M | $12.9M | 193 | 11 |
| TORRB3 | 2022 | 94 | 87,133 | $21.76M | $2.41M | $19.4M | 250 | 28 |
| TORRB3 | 2023 | 87 | 65,576 | $15.91M | **−$0.17M** | $16.1M | 243 | −3 |
| TORRB3 | 2024 | 79 | 107,394 | $20.47M | $1.35M | $19.1M | 191 | 13 |
| TORRB4 | 2022 | 86 | 64,021 | $15.50M | $1.43M | $14.1M | 242 | 22 |
| TORRB4 | 2023 | 86 | 63,337 | $15.23M | **−$0.39M** | $15.6M | 241 | −6 |
| TORRB4 | 2024 | 54 | 64,830 | $12.81M | $0.97M | $11.8M | 198 | 15 |
| **Total** | | **683** | **625,635** | **$141.9M** | **$7.2M** | **$134.7M** | ~227 | ~11 |

## What the spot column is made of
48.2% of all directed MWh were delivered at NEGATIVE spot prices; the MWh-weighted mean spot
price in the directed windows is $11.4/MWh. Against an engineering SRMC of ~$80-110/MWh, a
unit running those windows commercially loses on the order of $90 on every MWh before it earns
a cent -- while the direction channel pays $191-272/MWh gross. In 2023 the spot value of the
directed output was negative for all three units: there is no fuel-cost assumption under which
running beats being directed in these hours. Consistency check: on the actual-compensation
subset alone (2023-10 onward), $52.5M direction vs $2.4M spot -- the same ~22x ratio, so the
formula-imputed early years are not driving the result. (Using actual compensation if anything
UNDERSTATES the direction channel: it nets off retained market revenue, whose median was
negative in these windows.)

## The interpretation-note check, closed
The staged framework's economic core -- "given how the direction channel pays, absence
dominates commitment across essentially all conditions, so there is nothing left to calibrate
daily" -- is now quantitative: the direction channel out-paid the market channel by a factor
of ~20 on the same megawatt-hours, every unit, every year, with the market alternative
actually loss-making in the middle year. The standing absence is not a puzzle to explain; at
these relative payment rates it is the only posture an informed desk would hold. The economic
content is in the mechanism's design.

**STOP -- Task B complete. Analysis phase closes after the outstanding commit + stale-artifact
regeneration (pre-authorized next steps).**
