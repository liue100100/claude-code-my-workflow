#!/usr/bin/env Rscript
# build_docs.R — generate proposal.docx and methods.docx with officer (no pandoc).
suppressMessages(library(officer))
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUTDIR <- "outputs/docs"; dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

H1 <- function(d,t) body_add_par(d,t,style="heading 1")
H2 <- function(d,t) body_add_par(d,t,style="heading 2")
P  <- function(d,t) body_add_par(d,t,style="Normal")
B  <- function(d,t) body_add_par(d, paste0("•  ", t), style="Normal")
N  <- function(d,t) body_add_par(d, paste0("Note. ", t), style="Normal")
TBL<- function(d,df) body_add_table(d, df, style="table_template")
SP <- function(d) body_add_par(d, "", style="Normal")
FIG<- function(d,png,w,h) body_add_img(d, src=png, width=w, height=h)
CAP<- function(d,t) body_add_par(d, t, style="Normal")

############################################################################
## 1. PROPOSAL
############################################################################
doc <- read_docx()
doc <- body_add_par(doc, "Strategic Withholding and System-Strength Directions in the South Australian Electricity Market", style="heading 1")
doc <- P(doc, "Research proposal. Monash University. Draft 2026-06-29.")
doc <- P(doc, "Framing choices made for this draft (overridable): the unit of analysis is the South Australian (SA) synchronous generation fleet, with Torrens Island B (TIB) as the salient case; the primary outcome is the SRMC-relative withheld share; the third leg of the triple-difference is system-strength pivotality interacted with non-synchronous penetration. Empirical claims cite fact bullets [F#] in facts_memo.md; literature placeholders are marked [CITE].")

doc <- H1(doc, "1. Motivation")
doc <- P(doc, "South Australia runs the most renewables-intensive synchronous-thin grid in the National Electricity Market (NEM). To maintain system strength and security, the Australian Energy Market Operator (AEMO) frequently directs synchronous generators to run when the market would not dispatch them. A directed generator is compensated at the directed price d_t, a trailing-365-day 90th percentile of the regional spot price. Over 2022-2024 that price sat far above the directed units' short-run marginal cost: mean pre-exit margins of d_t over marginal cost ranged from roughly $78 to $148/MWh across units [F4], and the per-interval direction rent (d_t minus spot) was positive in more than 94% of directed intervals and rose monotonically with d_t, from about $126 to $269/MWh across the d_t distribution [F5].")
doc <- P(doc, "The resulting compensation bill is large and persistent, and it does not move with directed volume. The quarters with the highest compensation are not the quarters with the most directed energy: a small directed volume in late 2022 and early 2023 produced the largest bills, because each megawatt-hour was paid the inflated, slow-moving directed price (Figure 1).")
doc <- FIG(doc, "outputs/proposal_figures/F2_volume_cost.png", 6.2, 3.29)
doc <- CAP(doc, "Figure 1. Energy generated under direction (bars) and total compensation paid (line), by quarter, 2021-2024. The highest-cost quarters are not the highest-volume quarters.")
doc <- P(doc, "A large, reliable rent for being directed creates an incentive to be directed. This proposal asks whether SA synchronous generators act on that incentive by withholding capacity, and whether the behaviour is concentrated where it can actually work, namely in units that are pivotal for system strength. Preliminary descriptive evidence assembled for this proposal is affirmative and sharp: within a unit, being pivotal for system strength raises the share of capacity offered above marginal cost by 11 to 14 percentage points, a result that survives restriction to undirected market-facing intervals and holds for a pivotality measure constructed from rivals' availability alone [F14]. Pivotal units also actively rebid, withdrawing roughly 40 MW of available capacity intraday and moving 4 to 18 percentage points of capacity above marginal cost across the trading day [F16]. The pivotality state, not the size of the prize, is the dominant margin [F15].")

