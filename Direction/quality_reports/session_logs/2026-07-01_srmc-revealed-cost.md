# Session log — 2026-07-01 — SRMC methodology doc + revealed-cost anchor

## Goal
Consolidate the SRMC methodology + results into one doc; then build the §7 revealed-cost
regression (the one open piece of the cost stage) and produce the robustness row.

## What was done
1. **`Direction/02_cost/SRMC_methodology.md`** — new write-up of the engineering SRMC:
   formula, two measures (marginal/all-in), inputs (AEMO heat rates, Aurecon VOM, STTM gas,
   diesel), conventions, unit adjustments, estimated levels + margins, [F3]/[F4].
2. **`Direction/02_cost/gate_a_revealed_cost.R`** — ran the §7 revealed-cost anchor:
   regress the low (cost-reflective) offer band on STTM gas over competitive unit-days
   (undirected, non-pivotal, not-short; n=9,295, comp_share ≥ 0.80).

## Key result — revealed-cost anchor REJECTED on BOTH margins [F3a]
Tested on competitive intervals only (undirected, non-pivotal, not short) so it's not circular.
- **Price margin** (`gate_a_revealed_cost.R`): pooled within-unit slope (implied heat rate) =
  **0.22 GJ/MWh** (t 3.6, within-R² 0.003) vs engineering 7–11. Per-unit HRs near-zero /
  wrong-signed (PPCCGT −1.61, MINTARO/Dry Creek ≈ −0.6) / implausible (QPS5 3.61); "VOM" $52–143.
- **Quantity margin** (`gate_a_revealed_cost_qty.R`, added after user flagged that conduct runs
  on quantities): low-tranche price `p_at_25` on gas pooled slope **−110.7** (t −5.8, wrong-signed);
  share of offered cap ≤ $150 on gas pooled slope **−0.0002** (t −0.23, within-R² 0.0002 — flat).
  Torrens B parks ~26% below $150 whether gas is $10 or $30/GJ (SRMC $110 vs $300).
- Mechanism: fixed base tranche at fixed low ladder prices, rest dumped near the price cap;
  structure invariant to fuel cost. In 2022 (gas ~$21/GJ, eng SRMC ~$300) low band still ~$110.
- **Consequence:** engineering SRMC (`gate_a_srmc.R`) is the maintained cost measure; the
  BARKIPS1 heat-rate and TORRB VOM proxy gaps cannot be filled by revealed cost and stay flagged.
  The negative result reinforces the conduct story [F16] and is a robustness point, not a gap.

## Follow-on: recovered supply curves by regime [F14a]
Recovered each unit's inverse supply curve (offer price/SRMC on log at each cumulative-capacity
quantile; cumulative offer CAPPED at MAXAVAIL — key fix, since BANDAVAIL is posted full even when
MAXAVAIL is cut). Normalisations: share of MAXAVAIL (price shape) + share of registered cap
(both levers). Median across months, IQR ribbon.
- `04_market_power/supply_curves_by_regime.R` — 2×2 direction×pivotality. Finding: Torrens B has a
  cheap tranche only when undirected+non-pivotal; pivotality collapses avail_frac 1.0→0.20 AND prices
  the rest at the cap; direction adds little beyond pivotality.
- `04_market_power/f4_supply_curves.R` — F4 as nested cuts (all/directed/directed-pivotal).
- `05_directions/f5_runup_supply_curves.R` — F5/run-up as evolving curve by lead-time bin (Δ =
  submission − τ); 6,149 Synchronise versions / 669 episodes; cheap tranche withdrawn as τ nears.
  Caches to `outputs/direction_rebid/f5_ver.rds` (REBUILD_F5=1 to rescan).
- TORRB1 dropped everywhere (offline: 95th-pctile MAXAVAIL = 0).
- Raw-dollar ($/MWh) variants added to all three (`*_raw.png`): y = offer price, linear, SRMC
  reference line. Shows offers pinned ~$15-16.6k (cap) vs SRMC ~$120.
- **Monotonicity fix (user-flagged):** offer curves were non-monotone (dips) — an artifact of
  per-quantile sample changes (dropping the sub-cost floor tranche to fit the log axis). Fixed:
  median over a FIXED interval/version set across all quantiles (drop an interval entirely if its
  curve has any NA), floor tranche CLAMPED to 0.1 not dropped. Median-of-monotone-over-fixed-set is
  guaranteed monotone; all three figure sets now confirmed monotone.

## F5 composition diagnosis + within-episode fix (user-flagged)
Diagnosed pooled-bin F5: near-issue lead bins (−6..−3h) hold only 18–32 of ~130 episodes (a
self-selected subset), and each episode covers only 2–4 of 7 bins — so pooled medians compare
different episode sets. NOT upstream filtering (episodes present); the window just has sparse
rebids, and MIN_VER=15 then drops it for TORRB3/4.
Fix: `05_directions/f5b_within_episode_runup.R` — carry each episode's bid forward (LOCF rolling
join) to a common event-time grid [−24h..0], fixed set = 100% of episodes, change-from-baseline
(within transform). **Result reverses the naive read:** no unconditional cheap-tranche withdrawal
(flat ~5%, slightly +); quantity margin heterogeneous (Torrens +6–8% preparing to synchronise,
Mintaro −15% / QPS5 −6% withdraw). Withholding is a standing posture [F6], not a run-up. [F14a](iii)
corrected. Reads f5_ver.rds (no re-scan). Next: within-episode × pivotality split.
- Bugs fixed mid-build: MAXAVAIL cap (withheld_ma was >1), colour-scale level mismatch, NA in
  price_at index (guarded), NA mpc.

## Docs updated for consistency
`facts_memo.md` (+[F3a]), `INDEX.md` (02_cost rows), `build_docs.R` (limitations row),
`descriptive_readout_v3.md` (robustness-row item struck).

## Open / for user
- Decision for the paper: present F3a as a robustness/mechanism point (recommended) vs. footnote.
- Not committed yet — awaiting user.
- Outstanding v3 robustness still open: `withheld_share_allin` (static-HR threshold).
