# Proofreading Report — manuscript/paper.tex + sections/ (2026-07-06)

**Status:** APPLIED 2026-07-06 — batch approved by user; all 26 items applied (incl. new cross-refs to App B from §5.1 and App C from §7.2); recompile clean (30 pp, 100/100, one 7.7pt overfull unchanged).
**Reviewer:** proofreader agent a4101a22048fb62ba. 26 findings: 6 high / 10 medium / 8 low + 2 units.

## High severity
1. `01_introduction.tex:90` — "a margin that literature treats" → "a margin that **the** literature treats" (grammar).
2. `01_introduction.tex:95` — "evidence that debate never had" → "evidence that **the** debate never had" (grammar).
3. Abstract vs body — abstract says "day-level exits"/"day-level state dependence"; body uses "evening exits"/"day-grain". Align abstract to body (consistency).
4. Bootstrap naming — "wild-cluster-bootstrap" (abstract/intro) vs "wild cluster bootstrap" (§5) vs "wild-bootstrap" (§6). Standardise: noun "wild cluster bootstrap", compound adjective "wild-cluster-bootstrap $p$-value" (consistency).
5. "CEM" used in §8/App A but never defined — add "(CEM)" at first mention in §5.4 (consistency).
6. "SRMC" used from §5 but never tied to "short-run marginal cost" — add "(SRMC)" in §3:36 (consistency).

## Medium severity
7. `02_setting.tex:80` — Oxford comma: "TORRB2, TORRB3, and TORRB4".
8. `01_introduction.tex:74` — "zero excess" → "zero or negative excess" (matches §2/§7 statistic).
9. Hypothesis naming — "insurance signature" / "regime-triggered (insurance) account" / "pure presence-inelasticity" are one concept; gloss them together at the §6 channel ranking.
10. `03_data.tex:61-63` — Q2-2023 machine-precision claim lacks a citation; tie to \citep{AEMO2024_qed_q2}.
11. "NER" acronym never introduced; add "(NER)" in §2 where the Rules are first named (Fig 2 caption uses it).
12. `03_data.tex:42` — "range of 7--11" → "7--11~GJ/MWh" (missing unit).
13. `04_descriptives.tex:63` — "cheap tranche under 100" → "under 100~MW".
14. `07_mechanism.tex:52` — "maxima up to 100" → "up to 100 days".
15. `07_mechanism.tex:33-35` — "$134.7M gap, roughly 20 to 1, for every unit in every year" — separate the aggregate from the per-unit ratio claim.
16. `07_mechanism.tex:127-129` — footnote referent: "the staged pattern ... deliberately does not establish motive" → "this paper deliberately does not use it to establish motive".
17. `paper.tex:39-40` — Unicode em dash in \thanks → "---".

## Low severity
18. `05_design.tex:137-138` — "asserted equal" → "confirmed numerically identical".
19. `06_results.tex:37-38` — "energy-market power account" → "energy-market-power account" (hyphenation).
20. `01_introduction.tex:23` — "directs specific units on" → "directs specific units online".
21. `appendix_a:7-8` — "registered first pass" → "first, preregistered pass".
22. `01_introduction.tex:60` — "an estimate committed to its interpretation before it was run" → "an estimate whose interpretation was committed before it was run".
23. `04_descriptives.tex:40-41` — "...statistics; Section~\ref{sec:data}." → "(Section~\ref{sec:data})".
24. `01_introduction.tex:11` — "administrative channel" one-off vs established "direction channel" (or keep as deliberate hook variation).
25/26. Orphaned labels — app:markup and app:n1 never \ref'd from main text; add forward pointers (§5/§6 → App B; §7 → App C).

Clean: \citet/\citep usage, dash ranges, cross-reference capitalisation, footnote punctuation, escaped characters.