doc <- H1(doc, "2. Institutional background: directions, the directed price, and pivotality")
doc <- P(doc, "Under National Electricity Rules clause 3.15.7(c), a directed participant providing energy is compensated by DCP = AMP x DQ. DCP is the directed-participant compensation, DQ is the counterfactual additional energy delivered because of the direction, and AMP is the directed price d_t: the price below which 90% of the relevant region's spot prices fell over the 12 months immediately preceding the trading day on which the direction was issued. Because d_t is a trailing percentile, it is predetermined relative to today's bidding decision.")
doc <- P(doc, "This predetermination produces the project's identifying variation. The 2022 SA price spike pushed the trailing 90th percentile to a plateau of about $348-350/MWh across 2022Q3-2023Q1. As the spike intervals rolled out of the trailing window in mid-2023, d_t fell mechanically to about $180/MWh by late 2023 and a trough near $160/MWh in 2024, a 54% decline from peak, on a date computable in advance from price history alone [F1]. Because the directed price tracks the previous twelve months of prices rather than today's costs, it keeps paying near-2022 levels well after the units' fuel costs have fallen, so the gap between the directed price and fuel cost — the rent for being directed — is small during the 2022 fuel spike and large once fuel falls in 2023 (Figure 2). The reconstructed d_t series matches realised compensation (DCP/DQ) with a correlation of 0.984 over the sample and 0.997 once the trailing window is fully populated [F2]. Crucially, marginal cost shows no structural break at the d_t exit, so the variation is in the prize, not in cost [F3].")
doc <- FIG(doc, "outputs/proposal_figures/F1_compensation_vs_fuel.png", 6.2, 3.29)
doc <- CAP(doc, "Figure 2. The directed price d_t (a trailing-365-day 90th percentile of SA spot) against the Adelaide wholesale gas price. The slow-moving prize stays high after fuel costs fall, opening a small rent during the 2022 fuel spike and a large rent in 2023.")
doc <- P(doc, "System strength in SA is governed by AEMO's published set of acceptable minimum combinations of synchronous units. Because the grid is synchronous-thin, secure operation requires that the synchronous generators online at any moment satisfy at least one acceptable combination; as non-synchronous wind and solar output rises, the admissible combinations become scarcer and stricter. We use this standard to define pivotality precisely: a unit is pivotal in a five-minute interval when no acceptable combination of the other available synchronous units can be formed without it, so the security requirement cannot be met unless that unit is kept on or directed on. We separate a unit that is pivotal given the fleet actually running from one that is pivotal to keep the system secure against the sudden loss of its single largest online unit (the N-1 standard AEMO operates to). Figure 3 shows this is the common case: 58% of directed unit-intervals are pivotal given the units actually running, a further 14% are pivotal to keep the system N-1 secure, and only 28% are non-pivotal. Most directions therefore fall on units that are genuinely essential rather than redundant — the precondition for the withholding-to-be-directed channel this proposal studies.")
doc <- FIG(doc, "outputs/proposal_figures/F3_pivotal_composition.png", 6.2, 3.72)
doc <- CAP(doc, "Figure 3. Composition of directed unit-intervals by how essential the directed unit was, 2022-2024. A unit is counted pivotal when no combination of the other available SA synchronous units could meet the system-strength requirement without it.")

doc <- H1(doc, "3. Research question")
doc <- P(doc, "Do SA synchronous generators strategically withhold energy, on both the price and quantity margins, to raise their probability of being directed and collecting d_t, and is the behaviour concentrated in units that are pivotal for system strength?")
doc <- P(doc, "The object of interest is a slope, not a level. The relevant comparison is not whether these units withhold (chronically, they do) but whether withholding intensifies in the states and for the units where it can route the firm into a paid direction. The mid-2023 d_t exit supplies predetermined within-unit variation in the prize; AEMO's combinations standard supplies cross-unit and over-time variation in pivotality.")

