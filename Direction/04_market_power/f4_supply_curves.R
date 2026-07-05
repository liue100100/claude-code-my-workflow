#!/usr/bin/env Rscript
# f4_supply_curves.R
# F4 ("d_t exceeds SRMC; the unit prices far above marginal cost") rendered as offer
# curves, per unit, over three NESTED interval cuts:
#   ALL            = every interval (the everyday offer curve)
#   DIRECTED       = directed intervals only
#   DIRECTED_PIV   = directed AND pivotal intervals
# Same construction as supply_curves_by_regime.R: inverse supply curve, offer price/SRMC
# (log) at each cumulative-capacity quantile, cumulative offer capped at MAXAVAIL,
# median across months with an IQR ribbon. Two quantity normalisations.
# Run from Direction/. Outputs to outputs/descriptives_v3/supply_curves/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/descriptives_v3/supply_curves"; CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
           "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
duid2piv <- c(
  TORRB2="piv_torrens_island_b", TORRB3="piv_torrens_island_b", TORRB4="piv_torrens_island_b",
  PPCCGT="piv_pelican_point_gt", `OSB-AG`="piv_osborne_gt_st",
  QPS5="piv_quarantine_5", MINTARO="piv_mintaro", BARKIPS1="piv_bips",
  DRYCGT1="piv_dry_creek", DRYCGT2="piv_dry_creek", DRYCGT3="piv_dry_creek")
QGRID <- seq(0.05, 1.00, by = 0.05); MIN_INT <- 20L
mpc_by_yyyymm <- function(ym){ yr<-as.integer(substr(ym,1,4)); mo<-as.integer(substr(ym,5,6))
  fy<-ifelse(mo>=7L,yr+1L,yr); ifelse(fy<=2023L,15500,ifelse(fy==2024L,16600,17500)) }

panel <- readRDS("outputs/descriptives_v3/panel_v3.rds")[
  duid %in% UNITS, .(duid, interval_dt, directed, MAXAVAIL)]
cap95 <- panel[, .(cap = as.numeric(quantile(MAXAVAIL,0.95,na.rm=TRUE))), by=duid][cap>0]
piv <- readRDS("outputs/descriptives_v3/pivotality_panel.rds"); piv[, interval_dt := SETTLEMENTDATE]
pv <- rbindlist(lapply(UNITS, function(u)
  data.table(duid=u, interval_dt=piv$interval_dt, pivotal=piv[[duid2piv[[u]]]])))
reg <- merge(panel[, .(duid, interval_dt, directed)], pv, by=c("duid","interval_dt"), all.x=TRUE)
reg[is.na(pivotal), pivotal := FALSE]
reg <- reg[, .(duid, interval_dt, directed, pivotal)]
srmc_ref <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  , .(duid, yyyymm=as.character(yyyymm), srmc=srmc_marginal)]

price_at <- function(cumshare, PB, q, mpc_vec){
  hit <- cumshare >= q; idx <- max.col(hit, ties.method="first")
  pr <- PB[cbind(seq_len(nrow(PB)), idx)]; pr[rowSums(hit)==0] <- mpc_vec[rowSums(hit)==0]; pr }

ba_cols <- paste0("BANDAVAIL",1:10); pb_cols <- paste0("PRICEBAND",1:10)
months <- sprintf("%d%02d", rep(2022:2024,each=12), rep(1:12,3))
months <- months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", months)))]

