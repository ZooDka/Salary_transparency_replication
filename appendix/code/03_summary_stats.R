## 03_summary_stats.R
## -----------------------------------------------------------------------------
## Reproduces every descriptive number in Section 3 ("Data") and
## Appendix Tables A.1 and A.2.
## -----------------------------------------------------------------------------
source("code/00_prep.R")
df <- load_panel()

cat("==================== SECTION 3 TEXT NUMBERS ====================\n")
n_weeks   <- length(unique(df$weeks))
n_states  <- length(unique(df$state))
treated   <- df %>% group_by(state) %>% summarize(tw = sum(is_date_passed), .groups = "drop") %>% filter(tw > 0)
cat(sprintf("Balanced panel: %d states x %d weeks = %d obs  (paper: 234 weeks, N = 11934)\n",
            n_states, n_weeks, nrow(df)))
cat(sprintf("Weeks span %s to %s\n", min(df$date), max(df$date)))
cat(sprintf("Treated states (%d): %s   (paper: 9)\n", nrow(treated),
            paste(state_names[treated$state], collapse = ", ")))
cat(sprintf("Total treated state-weeks: %d\n", sum(treated$tw)))
cat(sprintf("Share of treated-state weeks that are treated: %.1f%%  (paper: ~47%%)\n",
            100 * sum(treated$tw) / (nrow(treated) * n_weeks)))
cat(sprintf("Average treatment length: %.1f weeks  (paper: 110)\n", mean(treated$tw)))
cat(sprintf("Max treated weeks per state: %d  (max(e) usable in 1-year window: 52)\n", max(treated$tw)))

## ---- Table A.1 : Detailed State Summary Statistics --------------------------
## This is the `test` data frame in TransparencyAndIndeed2024_09_12.R (lines 42-48)
test <- df %>%
  group_by(state) %>%
  summarize(MeanDeaths   = mean(dweekly_deathRate),
            MeanPostings = mean(indeed_job_postings_index),
            Pct.Treated  = mean(is_date_passed), .groups = "drop") %>%
  mutate(State = state_names[state]) %>%
  select(State, MeanDeaths, MeanPostings, Pct.Treated)

tabA1 <- test %>%
  mutate(`Mean Covid Deaths` = signif(MeanDeaths, 3),
         `Mean Postings`     = sprintf("%.0f%%", MeanPostings),
         `Pct. Treated`      = ifelse(Pct.Treated > 0, sprintf("%.2f%%", 100 * Pct.Treated), "-")) %>%
  select(State, `Mean Covid Deaths`, `Mean Postings`, `Pct. Treated`)
write.csv(tabA1, file.path(TAB, "TableA1_state_summary.csv"), row.names = FALSE)
write.csv(test,  file.path(TAB, "TableA1_state_summary_raw.csv"), row.names = FALSE)

cat("\n==================== TABLE A.1 ====================\n")
print(as.data.frame(tabA1), row.names = FALSE)

cat(sprintf("\nStates with mean weekly COVID deaths/100k >= 1: %d of %d = %.0f%%  (paper: 86%%)\n",
            sum(test$MeanDeaths >= 1), nrow(test), 100 * mean(test$MeanDeaths >= 1)))
cat(sprintf("States whose mean Indeed index > 100 (growth): %d of %d  (paper: all)\n",
            sum(test$MeanPostings > 100), nrow(test)))

## ---- Table A.2 : Treated vs untreated ----------------------------------------
## Pooled over state-weeks. "Standard errors in parentheses" in the paper are the
## pooled standard deviations.
tabA2 <- df %>%
  mutate(group = ifelse(groupedByTreatLength > 0, "Transparent States", "Not Transparent States")) %>%
  group_by(group) %>%
  summarize(`Covid Deaths Per 100k` = sprintf("%.2f (%.2f)", mean(dweekly_deathRate), sd(dweekly_deathRate)),
            `Indeed Postings Index` = sprintf("%.2f (%.2f)", mean(indeed_job_postings_index), sd(indeed_job_postings_index)),
            `Treated (%)`           = sprintf("%.0f%%", 100 * mean(is_date_passed)),
            N = n(), .groups = "drop") %>%
  arrange(desc(group))
write.csv(tabA2, file.path(TAB, "TableA2_treated_vs_untreated.csv"), row.names = FALSE)

cat("\n==================== TABLE A.2 ====================\n")
print(as.data.frame(tabA2), row.names = FALSE)
cat("paper: Transparent 1.09 (1.80) | 122.73 (30.60) | 47%\n")
cat("       Not transp. 1.29 (1.83) | 129.60 (29.61) |  0%\n")

## treatment groups for reference (first treated week index), as in the R script
cat("\nTreatment groups (first treated week index; 0 = never):\n")
print(df %>% distinct(state, groupedByTreatLength) %>% filter(groupedByTreatLength > 0) %>%
        arrange(groupedByTreatLength) %>% as.data.frame(), row.names = FALSE)
