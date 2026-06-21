# Why is a directed unit non-pivotal? — institutional grounding

**Date:** 2026-06-20 · Companion to facts_memo [F17] and `pivotality_readout.md` ("Why are non-pivotal units directed?").
**Question:** under AEMO's direction power, why is a unit directed when, by our system-strength pivotality measure, removing it alone does not breach the standard?

The short answer: **AEMO's direction power is broader than our pivotality measure by construction.** Pivotality asks one narrow counterfactual — "does the *system-strength fault-level* standard break if this one station goes offline *right now*, under the `system_normal` regime, given the realised online fleet?" AEMO's directions answer a wider question — "what must be committed to keep the system in a secure operating state, against credible contingencies, across the coming hours, for system strength *and* inertia *and* voltage?" Six distinct reasons follow, each grounded below in AEMO/AEMC documentation and cross-checked against our own data.

---

## 1. The requirement is a minimum *combination/count*, not a named unit — so the marginal directed unit is rarely individually essential

The SA security standard is "a complex suite of **51 combinations involving 16 generating units across seven power stations**" (AEMC 2019); our `sa_minimum_generator_combinations.csv` encodes the current version (122 combinations across non-sync tiers and regimes). The standard is satisfied if the online fleet matches **≥1** acceptable combination. When several units could each fill the last required slot, **none is individually pivotal**, yet AEMO must still direct one of them on. Unit selection among substitutes is **operational discretion** — the documents specify no algorithmic preference.

