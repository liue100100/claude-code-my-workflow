#!/usr/bin/env Rscript
# f5_runup_supply_curves.R
# The pre-issue rebid run-up ([F16]/Analysis B) rendered as an EVOLVING offer curve:
# how does a unit's supply curve shift as the direction issue time tau approaches?
#
# For each Synchronise episode we take every BIDOFFERPERIOD version whose target
# interval g lies in the directed window [s,c], average the 10-band offer over g,
# and index the version by Delta = OFFERDATETIME (submission) - tau (issue), in hours.
# Versions are binned on Delta; per (unit, Delta-bin) we build the median inverse
# supply curve (offer price / SRMC at each cumulative-capacity quantile), cumulative
# offer capped at MAXAVAIL. Delta<0 is the interpretable run-up; Delta>0 is post-issue
# (contaminated by the direction itself) -- shown dashed, never read as reversion.
#
# Run from Direction/. Outputs to outputs/direction_rebid/.

suppressMessages({ library(data.table); library(ggplot2) })
setwd("C:/Users/ericl/Documents/my-project/Direction")
OUT <- "outputs/direction_rebid"; CACHE <- "bid_cache"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

QGRID <- seq(0.05, 1.00, by = 0.05); MIN_VER <- 15L
BANDS <- 1:10; bcols <- paste0("BANDAVAIL",BANDS); pcols <- paste0("PRICEBAND",BANDS)
mpc_by_yyyymm <- function(ym){ yr<-as.integer(substr(ym,1,4)); mo<-as.integer(substr(ym,5,6))
  fy<-ifelse(mo>=7L,yr+1L,yr); ifelse(fy<=2023L,15500,ifelse(fy==2024L,16600,17500)) }

# registered-capacity proxy per unit (95th-pctile MAXAVAIL), same as supply-curve scripts
UNITS <- c("TORRB2","TORRB3","TORRB4","PPCCGT","OSB-AG",
           "MINTARO","BARKIPS1","DRYCGT1","DRYCGT2","DRYCGT3","QPS5")
cap95 <- readRDS("outputs/descriptives_v3/panel_v3.rds")[
  duid %in% UNITS, .(cap = as.numeric(quantile(MAXAVAIL,0.95,na.rm=TRUE))), by=duid][cap>0]

ep <- as.data.table(readRDS(file.path(OUT, "episodes.rds")))
ep <- ep[instruction == "Synchronise"]                       # headline
ep[, `:=`(tau_s = as.numeric(tau),
          s_grid = (floor(as.numeric(s)/300)+1)*300,
          c_grid =  floor(as.numeric(c)/300)*300)]
ep <- ep[c_grid >= s_grid & duid %in% cap95$duid]
DIRECTED_DUIDS <- unique(ep$duid)

srmc <- fread("outputs/descriptives_v3/GateA_srmc_params.csv")[
  , .(DUID=duid, yyyymm=as.integer(yyyymm), srmc=srmc_marginal)]

# months to scan
tzb <- "Australia/Brisbane"
all_months <- unique(unlist(lapply(seq_len(nrow(ep)), function(i){
  ms <- seq(as.Date(format(as.POSIXct(ep$s_grid[i],origin="1970-01-01",tz=tzb))),
            as.Date(format(as.POSIXct(ep$c_grid[i],origin="1970-01-01",tz=tzb))), by="month")
  unique(as.integer(format(ms,"%Y%m"))) })))
months <- sort(all_months[file.exists(file.path(CACHE, sprintf("BIDOFFERPERIOD_%d.rds", all_months))) &
                          file.exists(file.path(CACHE, sprintf("BIDDAYOFFER_%d.rds",  all_months)))])
cat(sprintf("Synchronise episodes: %d | months: %d\n", nrow(ep), length(months)))

