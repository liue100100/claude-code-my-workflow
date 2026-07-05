# Stage 0 findings -- inventory (Direction_clean/)

One-page inventory of every input this pipeline reuses from `Direction/` (read-only), plus the one
gap this stage fills. Written for a reader with no electricity-market background -- see `README.md`
glossary for every term used below.

## Sample window and focal units
36 months cached, 202201 to 202412. Focal units: TORRB2, TORRB3, TORRB4, PPCCGT (primary); OSB-AG
(descriptive only -- near-must-run, no withholding contrast); BARKIPS1 excluded (no cheap tranche
exists even in fully competitive intervals).

## Tables reused from Direction/ (all read-only)
| Table | Grain | Rows | Time resolution |
|---|---|---|---|
| Bid ladder (offer quantities + price bands) | per (generator, bid version, 5-min interval) | (see Direction/ cache) | 5-min |
| Essentiality panel | per 5-min interval, SA-wide | 315646 | 5-min |
| SRMC (short-run marginal cost) | per generator x month | 432 | monthly |
| Direction events | per direction event x generator | 1638 | event |
| Direction compensation (episode-level) | per report event | 121 | event |
| Compensation-price series | per month | 35 | monthly (202201 to 202412) |
| Realised directed/synchronise flags | per generator x 5-min interval | 375264 | 5-min |

## Timezone and interval convention
AEMO timestamps label the **end** of the interval (e.g. 00:05 covers the 5 minutes ending at
00:05). Two timezone labels appear across the source files (`Etc/GMT-10` and `Australia/Brisbane`)
-- both are UTC+10 with no daylight saving, so they represent the same clock, but every timestamp
column is force-converted to a single label (`Etc/GMT-10`) before any join, and checked against a
known directed interval. **Check passed**: a known directed interval for a focal generator resolved
to exactly one row in the essentiality panel after the tz fix.

**Anomaly caught and fixed, not smoothed over:** the realised directed-flag table
(`treatment_panel.rds`) only contains rows where the generator *was* directed (every row has
directed=1; non-directed intervals are simply absent, not encoded as 0) and it spans back to 2021
-- wider than the essentiality panel's 202201-202412 coverage. The first check attempt picked a
directed interval from 2021 and correctly failed to find a match (0 rows, not 1), because that
interval predates the essentiality panel entirely. Fixed by restricting the check (and every future
join against this table) to the confirmed 202201-202412 sample window.

## Registered capacity -- the one gap, now filled
`Direction/` never cached generator registered capacity (the extraction pipeline fetches AEMO's
generator-detail table but discards every column except the generator ID). Confirmed directly this
session that the summary version of that table has no capacity field at all -- the field lives in a
different, more detailed AEMO table (`DUDETAIL`). Pulled it for the focal units, for both the start
and end of the sample window, and confirmed it is unchanged throughout:

| Generator | Registered capacity (MW) | Technical max (MW) |
|---|---|---|
| OSB-AG | 180 | 204 |
| PPCCGT | 478 | 522 |
| TORRB2 | 200 | 210 |
| TORRB3 | 200 | 210 |
| TORRB4 | 200 | 210 |

Saved to `outputs/00_inventory/focal_unit_registered_capacity.csv`.

## Known gaps for later stages (not blocking Stage 0/1)
- **Region-wide demand** -- not cached as a single table; would need summing per-generator
  dispatch across the full South Australian generator roster. Needed for Stage 2 (competition
  measure), not before.
- **Interconnector flow** (SA's links to the rest of the grid) -- not extracted at all. Needed for
  Stage 2, not before.

Both are correctly out of scope for this pass and will be sized properly when Stage 2 is planned.