curve_list <- vector("list", length(months))
for (i in seq_along(months)) {
  M <- months[i]; mpc <- mpc_by_yyyymm(M)
  bop <- readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%s.rds", M))); setDT(bop)
  bop <- bop[DUID %in% cap95$duid & BIDTYPE=="ENERGY"]
  bop <- bop[bop[, .I[which.max(OFFERDATETIME)], by=.(DUID,INTERVAL_DATETIME)]$V1]
  bop <- bop[, c("DUID","INTERVAL_DATETIME","TRADINGDATE","MAXAVAIL", ba_cols), with=FALSE]
  bop[, td := as.Date(TRADINGDATE)]
  bdo <- readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%s.rds", M))); setDT(bdo)
  bdo <- bdo[DUID %in% cap95$duid & BIDTYPE=="ENERGY"]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID,SETTLEMENTDATE)]$V1]; bdo[, td := as.Date(SETTLEMENTDATE)]
  m <- merge(bop, bdo[, c("DUID","td",pb_cols), with=FALSE], by=c("DUID","td"))
  m <- merge(m, reg, by.x=c("DUID","INTERVAL_DATETIME"), by.y=c("duid","interval_dt"))
  m[, yyyymm := M]
  m <- merge(m, srmc_ref, by.x=c("DUID","yyyymm"), by.y=c("duid","yyyymm"))
  m <- merge(m, cap95, by.x="DUID", by.y="duid")
  m <- m[is.finite(MAXAVAIL) & MAXAVAIL>1 & is.finite(srmc) & srmc>0]
  if (!nrow(m)) next
  BA <- as.matrix(m[, ..ba_cols]); BA[is.na(BA)] <- 0; PB <- as.matrix(m[, ..pb_cols])
  SR <- m$srmc; MA <- m$MAXAVAIL; CAP <- m$cap; mpcv <- rep(mpc, nrow(m))
  cumBA <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1]+BA[,j]
  cumBA_eff <- pmin(cumBA, MA)
  cumsh_ma <- cumBA_eff/MA; cumsh_reg <- cumBA_eff/CAP
  # cut membership per interval
  m[, `:=`(is_all=TRUE, is_dir=directed==1L, is_dpv=directed==1L & pivotal==TRUE)]
  # fixed-interval-set median (drop any interval with a gap; clamp floor for log) -> monotone curves
  mk <- function(cumsh, norm){
    id <- seq_len(nrow(m))
    pts <- rbindlist(lapply(QGRID, function(q){
      pr <- price_at(cumsh, PB, q, mpcv)
      data.table(id=id, DUID=m$DUID, q=q, price=pr,
                 is_all=m$is_all, is_dir=m$is_dir, is_dpv=m$is_dpv)}))
    bad <- pts[!is.finite(price), unique(id)]; pts <- pts[!id %in% bad]
    pts[, ratio := pmax(price / SR[id], 0.1)]
    long <- rbindlist(list(
      pts[is_all==TRUE][, cut:="ALL"],
      pts[is_dir==TRUE][, cut:="DIRECTED"],
      pts[is_dpv==TRUE][, cut:="DIRECTED_PIV"]))
    long[, .(med=median(ratio), q25=quantile(ratio,.25), q75=quantile(ratio,.75),
             med_p=median(price), lo_p=quantile(price,.25), hi_p=quantile(price,.75), n=.N),
         by=.(DUID, cut, q)][n>=MIN_INT][, norm:=norm][] }
  curve_list[[i]] <- rbind(mk(cumsh_ma,"MAXAVAIL"), mk(cumsh_reg,"registered"))[, yyyymm:=M][]
  cat(sprintf("  [%s] ok\n", M))
}
curves <- rbindlist(curve_list)
CUR <- curves[, .(ratio=median(med), lo=quantile(med,.25), hi=quantile(med,.75),
                  price=median(med_p), plo=quantile(med_p,.25), phi=quantile(med_p,.75), n_mth=.N),
              by=.(DUID, cut, q, norm)]
fwrite(CUR, file.path(OUT, "f4_supply_curves.csv"))

cut_lab <- c(ALL="All intervals (every day)", DIRECTED="Directed intervals",
             DIRECTED_PIV="Directed & pivotal")
cut_col <- c(ALL="#4575b4", DIRECTED="#fd8d3c", DIRECTED_PIV="#d7191c")
CUR[, cut := factor(cut, levels=names(cut_lab))]
UNIT_ORDER <- UNITS[UNITS %in% unique(CUR$DUID)]; CUR[, DUID := factor(DUID, levels=UNIT_ORDER)]
srmc_line <- srmc_ref[duid %in% UNIT_ORDER, .(srmc=median(srmc)), by=.(DUID=duid)][
  , DUID := factor(DUID, levels=UNIT_ORDER)]

