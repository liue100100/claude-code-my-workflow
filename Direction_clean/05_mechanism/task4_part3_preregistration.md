# Part 3 pre-registration — the registered instrument test

**Written and committed BEFORE estimation. 2026-07-05.**

## Registered question (verbatim from the instruction)
Around direction episodes and on essential days — clean days only, corrected clock — do any of
the validated instruments show movement the floor-point measure missed? Specifically:
(i) do the ladder-shape summaries shift on essential vs ordinary clean days? (ii) does rebid
intensity or the lever mix change on essential mornings and in the 48h before clean-day first
directions? (iii) does the absence type composition shift as direction episodes approach — in
particular, priced-out converting to full exit? (iv) does bid churn concentrate ahead of
essentiality or direction episodes rather than at random?

## Committed readings (verbatim)
Movement on any validated instrument with a flat floor point = a behavioural response existed
at a margin the original outcome could not see — reported as the finding, with the instrument
and margin named. Nothing moves on any instrument = the unresponsiveness conclusion now holds
across every observable dimension of the bid — the ladder's shape, the intraday record, the
absence type, and the document's churn — and is reported as the strongest available version of
the standing-posture result. Partial movement (e.g. churn without shape change) = described
exactly, no stretching toward either headline.

## Instrument eligibility (fixed by the Part 2 gate; no additions/removals after this point)
Eligible: churn; shape wmean_price / top2_share / steep_iqr (all units), q_2xsrmc / q_shoulder
(PPCCGT only — declared blind for Torrens); absence taxonomy; non-tagged rebids
(ELIGIBLE-WITH-FLAG: weak detector, strongest validated behaviour is suppression during
direction traffic). Quarantined from conduct claims: direction-tagged rebids (descriptive
columns only). Descriptive stream: "none"-lever rebids. Benchmark carried: the floor-point
composite (Component A / B where applicable).

## Fixed designs (event counts reported before any coefficient, always)
- **(i) Shape on essential days** — unit-day regression, clean days, suspension days excluded
  (established June handling): instrument ~ essential_day + SRMC + demand + non-sync MW + spot
  + competition (slope mean, saturated share) | unit + month FE; cluster month; WCB
  (Rademacher/Webb, R=999) on the essential coefficient. Benchmark row: composite. PPCCGT-only
  rows for the q-measures (expected to be a bound: ~5 clean essential PPCCGT days).
- **(ii) Rebids** — (a) same regression design with n_nontag (and its morning-lodged count,
  hours 00–12) as outcome; lever mix as MAXAVAIL-lever share among non-tagged rebids;
  (b) event-window description at D−2, D−1 before the 280 clean-day first directions, count
  rule from Part 2 (rate ratio vs quiet baseline; registered if RR ≥ 2 or ≤ 0.5 with absolute
  change ≥ 0.5/day); windows restricted to approach days that are themselves clean (count
  reported).
- **(iii) Taxonomy approach** — count table first: within-spell type transitions conditioned on
  distance to the next direction start (next direction within 2 days vs none within 7 days).
  With only 13 priced-out→full-exit conversions in the whole sample, this is expected to be
  reported as counts/bounds, never a forced estimate.
- **(iv) Churn concentration** — event-time profile of churn (median z vs own-unit quiet
  baseline) on days D−3..D+1 around (a) clean first directions and (b) essentiality onsets
  (first essential day after ≥7 non-essential days); "concentrated rather than random" =
  pre-event days (D−3..D−1, themselves clean) show |median z| > 0.5 where the quiet baseline
  by construction sits at 0. Benchmark: the floor-point composite over the same windows.
- Thin cells (n < 10 unit-days) reported as bounds. Anomalies reported, not smoothed.