*In our data:* this is the verified "individual vs collective pivotality" driver ([F17] driver 2). Peakers QPS5/Mintaro are directed yet have per-direction hit-any 0.31/0.49 and ex-ante pivotality ≈0 — they are the swing unit AEMO picks from a feasible set, not a uniquely-needed unit. **Source:** [AEMC 2019, Investigation into intervention mechanisms and system strength](https://www.aemc.gov.au/sites/default/files/2019-04/Investigation%20into%20intervention%20mechanisms%20and%20system%20strength%20in%20the%20NEM%20-%20FINAL%20for%20publication%20040419.pdf).

## 2. AEMO commits to a forward-looking *secure operating envelope*, not the realised instant

Directions "enforce a forward-looking security standard, not just instantaneous conditions" — AEMO applies **credible contingencies** (e.g. the trip of the largest unit or an interconnector) and typical forecast dispatch patterns. A unit directed so the system stays secure *against a contingency that did not eventuate* is, ex-post, non-pivotal in our realised-state measure. This is the operational meaning of the "satisfactory/secure operating state" obligation behind NER 4.8.9.

*In our data:* this is why per-direction hit-issue (0.53 for TIB) sits below per-direction hit-any (0.70) and far above the spell-average fraction pivotal (0.40) — many directions are precautionary at issue and only bind (if at all) later. **Source:** AEMC 2019; [AEMO Procedures for issue of Directions and Clause 4.8.9 Instructions (SO_OP_3707)](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/power_system_ops/procedures/so_op_3707-procedures-for-issue-of-directions-and-clause-4-8-9-instructions.pdf).

## 3. The **islanding contingency** imposes a minimum even when interconnected conditions are slack — and our measure excludes it

If SA separates from the NEM (a Heywood trip at high flow is "the most significant event for the region"), the islanded system needs far more local synchronous support. AEMO's standing requirement has been that **"two or more generating units must remain online if South Australia is islanded"** until Project EnergyConnect Stage 2 + a special protection scheme are in place. This binds *pre-emptively*, under interconnected conditions where the `system_normal` fleet looks comfortable.

*In our data — directly verifiable and partly self-inflicted:* the combinations file has **122 combinations, of which we use only the 79 `regime == system_normal`** ones; the **43 `risk_island_or_island` combinations (42 `secure_for_island = TRUE`)** are *excluded by assumption* in `pivotality.R`. The islanding combinations are stricter (require more synchronous units), so a unit directed to satisfy islanding-security is mechanically flagged **non-pivotal** by our measure. **This is the most actionable item:** recomputing pivotality with the risk-island combinations active during high-Heywood-flow / islanding-risk intervals is expected to raise P(pivotal | directed). **Source:** AEMO/WattClarity on Heywood + islanding; the `secure_for_island` column in our own combinations file.

## 4. Directions cover services our measure does not encode — **inertia** and **voltage/reactive support**

System security rests on three "interconnected but separate" services, each with its own framework: (i) **system strength / fault level** — what our pivotality measures; (ii) **inertia** — rotational energy limiting RoCoF, the subject of a *declared SA inertia shortfall* (Aug 2020), acute under islanding; (iii) **voltage and reactive support** — ongoing, and *locational* (a unit may be directed to hold voltage in metro Adelaide regardless of fault level). A unit directed for inertia or local voltage is non-pivotal on the fault-level combinations by construction.

*In our data:* the 2024 **"System security - voltage"** reason label (151 events) is exactly this — directions for a service our measure does not represent. (Note the empirical wrinkle from [F17]: those voltage directions are *more* pivotal, not less, because they fall on the same large machines that also provide strength — so the reason field cannot cleanly separate the services.) **Sources:** [AEMO 2024 System Strength Report](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/system_security_planning/2024-system-strength-report.pdf); [AEMO 2024 Inertia Report](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/system_security_planning/2024-inertia-report); [WattClarity, AEMO's notice of Inertia Shortfall in SA (2020)](http://www.wattclarity.com.au/articles/2020/08/aemos-notice-of-inertia-shortfall-in-south-australia/).

## 5. AEMO carries operational margin and locational cover — it directs *more* units than the bare arithmetic minimum

Even within the fault-level standard, AEMO directs extra units for: **contingency margin** (so security survives a *directed* unit itself tripping), **locational effectiveness** (geography changes how much voltage support a unit actually provides), and **dispatch flexibility** (room to load-follow while holding the minimum). The "remove exactly one unit" counterfactual in our pivotality test understates the buffer AEMO actually holds.

*In our data:* consistent with the modest gap between per-interval (0.65) and per-direction (0.70) hit rates for TIB and the substitutable-peaker pattern — AEMO keeps headroom rather than running to the knife-edge our measure tests. **Source:** AEMC 2019.

## 6. Lumpiness: minimum run times and multi-hour spells

Synchronous plant cannot be cycled every 5 minutes (start-up, minimum-up-time, ramp). AEMO issues a direction as a **spell** covering the forecast at-risk window; once committed, the unit stays directed through surrounding intervals whose realised state is no longer pivotal. Directions in our data run a median 9.0 h (mean 18.7 h).

*In our data:* the verified spell-dilution driver ([F17] driver 1) — a typical TIB direction is pivotal only ~40% of its duration. **Source:** `direction_events` spell durations; AEMC 2019 (directions "in place 30% of the time on average" in 2018 — persistent, not momentary).

---

## How this reframes the research

1. **Non-pivotal-but-directed is the expected behaviour of the institution, not an anomaly.** Pivotality (narrow, fault-level, realised-instant, `system_normal`) is a *subset* of the secure-envelope question AEMO answers. P(pivotal | directed) < 1 is mechanical.
2. **Our measure has two fixable gaps that account for a real share of it:** excluded `risk_island` combinations (reason 3) and the un-modelled inertia/voltage services (reason 4). The first is testable inside our data.
3. **For the strategic-withholding design this is reassuring, not threatening.** The behavioural results ([F14]–[F16]) condition on the *pivotal state* (incl. the exogenous ex-ante measure and the continuous non-sync driver), not on direction incidence. The reasons above explain why the *direction* set is broader than the *pivotal* set; they do not contaminate the test of whether units withhold more *when pivotal*.

## Next steps (optional, in priority order)

- **[high-value, in-data] Risk-island robustness.** Define an islanding-risk flag (e.g. high Heywood import / specific market-notice conditions) and recompute pivotality with the 43 `risk_island_or_island` combinations active on those intervals. Expected to raise P(pivotal | directed) and quantify reason 3.
- **[medium] Model the syncon count by month** (combinations need `syn_cons` ∈ {0,2,4}; we assume 4 throughout) — also fixes the 2021 problem flagged in [F17].
- **[scoping] Inertia/voltage** are separate frameworks with their own data (AEMO inertia requirement; reactive plant) — encoding them is a project of its own; for now treat reason 4 as a documented, unquantified component.

## Sources

- [AEMC (2019), Investigation into intervention mechanisms and system strength in the NEM](https://www.aemc.gov.au/sites/default/files/2019-04/Investigation%20into%20intervention%20mechanisms%20and%20system%20strength%20in%20the%20NEM%20-%20FINAL%20for%20publication%20040419.pdf) — 51 combinations / 16 units / 7 stations; three services; secure envelope; why more than minimum; 30%-of-time figure.
- [AEMO, Reduction of minimum synchronous generators in South Australia](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/congestion-information/related-resources/reduction-of-minimum-synchronous-generators-in-south-australia.pdf) — the minimum-combinations framework; 4→2→1 evolution as syncons/EnergyConnect arrive.
- [AEMO, SO_OP_3707 — Procedures for issue of Directions and Clause 4.8.9 Instructions](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/power_system_ops/procedures/so_op_3707-procedures-for-issue-of-directions-and-clause-4-8-9-instructions.pdf).
- [AEMO, 2024 System Strength Report (Feb 2025)](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/system_security_planning/2024-system-strength-report.pdf).
- [AEMO, 2024 Inertia Report (Dec 2024)](https://www.aemo.com.au/-/media/files/electricity/nem/security_and_reliability/system_security_planning/2024-inertia-report).
- [WattClarity (2020), AEMO's notice of Inertia Shortfall in South Australia](http://www.wattclarity.com.au/articles/2020/08/aemos-notice-of-inertia-shortfall-in-south-australia/).
- [RenewEconomy — history of AEMO directing a minimum number of SA gas units from ~2017](https://reneweconomy.com.au/the-response-to-south-australias-blackout-started-with-a-tweet-and-became-a-revolution-on-the-grid/).
