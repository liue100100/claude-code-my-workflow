# Boundary support (REBUILT M) — where the days sit (Step 0; outcome untouched)

Panel: 2796 clean unit-days with a final-run PD price (0 dropped for missing price).
Rebuilt M_d = 24h x floor x (final-run PD day-mean - SRMC) - $35621/day start charge.
Measurement blur: day-mean price MAE $148.6 (was $84.9 with prev-day realized); in dollars at the Torrens floor: ~$160k/day (was ~$86k).
Timing caveat (dated note item 1): final-run PD prices form ~30 min before delivery, not at bid formation.

## TORRENS
R range $-14183k to $365k | median $100k | share R>0: 82.7%
days within ±$20k: **105** | ±$30k: **171** | ±$50k: 337

## PPCCGT
R range $-44592k to $911k | median $215k | share R>0: 78.1%
days within ±$20k: **39** | ±$30k: **55** | ±$50k: 87

## Gate, clustering, movement
Pooled Torrens days within ±$30k: **171** (gate 60) → **gate passes**.
Near-boundary months: 22 distinct; top-3 hold 40% (202405, 202406, 202305).
Region movement vs the regions task: TORRENS 20.6%, PPCCGT 24.2% of days change region (cross-tab in log).