# per (episode, version): sum over target intervals g of each band + MAXAVAIL + ladder + srmc
process_month <- function(M){
  b <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDOFFERPERIOD_%d.rds", M))))
  b <- b[BIDTYPE=="ENERGY" & DUID %in% DIRECTED_DUIDS,
         c("DUID","TRADINGDATE","INTERVAL_DATETIME","OFFERDATETIME","MAXAVAIL", bcols), with=FALSE]
  if (!nrow(b)) return(NULL)
  bdo <- as.data.table(readRDS(file.path(CACHE, sprintf("BIDDAYOFFER_%d.rds", M))))
  bdo <- bdo[BIDTYPE=="ENERGY" & DUID %in% DIRECTED_DUIDS]
  bdo <- bdo[bdo[, .I[which.max(OFFERDATE)], by=.(DUID,SETTLEMENTDATE)]$V1]
  ladder <- bdo[, c("DUID","SETTLEMENTDATE", pcols), with=FALSE]; setnames(ladder,"SETTLEMENTDATE","TRADINGDATE")
  b <- merge(b, ladder, by=c("DUID","TRADINGDATE"), all.x=TRUE)
  b[, yyyymm := as.integer(format(TRADINGDATE,"%Y%m"))]
  b <- merge(b, srmc, by=c("DUID","yyyymm"), all.x=TRUE)
  b[, isecs := as.numeric(INTERVAL_DATETIME)]
  bo <- b[, c("DUID","isecs","OFFERDATETIME","MAXAVAIL","srmc", bcols, pcols), with=FALSE]
  bo[, `:=`(istart=isecs, iend=isecs)]; setkey(bo, DUID, istart, iend)
  epk <- ep[, .(duid, episode_id, tau_s, g_lo=s_grid, g_hi=c_grid)]; setkey(epk, duid, g_lo, g_hi)
  m <- foverlaps(bo, epk, by.x=c("DUID","istart","iend"), by.y=c("duid","g_lo","g_hi"), nomatch=0L)
  if (!nrow(m)) return(NULL)
  agg <- m[, c(lapply(.SD, sum), .(n_g=.N)),
           by=.(episode_id, DUID, OFFERDATETIME, tau_s),
           .SDcols=c("MAXAVAIL", bcols)]
  # ladder + srmc: mean over g (sum then /n_g later); take sums
  agg2 <- m[, c(lapply(.SD, sum)), by=.(episode_id, OFFERDATETIME),
            .SDcols=c("srmc", pcols)]
  merge(agg, agg2, by=c("episode_id","OFFERDATETIME"))
}
VER_CACHE <- file.path(OUT, "f5_ver.rds")
if (file.exists(VER_CACHE) && !nzchar(Sys.getenv("REBUILD_F5"))) {
  cat("Reusing f5_ver.rds (set REBUILD_F5=1 to rescan).\n"); ver <- readRDS(VER_CACHE)
} else {
  raw <- rbindlist(lapply(months, function(M){ r<-process_month(M)
    cat(sprintf("  %d: %s\n", M, if(is.null(r)) 0 else nrow(r))); r }))
  sumcols <- c("MAXAVAIL", bcols, "srmc", pcols, "n_g")
  ver <- raw[, lapply(.SD, sum), by=.(episode_id, DUID, OFFERDATETIME, tau_s), .SDcols=sumcols]
  for (cc in c("MAXAVAIL", bcols, "srmc", pcols)) ver[[cc]] <- ver[[cc]] / ver$n_g   # -> means over g
  ver[, delta_h := (as.numeric(OFFERDATETIME) - tau_s)/3600]
  saveRDS(ver, VER_CACHE)
}

# Delta bins: pre-issue run-up + one post bin
brk <- c(-Inf,-24,-12,-6,-3,-1,0,3)
lab <- c("<=-24h","-24..-12h","-12..-6h","-6..-3h","-3..-1h","-1..0h","0..+3h (post)")
ver[, dbin := cut(delta_h, breaks=brk, labels=lab, right=FALSE)]
ver <- ver[!is.na(dbin)]
ver <- merge(ver, cap95, by.x="DUID", by.y="duid")

# build inverse supply curve per version, then median by (unit, dbin, q)
BA <- as.matrix(ver[, ..bcols]); BA[is.na(BA)] <- 0
PB <- as.matrix(ver[, ..pcols])
SR <- ver$srmc; MA <- ver$MAXAVAIL; CAP <- ver$cap
cumBA <- BA; for (j in 2:10) cumBA[,j] <- cumBA[,j-1]+BA[,j]
cumBA_eff <- pmin(cumBA, MA); cumsh_reg <- cumBA_eff/CAP; cumsh_ma <- cumBA_eff/MA
price_at <- function(cumshare, q, mpcv){ hit <- cumshare>=q; hit[is.na(hit)] <- FALSE
  idx <- max.col(hit,ties.method="first"); pr <- PB[cbind(seq_len(nrow(PB)), idx)]
  none <- rowSums(hit)==0; pr[none] <- mpcv[none]; pr }
mpcv <- mpc_by_yyyymm(format(ver$OFFERDATETIME, "%Y%m"))
mpcv[is.na(mpcv)] <- 17500

# fixed-version-set median (drop any version with a gap; clamp floor for log) -> monotone curves
mk <- function(cumsh, norm){
  ok <- which(is.finite(MA) & MA>1 & is.finite(SR) & SR>0)
  pts <- rbindlist(lapply(QGRID, function(q){
    pr <- price_at(cumsh,q,mpcv)
    data.table(id=ok, DUID=ver$DUID[ok], dbin=ver$dbin[ok], q=q, price=pr[ok]) }))
  bad <- pts[!is.finite(price), unique(id)]; pts <- pts[!id %in% bad]
  pts[, ratio := pmax(price / SR[id], 0.1)]
  pts[, .(ratio=median(ratio), price=median(price), n=.N),
      by=.(DUID,dbin,q)][n>=MIN_VER][, norm:=norm][] }
