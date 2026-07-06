# Literature Review: Targeted Bibliography for the SA Directions Paper

**Date:** 2026-07-06
**Query:** Populate Bibliography_base.bib across five clusters for "Paid to Be Absent: Direction Compensation and Capacity Withholding in the South Australian Electricity Market."

## Summary

The paper sits at the intersection of two literatures that rarely meet. The first is the empirical market-power literature in electricity, which measures conduct on the *pricing* margin: markups over marginal cost (Wolfram 1999), decompositions of payments into cost, inframarginal rent, and market-power rent (Borenstein–Bushnell–Wolak 2002), best-response bidding benchmarks (Hortaçsu–Puller 2008), and pivotal-supplier ability/incentive indices (Wolak 2003; McRae–Wolak 2014). Physical withholding appears in this literature as an input to price manipulation (Joskow–Kahn 2002). Our paper's conduct margin is different: availability itself is the strategic object, because the payment channel (direction compensation) rewards *presence under direction*, not energy sold at a price.

The second literature is on out-of-market reliability payments. The closest ancestor is Bushnell–Wolak's analysis of California's reliability-must-run contracts, which documented that the contract form itself created incentives to be designated must-run and distorted bidding — the same design-begets-conduct logic our paper formalizes for AEMO directions under NER 3.15.8. The capacity-mechanism design literature (Cramton–Ockenfels–Stoft 2013; Fabra 2018) supplies the normative framework: when administered payments coexist with energy markets, the payment's *reference price* and *base quantity* determine conduct. Our contribution is a preregistered dose-response test showing withholding responds to the administered compensation price — the signature that separates payment-seeking from ordinary market power.

The Australian institutional cluster (Simshauser 2018 on NEM stability under intermittency; AER/AEMO reports; the NER itself) grounds the setting: South Australia's minimum synchronous requirement, the direction regime it necessitated, and the synchronous condensers whose entry (and the September 2025 requirement cut) bracket the sample.

## Key Papers

### Wolfram (1999) — Measuring Duopoly Power in the British Electricity Spot Market
- **Main contribution:** First systematic markup measurement in a restructured electricity market.
- **Method:** Direct marginal-cost measures plus cost-free markup estimators.
- **Key finding:** Prices above marginal cost but well below theoretical duopoly predictions.
- **Relevance:** The canonical pricing-margin conduct benchmark our availability-margin measure is positioned against.

### Borenstein, Bushnell & Wolak (2002) — Measuring Market Inefficiencies in California
- **Main contribution:** Decomposition of wholesale payments into production cost, inframarginal rent, and market-power rent.
- **Method:** Competitive counterfactual simulation, June 1998–October 2000.
- **Key finding:** Large departures from competitive pricing in high-demand months.
- **Relevance:** Template for our $141.9M-vs-$7.2M direction-channel accounting.

### Hortaçsu & Puller (2008) — Strategic Bidding in the Texas Balancing Market
- **Main contribution:** Structural benchmark of profit-maximizing bidding in a uniform-price multi-unit auction.
- **Key finding:** Large firms near the benchmark; small firms bid excessively steep schedules.
- **Relevance:** Bid-level conduct measurement; our bid-ladder outcome construction descends from this tradition.

### Wolak (2003) — Measuring Unilateral Market Power (AER P&P)
- **Main contribution:** Firm-level ability/incentive indices for unilateral market power.
- **Relevance:** The pivotal-supplier logic behind our essentiality flag; our rivals-only `pex` is the ex-ante version.

### McRae & Wolak (2014) — How Do Firms Exercise Unilateral Market Power? (CUP chapter)
- **Main contribution:** Half-hourly ability/incentive measures in the New Zealand market; net-pivotal status drives offer behaviour.
- **Relevance:** Closest methodological ancestor for interval-level pivotality measurement.

