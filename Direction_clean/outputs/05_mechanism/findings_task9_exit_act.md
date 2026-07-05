# The registered exit-act regression under N-1 essentiality

Pre-registration `task9_preregistration.md`, committed before estimation. Sample: 473 clean
Torrens evening-on-offer days (492 minus suspension days and FE singletons), 96 essential_n1
days, 107 cancellations. Script `task9_exit_act_regression.R`; table `task9_results.csv`.

## The coefficients

| Model | essential_n1 | WCB p | exp_loss | ess x exp_loss |
|---|---|---|---|---|
| No loss control | **-0.163 (p 0.020)** | **0.017-0.019** | -- | -- |
| With loss control | -0.124 (p 0.068) | 0.058-0.065 | -0.0003 (p 0.005) | -0.0007 (p 0.0006) |
| Three-tier | N-1-only **-0.190 (p 0.004)**; N-0 **-0.001 (p 0.99)** | -- | -- | -- |

## Which committed reading applies (quoted as written)
**Reading 2:** "Null or negative essential_n1 coefficient: consistent with the descriptive
record (Check 4a: the act is event-timed, not envelope-timed; within-window the envelope adds
nothing positive). Reading: the standing-state account holds at the individual-decision level
-- the envelope does not provoke exits; exits cluster into the direction run-up, and whether
THAT clustering is loss-avoidance is answered by the loss control's own coefficient, reported
alongside. A negative point estimate is NOT read as 'essentiality retains' without surviving
inference the same way a positive would have to."

Applying its own caution: the negative coefficient survives inference WITHOUT the loss control
(WCB p 0.017-0.019) and is marginal WITH it (WCB p 0.058-0.065). The clean claim is therefore:
**on days the system is one contingency from needing the unit, the unit is NOT more likely to
cancel an offered evening -- and by the unconditional estimate, 16 percentage points LESS
likely (off a 22.5% ordinary base).** The retention reading ("essentiality holds evenings in
the book") is suggestive at p ~ 0.06 conditionally and is not claimed beyond that.

## The loss control's own answer, reported not smoothed
exp_loss enters NEGATIVE (-0.0003, p 0.005; interaction -0.0007, p 0.0006): cancellations are
LESS likely when the previous day's prices imply running losses, not more. That is the
opposite of the loss-avoidance account of the act's timing (committed reading 3 predicted a
positive sign), so reading 3 is NOT confirmed at the individual-decision level. Caveat carried
from the registration: the proxy is the previous day's DAY-MEAN price against SRMC, which
represents evening-block economics poorly on high-solar days (negative middays drag the mean
while evening peaks stay strong); this was the registered proxy, the limitation stands as
registered, and no re-specification was run after seeing the sign.

## What the paper can now say (one paragraph)
At the level of individual decisions, on clean days, with directions excluded from the design:
the exit act is event-timed (Check 4a), not need-timed (this regression -- the N-1 envelope
if anything RETAINS offered evenings, -0.19 in the newly-added tier vs an exact zero in N-0),
and not loss-calendar-timed (the loss control's wrong sign). Every arrow points the same way:
the evening cancellations that precede directions are not provoked by the security envelope or
by expected losses on the day -- they sit in the direction run-up itself, which is where the
record already located them. The N-0 side-by-side, per the sequence note: 20 days / 6 events,
too thin, reported as counts (findings_task6); this N-1 result is the powered version, and its
sign runs against the strategic-exit reading, not for it.

**STOP -- registered test complete and adjudicated. No follow-ups without a new registration.**