doc <- H1(doc, "4. Data")
doc <- B(doc, "Bid panel, 5-minute, 2022-01 to 2024-12: per-band offer quantities (BIDOFFERPERIOD: MAXAVAIL, BANDAVAIL1-10) and daily price bands (BIDDAYOFFER: PRICEBAND1-10), SA generators, all rebid versions retained.")
doc <- B(doc, "Dispatch: regional spot price (DISPATCHPRICE, SA1 RRP) and unit dispatch/availability (DISPATCHLOAD: INITIALMW, TOTALCLEARED, AVAILABILITY, SEMIDISPATCHCAP), all 36 months.")
doc <- B(doc, "Directions: per-DUID event log (issue/effective/cancellation times, instruction Synchronise vs Remain, reason, directed MWh, compensation) and early-period event-level financials.")
doc <- B(doc, "System strength: AEMO acceptable minimum synchronous generator combinations for SA (123 combinations across system-normal and risk-of-islanding regimes).")
doc <- B(doc, "Cost primitives: AER quarterly STTM Adelaide ex-ante gas prices; AEMO heat-rate workbook (incremental and static, HHV as-generated); Aurecon 2024 variable O&M by technology class.")
doc <- N(doc, "June 2022 is a market-suspension and administered-price month; bidding was administrative, not strategic, and it is dummied or dropped.")

doc <- H1(doc, "5. Descriptive evidence")
doc <- P(doc, "Two preliminary patterns, assembled for this proposal from the 5-minute bid data, speak directly to conduct. Both use the pivotality measure defined above, and both express price withholding as the share of a unit's capacity offered above $300/MWh — a level well above these units' fuel cost of roughly $100/MWh, used here as a simple, model-free withholding threshold.")
doc <- P(doc, "Bidding shifts with pivotality. Figure 4 compares three groups of unit-days: every day, days the unit was directed, and directed days on which the unit was pivotal. The number of intraday rebids is essentially flat across the three groups, and the intraday change in available capacity turns negative on direction days, mechanically, because a directed unit is required to add output. The informative margin is price: the share of capacity offered above $300/MWh rises from 77% on an average day to 82% on direction days and 84% on directed days when the unit is pivotal. Units price more of their capacity high precisely when they are essential.")
doc <- FIG(doc, "outputs/proposal_figures/F4_rebidding_by_sample.png", 6.2, 2.59)
doc <- CAP(doc, "Figure 4. Rebidding behaviour across three groups of unit-days for the pivotal-capable SA gas units: every day, direction days, and pivotal direction days. Averages per unit-day.")
doc <- P(doc, "The repositioning precedes the direction. Figure 5 follows the offer for the directed intervals from a unit's first bid version to its last version submitted before the direction is issued, on a clock measured in hours before issue and expressed as the change since that first version. The share of capacity offered above $300/MWh rises by two to six percentage points over the run-up, for both Synchronise (start-up) and Remain (keep-running) directions and whether we use the whole directed window or only its first hour; the available-capacity margin is noisier. The pattern is consistent with units positioning their offers in anticipation of being directed, not merely responding once directed.")
doc <- FIG(doc, "outputs/proposal_figures/F5_runup.png", 6.2, 3.78)
doc <- CAP(doc, "Figure 5. Change in the offer for the directed intervals, from each direction episode's first bid version to its last version before the direction is issued (0 = issued). Rows: capacity offered and share offered above $300/MWh; columns: the full directed period and its first hour; lines: Synchronise versus Remain.")