### Joskow & Kahn (2002) — Pricing Behavior in California, Summer 2000
- **Main contribution:** Competitive benchmark gap attributed partly to capacity withholding.
- **Relevance:** The classic physical-withholding-for-price story; our withholding is for *direction*, not price — the contrast sharpens the contribution.

### Bushnell & Wolak (1999) — Reliability Must-Run Contracts for California
- **Main contribution:** RMR contract design analysis; the 1998 contract form created serious incentive problems, and generators could influence their own RMR designation through bids.
- **Relevance:** The closest ancestor: an administered reliability payment whose design induces the conduct it pays for.

### Cramton, Ockenfels & Stoft (2013) — Capacity Market Fundamentals
- **Relevance:** Design principles for administered capacity payments; frames the "pay the wedge, not gross output" counterfactual in §9.

### Fabra (2018) — A Primer on Capacity Mechanisms
- **Main contribution:** Model of market power–investment interaction under capacity mechanisms; price caps + capacity payments disentangle investment incentives from market-power mitigation.
- **Relevance:** Normative framework for §9's redesign discussion.

### Simshauser (2018) — Intermittent Renewables and NEM Stability
- **Relevance:** The NEM-institutional anchor: intermittency, energy-only design, and the security pressures that produced the SA direction regime.

### Institutional (AER 2021 State of the Energy Market; AEMO QED Q2 2024; AEMO SA Electricity Report 2025; AEMC NER cl. 3.15.8)
- **Relevance:** Direction regime mechanics, the published direction-cost series our data reconcile against (QED Figure 85), the synchronous requirement and its 2025 relaxation.

## Gaps and Opportunities

1. **No econometric conduct study of NEM directions.** The NEM intervention literature is institutional/engineering; nobody has estimated generator behavioural response to the direction-compensation price. This is the paper's slot.
2. **RMR incentive problems were argued, not dose-response identified.** Bushnell–Wolak documented design flaws; our RQ2 provides the price-sensitivity test their setting never got.
3. **Availability as the conduct margin.** The markup literature treats availability as exogenous capacity; here availability is the choice variable.

## Suggested Next Steps

- During §1/§9 drafting, consider adding: von der Fehr–Harbord (1993) auction model (if pricing-margin theory needs an anchor), Reguant (2014) complex bids, and an AEMC directions-review determination for the institutional history. Verify before adding.
- Obtain PDFs of Bushnell–Wolak RMR report and McRae–Wolak chapter into `master_supporting_docs/supporting_papers/`.

## BibTeX Entries

Appended to `Bibliography_base.bib` (16 entries, replacing the empty template). Keys follow `AuthorYear_keyword`.

## Post-Flight Verification (CoVe)

**Status: PASS** — all 11 claims VERIFIED by `claim-verifier` (fresh fork, agent ac845b50e57da3656, 2026-07-06); journal fields confirmed against the Crossref DOI registry, the CUP chapter against the publisher page, and the two 1999 reports against Stanford/SSRN hosting. Two enrichments applied to the bib: McRae–Wolak chapter pages 390–420; Bushnell–Wolak leverage paper is POWER working paper PWP-070. Joskow–Kahn page range resolved to 1–35. Zero contradictions; nothing gates a commit.

## Verification notes (pre-CoVe)

- Journal-article details (Wolfram; BBW 2002; Hortaçsu–Puller; Wolak 2003; Joskow–Kahn; Simshauser; Fabra; Cramton–Ockenfels–Stoft) were confirmed against publisher/RePEc pages during search.
- **Flagged for verifier:** Elsevier DOIs for Simshauser2018 (10.1016/j.eneco.2018.02.006) and Fabra2018 (10.1016/j.eneco.2018.08.003) were not shown verbatim in search results; Joskow–Kahn end page (35 vs 36); McRae–Wolak chapter editors (Brousseau & Glachant) and chapter number (18).
- Institutional techreports (AEMO/AER/AEMC) are documents the project already uses; kept deliberately generic.
