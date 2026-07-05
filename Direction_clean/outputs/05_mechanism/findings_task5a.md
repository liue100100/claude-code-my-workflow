# Task A -- did the pre-direction bid touching actually change the bid?

**The answer, one sentence: the touches add up inside individual episodes -- 69.1% of
pre-direction windows show a materially different bid, twice the quiet rate of 36.3% -- but
they cancel across episodes: the movement has no consistent direction (means ~0, up and down
near-balanced), so the bid before a direction is a re-checked and re-jiggled bid, not a
systematically repositioned one.**

Method as specified: for each clean first direction, the midnight stance at D-3 differenced
against D-1 (both pre-issue); quiet 48-hour windows as contrast. Material = |net| >= 5% of
registered capacity (10 MW Torrens, 23.9 MW PPCCGT) on day-mean cheap capacity (<= $300) or
day-mean availability -- fixed before running. Denominators: **123 of 264** clean first
directions have both D-3 and D-1 clean and measurable (the both-days-clean requirement bites;
stated, not hidden); 1,433 quiet windows. Script `task5a_did_the_bid_change.R`; tables
`task5a_{pairs,summary}.csv`.

| | Pre-direction (n=123) | Quiet 48h (n=1,433) |
|---|---|---|
| Windows materially changed | **69.1% (85)** | 36.3% (520) |
| Mean net cheap-capacity change (all windows) | -0.5 MW | 0.0 MW |
| Mean net availability change (all windows) | -0.5 MW | 0.0 MW |
| Mean absence-depth change (all windows) | -0.32 h | -0.06 h |
| Among material movers: cheap UP / DOWN | 45.9% / 54.1% | 50.8% / 49.2% |
| Among material movers: availability UP / DOWN | 36.5% / **63.5%** | 45.8% / 54.2% |
| Among material movers: absence deeper | 43.5% | 38.3% |
| Material-mover cheap change, P25 / P75 | -50 / +54 MW | -85 / +86 MW |
| Material-mover availability change, P25 / P75 | -49 / +89 MW | -92 / +100 MW |

Reading, with the minority asymmetries reported rather than smoothed:
- The distributions are wide in BOTH directions in both groups -- these are real bid movements
  of +-50-90 MW, not noise -- and their means sit at zero. The pre-direction window does not
  tilt the book toward absence or presence; it churns it in place at twice the quiet frequency.
- The one visible asymmetry: among pre-direction material movers, availability moves DOWN in
  63.5% of cases (vs 54.2% quiet) -- but the downs are smaller than the ups (mean -1.2 MW), so
  even this tilt nets to nothing. Consistent with Part 3b's thin D-1 cheap-drain edge: present,
  directionally suggestive, an order of magnitude too small to constitute repositioning.
- This closes the churn-ramp question exactly as Part 3b's "vigilance" reading predicted: more
  frequent material rewriting before directions, zero systematic displacement of the posture.

No further decomposition, per instruction.

## Addendum (requested follow-up): does the floor block move UP in price bands?
**No -- up-band migration of the floor megawatt is essentially nonexistent: 1 of 123
pre-direction windows (0.8%; 5 hours, straight to near-cap) and 0 of 1,433 quiet windows show
>= 1 hour shifting from cheap-or-below to above $1,000 while offered.** The composition table
explains why: the floor MW lives in exactly two states -- withdrawn (11-16 h/day) or in the
<= $0 floor band (8-12 h/day) -- with the intermediate and high price classes holding ~0.0-0.2
hours/day. The repricing of the floor megawatt that the taxonomy's "priced-out" days record
happens as whole-day bid shapes (the cheap tranche absent from the ladder from midnight), never
as a mid-horizon migration of quantity up the bands; and band PRICES themselves never move
(lever table: 2 changes in ~1,030 jumps). The two-state picture -- floor block at -$1,000/$0,
or floor block gone -- holds at the day-over-day margin too. What little movement the
pre-direction windows show runs the other way: a small net shift from withdrawn INTO the floor
band (+0.38 h cheap-side, -0.32 h withdrawn), consistent with the table above.
Script `task5a2_floor_block_migration.R`; tables `task5a2_floor_migration_{pairs,summary}.csv`.

**STOP -- Task A complete (with addendum). Awaiting review before Task B.**
