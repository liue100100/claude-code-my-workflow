# Decision memo — the make-whole premise, resolved (Case B)

Inputs: `claims_record.md` (Stages 1–3), `findings_test4.md` (Test 4). Mapping committed in the
task prompt before the record was built. No recommendations beyond the committed mapping.

## The determination: Case B — material top-ups found

The empirical question was whether the focal units were actually made whole via NER 3.15.7B when
d_t sat below cost. They were. Every Apr–Jun 2022 direction event received an additional-
compensation payment; the top-ups total $3.76M against $3.75M of formula compensation (ratio
1.003), bringing the combined payment to ≈ $348/MWh against a Torrens all-in cost of $322/MWh;
independent-expert fees confirm the 3.15.7B process ran. The addl/comp ratio is 0.175 in normal
months and 1.003 where the floor binds — the make-whole signature. Case A (no top-ups) is
excluded by the record.

## Consequence under the committed mapping

**The rent max(d_t − cost, 0) is the incentive-correct dose, and its null stands.** The paper's
dose-response claim weakens to:

> Conduct tracks the gross administered price, not the identified net rent; the fuel channel is
> unresolved on the eligibility margin.

Reported verbatim regardless of case, per the commitment:

- **Horse race (base sample):** essential×d_t = −0.041 and essential×all-in-cost = −0.063 —
  both negative; the make-whole (equal-and-opposite) restriction is rejected on every outcome
  (reach p = 0.0008, share_a p = 0.0072, share_b p = 0.0025).
- **Rent-variation diagnostic:** the rent dose has IQR **$12/MWh** across essential rows against
  **$153/MWh** for d_t; its two largest essential-mass clusters (Sep 2022, 20.5%; Sep–Nov 2024,
  30.8%) sit at nearly identical rent (~$71 vs ~$74–81) while d_t differs by $143. The null is
  produced jointly by genuine non-response to the prize and by near-degenerate identifying
  variation; the design cannot apportion between the two.

Two bounded qualifications, both already registered:

1. **Conservatism.** High gas lowers rent, so fuel-stress conduct biases the rent coefficient
   toward positive; the observed −0.039 is consistent with a modest masked payment response.
   This softens "no rent response" to "no demonstrable rent response," nothing more.
2. **Materiality (Stage 3).** The sub-cost exposure is $2.32M–$3.76M, under 3% of the $141.9M
   headline. The transfer-accounting story of the paper is unaffected; Case B bites only on the
   behavioral-interpretation claim.

## Manuscript consequences (decisions, not actions — nothing edited under this task)

1. **§8 robustness subsection (already drafted under Test 4's Fails reading):** its conditional
   framing — "if 3.15.7B top-ups are complete where they bind… / if they are partial, delayed,
   or contested…" — is now resolved to the first branch. The subsection should state the Case B
   resolution: top-ups were paid in full view of the record, the rent is the incentive-correct
   dose, and the sentence "conduct tracks the gross administered price, not the identified net
   rent" replaces the two-sided conditional. The "reinforces, and does not relax, the
   consistent-with framing" close should be re-examined by the author — under Case B it reads
   too favorably.
2. **§2 setting footnote (added under Test 4):** "the channel is unmeasured" in the bound
   months is contradicted by the event-grain record and must be corrected to cite the observed
   top-ups (event grain 2021–2023; unit grain only from Oct 2023).
3. **Registration + findings_test4 evidential-status passages** carry the same "unmeasured"
   characterization; annotate rather than rewrite (registrations are not edited after the fact —
   append a dated corrigendum note).
4. **Transfer accounting (author's attention):** if the $141.9M is DCP-only, settled payments
   including 3.15.7B run ~17–20% higher; the abstract's transfer figure may be conservative.
   Verify how the headline dollar figure was built before any resubmission.
5. **Headline behavioral language (author's decision, per the Test-4 stop rule):** Case B is the
   branch under which the existing "consistent with payment-seeking" framing carries the most
   weight it can bear. The candidate softening is to state that the payment the conduct tracks
   is the gross administered price — the sticker, not the profit — and that the profit-tracking
   version of the hypothesis is unsupported where it is identified. Whether this goes in the
   abstract or stays in §8 is the author's call.
