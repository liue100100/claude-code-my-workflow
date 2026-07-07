# Boundary test findings — no jump at the crossing line; the design-anatomy framing is final

Registration: `10_boundary_test/registration.md` (post-hoc status disclosed there); Step-0 note
with pre-outcome choices: `step0_note.md`; support: `boundary_support.md`. Script
`boundary_battery.R`; outputs `step*_*.csv`; log `battery_run.log`.

**Signed biases, restated:** M_d carries no start costs and uses yesterday's prices — both make
"profitable" days look more profitable, pushing days into R < 0 that belong at R > 0. The
previous-day forecast is very noisy at this grain (unit-month MAE averages $86k/day against a
$30k window), so R is measured with error larger than the window itself; measurement blur
attenuates any true jump toward zero. Both facts frame everything below.

## Step 0 — support (outcome untouched)

316 pooled Torrens clean unit-days within ±$30k of R = 0 (gate ≥ 60: passes), 224 within ±$20k;
near-boundary days spread over 30 months (top-3 hold 23%), so both inference routes stand as
registered. w = $30k retained. Haircut constants fixed in the note before Step 1.

## Step 1 — the picture

Binned sit-out rates (`step1_bins_torrens_base.csv`): the rate slides through the crossing —
roughly 51% just below R = 0, 55% just above, rising gently and smoothly with R across the
support. There is no visible break at the line.

## Step 2 — the jump. Committed reading: payment-seeking predicts Δ > 0 at the line.

| window | n below | n above | rate below | rate above | Δ |
|---|---|---|---|---|---|
| ±$20k | 73 | 151 | 0.521 | 0.550 | +0.029 |
| ±$30k | 114 | 202 | 0.509 | 0.550 | **+0.041** |
| ±$50k | 170 | 361 | 0.512 | 0.584 | +0.073 |

Positive but small — a 4-point step against a ~51% base and a rate that drifts this much
between arbitrary neighbouring bins.

## Step 3 — is the line special? Committed reading: the p-value is the rank among fake lines.

**No.** |Δ| at the true crossing ranks in the middle of 192 usable placebo lines: **p = 0.715**.
The within-month randomization supplement agrees: **p = 0.669**. An arbitrary cut in R produces
a contrast like the real line's more often than not. **Check (a)/(b) fail: there is no jump at
the registered line.**

## Step 4 — bundling guard (moot given Step 3, reported per the registration)

Within π-terciles and N−1 strata the local Δs are sign-unstable (−0.06, +0.16, −0.21
descriptive-only, +0.07, −0.06) — no coherent pattern survives conditioning, consistent with
Step 3's verdict that the raw contrast is noise.

## Step 5 — the measurement guard, and the one wrinkle reported without rescue

Haircut as fixed in the note: start charge $47,000/start ÷ median committed run **1.3 days** =
$35.6k per committed day (a striking primitive in itself: Torrens commitment spells are short),
plus the unit-month forecast-MAE penalty (mean $86k/day). The haircut reclassifies 36% of
near-boundary days.

At the **new** zero: Δ = **+0.203** (cells 22 / 30), placebo rank **p = 0.010**. At the old
zero the contrast is unchanged (+0.041). The registration committed a reading for a jump that
*stays glued* to the old line (artifact) and for one that *moves* with it (real threshold) — but
committed nothing for the configuration observed: **no jump at the registered line, a jump only
after the measurement correction.** Under the honesty rule this cannot be promoted to
confirmation: check (a) failed at the registered construction, and the Step-5 guard exists to
kill false positives, not to mint one. Three caveats keep it demoted: the cells are tiny (52
days total, se(Δ) ≈ 0.14); the placebo lines carry larger cells than the true line, so the rank
test flatters a noisy small-cell Δ; and it is one of many post-correction cuts. It is recorded
as an unregistered observation that a *fresh* registration on independent grounds could test —
nothing more.

## Step 6 — the unit with nothing at stake. Committed reading: a Torrens-sized jump here breaks the money reading.

PPCCGT: Δ(±$30k) = **−0.074**, placebo p = 0.49, RI p = 0.72. No jump at the no-stakes unit —
this guard is clean (and moot, since there is no Torrens jump to compare against).

## Step 7 — pessimistic re-run. Committed reading: what survives is hard.

Δ(±$30k) = +0.040, placebo p = 0.668, RI p = 0.502. Identical verdict.

## The mapping to the manuscript, as committed

The jump fails at the registered line. **The design-anatomy framing is final: the regions-task
B/C pattern stays a suggestive fragment, and no payment-sensitivity claim returns from this
task.** The first-class null reads: on the days where the two accounts disagree, the desk's
on/off choice slides smoothly through the point where the direction option starts to out-pay
commitment — the only threshold the data mark is the commercial one (the sit-out rate steps
down 23 points at M = 0, the A/B boundary, per the regions task). Two honest limits attach: R
is measured with error comparable to several window-widths, which attenuates a true jump; and
the one measurement-corrected cut that does show a break sits on 52 days and a flattering
placebo comparison, disclosed above. No manuscript edits under this task.
