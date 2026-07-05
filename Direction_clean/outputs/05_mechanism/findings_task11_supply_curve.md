# The supply-curve history -- when the ladder changes, and what it changes with

Descriptive examination requested to interrogate the no-prize-response conclusion in the raw
object. No tests; the adjudication boundary applies. Scripts `task11_supply_curve_history.R` +
`task11b_remaining.R`; tables `task11_{monthly_curve,hourly_curve,comovement,era_split}.csv`.
Curve = the effective ladder (band quantities cumulated, capped at declared availability),
summarised as MW offered <= $300 ("the cheap tranche"), total availability, and top-band mass,
per unit, monthly and by hour of day, 2022-01 to 2024-12.

## The single most probative fact: the posture did not soften when the prize halved
The compensation price fell mechanically from a $286/MWh era-average (2022-01..2023-06) to
$203 (2023-07..2024-12) as the 2022 crisis rolled out of its trailing window -- a 30% cut in
the prize, computable in advance, with gas simultaneously flat-to-lower. If the standing
absence were priced to the prize, it should have relaxed. It did not (`task11_era_split.csv`):

| Unit | Cheap MW (high-d_t era -> post-drop) | % intervals with zero cheap | Availability |
|---|---|---|---|
| TORRB2 | 20.4 -> 21.3 | 76.9 -> 81.4% | 53 -> 44 MW |
| TORRB3 | 29.1 -> 27.0 | 70.0 -> 74.8% | 69 -> 59 MW |
| TORRB4 | 30.7 -> 18.7 | 71.0 -> 82.2% | 63 -> 42 MW |
| PPCCGT | 212.7 -> 192.7 | 39.2 -> 45.4% | 229 -> 199 MW |

Every unit's absence held or DEEPENED after the prize fell. Monthly co-movements say the same
(`task11_comovement.csv`): cor(cheap tranche, d_t) = -0.13 to +0.20 in levels, -0.12 to +0.26
in month-over-month changes, and 0.00 to +0.15 within the post-drop window where gas is flat
(sd $1.2/GJ) and d_t still moves (sd $24). The acknowledged confound -- cor(d_t, gas) = 0.48
-- cuts against the null only in the 2022 era, which is exactly why the flat-gas window is the
informative one, and it is empty of prize-tracking.

## When the curve actually changes (`task11_monthly_curve.csv`, TORRB2 shown; all units similar)
1. **The 2022 crisis collapse (Aug-Sep 2022):** the cheap tranche goes to 4 MW then literally
   0 (97-100% of intervals with zero cheap) exactly as d_t peaks ($365-378) and gas runs $27.
   This is the one period where "absent while the prize was maximal" is true -- and it is also
   the winter fuel-scarcity emergency; monthly data cannot separate the two, the same
   cross-month confound Stage 4 registered.
2. **The deepest absence block (Mar-May 2023): the decisive counter-case.** Three consecutive
   months at exactly zero cheap MW and zero availability -- while d_t was at its plateau
   ($323-329, near-maximum) BUT directions were zero (n_dir = 0 all three months) and
   essentiality nearly so (1-3 N-1 days/month). The units were completely absent when there
   was nothing to harvest: no need, no directions, no compensation. A prize-harvesting
   strategy parks itself where the directions are; a maintenance/shoulder-season plant parks
   itself where the demand isn't. The record matches the second.
3. **The recommissioning waves (Jun 2024; Nov-Dec 2024):** the largest POSITIVE cheap-tranche
   jumps (TORRB3 +70, TORRB4 +72; TORRB2 +41, and Dec 2024 the sample's maximum cheap tranche
   at 62 MW) arrive with flat d_t (+$1-2) -- seasonal return-to-service ahead of summer, not
   price events.
4. **What the biggest monthly shifts co-move with:** gas and season, not the prize -- and the
   gas correlation is POSITIVE for Torrens (+0.16 to +0.59: more cheap capacity when fuel is
   dearer), the anti-cost signature already established in [F3a]; it reflects winter running,
   when high gas, high demand and high prices arrive together.

## Over the hours of the day (`task11_hourly_curve.csv`)
The little cheap capacity Torrens offers is concentrated in the MIDDAY hours -- TORRB2 peaks
at 39-50 MW at 13:00-16:00 and troughs at 14-18 MW at 06:00-09:00, in every year -- which is
precisely where essentiality fires (09:00-13:00) and directions land. **The intraday shape of
the curve runs opposite to an absence-when-needed strategy**: within the day, the units tilt
their cheap megawatts TOWARD the system's tight hours, consistent with the Task 9 retention
finding (essential days hold offered evenings) rather than with positioning to be directed.
2023 is uniformly the most withdrawn year at every hour (3-17 MW); 2024 the most present.
PPCCGT shows its commercial duty cycle (60-100 MW cheap at 07:00-10:00 vs 250-350 at
14:00-19:00) unchanged in shape across all three years.

## Assessment against the doubt (plainly)
The raw curve gives the doubt one genuine foothold and takes four away. The foothold: the
Aug-Sep 2022 total withdrawal coincides with the prize's all-time peak, and monthly resolution
cannot separate crisis conservatism from prize positioning -- this is, and remains, the
registered cross-month caveat on Stage 4's interval-level dose-response (the one positive
prize-sensitivity on the record). Taken away: (1) the prize's 30% mechanical fall changed
nothing in the posture; (2) month-to-month curve movements are uncorrelated with d_t moves,
including in the clean flat-gas window; (3) the deepest absence sat in months with zero
directions to harvest; (4) within the day, cheap capacity tilts toward, not away from, the
hours the system needs it. Under the standing boundary: nothing here re-opens an adjudicated
result; a formal era-contrast or crisis-decomposition test would require a new
pre-registration, and the Mar-May 2023 block plus the flat-gas window define what it would
have to explain.

## Addendum (requested): the lag-wedge window — gas down, prize still high
The trailing-365-day construction creates a window where cost falls but the prize lags:
**Oct 2022 – Jun 2023** (gas $12.6–18.6/GJ vs $27–30 before; d_t $298–350 — the maximum
prize-over-cost wedge of the sample, ~$200+/MWh for ~8 months). The curve over it, TORRB2
exemplar (`task11_monthly_curve.csv`), splits into two phases:

- **Oct 2022 – Feb 2023 (wedge + need):** directions at their sample peak (7–15 episodes/
  month) — and the posture NOT deeper than usual: zero-cheap interval share 66–82% (sample
  mean ~77%), cheap tranche 10–46 MW (sample mean ~21; Oct–Nov ABOVE average). The units were
  slightly MORE present than usual through the maximum-wedge need season.
- **Mar – May 2023 (wedge, no need):** the sample's deepest absence — three months at exactly
  zero cheap MW and zero availability — with ZERO directions and 1–3 essential days/month.
  Maximal wedge, total absence, nothing harvested.

The cross-season control: the comparable need season at LOW wedge (Sep–Oct 2024: 13–21
essential days/month, d_t ~$220, gas ~$13) shows the DEEPEST in-season absence of the record
(zero-cheap 95–99%, cheap tranche 1–5 MW) — the ordering is the reverse of the harvest
prediction (deepest absence should sit in the high-wedge need season; it sits in the low-wedge
one). Caveats stated: the 2024 comparison is confounded by closure wind-down (absence trends
deeper as June 2026 approaches), and total direction REVENUE did peak in the wedge window —
but through direction frequency (the system's need) at the mechanically high price, not
through any measurable deepening of the posture. What the wedge window shows is the mechanism
paying its maximum rates into an unchanged stance.

**Descriptive examination complete.**
