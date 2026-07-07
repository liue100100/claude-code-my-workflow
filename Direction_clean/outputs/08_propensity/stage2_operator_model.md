# Stage 2 findings — the operator model: hazard, decomposition, propensity

Registration: `08_propensity/registration.md`. Script: `stage2_operator_model.R`; outputs
`stage2_{panel.rds, hazard_coefs, calibration, leadtimes, decomposition}.csv`; log
`stage2_run.log`. Grain: 30-min, 2022–2024. Onset rule N = 8h (Stage 0: 386 independent onsets
from 480 merged spells).

## The hazard (registered 9-parameter logit): the fixed spec passes its diagnostics

Risk set: 21,678 half-hours with no direction active and > 8 h since the last spell ended;
252 of the 386 independent onsets fall inside it (the rest sit in the post-spell cool-down or at
covariate edges — they feed the decomposition, not the trigger model). Events per parameter: 28.

| regressor | estimate | z | reading |
|---|---|---|---|
| min forecast slack (lead window) | **−0.599** | −9.6 | the registered workhorse, as expected: one unit of forecast slack roughly halves the onset odds |
| current slack (commitment) | −0.347 | −4.4 | current tightness adds signal beyond the forecast |
| forecast demand trough (GW) | −0.762 | −3.8 | deeper overnight/midday troughs → higher hazard |
| forecast non-sync share | −0.003 | −0.6 | **null** — the non-sync tier is already inside the slack, as designed |
| log time-since-last-direction | −0.756 | −8.1 | strong clustering: hazard decays with distance from the last episode |
| hour blocks (3) | +2.06 (06–12), −1.03 (12–18), +0.88 (18–24) | 12.6 / −1.7 / 3.6 | the morning commitment window dominates — an operating-calendar signature |

**Month-out cross-validated fit: AUC 0.863** (in-sample 0.870 — essentially no overfit),
CV deviance ratio 0.199, calibration monotone across all ten predicted-hazard deciles (top
decile: predicted 7.0%, observed 6.1%). The registered fallback (L1) is not needed.

## Lead-time distribution: the operator directs at need, not ahead of it

352 of 386 onsets contain a commitment-need event (slack_commit = 0) in their spell. The gap
from issue to first need: **median 0.5 h, p25 0.0 h, p75 0.5 h.** There is essentially no
forecast buffer — directions are issued when the committed fleet actually falls below the
standard, not in anticipation.

## Five-bucket decomposition of all directed time (need = slack_commit = 0; registered gate)

| bucket | hours | share |
|---|---|---|
| **core need** (committed fleet below standard) | 10,482 | **86.4%** |
| persistence (post-need trailing, same spell) | 898 | 7.4% |
| **unexplained residual** (chains with no need anywhere) | 334 | **2.8%** |
| forecast buffer (pre-first-need) | 300 | 2.5% |
| panel-edge NA | 62 | 0.5% |
| extension chaining (re-issues past the last need) | 51 | 0.4% |

**Gate adjudication: the residual bucket is small (2.8%) → the two-layer trigger is validated;
Stage 4 is licensed.** The committed alternative reading (dominant persistence + buffer =
compensated time no one needs) does not obtain: directed time is overwhelmingly core need *on
the commitment margin*. The §9-relevant contrast is the sensitivity row: on the strict
**availability** margin only 46 of 386 chains ever hit a need event, and **73.5% of directed
time sits in chains with no availability-need at all** — the scheme compensates presence that
the rival fleet could in principle have covered had it been committed; what it cannot cover is
the commitment itself.

## The propensity

π(t) = 1 − Π(1 − ĥ) accumulated from month-out CV hazards (leak-free; hazard = 0 inside spells
and cool-downs, where an independent onset cannot occur). Primary horizon 8 h; 4 h and 24 h
computed alongside.

- π_8h: mean 0.065, sd 0.127.
- Slow/fast split (30-day centered moving average): **slow-component variance share 9%** —
  the propensity is dominated by daily innovations, not the seasonal/outage calendar. Stage 4's
  registered "preferred shape" (π_slow × d_t loading, π_fast null) will be tested against a slow
  component with sd 0.039 against the fast component's 0.121; the power asymmetry is noted here,
  before estimation.

## Definitional choices fixed in this stage (stated per the discipline)

Need = slack_commit = 0 (Stage-1 handoff; availability sensitivity reported). Buffer = chain
time before the first need; persistence = post-last-need time in the last-need spell; chaining =
re-issue-spell time past the chain's last need; residual = whole chains with no need.
Sub-30-min spells occupy their covering half-hour. Onsets outside the risk set (cool-down) are
excluded from estimation but included in the decomposition.