doc <- H1(doc, "6. Identification")
doc <- H2(doc, "6.1 Design 1: window-exit event study")
doc <- P(doc, "An event study of withheld share on event-time relative to the mid-2023 d_t exit, SA synchronous units, with unit and calendar-time fixed effects and d_t entered as the predetermined regressor. Identifying assumption: absent the d_t decline, treated units' withholding intensity would have followed its own pre-exit trend, so the only thing changing discontinuously at the window exit is the predetermined prize, not cost [F3] or the compensation formula (unchanged across 2021-2024). Main threat: the 2022 price regime moves d_t, marginal cost, and spot together; the raw d_t slope is sign-flipped by exactly this confound, and reverses to positive only once marginal cost is controlled [F7, F8]. Robustness: control SRMC and native 5-minute spot; pre-trend tests on event-time leads; Remain-directed intervals as a placebo for the Synchronise margin; drop June 2022.")
doc <- H2(doc, "6.2 Design 2: triple-difference, d_t x pivotality x tightness")
doc <- P(doc, "The withholding-to-be-directed channel should bite hardest where the firm can swing the security outcome, namely where it is pivotal under a binding requirement. The headline design interacts predetermined d_t with unit pivotality and with non-synchronous penetration (system tightness). Pivotality is built and validated [F13]; AEMO directs units 1.5 to 2 times more often when they are pivotal. Identifying assumption: conditional on the lower-order interactions and fixed effects, the differential response across pivotal vs non-pivotal units in tight vs slack states is not driven by another factor varying on the same triple margin. Main threat: pivotality measured from a unit's own realised dispatch is endogenous to its own withholding. This is addressed by the ex-ante measure, which computes essentiality from rivals' availability alone and yields a larger effect [F14], and by the continuous, weather-driven non-synchronous penetration instrument, which independently predicts withholding [F14]. Falsification: the triple-difference should vanish for Remain events and for non-synchronous (wind and solar) units, which cannot execute the offline-to-directed channel; consistent with this, peakers are essentially never pivotal and show no pivotal-withholding response [F13, F14].")

doc <- H1(doc, "7. Methodology")
doc <- P(doc, "Reduced-form first. The estimators are two-way fixed-effects regressions of the withheld share (and, as secondary outcomes, rebid-based quantity withdrawal and price-band escalation) on d_t, pivotality, and their interaction, absorbing unit and time fixed effects and controlling marginal cost and spot. The full construction of every variable is documented in the companion methods document.")
doc <- P(doc, "Inference accounts for few clusters in every dimension: 35 months, 11 to 12 units. Analytic cluster-robust standard errors are unreliable at this cluster count, so the primary inference is the wild-cluster bootstrap with Webb six-point weights and the small-cluster correction [CITE Cameron, Gelbach and Miller; CITE Roodman et al. boottest]. All headline coefficients will be reported with wild-cluster-bootstrap p-values and confidence intervals.")
doc <- P(doc, "A structural extension is future work: a model of the unit's joint price-and-availability bidding under the system-strength constraint and the directed-price option, which would let the directed-price reform be evaluated counterfactually rather than only descriptively. It is not required for the reduced-form contribution.")

# (Contribution and Timeline sections dropped for this draft.)

doc <- H1(doc, "References")
doc <- P(doc, "[CITE] Cameron, A. C., Gelbach, J. B., and Miller, D. L. Bootstrap-based improvements for inference with clustered errors.")
doc <- P(doc, "[CITE] Roodman, D., MacKinnon, J. G., Nielsen, M. O., and Webb, M. D. Fast and wild: bootstrap inference in Stata using boottest.")
doc <- P(doc, "[CITE] Literature on capacity withholding and pivotal suppliers in wholesale electricity markets.")
doc <- P(doc, "[CITE] AEMO. System strength requirements and the SA minimum synchronous generation framework.")
doc <- P(doc, "[CITE] AEMO. Directions compensation methodology and the proposed replacement of the 90th-percentile directed price.")

print(doc, target = file.path(OUTDIR, "proposal.docx"))
cat("wrote proposal.docx\n")

############################################################################
## 2. METHODS — full measure construction
############################################################################
m <- read_docx()
m <- body_add_par(m, "Construction of Measures for the SA Directions Descriptive Exercise", style="heading 1")
m <- P(m, "Companion methods document. Monash University. 2026-06-20. This document specifies, for every variable used in the descriptive exercise, its data source, exact definition, construction steps, the assumptions it rests on, and any validation performed. Scripts named below live in the project's Direction/ directory.")

m <- H1(m, "0. Sample, units, and panel spine")
m <- P(m, "Sample period 2022-01 to 2024-12 at 5-minute resolution, South Australia (region SA1). The treated synchronous units are TORRB1-4 (Torrens Island B), PPCCGT (Pelican Point), OSB-AG (Osborne), QPS5 (Quarantine), DRYCGT1-3 (Dry Creek), MINTARO, and BARKIPS1 (Barker Inlet). June 2022 is excluded from behavioural panels (market suspension and administered pricing). The behavioural spine is panel_v3.rds, one row per treated unit per 5-minute interval, carrying the offer, dispatch, cost, prize, and treatment variables defined below. Built by descriptive_analysis_v3.R.")

