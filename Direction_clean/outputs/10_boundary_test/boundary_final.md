# The boundary test on the desk's numbers — no jump at the option line; a cliff at the commercial line

Registration: `10_boundary_test/registration_final.md` (+ dated provenance note, completed
pre-Step-1). Scripts `step0_final_support.R`, `boundary_final_battery.R`; outputs
`boundary_final_support.md`, `final_step*_*.csv`; logs on disk. The earlier boundary test is
the pre-correction version and is superseded by this construction, per the registration.

**What changed in the measurement.** M_d now uses the final-run PREDISPATCH day-mean price
(newly extracted, 37 months, complete) and carries the start charge in the base construction
($47,000/start ÷ 1.319-day median committed run = $35,621/day, exact cached value). Two flags
from the dated note travel with every number: (i) final-run PD prices form ~30 minutes before
delivery — the true bid-formation-time forecast runs are not publicly retained — so this is a
minimum-blur, not strictly day-ahead, measure; (ii) the day-mean MAE against realized prices
*rose* ($148.6 vs $84.9; ~$160k vs ~$86k of dollar blur at the Torrens floor) because
half-hourly forecasts miss 5-minute spikes that cluster across adjacent days. The null below is
informative against a smooth-expectation desk; against a spike-inclusive expectation the blur
caveat stands. (iii) Movement flag: 20.6% of Torrens and 24.2% of PPCCGT days change region
under the rebuilt M; 111 of the regions task's 136 region-B days move to region A once starts
are priced — the discriminating cell shrinks to 67 days on the desk's own break-even.

## Step 0 — support

Gate passes: 171 pooled Torrens clean days within ±$30k of the rebuilt R = 0 (threshold 60);
clustering moderate (top-3 months 40%); w = $30k and placebo-primary fixed in the note.

## Steps 1–3 — the picture, the jump, the placebo rank. Committed reading 3 applies.

The binned sit-out rate is flat through the crossing. At the line:

| window | n below | n above | rate below | rate above | Δ |
|---|---|---|---|---|---|
| ±$20k | 43 | 62 | 0.465 | 0.403 | −0.062 |
| ±$30k | 64 | 107 | 0.469 | 0.467 | **−0.001** |
| ±$50k | 93 | 244 | 0.462 | 0.496 | +0.034 |

Placebo-line rank: **p = 0.968** (189 lines). Within-month permutation: **p = 0.994**. The
crossing where the direction option starts to out-pay commitment is one of the least
distinguished points in R's support. **No jump — the committed informative null:** the daily
on/off choice tracks the commercial margin only; the direction payment does not detectably
enter it, measured on the inputs the desk faces with the start-cost break-even priced in.

This also settles the pre-correction Step-5 wrinkle: the corrected-line break (Δ = +0.203 on 52
days, placebo p = 0.010) **does not reappear** on independently rebuilt measurement. It is
adjudicated an artifact of the ad-hoc haircut's small cells, as the honesty rule anticipated.

## Step 4 — proximity guard (moot, reported)

Strata Δs are sign-unstable (−0.009, −0.012 descriptive, +0.087, −0.142) — noise around a null.

## Step 5 — the negative control

PPCCGT: Δ(±$30k) = +0.051, placebo p = 0.509, RI p = 0.645, and a near-zero sit-out base rate
in the window (3–8%). Clean.

## Step 6 — the commercial threshold on the same footing

With starts priced, only 314 of 1,744 Torrens clean days (18%) are commercially profitable at
the floor. The commercial contrast is the one the data mark: sit-out is **73.7%** on
unprofitable days against **40.8%** on profitable days globally — a 33-point cliff — with a
gentler local step at the break-even itself (+0.054/+0.074/+0.106 at the three windows). The
regions task's 23-point cliff at raw M = 0 relocates and steepens under the rebuilt M, exactly
as a commercially-governed commitment rule implies.

## The mapping to the manuscript, as committed

Reading 3: **the daily choice tracks the commercial margin only.** The behavioral claim does
not return in boundary form; the pre-correction test's suggestive fragment is closed as an
artifact; and the paper gains a clean two-threshold fact measured on one footing — the
commercial line bites (33 points), the option line does not (−0.001, placebo p = 0.97). Signed
context for any quotation: M_d's remaining blur is ~$160k/day against a $30k window under the
spike-inclusive reading, so "no detectable entry" is the precise claim; and the same-clock
caveat (§7 fn 14) continues to bar any daily-intent language in either direction. No manuscript
edits under this task; when the manuscript cites a boundary construction, it cites this one,
with the earlier test as the pre-correction version.
