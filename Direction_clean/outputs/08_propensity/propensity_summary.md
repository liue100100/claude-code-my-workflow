# The direction propensity, on one page

**What triggers directions.** Directions fire on the commitment margin, not the availability
margin. The rival fleet's declared capacity satisfies South Australia's minimum-synchronous
standard 98.6% of all half-hours; the fleet actually running satisfies it only 50.6%. Directed
time decomposes almost entirely into real need at the commitment margin: 86.4% of directed
half-hours have the committed fleet below the standard, 7.4% is post-need trailing time, 2.5%
is pre-need buffer, 0.4% is extension chaining, and 2.8% is unexplained. The operator directs
at the need, not ahead of it: the median gap from issue to the first commitment shortfall is
half an hour. On the strict availability margin the picture inverts — 73.5% of directed time
sits in episodes where the rival fleet, had it been running, could have covered the standard
without Torrens. The scheme pays for commitment, and commitment is what the market does not
deliver on its own.

**How predictable the trigger is from public information.** Highly. A nine-parameter hazard on
rivals' lodged bids, the PASA demand forecast, and the combination tables — no focal inputs, no
spot price, no direction history — separates onset from non-onset half-hours with a month-out
cross-validated AUC of 0.85–0.86, calibrated across all ten predicted-risk deciles. Forecast
slack over the commitment lead window is the workhorse; the morning commitment window dominates
the clock pattern. A trading desk could compute this propensity in real time from public data,
and its accumulated 8-hour version is near its maximum exactly where the realized essentiality
flag fires (mean π 0.56 there, against 0.14 elsewhere).

**What conduct loads on, and does not.** The desk's posture tracks the propensity: the
probability that a Torrens unit keeps its floor within dispatch's reach falls by roughly 40
percentage points as the rivals-only propensity moves from zero to one (p = 0.002; the same on
a day-ahead, timing-immunized propensity, p = 0.009). It does not track what the direction
pays: π × d_t is +0.02 (p = 0.56; randomization inference p = 0.83), the slow and fast
components are both null, and a binary exposure flag at exactly the realized-flag's incidence
carries −0.02 (p = 0.26) where the realized flag carries −0.086 (p < 0.001). The registered
null reading therefore stands: the payment-sensitivity result is a property of realized
essentiality — the moments the system in fact could not do without the units — and does not
generalize to ex-ante exposure. The sharpest version of the question — does conduct scale with
the expected prize, probability times net payment, holding the probability fixed — was
registered and run separately (Stage 5): the expected-prize dose is well-powered (IQR $47/MWh
across essential rows, four times the raw rent's) and comes back wrong-signed and null (+0.15,
randomization inference p = 0.19). Conduct responds to whether a direction is coming; on every
ex-ante margin where a payment object is identified — gross, net, or probability-weighted — it
shows no response to what the direction pays. The payment gradient exists only where realized
essentiality and the gross administered price meet.
