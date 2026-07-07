# Registration: the boundary test, rebuilt on the desk's actual numbers

**Date: 2026-07-08, saved before any estimation code exists for this task.** Author's text
verbatim below; dated provenance note follows. Findings map to
`Direction_clean/outputs/10_boundary_test/` (`boundary_final_support.md`,
`boundary_final.md`; the earlier test's files are the pre-correction version).

---

Task: The boundary test, rebuilt on the desk's actual numbers

What we're doing and why.
The earlier boundary test asked whether the desk's daily on/off choice jumps at the point where
the direction option starts to out-pay running the unit. It found no jump — but the profit
measure it used was a stand-in: yesterday's prices in place of a forecast, and no start-up
costs. Both substitutions were made because the right inputs didn't exist in the pipeline at
the time. They do now: the propensity workstream extracted the final-run PREDISPATCH forecast
prices the desk sees, and Step 5 surfaced the start-cost primitive ($47k per start, median
committed run 1.3 days).
This task rebuilds the payoffs on those inputs and asks the same question with the measurement
the desk actually faces. The previous null and the Step-5 corrected-line jump are equally live:
the null may have been real, or an artifact of a profit measure whose noise (~$86k MAE) was
roughly three times the examination window ($30k). This test is built to distinguish them, and
either answer is a finding the paper uses.

The rebuilt payoffs.
Running profit, M_d: floor output × (forecast price − fuel cost), summed over the day — with two
changes from before. Prices are the final-run PREDISPATCH forecasts in force at bid-formation
time, not yesterday's realized prices. And start-up cost enters the base construction, not a
robustness row: charge $47k per start, amortized over the median committed run (1.3 days →
$35.6k/day; record the exact amortization rule in the dated note before running). This moves
the commercial break-even from "price above fuel" to where the desk actually experiences it.
Option value, V_d: unchanged — direction probability (day-ahead, rivals-only π) × expected
episode length × floor × the direction payment margin.
The line: R_d = V_d − M_d. The question, as before: does the sit-out rate jump where R crosses
zero?

Order of work.
Step 0 — support first. Compute R for all Torrens clean unit-days and PPCCGT. Write the
histogram and near-zero day counts to findings/boundary_final_support.md before touching any
outcome data. Gate: at least 60 pooled Torrens days within ±$30k of zero; if it fails, report
descriptively and stop. Also report the new measurement-noise estimate: with real forecasts,
the forecast-error component should shrink substantially — state the remaining MAE so the
result is read against the right blur, whichever way it goes. Fix the window width from the
histogram in the dated note before Step 1. If near-zero days cluster in a few months, declare
in the same note which inference (placebo-line or within-month permutation) is primary — before
Step 2 runs.
Step 1 — the picture. Binned sit-out rate against R for the Torrens pool, $10k bins. This is
the exhibit; everything after is discipline around it.
Step 2 — the jump. Δ = sit-out rate just above zero minus just below, at the fixed window plus
two sensitivity widths. Local means only — no polynomials; the cells won't support them.
Step 3 — is the line special? Recompute Δ at 199 placebo crossings across R's interior support
(excluding the window around the true zero); the p-value is the real |Δ|'s rank among them.
Within-month permutation (999 draws) as the supplement, unless Step 0's note demoted it.
Step 4 — the proximity guard. Days where the option wins are disproportionately direction-close
days (high π, N−1); a jump could reflect the state, not the payoff. Recompute Δ within
π-terciles and within N−1 strata, so days on either side of the line are equally close to a
direction and differ only in which payoff wins. Strata under 15 days a side: descriptive only.
Step 5 — the negative control. Identical battery on Pelican Point, which is rarely directed and
runs commercially. Whatever pattern Torrens shows, PPCCGT is the reference for whether it's
about the direction money.
Step 6 — the commercial threshold, same construction. Report the sit-out contrast at M_d = 0
under the rebuilt M_d. With start costs priced, the commercial break-even has moved — the
23-point cliff from the regions task should relocate accordingly. This gives the paper both
thresholds measured on the same footing: where the commercial line bites, and whether the
option line bites.

Committed readings — every outcome written up with the same care.
- Jump at the crossing, survives the placebo test and the proximity guard, absent at Pelican
  Point: the commitment choice tracks the direction option's payoff ranking — the payment
  enters the daily decision. The behavioral claim returns to the paper in its boundary form,
  stronger than the original headline: it predicts the dose nulls rather than contradicting
  them, and it rests on the desk's own information set. Origin disclosed (prompted by the
  Step-5 observation, confirmed on independently rebuilt measurement).
