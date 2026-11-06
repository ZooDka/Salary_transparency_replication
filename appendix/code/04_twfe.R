## 04_twfe.R
## -----------------------------------------------------------------------------
## Table A.3: two-way fixed effects model, eq. (A.1)
##   y_it = b0 + a1[state] + a2[time] + b1 * currentlyTreated_it + b2 * WeeklyDeathRate_it
## Baselines: Alaska (first alphabetically) and the first time period.
## Classical OLS standard errors. Time fixed effects are weeks (the panel's
## time unit); a month-FE version is reported below for comparison.
## -----------------------------------------------------------------------------
source("code/00_prep.R")
df <- load_panel()

# factor levels: alphabetical state order puts "ak" first; months sort chronologically
df$state_f <- factor(df$state)
df$month_f <- factor(df$month)

m_week  <- lm(indeed_job_postings_index ~ state_f + factor(weeks) + is_date_passed + dweekly_deathRate, data = df)
m_month <- lm(indeed_job_postings_index ~ state_f + month_f + is_date_passed + dweekly_deathRate, data = df)

fmt <- function(m, label) {
  s  <- summary(m)
  cf <- s$coefficients
  keep <- c("(Intercept)", "is_date_passed", "dweekly_deathRate")
  out <- data.frame(Coefficient = c("(Intercept)", "Treatment X Treated", "Weekly Death Rate"),
                    Estimate = round(cf[keep, 1], 3),
                    Std.Error = round(cf[keep, 2], 3),
                    t.Statistic = round(cf[keep, 3], 3),
                    p.Value = round(cf[keep, 4], 3), row.names = NULL)
  cat(sprintf("\n==== %s ====\n", label))
  print(out, row.names = FALSE)
  cat(sprintf("R^2: %.3f  adj R^2: %.3f  N: %d\n", s$r.squared, s$adj.r.squared, nobs(m)))
  invisible(out)
}

tabA3 <- fmt(m_week, "TABLE A.3  (state FE + WEEK FE) -- matches the published table")
cat("paper:  116.390 (1.289) 90.292 | -5.956 (0.443) -13.451 | 0.526 (0.066) 7.961 | R2 0.92, N 11934\n")
write.csv(tabA3, file.path(TAB, "TableA3_twfe.csv"), row.names = FALSE)

## ---- variants not in the paper -----------------
tabA3m <- fmt(m_month, "Variant: state FE + MONTH FE (what the table note literally says)")
write.csv(tabA3m, file.path(TAB, "TableA3_twfe_monthFE_variant.csv"), row.names = FALSE)

suppressPackageStartupMessages({library(sandwich); library(lmtest)})
ct <- coeftest(m_week, vcov = vcovCL(m_week, cluster = df$state))
cat("\n==== Variant: week-FE model with state-clustered SEs (not in paper) ====\n")
print(round(ct[c("is_date_passed", "dweekly_deathRate"), ], 3))

## ---- Treatment effect as % of 2020 baseline (index = 100) -------------------
cat(sprintf("\nTWFE effect = %.3f index points = %.1f%% of the Feb-2020 baseline (paper: 'about 6%%')\n",
            coef(m_week)["is_date_passed"], coef(m_week)["is_date_passed"]))
