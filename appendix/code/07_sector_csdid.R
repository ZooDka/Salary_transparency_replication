## 07_sector_csdid.R
## -----------------------------------------------------------------------------
## Figure A.3: Callaway-Sant'Anna event studies of monthly private employment
## (as a share of state population) by QCEW super-sector, -12..+12 months.
##
## Same specification as the main analysis, at monthly frequency:
##   att_gt(y = employment_rate, t = month index, id = state,
##          g = first treated month, X = monthly change in COVID deaths/100k)
##   aggte(type = "dynamic", min_e = -12, max_e = 12)
## Panel titles follow the paper: "Employment Rate: <industry> <ownership>".
##
## Options (environment variables):
##   COVARIATE   ~ dmonthly_deathRate (default) | NULL
##   END_MONTH   "2024-03" (default) drops the preliminary 2024Q2 QCEW quarter,
##               which is incomplete for Colorado (otherwise did::att_gt drops
##               Colorado, a treated state, from every sector); "2024-06" = all.
##   GROUP_VAR   "first_treat_month" (default; month of first treatment) or
##               "groupedByTreatLength" (the WEEK index from the weekly scripts;
##               with a monthly time index did() reads 35/48 as months and
##               treats the other groups as never-treated).
## -----------------------------------------------------------------------------
source("code/00_prep.R")
suppressPackageStartupMessages(library(ggpubr))
set.seed(20250207)

COVARIATE <- ~ dmonthly_deathRate      # or NULL
END_MONTH <- Sys.getenv("SECTOR_END_MONTH", "2024-03")
GROUP_VAR <- Sys.getenv("SECTOR_GROUP_VAR", "first_treat_month")
OWNERSHIP <- "Private"                 # sub-sector rows exist only for Private in the QCEW extract
INDUSTRIES <- c("101 Goods-producing", "1011 Natural resources and mining", "1012 Construction",
                "1013 Manufacturing", "102 Service-providing",
                "1021 Trade, transportation, and utilities", "1022 Information",
                "1023 Financial activities", "1024 Professional and business services",
                "1025 Education and health services", "1026 Leisure and hospitality")
# excluded: "1027 Other services", "1029 Unclassified", "10 Total, all industries"

sec <- read.csv(file.path(PROC, "sector_monthly_panel.csv"), check.names = FALSE)
sec <- sec[sec$month <= END_MONTH, ]
sec$stateNum <- as.numeric(as.factor(sec$state))
if (GROUP_VAR == "groupedByTreatLength") {
  gw <- load_panel() %>% distinct(state, groupedByTreatLength)
  sec <- left_join(sec, gw, by = "state")
}
cat(sprintf("Sector panel: months %s..%s, group variable = %s, covariate = %s\n",
            min(sec$month), max(sec$month), GROUP_VAR, if (is.null(COVARIATE)) "none" else deparse(COVARIATE)))
TAG <- if (END_MONTH == "2024-03" && GROUP_VAR == "first_treat_month") "" else sprintf("_%s_%s", END_MONTH, GROUP_VAR)

run_one <- function(ind, own = OWNERSHIP) {
  d <- sec[sec$Industry == ind & sec$Ownership == own & !is.na(sec$employment_rate), ]
  n_per <- table(d$state)
  dropped <- names(n_per)[n_per < max(n_per)]   # states with suppressed months
  if (length(dropped)) cat(sprintf("  note: did::att_gt drops unbalanced state(s): %s\n", paste(dropped, collapse = ",")))
  # default allow_unbalanced_panel = FALSE: did drops units without all periods
  a <- att_gt(yname = "employment_rate", tname = "month_index", idname = "stateNum",
              gname = GROUP_VAR, xformla = COVARIATE, data = d)
  dyn <- aggte(a, type = "dynamic", min_e = -12, max_e = 12, na.rm = TRUE)
  list(attgt = a, dyn = dyn, n = nrow(d), dropped = dropped)
}

res <- list(); rows <- list(); plots <- list()
for (ind in INDUSTRIES) {
  cat(sprintf("--- %s ---\n", ind))
  r <- tryCatch(run_one(ind), error = function(e) { cat("  ERROR:", conditionMessage(e), "\n"); NULL })
  if (is.null(r)) next
  res[[ind]] <- r
  dyn <- r$dyn
  post <- dyn$egt >= 0
  sig_post <- dyn$egt[post][abs(dyn$att.egt[post]) / dyn$se.egt[post] > dyn$crit.val.egt]
  base_rate <- mean(sec$employment_rate[sec$Industry == ind & sec$Ownership == OWNERSHIP &
                                          sec[[GROUP_VAR]] > 0 & sec$is_date_passed == 0], na.rm = TRUE)
  rows[[ind]] <- data.frame(
    industry = ind, N = r$n, dropped_states = paste(r$dropped, collapse = ","),
    overall_att = dyn$overall.att, overall_se = dyn$overall.se,
    att_e0 = dyn$att.egt[dyn$egt == 0], att_e12 = dyn$att.egt[dyn$egt == 12], se_e12 = dyn$se.egt[dyn$egt == 12],
    pre_treat_mean_rate = base_rate,
    overall_att_pct_of_base = 100 * dyn$overall.att / base_rate,
    sig_post_months = if (length(sig_post)) paste(sig_post, collapse = ",") else "none")
  cat(sprintf("  overall ATT %.4f (se %.4f) = %.2f%% of pre-treatment level; e=12: %.4f (se %.4f); significant post months: %s\n",
              dyn$overall.att, dyn$overall.se, 100 * dyn$overall.att / base_rate,
              dyn$att.egt[dyn$egt == 12], dyn$se.egt[dyn$egt == 12], rows[[ind]]$sig_post_months))
  plots[[ind]] <- ggdid(dyn, title = paste("Employment Rate:", ind, OWNERSHIP),
                        xlab = "Relative Time From Treatment", ylab = "", xgap = 4) +
    theme(plot.title = element_text(size = 7), axis.text = element_text(size = 7),
          axis.title = element_text(size = 7), legend.text = element_text(size = 7))
  write.csv(data.frame(e = dyn$egt, att = dyn$att.egt, se = dyn$se.egt, crit_val = dyn$crit.val.egt),
            file.path(TAB, sprintf("FigA3_%s%s.csv", gsub("[^A-Za-z0-9]+", "_", ind), TAG)), row.names = FALSE)
}
summ <- do.call(rbind, rows); rownames(summ) <- NULL
write.csv(summ, file.path(TAB, sprintf("FigA3_sector_summary%s.csv", TAG)), row.names = FALSE)
cat("\n==== Sector summary (paper: effects 'about -0.5% to 1%'; Education & Health significant at 12 months) ====\n")
print(summ[, c("industry", "overall_att", "overall_se", "overall_att_pct_of_base", "att_e12", "sig_post_months")], row.names = FALSE)

saveRDS(res, file.path(PROC, sprintf("csdid_sectors%s.rds", TAG)))
grid <- ggarrange(plotlist = plots, ncol = 3, nrow = 4, common.legend = TRUE, legend = "bottom")
ggsave(file.path(FIG, sprintf("FigureA3_sector_event_studies%s.png", TAG)), grid, width = 12, height = 14, dpi = 150)
if (TAG == "") for (ind in names(plots))
  ggsave(file.path(FIG, sprintf("FigA3_%s.png", gsub("[^A-Za-z0-9]+", "_", ind))), plots[[ind]],
         width = 5, height = 4, dpi = 150)
cat("Done.\n")