m <- H1(m, "1. The directed price d_t")
m <- P(m, "Source: SA1 dispatch price (DISPATCHPRICE) for the reconstruction; early-period directions financials for validation. Definition: d_t is AEMO's AMP, the trailing-365-day 90th percentile of the SA regional spot price as of the trading day a direction is issued. Operationally we use a monthly series (gate0_dt_series.rds, column dt_real): for each month, the 90th percentile of SA spot over the preceding 365 days.")
m <- P(m, "Validation: the reconstructed series is compared to realised compensation per unit of directed energy, DCP/DQ, recovered from the directions financials. Correlation is 0.984 over 35 overlapping months and 0.997 over the 24 months in which the trailing window is fully populated; mean absolute difference $7.6-10.6/MWh. Spike-month level gaps (e.g. realised $378 vs reconstructed $350 in 2022-08) reflect aggregation across issue dates and the June-2022 administered-price period.")
m <- P(m, "Key property: because d_t depends only on prices in the preceding 12 months, it is predetermined relative to current bidding. The mid-2023 exit (a 54% fall from the ~$349 plateau to a ~$160 trough as 2022 spike intervals leave the trailing window) is computable in advance and is the project's identifying variation. Exit month: 2023-07.")

m <- H1(m, "2. Treatment flags: directed and synchronise")
m <- P(m, "Source: per-DUID direction event log; build_treatment_panel.R producing treatment_panel.rds (375,264 directed unit-intervals). Construction: each event is expanded from its effective time to its cancellation time onto the 5-minute grid, per DUID; overlapping market notices are unioned (not summed). Two indicators result: directed (any direction active) and synchronise (the instruction was to synchronise an offline unit, as opposed to Remain, which keeps an already-running unit on). The Synchronise margin is the strategic offline-to-directed margin; Remain serves as a placebo. Flags are merged onto the bid panel by DUID and interval; intervals with no event row are coded zero.")

m <- H1(m, "3. Short-run marginal cost (SRMC)")
m <- P(m, "Source and script: gate_a_srmc.R, producing GateA_srmc_params.csv (one row per unit-month). SRMC combines a fuel price, a heat rate, and variable O&M.")
m <- H2(m, "3.1 Fuel price")
m <- P(m, "Gas: AER quarterly STTM Adelaide ex-ante price (Quarterly_STTM_Price.CSV), HHV $/GJ, mapped from each 'quarter ending' to its three constituent calendar months. Distillate parity: distillate-capable units (BARKIPS1, DRYCGT1-3, QPS5) may burn the cheaper of gas and diesel, so the fuel price is min(gas, diesel) and a fuel-type flag records which bound. A locale-safe month-name parser is used because Windows date parsing returns NA on abbreviated month names.")
m <- H2(m, "3.2 Heat rate")
m <- P(m, "From the AEMO heat-rate workbook (summarised in srmc_inputs_heatrate_vom.md), as-generated, higher-heating-value. The workbook encodes a two-part fuel curve, fuel(GJ/h) = no-load base + incremental x MW, yielding two heat rates per unit: an incremental (marginal) heat rate and a static (average) heat rate. Both are carried. Two data gaps are filled by proxy and flagged: BARKIPS1 has no workbook entry (reciprocating-engine class proxy, ~7.9 GJ/MWh); Torrens Island B has no class VOM (proxy $2.5/MWh). For PPCCGT and OSB-AG the workbook's incremental heat rate exceeds the static, which is physically backwards; for these two units the static heat rate is used for both SRMC measures.")
m <- H2(m, "3.3 Variable O&M")
m <- P(m, "Aurecon 2024 Cost and Technical Parameters Review, by technology class: CCGT $4.1/MWh, OCGT $8.1/MWh (large frame), reciprocating $8.51/MWh, gas-steam proxied at $2.5/MWh. These are new-entrant representative costs and small relative to fuel, so they barely move the SRMC level; the heat rate and gas price dominate.")
m <- H2(m, "3.4 The two SRMC measures")
m <- P(m, "SRMC_marginal = fuel_price(GJ) x incremental_heat_rate + VOM. SRMC_allin = fuel_price(GJ) x static_heat_rate + VOM. The marginal measure is the relevant threshold for the above-cost withholding test (is the marginal offer band priced above the marginal cost of one more MWh while running); the all-in measure is used for the on/off question and as a robustness threshold. Validation (Gate A): d_t exceeds SRMC_marginal in 33-34 of 35 months for every unit, with no structural break at the d_t exit, confirming the variation is in the prize not in cost.")

