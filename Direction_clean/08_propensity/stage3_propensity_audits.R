#!/usr/bin/env Rscript
# stage3_propensity_audits.R -- Stage 3: (i) leakage regression of pi on the focal station's
# own availability + cheap share (stop condition R^2 > 0.01); (ii) tier nesting (pex / N-1 /
# rest); (iii) slow/fast variance split. Run from Direction_clean/.

suppressMessages({ library(data.table) })
ROOT <- normalizePath("..")
OUT  <- file.path(ROOT, "Direction_clean/outputs/08_propensity")
CACHE <- file.path(ROOT, "Direction/bid_cache")
force10 <- function(x) { x <- as.POSIXct(x); attr(x, "tzone") <- "Etc/GMT-10"; x }
MONTHS <- format(seq(as.Date("2022-01-01"), as.Date("2024-12-01"), by = "month"), "%Y%m")
TOR <- c("TORRB1", "TORRB2", "TORRB3", "TORRB4")

S <- readRDS(file.path(OUT, "stage2_panel.rds")); setDT(S)

# ---- focal inputs: station availability (DISPATCHLOAD) + cheap share (regression panel) ----
FA_F <- file.path(OUT, "focal_avail_cache.rds")
if (file.exists(FA_F)) { FA <- readRDS(FA_F) } else {
  FA <- rbindlist(lapply(MONTHS, function(M) {
    dl <- readRDS(file.path(CACHE, sprintf("DISPATCHLOAD_%s.rds", M))); setDT(dl)
    dl <- dl[DUID %chin% TOR & INTERVENTION == 0, .(SETTLEMENTDATE, DUID, AVAILABILITY)]
    dl[, SETTLEMENTDATE := force10(SETTLEMENTDATE)]
    unique(dl, by = c("SETTLEMENTDATE", "DUID"))[, .(avail = sum(AVAILABILITY)), by = SETTLEMENTDATE]
  }))
  saveRDS(FA, FA_F)
}
FA[, t30 := as.POSIXct(ceiling(as.numeric(SETTLEMENTDATE) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
fa30 <- FA[, .(tor_avail = mean(avail)), by = t30]

D <- readRDS(file.path(ROOT, "Direction_clean/outputs/03_rq1_essentiality/regression_panel.rds")); setDT(D)
cs <- D[DUID %chin% c("TORRB2", "TORRB3", "TORRB4"), .(interval_dt, cheap_a_share)]
cs[, t30 := as.POSIXct(ceiling(as.numeric(interval_dt) / 1800) * 1800, origin = "1970-01-01", tz = "Etc/GMT-10")]
cs30 <- cs[, .(tor_cheap_share = mean(cheap_a_share, na.rm = TRUE)), by = t30]

A <- Reduce(function(a, b) merge(a, b, by = "t30", all.x = TRUE),
            list(S[!is.na(pi_8h), .(t30, pi_8h, pi_slow, pi_fast, pex30, n1_30)], fa30, cs30))
A <- A[!is.na(tor_avail) & !is.na(tor_cheap_share)]
cat(sprintf("audit rows: %d\n", nrow(A)))

# ---- (i) leakage ----
lk <- lm(pi_8h ~ tor_avail + tor_cheap_share, A)
r2 <- summary(lk)$r.squared
cat(sprintf("\n(i) LEAKAGE: pi_8h ~ focal availability + focal cheap share -> R^2 = %.5f (stop if > 0.01)\n", r2))
print(coef(summary(lk)))
verdict <- if (r2 > 0.01) "FAIL -- STOP CONDITION FIRES" else "PASS"
cat(sprintf("VERDICT: %s\n", verdict))

# ---- (ii) nesting: mean pi by tier ----
A[, tier := fifelse(pex30, "pex = 1", fifelse(n1_30, "N-1 = 1 (not pex)", "rest"))]
nest <- A[, .(n = .N, mean_pi = mean(pi_8h), p90_pi = quantile(pi_8h, .9)), by = tier][order(-mean_pi)]
cat("\n(ii) NESTING: mean pi_8h by tier (expect pex >= N-1 >= rest)\n"); print(nest)

# ---- (iii) slow/fast variance split ----
vs <- A[!is.na(pi_slow), .(var_pi = var(pi_8h), var_slow = var(pi_slow), var_fast = var(pi_fast))]
cat(sprintf("\n(iii) VARIANCE SPLIT: slow %.1f%% | fast %.1f%% of var(pi_8h)\n",
            100 * vs$var_slow / vs$var_pi, 100 * vs$var_fast / vs$var_pi))

fwrite(nest, file.path(OUT, "stage3_nesting.csv"))
fwrite(data.table(r2_leakage = r2, verdict = verdict,
                  var_share_slow = vs$var_slow / vs$var_pi), file.path(OUT, "stage3_audits.csv"))
cat("\nDONE stage3\n")
