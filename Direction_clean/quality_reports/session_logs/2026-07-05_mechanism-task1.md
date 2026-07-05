# Session log — 2026-07-05 — Mechanism check, Task 1 (directed output vs floor block)

## Goal
User-specified mechanism check, three gated tasks. Task 1: for every focal-unit direction
episode, compare realised output while directed against minimum stable load and the $0-floor
block offered in the bid in force at issue. Institutional background encoded in the findings per
instruction (Synchronise = presence requirement; compensation = (actual − bid-established
counterfactual) × directed price). Stop after Task 1.

## Build (`05_mechanism/task1_directed_output.R`)
- 1,116 focal episodes; joined 36 months of dispatch (17,445 exact-duplicate rows removed —
  known cache artifact; physical run preferred where dual runs exist); resolved the in-force bid
  (quantity version + daily ladder, both ≤ issue instant tau) for each episode's first directed
  interval.

## Anomalies investigated, not smoothed (two)
1. **Apparent 34% bid-resolution failure was sample-window truncation, not selection.** The
   episode table spans back to 2021 (like treatment_panel — same lesson as the Stage-0 tz check);
   the dispatch cache also reaches into 2021 from old pipeline work, which made the raw coverage
   count misleading. Verified directly: **all 740 in-window (2022-2024) episodes resolve — zero
   within-sample selection.** PPCCGT's directions concentrate in 2021, hence only 29 in-sample.
2. **Declared MINIMUMLOAD is 100% empty in the AEMO archive** — the declared technical minimum is
   unavailable. Observed floor (P5 of positive directed output) carries the measure: exactly
   40 MW for all three Torrens units, tight and credible as true minimum stable load.

## Result — the institutional account is confirmed for Torrens
Directed output (median 40 MW = 20% of registered capacity) = observed operating floor (40 MW) ≈
the unit's own $0-floor block at issue (median 20-40 MW). Pooled: 36.9% of episodes deliver zero
or negative excess over the floor block; 54.3% within 25 MW; median excess +17.5 MW. A direction
buys PRESENCE, not energy. PPCCGT is the instructive contrast (n=29): median floor block at issue
is ZERO yet it runs 70+ MW directed — the lowest bid-established counterfactual and hence the
largest compensated wedge per MWh. OSB-AG runs exactly at its floor (+3 MW) — near-must-run.

## Implication carried to Task 2
With directed output pinned at the floor, the compensated quantity is governed almost entirely by
the counterfactual side of the formula — what the unit's bids said it would have done — which
makes the commitment margin (heading offline before issue?) the margin that both triggers
directions and sizes compensation. That is Task 2's classification question.

## Status: Task 1 COMPLETE — STOPPED for review before Task 2, per instruction.
Outputs: `outputs/05_mechanism/{findings_task1.md, task1_summary_by_unit.csv,
task1_episode_level.csv, task1_excess_over_floor.png}`.
