# Post-Flight Verification (CoVe) — manuscript/paper.tex

**Date:** 2026-07-06
**Claims extracted:** 18 (9 citation-attribution pairs, 9 institutional facts)
**Verified independently:** 18 (forked `claim-verifier`, agent adadb699737feb304 — draft text withheld)
**Outcome:** PARTIAL → all actionable items fixed in the manuscript same-session; post-fix status PASS with one EXPLAINED and one MED retrieval note.

## Discrepancies found and fixed

- **C10 (was HIGH) — NER clause misattribution.** Compensation *entitlement* is clause **3.15.7**; **3.15.8** is the cost-*recovery* mechanism (the QED `cra` concept — consistent with project memory); the power to direct is 4.8.9. §2 corrected to "entitled to compensation under 3.15.7, recovered under 3.15.8." §3/§4 uses of "recovery amount" were already correct.
- **C7 (MED, emphasis drift) — Bushnell–Wolak RMR.** The report supports "1998 RMR contract design created serious incentive problems and raised prices"; the sharper claim that generators could influence their own RMR designation through bids is not clearly the report's own mechanism (verifier could not extract the PDF cleanly; secondary sources only). §1 and §9 rephrased to the supported claim.
- **C16 (EXPLAINED) — "86% of a 2021 quarter under direction."** Public trade-press peaks are ~51–67%; our figure (85.7%, Q4-2021) comes from the project's parsed event record, whose share-of-time-directed series reproduces AEMO QED within 0.1pp in 6 of 9 validated quarters. §2 now attributes the figure explicitly to this paper's event record with the validation cross-reference. Named alternative: own QED-validated panel, different quarter than the trade-press citations.

## Verified without correction

C1–C6, C8, C9 (all academic attributions — no fabricated references, directions of findings correct, Fabra 2018 paraphrase near-verbatim); C11 (90th-percentile trailing-12-month compensation price); C12 (SA minimum synchronous requirement mechanics); C13 (four ElectraNet syncons, Davenport/Robertstown, commissioned through 2021); C14 (Sept-2025 reduction to one unit, PEC Stage 2 pathway); C15 (market suspension 15–24 June 2022, $300 APC); C17 (Torrens B 4×200 MW, B1 mothballed 2021, closure announced Nov 2022 for June 2026); C18 (Pelican Point ~478 MW CCGT).

## Residual notes for submission

- C7: obtain the Bushnell–Wolak PDF into `master_supporting_docs/supporting_papers/` and confirm the incentive-section wording before any stronger claim is reinstated.
- C16: if a referee queries the 86%, the answer is the QED reconciliation (session log 2026-07-06, `Direction/quality_reports/session_logs/2026-07-06_f2-aemo-reconciliation.md`).
