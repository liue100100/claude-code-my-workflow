# Research Question & Identification — for sign-off

**Status: DRAFT awaiting your sign-off. No proposal prose until you approve.**

---

## 1. Research question

> **When the directed price d_t rises, do South Australian synchronous generators — Torrens Island B above all — shift capacity out of the dispatchable offer stack to raise the probability of being directed on and collecting d_t; and does that shift scale with the size of d_t?**

The object of interest is a **slope**, not a level: not "do these units withhold" (they chronically do — withheld_share sits at the ceiling, [F6]) but "does the *intensity* of withholding move with the predetermined prize." The mid-2023 window-exit halves d_t from a predetermined source ([F1]), giving within-unit variation in the prize while marginal cost stays flat ([F3]).

**Why it is identified at all:** the prize d_t is a trailing-365-day price percentile, so it is predetermined relative to today's bid ([F1]); AEMO's decision to *issue* a direction is driven by system security, not by the rent (volume–margin corr 0.167, peaks offset, directions even when margin is negative — [F11]). The firm chooses its offer stack; AEMO chooses whether security binds. That separation is the design.

---

## 2. Outcome and treatment variables

- **Primary outcome:** `withheld_share` = MW in price bands above SRMC_marginal / MAXAVAIL, per DUID × 5-min interval ([F8]). SRMC built from STTM Adelaide gas × AEMO heat rates + Aurecon VOM ([F3]).
- **Secondary outcomes:** offline-but-available indicator [G4]; rebid intensity per unit-day [G5]; offer-price level near the cap.
- **Prize:** d_t, monthly, predetermined ([F1]).
- **Treatment timing:** Synchronise vs Remain interval flags ([F12]); Synchronise is the withhold-then-directed margin, Remain the keep-running placebo.

---

## 3. Design 1 — Event study on the d_t window-exit

Within-treated event study of `withheld_share` (and secondary outcomes) on event-time relative to the mid-2023 exit (202307), SA synchronous units only, unit and calendar-time fixed effects, d_t entered as the continuous predetermined regressor.

- **Identifying assumption:** absent the d_t decline, treated units' withholding intensity would have evolved in parallel with its own pre-exit trend — i.e. the only thing changing discontinuously at the window-exit for these units is the predetermined prize, not cost ([F3]) or the compensation *formula* (unchanged 2021–2024; the Aug-2022 method change is a year earlier and on the affected-participant limb, footnote).
- **Main threat:** a confounder that moves with d_t's roll-off — most sharply, the 2022 gas/price regime, since high d_t and high SRMC and high spot all coincide in 2022. Raw slopes are sign-flipped by exactly this ([F7]).
- **Test / robustness that addresses it:**
  1. Control SRMC and native 5-min spot; the d_t slope survives both and the sign reverses to positive only once SRMC is partialled out ([F8]) — direct evidence the threat is the price regime and that conditioning removes it.
  2. Pre-trend test on event-time leads; flag if leads are jointly non-zero.
  3. Placebo: **Remain**-directed intervals (already-running units) should show a weaker/no slope than **Synchronise** intervals if the channel is withhold-to-be-directed, not mechanical constrained-on bidding ([F5] shows both rents positive; the behavioural slope is the discriminator).
  4. Drop June-2022 (administered-price regime, [F1] caveat).

---

## 4. Design 2 — Triple-difference: d_t × pivotality × requirement-active

Headline causal design. The withholding-to-be-directed channel should bite **hardest where the firm can actually swing the outcome**: where the unit is pivotal to meeting a *binding* security requirement. Triple interaction of the predetermined prize d_t with (a) unit pivotality and (b) an active-requirement indicator.

