# Pre-registration — the exit-act regression under N-1 essentiality

**Written and committed BEFORE estimation. 2026-07-05.** Sequence on record: the N-0 version
ran first and was too thin (20 days / 6 events, `findings_task6_exit_act.md`); the N-1 label
was adopted afterward on the operator's-standard argument (secure N-1 explains 98.4% of
directions); the four checks + Check 4a (`findings_task8_four_checks.md`) passed and their
descriptive content — including the raw below-ordinary N-1 cancellation rate and the
event-not-envelope decomposition — is known at registration time and reflected in the
committed readings below. Both label versions will be shown side by side in the paper.

## Design (fixed)
- **Population:** the Check-4 population — clean Torrens unit-days (Job 2) with a full evening
  on offer in yesterday's midnight stance (all five hourly means 19:00–24:00 ≥ 40 MW). n = 492.
- **Outcome:** evening cancellation (≥1 evening hour crossing from ≥40 to <40 MW, ≥1 MW drop —
  the depth-check case-2 event). Linear probability model.
- **Treatment:** `essential_n1` — the pex_n1 day flag (≥1h rule), rivals-only, leakage-audited.
  Secondary row: the three-tier split (N-1-only and N-0 dummies vs ordinary), N-0 reported as
  counts-supported context only (its cells are 20/6).
- **Controls:** expected running loss (SRMC − previous day's mean realised RRP, the established
  proxy; entered alone and interacted with essential_n1), day-mean demand, non-sync MW, spot,
  competition (day-mean slope + saturated share). Unit and month fixed effects. Cluster month;
  wild cluster bootstrap (Rademacher/Webb, R = 999) on the essential coefficient.
- **HARD RULE:** nothing derived from directions enters — no directed flag, no approach-window
  indicator (defined off subsequent direction starts, which cancellations themselves trigger).
  Essentiality is system-conditions-only by construction.
- Suspension days excluded (established June-2022 handling). Reported with and without the
  loss control.

## Committed readings (written with Check 4a on the record)
1. **Positive, significant essential_n1 coefficient surviving the loss control:** the exit act
   tracks the conditions that trigger directions beyond loss-avoidance — the strongest
   behavioural statement this data allows. WHY stays unknowable (payment and weather share a
   clock).
2. **Null or negative essential_n1 coefficient:** consistent with the descriptive record
   (Check 4a: the act is event-timed, not envelope-timed; within-window the envelope adds
   nothing positive). Reading: the standing-state account holds at the individual-decision
   level — the envelope does not provoke exits; exits cluster into the direction run-up, and
   whether THAT clustering is loss-avoidance is answered by the loss control's own
   coefficient, reported alongside. A negative point estimate is NOT read as "essentiality
   retains" without surviving inference the same way a positive would have to.
3. **Loss control absorbs everything (essential null, exp_loss strongly predictive):** the
   innocent reading confirmed at the level of individual decisions — cancellations are
   loss-calendar events; directions catch them.
Whichever applies is quoted verbatim in the findings; no post-hoc blending.