m <- H1(m, "4. Withheld share (primary outcome)")
m <- P(m, "Definition, per treated unit and 5-minute interval: withheld_share = (sum over price bands j of BANDAVAIL_j for bands with PRICEBAND_j > SRMC_marginal) / MAXAVAIL. It is the fraction of a unit's available capacity that is offered above its marginal cost. Construction: keep the latest rebid version per unit-interval (most recent OFFERDATETIME); join the daily price bands (BIDDAYOFFER PRICEBAND1-10) to the interval band quantities (BIDOFFERPERIOD BANDAVAIL1-10); compare each band's price to the unit-month SRMC_marginal; sum the qualifying band quantities and divide by MAXAVAIL. The measure is defined when MAXAVAIL > 1 MW and is capped at 1. It is SRMC-relative by design, so a change in the cost environment does not mechanically move it for a fixed offer.")

m <- H1(m, "5. Spot price and net rent")
m <- P(m, "Spot: SA1 regional reference price (DISPATCHPRICE RRP), base run only (INTERVENTION = 0), at native 5-minute resolution. In regressions spot enters at 5-minute resolution so within-day volatility is fully preserved. For figures that require a monthly spot level, a hierarchical aggregation (5-minute to 30-minute to daily to monthly) is used so that each day contributes equally rather than a flat mean dominated by a few cap-priced intervals; with complete 5-minute data this nested mean equals the grand mean, so a separate spike-share statistic (fraction of intervals above $300/MWh) carries the within-day volatility information. Net rent, per directed interval: rent = d_t - spot, the per-MWh value of being directed rather than settling at spot.")

m <- H1(m, "6. Derived descriptive cuts")
m <- B(m, "d_t terciles: tercile cutpoints of d_t computed over the directed-interval distribution, labelling Low, Mid, High; used to show net rent rising with d_t.")
m <- B(m, "Direction margin: d_t - SRMC_marginal, the per-MWh rent over marginal cost; reported by unit and pre/post exit.")
m <- B(m, "Direction volume: total directed unit-hours per month (directed 5-minute intervals summed across units, times 5/60); plotted against the fleet-mean margin to show AEMO direction incidence is only weakly correlated with the rent (correlation 0.167), supporting exogeneity of direction incidence.")

