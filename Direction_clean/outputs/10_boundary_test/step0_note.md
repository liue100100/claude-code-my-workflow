# Step-0 dated note — choices fixed before any outcome data is touched (2026-07-07)

Support report on disk (`boundary_support.md`): 316 pooled Torrens clean unit-days within
±$30k of R = 0 (base) — the gate passes; 224 within ±$20k; near-boundary days spread across 30
months, top-3 months hold 23%.

Choices fixed now:

1. **Window width w = $30k (the default).** The histogram gives no reason to move it: R's
   central mass sits on the ±$100k scale (median $63k), so ±$30k is local without being empty
   (316 days). Δ also reported at $20k and $50k per the registration.
2. **Inference roles unchanged:** near-boundary days do NOT cluster in a few months (30 months,
   23% top-3), so the within-month permutation is not degenerate. The placebo-line rank test is
   the registered p-value; the within-month randomization (999 draws, seed 20260705) stands as
   the supplement.
3. **Step-5 haircut constants, fixed before Step 1 runs:**
   - Start-cost charge: the Aurecon/ISP workbook is not machine-retrievable (AEMO 403); the
     documented substitute range for conventional-unit starts in NEM modelling is 120 (warm) –
     350 (cold) $/MW; midpoint **235 $/MW × 200 MW = $47,000 per start**, amortized over the
     median committed run length of the Torrens units (computed from DISPATCHLOAD commitment
     spells — the second licensed haircut input; value recorded in the battery log). Range
     noted per the registration; hot starts (40 $/MW) excluded — the decision studied is a
     day-grain off→on commitment.
   - Forecast-error penalty: unit-month mean absolute error of the previous-day day-mean price,
     MAE_{u,m} = mean |rrp_d − rrp_prev_mean_d| within unit-month, charged as
     24 h × floor × MAE against M_d.
