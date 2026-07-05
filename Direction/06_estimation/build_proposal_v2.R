#!/usr/bin/env Rscript
# build_proposal_v2.R — plain-language version of the proposal.
# Same structure and figures as proposal.docx, rewritten in concise, factual,
# low-jargon prose with no rhetorical language. Writes a SEPARATE file
# (proposal_v2.docx); does not touch proposal.docx or build_docs.R.
suppressMessages(library(officer))
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUTDIR <- "outputs/docs"; dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

H1 <- function(d,t) body_add_par(d,t,style="heading 1")
H2 <- function(d,t) body_add_par(d,t,style="heading 2")
P  <- function(d,t) body_add_par(d,t,style="Normal")
B  <- function(d,t) body_add_par(d, paste0("•  ", t), style="Normal")
N  <- function(d,t) body_add_par(d, paste0("Note. ", t), style="Normal")
FIG<- function(d,png,w,h) body_add_img(d, src=png, width=w, height=h)
CAP<- function(d,t) body_add_par(d, t, style="Normal")

doc <- read_docx()
doc <- H1(doc, "Strategic Withholding and System-Strength Directions in the South Australian Electricity Market")
doc <- P(doc, "Research proposal. Monash University. Draft 2026-06-29. Plain-language version.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "1. Motivation")
doc <- P(doc, "South Australia has the highest share of wind and solar generation in the National Electricity Market, and relatively few synchronous generators. To keep the system secure, the Australian Energy Market Operator (AEMO) sometimes instructs synchronous generators to run when the market would not otherwise dispatch them. These instructions are called directions. A directed generator is paid a regulated price, the directed price, rather than the market price.")
doc <- P(doc, "The directed price is set to the 90th percentile of the regional spot price over the previous 12 months. Between 2022 and 2024 it was well above the directed generators' running costs, so the payment for being directed was large.")
doc <- P(doc, "The total amount paid for directions does not move with the amount of energy directed. The quarters with the highest payments were not the quarters with the most directed energy. A small directed volume in late 2022 and early 2023 produced the largest payments, because each unit of energy was paid the high directed price (Figure 1).")
doc <- FIG(doc, "outputs/proposal_figures/F2_volume_cost.png", 6.2, 3.29)
doc <- CAP(doc, "Figure 1. Energy generated under direction (bars) and total compensation paid (line), by quarter, 2021-2024.")
doc <- P(doc, "A large and predictable payment for being directed gives generators a reason to want to be directed. This proposal asks whether South Australian synchronous generators withhold capacity to raise their chance of being directed, and whether this behaviour is concentrated in the generators that are needed for system security. The descriptive evidence in Section 5 is consistent with this: generators offer more of their capacity at high prices when they are needed for security, and they begin to do so in the hours before a direction is issued.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "2. Background: directions, the directed price, and pivotality")
doc <- P(doc, "Directions and their compensation are set by the National Electricity Rules. Under clause 3.15.7(c), a generator directed to provide energy is paid DCP = AMP times DQ, where DQ is the extra energy delivered because of the direction and AMP is the directed price. The directed price is the level below which 90 percent of the region's spot prices fell over the 12 months before the direction. Because it uses only past prices, it is fixed before any current bidding decision.")
doc <- P(doc, "This timing creates the variation the project uses. The 2022 price spike raised the directed price to about $350 per MWh, where it stayed from mid-2022 to early 2023. As the spike months passed out of the 12-month window in mid-2023, the directed price fell to about $180 per MWh by late 2023 and about $160 per MWh in 2024. The size and timing of this fall could be computed in advance from price history. Because the directed price reflects the past year of prices rather than current costs, it stayed high after fuel costs fell, so the gap between the directed price and fuel cost was small during the 2022 fuel spike and larger in 2023 (Figure 2). The reconstructed directed price matches the payments generators actually received (correlation 0.98). Running costs did not change much when the directed price fell, so the variation is in the payment, not in cost.")
doc <- FIG(doc, "outputs/proposal_figures/F1_compensation_vs_fuel.png", 6.2, 3.29)
doc <- CAP(doc, "Figure 2. The directed price and the Adelaide gas price, monthly. The directed price uses the past 12 months of spot prices, so it falls only after the 2022 spike leaves the window.")
doc <- P(doc, "System security in South Australia depends on which synchronous generators are running. AEMO publishes a list of acceptable minimum combinations of synchronous units. At each level of wind and solar output, the running units must match at least one combination on the list; as wind and solar output rises, fewer combinations remain acceptable. A generator is pivotal in a five-minute interval when no acceptable combination can be formed from the other available units without it. In that case the system cannot be kept secure unless the generator runs, so AEMO must keep it on or direct it on. We separate two cases: a generator pivotal given the units actually running, and a generator pivotal to keep the system secure if the largest running unit were lost. Most directed generators were pivotal (Figure 3): across 2022 to 2024, 58 percent of directed unit-intervals were pivotal given the running units, a further 14 percent were pivotal to stay secure against the loss of the largest unit, and 28 percent were not pivotal.")
doc <- FIG(doc, "outputs/proposal_figures/F3_pivotal_composition.png", 6.2, 3.72)
doc <- CAP(doc, "Figure 3. Directed unit-intervals by whether the directed unit was pivotal, 2022-2024. A unit is pivotal when no combination of the other available SA synchronous units could meet the system-strength requirement without it.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "3. Research question")
doc <- P(doc, "Do South Australian synchronous generators withhold energy, by raising offer prices or reducing offered capacity, to raise their chance of being directed and paid the directed price, and is this concentrated in the generators that are pivotal for system security?")
doc <- P(doc, "The question is about a change in behaviour, not a level. These generators offer capacity above cost much of the time. The test is whether withholding increases in the situations and for the units where it can lead to a paid direction. The fall in the directed price in mid-2023 gives variation over time in the size of the payment. The acceptable-combinations standard gives variation across units and over time in which units are pivotal.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "4. Data")
doc <- B(doc, "Offers, five-minute, 2022 to 2024: each generator's offered quantities by price band and the daily price bands, for SA generators, keeping every revised offer.")
doc <- B(doc, "Dispatch: the SA regional spot price and each generator's dispatch and availability, for all 36 months.")
doc <- B(doc, "Directions: a per-generator log of each direction, with start and end times, whether the unit was directed to start up or to keep running, the energy directed, and the compensation paid.")
doc <- B(doc, "System security: AEMO's list of acceptable minimum combinations of synchronous units for SA.")
doc <- B(doc, "Costs: quarterly Adelaide gas prices, generator heat rates, and variable operating and maintenance costs.")
doc <- N(doc, "June 2022 was a market-suspension month with administered prices; bidding was not strategic, so it is dropped or controlled for.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "5. Descriptive evidence")
doc <- P(doc, "Two patterns from the five-minute offer data bear on the question. Both use the pivotality measure above. Both measure price withholding as the share of a unit's capacity offered above $300 per MWh, which is well above these units' fuel cost of about $100 per MWh.")
doc <- P(doc, "Offers change with pivotality. Figure 4 compares three groups of unit-days: all days, days the unit was directed, and directed days on which the unit was pivotal. The number of intraday offer revisions is similar across the three groups. The intraday change in offered capacity is negative on direction days, because a directed unit is required to add output. The clearest difference is in price: the share of capacity offered above $300 per MWh rises from 77 percent on all days to 82 percent on direction days and 84 percent on directed days when the unit is pivotal.")
doc <- FIG(doc, "outputs/proposal_figures/F4_rebidding_by_sample.png", 6.2, 2.59)
doc <- CAP(doc, "Figure 4. Offer measures for the pivotal-capable SA gas units across three groups of unit-days: all days, direction days, and pivotal direction days. Averages per unit-day.")
doc <- P(doc, "The change happens before the direction. Figure 5 follows the offer for the directed intervals from a unit's first version to its last version before the direction is issued, measured in hours before the direction and shown as the change since the first version. The share of capacity offered above $300 per MWh rises by two to six percentage points over this period, for both start-up and keep-running directions and whether the measure uses the whole directed period or only its first hour. The change in offered capacity is smaller and less regular. The pattern is consistent with generators adjusting their offers before they are directed, not only after.")
doc <- FIG(doc, "outputs/proposal_figures/F5_runup.png", 6.2, 3.78)
doc <- CAP(doc, "Figure 5. Change in the offer for the directed intervals, from the first version to the last version before the direction is issued (0 = issued). Rows: capacity offered and share offered above $300 per MWh. Columns: the whole directed period and its first hour. Lines: start-up (Synchronise) and keep-running (Remain) directions.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "6. Identification")
doc <- H2(doc, "6.1 First design: the fall in the directed price")
doc <- P(doc, "We study how withholding changes around the mid-2023 fall in the directed price. We measure each unit's withholding over time and relate it to the directed price, holding constant each unit's own average level and common time effects, with the directed price entered as a value fixed in advance. The assumption is that, without the fall, the treated units' withholding would have continued on its own earlier path, so the only thing that changes abruptly at the window exit is the payment, not cost and not the payment rule, which is unchanged across 2021 to 2024. The main concern is that the 2022 price conditions moved the directed price, fuel cost, and the spot price together. We address this by controlling for running cost and the spot price, testing for pre-existing trends, using keep-running directions as a comparison, and dropping June 2022.")
doc <- H2(doc, "6.2 Second design: directed price, pivotality, and wind and solar output")
doc <- P(doc, "Withholding to be directed should matter most where a unit can affect the security outcome, that is, where it is pivotal. The main design relates withholding to the directed price, to whether the unit is pivotal, to wind and solar output, which determines how tight security is, and to the interaction of the three. AEMO directs units 1.5 to 2 times more often when they are pivotal. The main concern is that pivotality measured from a unit's own running depends on its own withholding. We address this with a pivotality measure built only from other units' availability, and with wind and solar output, which is driven by weather. As a check, the relationship should be absent for keep-running directions and for wind and solar units, which cannot be directed to start up from offline.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "7. Methodology")
doc <- P(doc, "We use linear regressions with separate intercepts for each unit and each time period. The main outcome is the share of capacity offered above cost. Secondary outcomes are the intraday change in offered capacity and the intraday change in the share of capacity priced above cost. The main variables are the directed price, pivotality, and their interaction, with controls for running cost and the spot price. Variable construction is documented in the companion methods document.")
doc <- P(doc, "The number of groups for clustering is small: 35 months and 11 to 12 units. Standard cluster-robust standard errors are not reliable at this size, so the main inference uses the wild cluster bootstrap, and the main coefficients are reported with bootstrap confidence intervals [CITE Cameron, Gelbach and Miller; CITE Roodman et al.].")
doc <- P(doc, "A structural model of joint price and availability bidding is left for later work and is not required for the main results.")

# ---------------------------------------------------------------------------
doc <- H1(doc, "References")
doc <- P(doc, "[CITE] Cameron, A. C., Gelbach, J. B., and Miller, D. L. Bootstrap-based improvements for inference with clustered errors.")
doc <- P(doc, "[CITE] Roodman, D., MacKinnon, J. G., Nielsen, M. O., and Webb, M. D. Fast and wild: bootstrap inference in Stata using boottest.")
doc <- P(doc, "[CITE] Literature on capacity withholding and pivotal suppliers in wholesale electricity markets.")
doc <- P(doc, "[CITE] AEMO. System strength requirements and the SA minimum synchronous generation framework.")
doc <- P(doc, "[CITE] AEMO. Directions compensation methodology and the proposed replacement of the 90th-percentile directed price.")

print(doc, target = file.path(OUTDIR, "proposal_v2.docx"))
cat("wrote proposal_v2.docx\n")