CUR <- rbind(mk(cumsh_reg,"registered"), mk(cumsh_ma,"MAXAVAIL"))
srmc_line <- ver[, .(srmc=median(srmc, na.rm=TRUE)), by=DUID]
fwrite(CUR, file.path(OUT, "f5_runup_supply_curves.csv"))
cat(sprintf("\nVersions: %d | episodes: %d | curve rows: %d\n",
            nrow(ver), uniqueN(ver$episode_id), nrow(CUR)))
print(ver[, .(versions=.N, episodes=uniqueN(episode_id)), by=DUID][order(-versions)])

# ---- plot: supply curve per unit, coloured by lead-time bin ----
UNIT_ORDER <- UNITS[UNITS %in% unique(CUR$DUID)]
CUR[, DUID := factor(DUID, levels=UNIT_ORDER)]
CUR[, dbin := factor(dbin, levels=lab)]
cols <- c("#2c7bb6","#4575b4","#74add1","#fdae61","#f46d43","#d73027","grey55")
names(cols) <- lab
plot_norm <- function(nm, extra){
  d <- CUR[norm==nm]
  ggplot(d, aes(q, ratio, colour=dbin, linetype=dbin=="0..+3h (post)")) +
    geom_hline(yintercept=1, linetype="dashed", colour="grey50") +
    geom_line(linewidth=0.85) +
    facet_wrap(~DUID, ncol=4, scales="free_x") +
    scale_y_log10(breaks=c(0.1,0.5,1,2,5,10,50,150),
                  labels=c("0.1","0.5","1 (SRMC)","2","5","10","50","150")) +
    scale_x_continuous(labels=scales::percent_format(accuracy=1)) +
    scale_colour_manual(values=cols, name="Lead (submission - issue)") +
    scale_linetype_manual(values=c(`FALSE`="solid",`TRUE`="22"), guide="none") +
    labs(title=sprintf("F5 run-up: offer curve shift approaching the direction issue -- x = %s", nm),
         subtitle=paste("Synchronise episodes. Offer price / SRMC (log) at each cumulative-capacity quantile;",
                        "median over bid versions in each lead-time bin. Blue=far before issue -> red=just before; grey dashed=post-issue.",
                        extra, sep="\n"),
         x=sprintf("Cumulative capacity offered (share of %s)", nm),
         y="Offer price / SRMC  (1 = marginal cost)") +
    theme_bw(base_size=9) + theme(legend.position="bottom", strip.text=element_text(size=8)) }
ggsave(file.path(OUT,"f5_runup_supply_curves_registered.png"),
       plot_norm("registered","Curve truncating/steepening as issue nears = withholding building in the run-up."),
       width=15, height=10, dpi=150)
ggsave(file.path(OUT,"f5_runup_supply_curves_MAXAVAIL.png"),
       plot_norm("MAXAVAIL","Price/steepness shape only."), width=15, height=10, dpi=150)

# ---- RAW-DOLLAR view ----
srmc_line[, DUID := factor(DUID, levels=UNIT_ORDER)]; srmc_line <- srmc_line[!is.na(DUID)]
plot_raw <- function(nm, extra){
  ggplot(CUR[norm==nm], aes(q, price, colour=dbin, linetype=dbin=="0..+3h (post)")) +
    geom_hline(data=srmc_line, aes(yintercept=srmc), linetype="dashed", colour="grey35") +
    geom_line(linewidth=0.85) +
    facet_wrap(~DUID, ncol=4, scales="free_x") +
    scale_y_continuous(labels=scales::dollar_format()) +
    scale_x_continuous(labels=scales::percent_format(accuracy=1)) +
    scale_colour_manual(values=cols, name="Lead (submission - issue)") +
    scale_linetype_manual(values=c(`FALSE`="solid",`TRUE`="22"), guide="none") +
    labs(title=sprintf("F5 run-up -- RAW $/MWh: offer curve shift approaching the direction issue, x = %s", nm),
         subtitle=paste("Synchronise episodes. Offer price ($/MWh, unscaled, linear); median over bid versions per lead-time bin.",
                        "Blue=far before issue -> red=just before; grey dashed=post-issue. Grey line = unit median SRMC.",
                        extra, sep="\n"),
         x=sprintf("Cumulative capacity offered (share of %s)", nm),
         y="Offer price ($/MWh)") +
    theme_bw(base_size=9) + theme(legend.position="bottom", strip.text=element_text(size=8)) }
ggsave(file.path(OUT,"f5_runup_supply_curves_registered_raw.png"),
       plot_raw("registered","Withdrawal of the cheap tranche toward the cap as issue nears."),
       width=15, height=10, dpi=150)
ggsave(file.path(OUT,"f5_runup_supply_curves_MAXAVAIL_raw.png"),
       plot_raw("MAXAVAIL","Price shape only."), width=15, height=10, dpi=150)
cat("\nSaved f5_runup_supply_curves_{registered,MAXAVAIL}{,_raw}.png and .csv\n")