**Pivotality is now built and validated ([F13]–[F16]) — and the core comparison already supports the design.** System-strength pivotality from AEMO's minimum-generator-combinations standard; realised and **ex-ante** (rivals'-availability) variants. Pivotal units withhold +11–14 pp more, robust to the ex-ante measure and to exogenous non-sync variation ([F14]); the effect is a *level* (pivotality state), not a d_t slope ([F15]); and pivotal units actively rebid to withdraw ~39 MW intraday ([F16]). The remaining estimation step is to interact this with the predetermined d_t and formalise inference.

- **Identifying assumption:** conditional on the two-way interactions and FEs, the *differential* response of withheld_share to d_t — across pivotal vs non-pivotal units when a requirement is active vs not — is not driven by any other factor that varies along the same triple margin. The third difference differences out any d_t-correlated shock common to a unit-period (absorbed by the lower-order terms), so a remaining confounder must itself be triple-interacted with prize × pivotality × requirement.
- **Main threat:** pivotality is **endogenous to withholding** — a unit becomes pivotal partly by withholding (withhold → directed → online → incumbency-pivotal). *Addressed:* the **ex-ante measure [F14]** computes essentiality from rivals' availability only (excludes the unit's own status) and gives a *larger* effect (+14 pp, t 3.0); the continuous **non-sync penetration** driver (weather-driven, exogenous) independently predicts withholding (t 8.6); and the level effect survives restriction to undirected, market-facing intervals.
- **Test / robustness that addresses it:**
  1. **DONE** — ex-ante pivotality (rivals-availability) + non-sync penetration as the exogenous instruments for being pivotal ([F14]); RSI variant remains optional.
  2. Define "requirement-active" from AEMO's stated security need (`reason` field → interval-level flag [G2]) as an independent cross-check on the pivotality+non-sync proxy.
  3. Report the triple-diff with pivotality measured at t−1 (lagged) to break contemporaneous simultaneity.
  4. Falsification: the triple-difference should be ~zero for Remain events and for non-synchronous (wind/solar) units, which cannot execute the offline-to-directed channel. (Cross-unit evidence already consistent: peakers are ~never pivotal and show no pivotal-withholding response — [F13]/[F14].)

---

## 5. Inference

Few clusters in every dimension: 35 months ([F8]), 11–12 DUIDs ([F9]), ~13 treated units. Analytic cluster-robust SEs are unreliable here. **Wild-cluster bootstrap** (Cameron-Gelbach-Miller [CITE]) on the treated-unit / month dimension is the primary inference; report Webb weights and the small-cluster correction. This is a methodology commitment, not yet run ([G8]).

---

## 6. What must be built before estimation (from the gaps)

| Need | Gap | Status |
|---|---|---|
| Pivotality (realised + ex-ante) | [G1] | **DONE** ([F13]–[F16]) |
| Requirement-active flag from `reason` (cross-check) | [G2] | Partly done (pivotality+non-sync proxy); `reason` flag open |
| Rebid intensity + quantity-withholding | [G5] | **DONE** ([F16]) |
| Within-treated event study on rebuilt outcome | [G3] | Open — blocks Design 1 |
| Offline-but-available indicator | [G4] | Open — mechanism/outcome |
| Wild-cluster bootstrap harness | [G8] | Open — all inference |
| Rebid price-band escalation | [G9] | Open — sharpens [F16] |

A Torrens-B-isolated series [G6] and dollar-rent merge [G7] strengthen the narrative but do not block the two designs.

---

## 7. Open choices for you

1. **Focal framing:** lead with Torrens Island B specifically [G6], or the SA synchronous fleet with TIB as the salient case? (Heterogeneity [F10] is mixed *within* TIB — TORRB2/3 positive, TORRB4 negative — so a TIB-only headline is not yet clean.)
2. **Primary outcome:** keep `withheld_share` (SRMC-relative) as headline, or elevate the offline-but-available indicator [G4] as closer to the literal mechanism?
3. **Triple-diff third leg:** requirement-active from `reason` as proposed, or a continuous tightness/reserve-margin measure instead?

**→ Sign off on the RQ wording, the two designs, and items 1–3, and I'll build `proposal.md` in your specified order.**
