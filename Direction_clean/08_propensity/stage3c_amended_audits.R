#!/usr/bin/env Rscript
# stage3c_amended_audits.R -- Stage 3 under AMENDMENT 1 (registration.md, 2026-07-07):
# (2) incremental-R^2 tripwire: focal terms beyond the conditions must add ~0;
# (3a) day-ahead pi variant (rival availability = bid version in force at 00:00 of the target
#      trading day; project day-ahead-stance convention) -- breaks same-day reflection;
# (3b) reflection VAR: rivals' daily declared availability on lagged focal availability.
# The provenance manifest (amendment item 1) is recorded in the findings file directly.
# Run from Direction_clean/.

suppressMessages({ library(data.table) })
set.seed(20260707)
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")

S <- readRDS(file.path(OUT, "stage2_panel.rds")); setDT(S); setorder(S, t30)

# focal terms (as in stage3)
fa30 <- readRDS(file.path(OUT, "focal_avail_cache.rds"))
fa30[, t30 := as.POSIXct(ceiling(as.numeric(SETTLEMENTDATE) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
fa30 <- fa30[, .(tor_avail = mean(avail)), by = t30]
D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds")); setDT(D)
cs <- D[DUID %chin% c("TORRB2", "TORRB3", "TORRB4"), .(interval_dt, cheap_a_share)]
cs[, t30 := as.POSIXct(ceiling(as.numeric(interval_dt) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
cs30 <- cs[, .(tor_cheap_share = mean(cheap_a_share, na.rm = TRUE)), by = t30]

A <- Reduce(function(a, b) merge(a, b, by = "t30", all.x = TRUE),
            list(S[!is.na(pi2_8h), .(t30, pi2_8h, min_fc_slack, slack_commit, dem_trough,
                                     ns_share_fc, hour_block)], fa30, cs30))
A <- na.omit(A)
cat(sprintf("tripwire rows: %d\n", nrow(A)))

# ---- (2) incremental-R^2 tripwire ----
m_cond  <- lm(pi2_8h ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + hour_block, A)
m_full  <- lm(pi2_8h ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + hour_block +
                tor_avail + tor_cheap_share, A)
r2c <- summary(m_cond)$r.squared; r2f <- summary(m_full)$r.squared
cat(sprintf("\n(2) TRIPWIRE: R^2 conditions-only %.4f | + focal terms %.4f | incremental %.5f (must be ~0)\n",
            r2c, r2f, r2f - r2c))
print(coef(summary(m_full))[c("tor_avail", "tor_cheap_share"), , drop = FALSE])

# ---- (3a) day-ahead pi variant ----
# Rival availability from the bid version in force at 00:00 of the target's calendar day.
RIVALS <- c("PPCCGT","OSB-AG","QPS5","DRYCGT1","DRYCGT2","DRYCGT3","MINTARO","BARKIPS1","SNAPPER1")
DUID2STATION <- c(PPCCGT = "pelican_point_gt", `OSB-AG` = "osborne_gt_st", QPS5 = "quarantine_5",
                  DRYCGT1 = "dry_creek", DRYCGT2 = "dry_creek", DRYCGT3 = "dry_creek",
                  MINTARO = "mintaro", BARKIPS1 = "bips", SNAPPER1 = "snapper_point")
combos <- fread(file.path(ROOT, "Direction/sa_minimum_generator_combinations.csv"))
STATIONS <- c("torrens_island_b","pelican_point_gt","osborne_gt_st","quarantine_5",
              "dry_creek","mintaro","bips","snapper_point")
combos[, (STATIONS) := lapply(.SD, function(x) { x[is.na(x)] <- 0L; as.integer(x) }), .SDcols = STATIONS]
cs2 <- combos[regime == "system_normal"]; REQ <- as.matrix(cs2[, ..STATIONS]); THRESH <- cs2$non_sync_mw
mw_units <- function(duid, mw) switch(duid,
  PPCCGT   = fifelse(mw > 250, 2L, fifelse(mw > 0, 1L, 0L)),
  `OSB-AG` = fifelse(mw > 120, 2L, fifelse(mw > 0, 1L, 0L)),
  BARKIPS1 = pmin(as.integer(round(mw / 16.1)), 12L),
  SNAPPER1 = pmin(as.integer(round(mw / 20.0)), 5L),
  fifelse(mw > 0, 1L, 0L))
DEPTH_MEMO <- new.env(parent = emptyenv())
min_removals <- function(cnt, R_appl, tierkey) {
  key <- paste0(tierkey, "|", paste0(cnt, collapse = ","))
  hit <- DEPTH_MEMO[[key]]; if (!is.null(hit)) return(hit)
  unmet <- rowSums(sweep(R_appl, 2, cnt, FUN = function(req, have) req > have))
  sat <- which(unmet == 0)
  if (length(sat) == 0L) { assign(key, 0L, envir = DEPTH_MEMO); return(0L) }
  req0 <- R_appl[sat[1L], ]
  js <- which(req0 >= 1L & cnt >= req0)
  best <- Inf
  for (j in js) {
    cnt2 <- cnt; cnt2[j] <- req0[j] - 1L
    cost <- cnt[j] - cnt2[j]
    if (cost >= best) next
    sub <- min_removals(cnt2, R_appl, tierkey)
    if (is.finite(sub) && cost + sub < best) best <- cost + sub
  }
  assign(key, best, envir = DEPTH_MEMO); best
}
depth_torrens <- function(counts, nonsync) {
  appl <- THRESH >= nonsync
  if (!any(appl)) appl <- THRESH == max(THRESH)
  R_appl <- REQ[appl, , drop = FALSE]
  tkey <- paste(which(appl), collapse = "")
  cnt <- counts; cnt["torrens_island_b"] <- 0L
  k <- min_removals(cnt, R_appl, tkey)
  if (!is.finite(k)) sum(cnt) + 1L else k
}

DA_F <- file.path(OUT, "slack_da_cache.rds")
if (file.exists(DA_F)) { SDA <- readRDS(DA_F) } else {
  RB <- rbindlist(lapply(MONTHS, function(M) readRDS(file.path(CACHE, sprintf("RIVAL_BOP_%s.rds", M)))))
  RB[, `:=`(INTERVAL_DATETIME = force10(INTERVAL_DATETIME), OFFERDATETIME = force10(OFFERDATETIME))]
  setkey(RB, DUID, INTERVAL_DATETIME, OFFERDATETIME)
  qs <- CJ(t30 = S$t30, off = seq(0, 25, by = 5) * 60)[, t5 := t30 - 1500 + off][]
  qs[, day0 := as.POSIXct(paste(format(t30 - 1, "%Y-%m-%d"), "00:00:00"), tz = "Etc/GMT-10")]
  ub <- NULL
  for (dd in RIVALS) {
    q <- RB[.(dd, qs$t5, qs$day0), roll = Inf, on = .(DUID, INTERVAL_DATETIME, OFFERDATETIME),
            .(MAXAVAIL)]
    q[, `:=`(t30 = qs$t30)]
    q[is.na(MAXAVAIL), MAXAVAIL := 0]
    q[, u := mw_units(dd, MAXAVAIL)]
    agg <- q[, .(u = min(u)), by = t30][, station := DUID2STATION[[dd]]]
    ub <- rbind(ub, agg)
  }
  CTS <- dcast(ub[, .(u = sum(u)), by = .(t30, station)], t30 ~ station, value.var = "u", fill = 0L)
  # non-sync forecast: keep the pi2 source (PDPASA UIGF is weather-driven, not focal-touching);
  # use the 8h-target column already on the panel, realized fallback
  CTS <- merge(CTS, S[, .(t30, ns = fifelse(is.na(ns_fc_8h), nonsync_mw, ns_fc_8h))], by = "t30")
  for (s in STATIONS) if (!s %in% names(CTS)) CTS[[s]] <- 0L
  CM <- as.matrix(CTS[, ..STATIONS]); NSV <- CTS$ns
  sl <- integer(nrow(CTS))
  for (i in seq_len(nrow(CTS))) sl[i] <- depth_torrens(CM[i, ], NSV[i])
  SDA <- data.table(t30 = CTS$t30, slack_da = sl)
  saveRDS(SDA, DA_F)
}
S <- merge(S, SDA, by = "t30", all.x = TRUE)
setorder(S, t30)

# day-ahead hazard + pi (same registered covariates, slack_da replacing the fc-slack terms)
S[, yyyymm := format(t30 - 1, "%Y%m")]
Rset <- S[in_spell == FALSE & tsl_h > 8 & !is.na(slack_da) & !is.na(dem_trough) & !is.na(ns_share_fc)]
fml_da <- onset ~ slack_da + dem_trough + ns_share_fc + hour_block
P <- S[!is.na(slack_da) & !is.na(dem_trough) & !is.na(ns_share_fc)]
P[, hz_da := NA_real_]
for (M in MONTHS) {
  f <- glm(fml_da, family = binomial(), data = Rset[yyyymm != M])
  P[yyyymm == M, hz_da := predict(f, .SD, type = "response")]
}
S <- merge(S, P[, .(t30, hz_da)], by = "t30", all.x = TRUE)
setorder(S, t30)
S[is.na(hz_da), hz_da := 0]
accum <- function(hz, k) 1 - exp(frollsum(log(pmax(1 - hz, 1e-12)), n = k, align = "left"))
S[, pi_da_8h := accum(hz_da, 16)]
cat(sprintf("\n(3a) DAY-AHEAD pi: cor(pi_da_8h, pi2_8h) = %.3f\n",
            S[, cor(pi_da_8h, pi2_8h, use = "complete.obs")]))
A2 <- merge(A, S[, .(t30, pi_da_8h)], by = "t30")
m_cond_da <- lm(pi_da_8h ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + hour_block, A2)
m_full_da <- lm(pi_da_8h ~ min_fc_slack + slack_commit + dem_trough + ns_share_fc + hour_block +
                  tor_avail + tor_cheap_share, A2)
cat(sprintf("(3a) tripwire on pi_da: incremental R^2 = %.5f\n",
            summary(m_full_da)$r.squared - summary(m_cond_da)$r.squared))

# ---- (3b) reflection VAR: rivals' daily availability on lagged focal availability ----
RBD <- rbindlist(lapply(MONTHS, function(M) {
  b <- readRDS(file.path(CACHE, sprintf("RIVAL_BOP_%s.rds", M)))
  b[, day := as.Date(force10(INTERVAL_DATETIME) - 1, tz = "Etc/GMT-10")]
  # day-ahead stance: version in force at 00:00
  b[force10(OFFERDATETIME) < as.POSIXct(paste(day, "00:00:00"), tz = "Etc/GMT-10"),
    .SD[which.max(OFFERDATETIME), .(MAXAVAIL)], by = .(DUID, day, INTERVAL_DATETIME)][
      , .(mw = mean(MAXAVAIL)), by = .(DUID, day)][, .(rival_mw = sum(mw)), by = day]
}))
RBD <- RBD[, .(rival_mw = sum(rival_mw)), by = day][order(day)]
fadm <- readRDS(file.path(OUT, "focal_avail_cache.rds"))
fadm[, day := as.Date(force10(SETTLEMENTDATE) - 1, tz = "Etc/GMT-10")]
fad <- fadm[, .(tor_mw = mean(avail)), by = day]
V <- merge(RBD, fad, by = "day")[order(day)]
V[, `:=`(rival_l1 = shift(rival_mw), tor_l1 = shift(tor_mw), mth = format(day, "%Y%m"))]
V <- na.omit(V)
mv <- lm(rival_mw ~ rival_l1 + tor_l1 + factor(mth), V)
ct <- coef(summary(mv))["tor_l1", ]
cat(sprintf("\n(3b) REFLECTION: rival daily availability on lagged focal availability -- b = %.4f (se %.4f, t = %.2f, p = %.3f); own-lag %.3f; n = %d days\n",
            ct[1], ct[2], ct[3], ct[4], coef(mv)[["rival_l1"]], nrow(V)))

saveRDS(S, file.path(OUT, "stage2_panel.rds"))
res <- data.table(check = c("tripwire_incR2_pi2", "tripwire_incR2_pi_da", "cor_pi_da_pi2",
                            "reflection_b_torl1", "reflection_p"),
                  value = c(r2f - r2c,
                            summary(m_full_da)$r.squared - summary(m_cond_da)$r.squared,
                            S[, cor(pi_da_8h, pi2_8h, use = "complete.obs")], ct[1], ct[4]))
fwrite(res, file.path(OUT, "stage3c_amended_audits.csv"))
print(res)
cat("\nDONE stage3c\n")