- Jump present but collapsing within proximity strata: the response is to the
  direction-adjacent state, not the payoff ranking; reported as such, with the distinction
  spelled out.
- No jump: the daily choice tracks the commercial margin only, and the direction payment does
  not detectably enter it. With measurement on the desk's own inputs, this is the informative
  null the previous test couldn't deliver.
- Jump at Torrens and at Pelican Point both: the pattern is not specific to the direction
  channel; reported as such, whatever it does to either story.
- Gate failure or degenerate strata: a support limit, reported with the descriptive picture.

Constraints. No estimation before the support report is on disk. New construction limited to
the rebuilt M_d from existing pipeline assets (PREDISPATCH extracts, Aurecon/ISP primitives).
Findings files only; no manuscript edits from this task. Anything contradicting prior outputs —
including the earlier boundary test's day sets and the regions task's region assignments, some
of which will move under the new M_d — is flagged with the size of the movement, not silently
reconciled. When both versions exist, the manuscript uses the rebuilt construction and cites
the earlier one as the pre-correction version.

---

## DATED PROVENANCE NOTE (2026-07-08, before estimation; completed with window/inference
## choices after the Step-0 support report, before Step 1)

1. **The forecast prices required a new pull, and their timing is flagged.** The propensity
   workstream extracted PREDISPATCH REGIONSUM (demand) and LOAD (unit availability) — not the
   price table. `PREDISPATCHPRICE_D` (final-run regional RRP, SA1) is being extracted now with
   the same machinery (licensed: "new construction limited to the rebuilt M_d from existing
   pipeline assets (PREDISPATCH extracts…)"). **Timing caveat, stated plainly:** the final run
   for interval t occurs ~30 minutes before t — during day d, hours after bid formation. The
   bid-formation-time forecast runs are exactly the all-runs data the public archive does not
   retain (established in the propensity Stage-0 gate). The rebuilt M_d therefore measures the
   day's economics at minimum blur — the registration's stated purpose — but it is a
   just-before-delivery measure, not strictly the desk's day-ahead information set, and
   final-run prices partially embed the day's realized fleet posture (the same direction, more
   mildly, as the earlier task's flagged-endogenous realized-price row). Both the low-blur
   virtue and the timing vice are carried into the write-up.
2. **Amortization rule, exact:** start charge per committed day = $47,000 ÷ (median committed
   run length in days, computed from the cached TORRB DISPATCHLOAD commitment spells,
   `torrens_run_lengths.rds`) — the identical constant as the earlier Step 5 (recorded there as
   $35,621/day; the exact cached value is re-read at run time, not retyped). M_d = 24 h ×
   floor × (day-mean final-run PD price − SRMC) − start charge. SRMC = the panel's as-built
   marginal (quarterly-step gas), unchanged from the regions task.
3. **V_d unchanged** from the regions task (π_da day-accumulated × H̄ = 11.8 h × floor ×
   (0.95·d_t − SRMC)).
4. Window width and primary inference: **fixed after the Step-0 support report, entered below
   before Step 1 runs.**

### Completed after Step-0 support (2026-07-08, before Step 1)

- **Window w = $30k retained** (171 pooled Torrens days inside; ±$20k holds 105 and would thin
  the cells; sensitivities at $20k/$50k as registered).
- **Near-zero clustering is moderate** (22 months, top-3 hold 40%): the placebo-line rank test
  is primary (as in the pre-correction test), within-month permutation stands as supplement.
- **Measurement-noise surprise, flagged rather than absorbed:** the day-mean MAE against
  realized prices ROSE under the rebuilt input ($148.6 vs $84.9; ~$160k vs ~$86k of dollar blur
  at the Torrens floor). Cause: final-run half-hourly PD forecasts do not carry the 5-minute
  price spikes, and spikes cluster across adjacent days, so yesterday's realized profile tracks
  realized outcomes more closely. Whether M_new is the better *decision* measure depends on
  whether the desk's expectation is spike-inclusive; the write-up reads the result against both
  blurs, per the registration's "whichever way it goes."
- **Region movement flag (constraint):** 20.6% of Torrens and 24.2% of PPCCGT clean days change
  region under the rebuilt M; 111 of the old 136 region-B days move to region A once start
  costs are priced (cross-tab in the step-0 log). The rebuilt construction supersedes; the
  regions task remains the pre-correction version.
