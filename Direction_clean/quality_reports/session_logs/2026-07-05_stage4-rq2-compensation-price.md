# Session log — 2026-07-05 — Direction_clean/ Stage 4 (RQ2: compensation-price response)

## Goal
RQ2 per the user's spec + amendments: does withholding respond to the SIZE of the compensation
price, specifically on essential intervals vs. a CEM-matched comparison (competition measure in
the matching)? Pre-registered interpretation written before estimation; power diagnostics before
the coefficient; June 2022 handled at the segment level from Stage 3b. Stop after findings.

## Implementation
- **Pre-registration honored mechanically:** run_rq2.R writes the committed interpretation mapping
  to findings.md as its first action, before any estimation code executes.
- **June compensation price (base case):** pre/post-suspension June intervals kept at the ex-ante
  daily trailing-365d d_t evaluated at 2022-06-01 = $241.38 (window ends 31 May — predetermined,
  uncontaminated; daily series tracks the monthly reconstruction at r=0.974). Robustness (ii)
  includes the suspension window at the $300 APC (ex-ante administered cap, never ex-post
  compensation).
- **CEM:** unit × month × non-sync-quintile × hour-block × competition-bin (saturated / slope
  terciles). 100% of essential rows matched (12,513 of 12,516).
- **Identification note stated up front:** the compensation price is monthly, so the interaction
  is identified off cross-month variation in the essential-vs-matched gap; effective clusters =
  the 21 essential-bearing months (top-3 hold 50.8% of the mass; price range $121–378).
- Expected fixest collinearity drops of the comp-price main effect under month FE (6 of 8 models;
  NOT dropped in the 2 variant-(ii) models where June has within-month price variation — the
  asymmetry is itself the correct internal consistency check).

## Result — the pre-registered payment-seeking signature is PRESENT
Interaction (per $100/MWh): **−0.051 fixed-$300 (WCB p=0.004 Rademacher / 0.004 Webb), −0.055
cost-indexed (WCB p=0.007 / 0.006)** — the essential-vs-matched withholding gap widens ~5.1pp of
registered capacity (~10 MW per Torrens unit) per $100 of compensation price. **Stable across all
four June treatments** (−0.044 to −0.058, p 0.001–0.029), including drop-all-June — unlike the RQ1
level result, this owes nothing to June 2022. Raw monthly gap-vs-price scatter corroborates
(rq2_gap_vs_price.png).

## Interpretation (committed mapping applied)
The Torrens RQ1 response is at least partly prize-driven. Channel ranking after Stages 3+4:
energy-market power as measured — eliminated (wrong sign of conditions); pure
presence-inelasticity with no payment sensitivity — rejected on its own pre-committed test (it
predicted a null); payment-seeking — supported. Refinement: conduct is regime-triggered on the
competition margin but dose-responsive on the payment margin.

## Caveats carried with the result
Attenuation (realised-state classification → true effect if anything larger); cross-month
confounding not excluded by month FE (fuel-stress in 2022H2 co-moves with the price — mitigated
by 2024 mid-price months carrying ~27% of essential mass and the unchanged drop-all-June row;
fuel-stress control = natural Stage-5 extension); 21 effective clusters with top-3 = 50.8%.

## Status: Stage 4 COMPLETE. STOPPED for review, per instruction. Remaining: Stage 5 (figures,
markup-benchmark appendix — inherits the |markup|<=10 trim flag from Stage 2 — and the
plain-language results summary).

## Housekeeping
Still nothing committed (Direction/ since 2026-06-21; Direction_clean/ ever). The full pipeline
now runs Stage 0 → 4 end-to-end; a checkpoint commit is overdue whenever the user says the word.