plot_norm <- function(nm, extra){
  ggplot(CUR[norm==nm], aes(q, ratio, colour=cut, fill=cut)) +
    geom_hline(yintercept=1, linetype="dashed", colour="grey40") +
    geom_ribbon(aes(ymin=lo, ymax=hi), alpha=0.12, colour=NA) +
    geom_line(linewidth=0.9) +
    facet_wrap(~DUID, ncol=4, scales="free_x") +
    scale_y_log10(breaks=c(0.1,0.5,1,2,5,10,50,150),
                  labels=c("0.1","0.5","1 (SRMC)","2","5","10","50","150")) +
    scale_x_continuous(labels=scales::percent_format(accuracy=1)) +
    scale_colour_manual(values=cut_col, labels=cut_lab, name=NULL) +
    scale_fill_manual(values=cut_col, labels=cut_lab, name=NULL) +
    labs(title=sprintf("F4 as offer curves: price vs SRMC, nested interval cuts -- x = %s", nm),
         subtitle=paste("Offer price / SRMC (log) at each cumulative-capacity quantile; median across months, IQR ribbon.",
                        "F4: the curve sits far above SRMC (=1) -> being directed is a rent.", extra, sep="\n"),
         x=sprintf("Cumulative capacity offered (share of %s)", nm),
         y="Offer price / SRMC  (1 = marginal cost)") +
    theme_bw(base_size=9) + theme(legend.position="bottom", strip.text=element_text(size=8)) }

ggsave(file.path(OUT,"f4_supply_curves_MAXAVAIL.png"),
       plot_norm("MAXAVAIL","Isolates the price/steepness shape."), width=15, height=10, dpi=150)
ggsave(file.path(OUT,"f4_supply_curves_registered.png"),
       plot_norm("registered","Truncation = quantity withheld (MAXAVAIL cut)."), width=15, height=10, dpi=150)

# ---- RAW-DOLLAR view ----
plot_raw <- function(nm, extra){
  ggplot(CUR[norm==nm], aes(q, price, colour=cut, fill=cut)) +
    geom_hline(data=srmc_line, aes(yintercept=srmc), linetype="dashed", colour="grey35") +
    geom_ribbon(aes(ymin=plo, ymax=phi), alpha=0.12, colour=NA) +
    geom_line(linewidth=0.9) +
    facet_wrap(~DUID, ncol=4, scales="free_x") +
    scale_y_continuous(labels=scales::dollar_format()) +
    scale_x_continuous(labels=scales::percent_format(accuracy=1)) +
    scale_colour_manual(values=cut_col, labels=cut_lab, name=NULL) +
    scale_fill_manual(values=cut_col, labels=cut_lab, name=NULL) +
    labs(title=sprintf("F4 as offer curves -- RAW $/MWh, nested interval cuts, x = %s", nm),
         subtitle=paste("Offer price ($/MWh, unscaled, linear) at each cumulative-capacity quantile; median across months, IQR ribbon.",
                        "Dashed grey = unit median SRMC (cost). Ceiling = market price cap.", extra, sep="\n"),
         x=sprintf("Cumulative capacity offered (share of %s)", nm),
         y="Offer price ($/MWh)") +
    theme_bw(base_size=9) + theme(legend.position="bottom", strip.text=element_text(size=8)) }
ggsave(file.path(OUT,"f4_supply_curves_MAXAVAIL_raw.png"),
       plot_raw("MAXAVAIL","Isolates the price shape."), width=15, height=10, dpi=150)
ggsave(file.path(OUT,"f4_supply_curves_registered_raw.png"),
       plot_raw("registered","Truncation to the cap = quantity withheld."), width=15, height=10, dpi=150)
cat("\nSaved f4_supply_curves_{MAXAVAIL,registered}{,_raw}.png and .csv\n")