m <- H1(m, "7. System-strength pivotality")
m <- P(m, "Scripts: extract_dispatchload.R (online status) and pivotality.R (the measure). This is the central new construction, so it is documented in full.")
m <- H2(m, "7.1 The security standard")
m <- P(m, "AEMO publishes acceptable minimum synchronous generator combinations for SA (sa_minimum_generator_combinations.csv): 123 rows across the system-normal and risk-of-islanding regimes. Each row specifies, at a given non-synchronous penetration threshold (non_sync_mw) and required synchronous-condenser count, how many units at each station must be online. The eight station columns are torrens_island_b, pelican_point_gt, osborne_gt_st, quarantine_5, dry_creek, mintaro, bips, snapper_point. System strength is secure if and only if the online synchronous fleet satisfies at least one applicable combination, that is, for every station the online count meets or exceeds that row's requirement.")
m <- H2(m, "7.2 Station-to-DUID mapping and online counts")
m <- P(m, "Multi-DUID stations are counted exactly from dispatch: torrens_island_b = number of TORRB1-4 online; dry_creek = number of DRYCGT1-3 online. Single-DUID multi-unit stations are approximated from MW because dispatch does not resolve the internal units: pelican_point_gt = 2 if PPCCGT > 250 MW else 1 if > 0; osborne_gt_st = 2 if OSB-AG > 120 MW else 1 if > 0; bips = round(BARKIPS1 MW / 16.1), capped at 12 (Barker Inlet is roughly twelve reciprocating engines under one DUID); snapper_point = round(MW / 20), capped at 5 (appears only in islanding combinations). A unit is online (synchronised) when TOTALCLEARED > 0 in DISPATCHLOAD; mere availability is not enough, because peakers sit available but unsynchronised 98-100% of the time and provide no system strength unless actually running.")
m <- H2(m, "7.3 Non-synchronous penetration and the applicable tier")
m <- P(m, "Non-synchronous penetration in each interval is the summed dispatched output (TOTALCLEARED) of SA semi-scheduled units, identified as those carrying a positive semi-dispatch cap (or, where the field exists, a positive intermittent-generation forecast UIGF). A combination with threshold T is treated as applicable when observed non-synchronous penetration is at or below T; as penetration rises, fewer and stricter combinations remain applicable. If penetration exceeds the maximum threshold, the strictest tier is used. Synchronous-condenser availability is assumed met throughout (the four SA condensers were commissioned in 2021); the analysis uses the system-normal regime as the headline, with risk-of-islanding combinations reserved for robustness.")
m <- H2(m, "7.4 The feasibility test and the two pivotality measures")
m <- P(m, "Feasibility(counts, penetration): TRUE if at least one applicable combination has every station requirement met by counts. Realised pivotality, piv: for an online unit, drop one of its units from the online vector and test feasibility; if removal makes every applicable combination infeasible, the unit is pivotal (incumbency). When the online fleet already satisfies no combination (the system is short), pivotality is assessed on the available menu (completion). Ex-ante pivotality, pex: set the station's availability to zero and test whether the remaining rivals' available fleet can satisfy any applicable combination; if not, the unit is essential. The ex-ante measure depends only on rivals' availability and the non-synchronous penetration, never on the unit's own online status or its own offer, and is therefore exogenous to the unit's own withholding. It is the clean treatment; the realised measure is reported alongside for completeness and is more prevalent but endogenous.")
m <- H2(m, "7.5 Prevalence and validation")
pv <- data.frame(
  Station = c("Torrens Island B","Pelican Point","Mintaro","Quarantine 5","Osborne / Dry Creek / BIPS / Snapper"),
  Realised_pct = c("42.4","15.3","11.8","1.6","~0"),
  ExAnte_pct   = c("1.3","0.1","~0","~0","~0"),
  stringsAsFactors = FALSE)
m <- TBL(m, pv)
m <- P(m, "Ex-ante essentiality is rare because peakers sit near-100% available, so the available fleet can almost always form some combination without any single unit; the rare cases are the genuinely scarce moments of unambiguous market power. Validation: directions concentrate in pivotal intervals. The probability that TIB is pivotal given it is directed is 0.65 versus a 0.44 baseline; for Pelican Point, 0.35 versus 0.17 (a 2.1-fold concentration). AEMO directs units 1.5 to 2 times more often when they are pivotal, confirming the measure tracks genuine security need.")

m <- H1(m, "8. Rebid measures")
m <- P(m, "Script: rebid_analysis.R. All offer versions are retained in BIDOFFERPERIOD, identified by OFFERDATETIME, which permits intraday rebid analysis. Three unit-day measures are built.")
m <- H2(m, "8.1 Rebid intensity")
m <- P(m, "n_versions = number of distinct OFFERDATETIME values per unit-day (mean 14.5; up to 51 for Pelican Point). This counts revisions regardless of direction.")
m <- H2(m, "8.2 Quantity withholding")
m <- P(m, "Interval-fixed first-versus-last MAXAVAIL change. For each unit, day, and 5-minute interval, take the MAXAVAIL of the first offer version (earliest OFFERDATETIME) and of the last version, and average (first minus last) over the day's intervals. A positive value means the unit withdrew available capacity across the trading day. The interval is held fixed so the comparison is like-for-like and not contaminated by the within-day shape of MAXAVAIL.")
m <- H2(m, "8.3 Price-band escalation")
m <- P(m, "Above-SRMC capacity share in the last version minus the first. The day's price ladder is held fixed at the latest BIDDAYOFFER price bands. For the first and last quantity versions, the band quantities (BANDAVAIL1-10, summed over the day's intervals) are split by whether each band's price exceeds SRMC_marginal, and the above-SRMC share is computed for each version. The escalation is the last-version share minus the first-version share; a positive value means the unit's rebidding moved capacity up the price ladder, above marginal cost, over the day. This isolates price withholding via rebid, complementing the quantity measure.")

