# Session log — 2026-07-05 — Mechanism check, Task 1c (zero-excess forensics)

## Goal
Resolve which explanation carries the 69 zero-excess episodes (of 271, 2023-10 → 2024-12):
(a) duration artifact, (b) exit-signal sequencing, (c) combination completion, (d) instrument
wording, (e) anticipation (floor-in-and-wait vs AEMO pre-emption). Gates Task 2.

## Verdict: EXIT-THEN-DIRECTED
Ranked shares (all-69 [45 window-survivors]): exit-signal 91% [89%] > duration artifact 35%
resolved > combination completion 16% [20%, ~all overlapping exit] > pure pre-emption ~9% of
survivors (~2 genuinely surprising). Signature finding: **77% of episodes had MAXAVAIL < 5 MW
over the direction window at issue** — bands parked at the floor, availability withdrawn; the
35 capped survivors have median window output 0 MWh yet were paid (gross world, Task 1b).
Zero-excess episodes are the MORE predictable ones (pre-issue 24h piv_n1 share 0.806 vs 0.731,
p=0.022); direction history doesn't discriminate (~80% both lobes).

## Bug found + fixed (validated)
`bid_cache` convention: `TRADINGDATE`/`SETTLEMENTDATE` label is one calendar day BEHIND the
day of the version's own intervals (label D carries intervals of D+1; BOP and BDO share the
convention). First run consequently showed "100% of issue-day intervals no-bid" — impossible,
diagnosed on TORRB2 2023-12-09, fixed by re-keying BOP on `dt10(INTERVAL_DATETIME − 1s)` and
BDO on label+1. Task 1/1b unaffected (they matched INTERVAL_DATETIME directly). Validation:
Task 1c's first-interval floor reproduces Task 1's floor 69/69, corr 1.000.
Also fixed: (b)'s exit definition tied to the direction window (a MAXAVAIL=0 block elsewhere
in the day is routine two-shifting and classified everything as a signal); (e) integer/double
median type error.

## Method notes
- Window counterfactual fully bid-established: 0 of 8,290 window intervals lacked an in-force
  bid at issue (next-day bids always existed at tau).
- Market-notice verbatim text unavailable offline (NEMWeb current-only; AEMO API 403s) — (d)
  uses the reports' own instrument column (only two wordings exist: Synchronise / Remain;
  zero-excess skews Synchronise 57% vs 42%).
- (e) is a realised-state proxy (piv_n1/short_n1 pre-issue), not pre-dispatch — no
  PREDISPATCH/P5MIN extraction in repo ([F21]); stated in findings.
- `_task1c_cache.rds` caches the focal BOP/BDO/DL/DP subsets (~5.3M BOP rows) for fast reruns.

## Task 2 implication (encoded in findings)
Pre-register: treatment margin = MAXAVAIL (not bands); outcome = direction receipt/eligibility
vs d_t; conditioning = pre-issue piv_n1. 1c cannot separate passive two-shifting from strategic
floor-in-and-wait — same observed sequence; they differ only in d_t-responsiveness of the exit
margin, which is Task 2's regression.

## Status: Task 1c COMPLETE — STOPPED. Outputs: `outputs/05_mechanism/{findings_task1c.md,
task1c_*.csv, _task1c_run.log}`; script `05_mechanism/task1c_zero_excess_forensics.R`; plan
`quality_reports/plans/2026-07-05_task1c-zero-excess.md` (COMPLETED).
