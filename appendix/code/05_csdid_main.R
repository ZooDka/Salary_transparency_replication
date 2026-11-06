## 05_csdid_main.R
## -----------------------------------------------------------------------------
## Callaway & Sant'Anna (2021) staggered DiD on weekly Indeed postings.
##   Figure 2   : main spec, COVID death-rate covariate, dynamic -52..+52
##   Figure A.4 : same, no covariate
##   Figure A.5 : placebo -- 21 of the 42 never-treated states get a uniformly
##                random fake treatment week anywhere in the window
##   Figure A.6 : placebo -- same, but fake weeks drawn only from the 2nd half
## Plus every number quoted in Section 4 (3.9%, "about 3%", 1-6% range,
## significant pre-trend coefficients ~35 weeks before treatment).
##
## Same `att_gt()` / `aggte()` call as RCode.R:
##   control_group = "nevertreated" (default), est_method = "dr" (default),
##   base_period = "varying" (default), bootstrap SEs with uniform bands.
## Bootstrap draws are random: point estimates do not depend on the seed,
## SEs/bands vary slightly with it.
## -----------------------------------------------------------------------------
source("code/00_prep.R")
df <- load_panel()
set.seed(20250207)   # bootstrap reproducibility

ES_LAB <- list(xlab = "Length of Exposure", ylab = "Estimated Effect Size")
BREAKS <- seq(-52, 52, 13)

run_cs <- function(data, xformla = ~ dweekly_deathRate, label) {
  cat(sprintf("\n######## att_gt: %s ########\n", label))
  t0 <- Sys.time()
  attgt <- att_gt(yname  = "indeed_job_postings_index",
                  tname  = "weeks",
                  idname = "stateNum",
                  gname  = "groupedByTreatLength",
                  xformla = xformla,
                  data   = data)
  cat(sprintf("  att_gt done in %.1f min; %d ATT(g,t) estimates\n",
              as.numeric(difftime(Sys.time(), t0, units = "mins")), length(attgt$att)))
  list(attgt = attgt,
       simple  = aggte(attgt, type = "simple",  min_e = -52, max_e = 52, na.rm = TRUE),
       dynamic = aggte(attgt, type = "dynamic", min_e = -52, max_e = 52, na.rm = TRUE),
       group   = aggte(attgt, type = "group",   min_e = -52, max_e = 52, na.rm = TRUE),
       calendar= aggte(attgt, type = "calendar",min_e = -52, max_e = 52, na.rm = TRUE))
}

es_table <- function(dyn) {
  data.frame(e = dyn$egt, att = dyn$att.egt, se = dyn$se.egt,
             lo_pt = dyn$att.egt - 1.96 * dyn$se.egt, hi_pt = dyn$att.egt + 1.96 * dyn$se.egt,
             lo_band = dyn$att.egt - dyn$crit.val.egt * dyn$se.egt,
             hi_band = dyn$att.egt + dyn$crit.val.egt * dyn$se.egt)
}

report <- function(res, label, note = "") {
  dyn <- res$dynamic; es <- es_table(dyn)
  post <- es[es$e >= 0, ]; pre <- es[es$e < 0, ]
  cat(sprintf("\n==== %s ====\n", label))
  cat(sprintf("Simple ATT (type='simple'):                 %.3f (se %.3f)\n", res$simple$overall.att, res$simple$overall.se))
  cat(sprintf("Dynamic overall ATT (avg of e=0..52):        %.3f (se %.3f)%s\n",
              dyn$overall.att, dyn$overall.se, note))
  cat(sprintf("Group-aggregated overall ATT:                %.3f (se %.3f)\n", res$group$overall.att, res$group$overall.se))
  cat(sprintf("Post-treatment ATT(e), e=0..52: min %.2f  max %.2f  mean %.2f   <- paper: 'ranging between 1-6%%'\n",
              min(post$att), max(post$att), mean(post$att)))
  cat(sprintf("Post weeks with 95%% uniform band excluding 0: %d of %d\n", sum(post$lo_band > 0 | post$hi_band < 0), nrow(post)))
  sigpre <- pre[pre$lo_band > 0 | pre$hi_band < 0, ]
  cat(sprintf("Pre-treatment ATT(e): mean %.3f; significant (uniform band) at e = %s   <- paper: '~35 weeks prior'\n",
              mean(pre$att), if (nrow(sigpre)) paste(sigpre$e, collapse = ",") else "none"))
  sigpre_pt <- pre[pre$lo_pt > 0 | pre$hi_pt < 0, ]
  cat(sprintf("   (pointwise 95%%: e = %s)\n", if (nrow(sigpre_pt)) paste(sigpre_pt$e, collapse = ",") else "none"))
  invisible(es)
}

