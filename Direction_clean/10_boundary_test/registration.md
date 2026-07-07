# Registration: the jump test at the crossing line (daily on/off choice vs which payoff wins)

**Date: 2026-07-07, saved before any estimation code exists.** Author's text verbatim below.
Post-hoc status disclosed in the text itself (hypothesis formed after four earlier results;
this task gives it prospective predictions). Findings paths map to
`Direction_clean/outputs/10_boundary_test/`.

---

Task: Test whether the desk's daily on/off choice tracks which payoff wins — a jump test at the
crossing line

Read this first — what we're testing and why.
Every clean day, the desk faces a choice: commit the unit (earn the running profit, M_d — market
price minus fuel, at floor output, already built in the pipeline) or rest it (earn nothing
unless directed, in which case the expected payout is V_absent,d — the direction probability
times what a direction pays, also already built).
Two stories predict different behavior. The commercial story: the desk only asks "does running
make money?" — the direction payout never enters. The payment-seeking story: the desk compares
the two payoffs and rests whenever the option beats the profit, even on profitable days.
These stories agree almost everywhere. They disagree on exactly one kind of day: running is
profitable, but the direction option is worth even more. So the test is: sort all days by the
gap R_d = V_absent,d − M_d, and look at the sit-out rate right around R = 0, the point where the
option starts to beat the profit. A jump in the sit-out rate at that line = the desk weighs the
direction money in the daily choice. Behavior sliding smoothly through the line = it doesn't,
and the only threshold that matters to them is the commercial one (M = 0).
Important context: this hypothesis was formed after seeing four earlier results (it explains why
the dose-response tests were null — an on/off chooser has no volume knob to detect). This task
exists to give the story predictions it can fail prospectively. Treat a "no jump" result as a
first-class finding, written up with the same care as a positive.
One honesty rule for the whole task: the story only earns confirmation if the jump (a) exists,
(b) sits at the real line and not at arbitrary ones, (c) isn't just "direction-heavy days look
different," (d) follows the line when we correct the payoff measurement, and (e) doesn't appear
at the unit that has no direction money at stake. Failing any one of these is reported as that
check failing — no averaging, no rescuing.

Step 0 — before anything else, report where the days sit.
Compute R_d for every Torrens clean unit-day (pooled across TORRB2/3/4) and for PPCCGT, base and
pessimistic calibrations, using the regions task's constructions unchanged. Write a support
report to findings/boundary_support.md: a histogram of R in $10k/day bins, and the count of
Torrens days within ±$20k and ±$30k of zero.
Gate: if fewer than 60 pooled Torrens days sit within ±$30k of zero (base calibration), stop
after descriptive output — binned sit-out rates only, no jump estimate, no inference — and state
plainly that the boundary can't be tested in this sample because almost no days sit near the
line. The gate firing is a finding, not a failure.
Also settle two choices from the support report, before any outcome data is touched, and record
them in a dated note: the window width w (default $30k; adjust only if the histogram shows R's
natural scale is clearly different, and say why), and whether near-boundary days cluster in a
few months (if so, the within-month permutation below will be degenerate — declare the
placebo-line test the primary inference now, in the note, not after seeing results).

Step 1 — the picture.
Binned sit-out rate against R for the Torrens pool: for each $10k bin, the share of days the
unit was rested (day-ahead stance, floor out of reach all day — the existing Task-2 measure).
Save the plot data. This picture is the exhibit; everything after is discipline around it.

Step 2 — the jump.
Δ = (sit-out rate on days with R in (0, +w]) minus (sit-out rate on days with R in [−w, 0]). The
payment-seeking story predicts Δ > 0. Report Δ at w = $20k, $30k, $50k. Just local means — do
not fit polynomials; the cells won't support them.

Step 3 — is the line special? (placebo lines)
Recompute Δ at 199 fake crossing points spread across the interior of R's support (excluding ±w
around the true zero). The p-value is where the real |Δ| ranks among the fakes. This asks
exactly the right question: does the sit-out rate jump at the payoff crossing, or would any
arbitrary cut in R show a similar contrast? Supplement with randomization inference permuting
days within month (999 draws) unless Step 0's note demoted it.

Step 4 — or are option-wins days just direction-heavy days? (the bundling guard)
Days where the option wins are mostly days when a direction is close (high π, N−1). The desk
might rest on those days for state reasons that have nothing to do with money. So: recompute Δ
within π-terciles and within N−1 strata — comparing days equally close to a direction that
differ only in which payoff wins. If Δ collapses once proximity is held fixed, the jump was
state-dependence wearing a payoff costume; say so. Any stratum with fewer than 15 days on either
side of the line is descriptive only.

Step 5 — does the jump follow the line? (the measurement guard)
Our running profit M_d is deliberately generous (no start costs, yesterday's prices as the
forecast), and it's most generous exactly on the high-renewables days that sit near the line —
so some "profitable" days weren't really, and a fake jump can be manufactured by that
mismeasurement. Fix a haircut before running this step and record it: a start-cost charge per
committed day (take the Aurecon/ISP primitive, amortize over the median run length; if the
primitive gives a range, take the midpoint and note the range) plus a forecast-error penalty
(the unit-month mean absolute error of the previous-day price profile). Recompute R with the
haircut, re-find the zero, re-estimate Δ at the new line. A real behavioral threshold moves with
the true payoffs: the jump should re-center at the new zero. A jump that stays glued to the old
zero after reclassification is an artifact of the original construction — report it as one.

Step 6 — the unit with nothing at stake.
Run the identical battery on PPCCGT. It's rarely directed and runs commercially — if it shows a
Torrens-sized jump, the "this is about the direction money" reading breaks, and that gets
reported, not footnoted.

Step 7 — the pessimistic re-run.
Repeat Steps 1–3 under the pessimistic calibration from the regions task. Whatever survives is
hard; whatever attrits is reported without rationalization.

Write-up. findings/boundary_test.md, plain declarative prose. Lead with the Step 1 picture and
the Step 0 support facts. Then the jump, the placebo rank, and each guard in order, each with
its committed reading stated before its number. Close with one paragraph mapping the outcome to
the manuscript: all checks pass → the payment-sensitivity claim returns as "the commitment
choice tracks the sign of the direction option against the commercial margin, at the directed
station only" (with the post-hoc disclosure attached); the jump fails or any guard fails → the
design-anatomy framing is final and the regions B/C pattern stays a suggestive fragment. Signed
biases restated wherever a number could be quoted alone.

Constraints. No estimation before the support report exists on disk. No new data construction
beyond the two haircut inputs. Findings files only — no manuscript edits from this task.
Anything contradicting prior pipeline outputs (day sets, floors, π, durations) is flagged, not
silently reconciled.