m <- H1(m, "9. Estimation and inference")
m <- P(m, "Estimators are two-way fixed-effects linear regressions (fixest::feols). The level test regresses withheld_share on the pivotality indicator with unit fixed effects and SRMC and spot controls; the prize test regresses on standardised d_t interacted with pivotality; the within-day test (Cut 6) uses unit-by-month fixed effects with d_t held fixed within month so identification comes from spot variation. Rebid tests regress the three unit-day measures on the daily pivotal share with unit and month fixed effects. Standard errors are clustered by month, the dimension in which the predetermined d_t and the non-synchronous state vary. Because the cluster counts are small (35 months; 11-12 units), analytic cluster-robust errors are a stopgap; the wild-cluster bootstrap with Webb weights is the planned primary inference for headline coefficients and is not yet run.")

m <- H1(m, "10. Assumptions and limitations")
al <- data.frame(
  Area = c("d_t resolution","SRMC heat rates","SRMC gaps","Online status","BIPS/Pelican counts","Non-sync tier","Syn condensers","Ex-ante sparsity","Rebid escalation","Inference"),
  Assumption_or_limitation = c(
    "Monthly trailing 90th percentile used operationally; per-issue-date variation within month suppressed.",
    "AEMO incremental vs static; PPCCGT/OSB-AG anomaly forces static for both measures.",
    "BARKIPS1 heat rate and TORRB VOM are proxies, flagged; the revealed-cost anchor was tested (gate_a_revealed_cost.R) and rejected -- offers are not gas-indexed cost bids [F3a] -- so the proxies stand and engineering SRMC is maintained.",
    "Synchronised proxied by TOTALCLEARED > 0; units spinning at zero MW are treated as offline.",
    "Internal unit counts approximated from MW; bind only for combinations requiring two-plus of a single-DUID station.",
    "A combination applies at or below its non_sync_mw threshold; mapping to be checked against AEMO source. Rooftop solar (non-scheduled) is excluded from the penetration measure.",
    "Four SA condensers assumed available throughout (true post-2021).",
    "Ex-ante binary pivotality is rare (TIB 1.3%), so power for the binary spec is limited; the continuous non-sync driver is the higher-powered exogenous instrument and agrees.",
    "Price ladder held at the day's latest bands; pure price-band rebids within the day are not separately tracked.",
    "Few clusters; wild-cluster bootstrap pending."),
  stringsAsFactors = FALSE)
m <- TBL(m, al)

m <- H1(m, "11. Reproducibility")
m <- P(m, "Pipeline order: extract_dispatchload.R (DISPATCHLOAD, 36 months) then pivotality.R (pivotality_panel.rds); gate_a_srmc.R (SRMC) and descriptive_analysis_v3.R (panel_v3.rds, Cuts 2-6); figures_srmc_controlled.R and cut5_spot_controlled.R (controlled figures and spot robustness); pivotality_analysis.R and rebid_analysis.R (pivotal-vs-non-pivotal bidding and rebids). Outputs are written to outputs/descriptives_v3/. Numbers cited here and in the proposal are traceable to the fact bullets in facts_memo.md and the readouts descriptive_readout_v3.md and pivotality_readout.md.")

print(m, target = file.path(OUTDIR, "methods.docx"))
cat("wrote methods.docx\n")
cat("done ->", normalizePath(OUTDIR), "\n")