## ---------------------------------------------------------------- Figure 2 ----
main <- run_cs(df, ~ dweekly_deathRate, "main spec (COVID control)  -> Figure 2")
saveRDS(main, file.path(PROC, "csdid_main.rds"))
es_main <- report(main, "FIGURE 2 / SECTION 4 NUMBERS", note = "   <- paper's 'point estimate of 3.9%'")
write.csv(es_main, file.path(TAB, "Fig2_dynamic_ATT_by_exposure.csv"), row.names = FALSE)
sink(file.path(TAB, "Fig2_aggte_summaries.txt"))
cat("### simple\n"); print(summary(main$simple))
cat("\n### dynamic\n"); print(summary(main$dynamic))
cat("\n### group\n"); print(summary(main$group))
cat("\n### calendar\n"); print(summary(main$calendar))
sink()
p2 <- ggdid(main$dynamic, xlab = ES_LAB$xlab, ylab = ES_LAB$ylab, xgap = 13)
ggsave(file.path(FIG, "Figure2_csdid_dynamic.png"), p2, width = 7, height = 5, dpi = 200)
# raw ATT(g,t) plot (not in paper)
pgt <- ggdid(main$attgt, grtitle = "States Treated At Week:")
ggsave(file.path(FIG, "extra_att_gt_by_group.png"), pgt, width = 10, height = 14, dpi = 150)

## -------------------------------------------------------------- Figure A.4 ----
nocov <- run_cs(df, NULL, "no covariates  -> Figure A.4")
saveRDS(nocov, file.path(PROC, "csdid_nocovid.rds"))
es_nocov <- report(nocov, "FIGURE A.4 (no COVID control)")
write.csv(es_nocov, file.path(TAB, "FigA4_dynamic_ATT_noCOVID.csv"), row.names = FALSE)
pA4 <- ggdid(nocov$dynamic, xlab = ES_LAB$xlab, ylab = ES_LAB$ylab, xgap = 13)
ggsave(file.path(FIG, "FigureA4_csdid_noCOVID.png"), pA4, width = 7, height = 5, dpi = 200)

## ------------------------------------------------------ Figures A.5 & A.6 ----
## "placebo treating 50% of the states (uniform random date, random state)"
## 42 never-treated states -> 21 placebo states ("adding 21 false treatment states").
make_placebo <- function(df, week_range, seed, fake_states = NULL) {
  set.seed(seed)
  never <- unique(df$state[df$groupedByTreatLength == 0])
  if (is.null(fake_states)) fake_states <- sort(sample(never, length(never) / 2))
  fake_week   <- setNames(sample(seq(week_range[1], week_range[2]), length(fake_states), replace = TRUE), fake_states)
  d <- df
  idx <- d$state %in% fake_states
  d$groupedByTreatLength[idx] <- fake_week[d$state[idx]]
  d$is_date_passed[idx] <- as.integer(d$weeks[idx] >= d$groupedByTreatLength[idx])
  attr(d, "placebo") <- data.frame(state = fake_states, fake_week = fake_week)
  d
}
maxw <- max(df$weeks)                                   # 233
dfA5 <- make_placebo(df, c(1, maxw), seed = 1)           # anywhere in the window
# A.6: "the exact same states" as A.5, new dates drawn from the second half only
dfA6 <- make_placebo(df, c(floor(maxw / 2) + 1, maxw), seed = 2, fake_states = attr(dfA5, "placebo")$state)
write.csv(attr(dfA5, "placebo"), file.path(TAB, "FigA5_placebo_assignment.csv"), row.names = FALSE)
write.csv(attr(dfA6, "placebo"), file.path(TAB, "FigA6_placebo_assignment.csv"), row.names = FALSE)

plA5 <- run_cs(dfA5, ~ dweekly_deathRate, "placebo, uniform over whole window  -> Figure A.5")
es_A5 <- report(plA5, "FIGURE A.5 (random placebo, whole window)", note = "   (paper: effect and SEs both decline)")
write.csv(es_A5, file.path(TAB, "FigA5_dynamic_ATT_placebo.csv"), row.names = FALSE)
ggsave(file.path(FIG, "FigureA5_csdid_placebo.png"),
       ggdid(plA5$dynamic, xlab = ES_LAB$xlab, ylab = ES_LAB$ylab, xgap = 13), width = 7, height = 5, dpi = 200)

plA6 <- run_cs(dfA6, ~ dweekly_deathRate, "placebo, uniform over 2nd half  -> Figure A.6")
es_A6 <- report(plA6, "FIGURE A.6 (late placebo, same states as A.5)", note = "   (paper: about half of -3.9, SEs about half)")
write.csv(es_A6, file.path(TAB, "FigA6_dynamic_ATT_late_placebo.csv"), row.names = FALSE)
ggsave(file.path(FIG, "FigureA6_csdid_late_placebo.png"),
       ggdid(plA6$dynamic, xlab = ES_LAB$xlab, ylab = ES_LAB$ylab, xgap = 13), width = 7, height = 5, dpi = 200)

cat("\nDone. Figures in output/figures, tables in output/tables.\n")
