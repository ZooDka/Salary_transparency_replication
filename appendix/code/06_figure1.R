## 06_figure1.R
## -----------------------------------------------------------------------------
## Figure 1: "Indeed Job Postings (Normalized by State and Week)".
## Same as TransparencyAndIndeed2024_09_12.R lines 51-77.
## The index is demeaned by week (across states) and then by state; only the
## nine treated states are plotted against weeks relative to their own law date,
## with separate OLS fits (95% bands) before and after.
## Uses the colours and labels of the published version.
## -----------------------------------------------------------------------------
source("code/00_prep.R")
df <- load_panel()

df <- df %>% group_by(week_ending) %>%
  mutate(dWeek = indeed_job_postings_index - mean(indeed_job_postings_index, na.rm = TRUE)) %>%
  ungroup() %>% group_by(state) %>%
  mutate(ddIndeed  = dWeek - mean(dWeek, na.rm = TRUE),
         countdown = weeks - groupedByTreatLength) %>%
  ungroup()

dfTreatedOnly <- df[df$groupedByTreatLength > 0, ]
write.csv(dfTreatedOnly[, c("state", "week_ending", "weeks", "countdown", "is_date_passed",
                            "indeed_job_postings_index", "dWeek", "ddIndeed")],
          file.path(TAB, "Fig1_plot_data.csv"), row.names = FALSE)

printedPlot <- ggplot(dfTreatedOnly, aes(x = countdown, y = ddIndeed, color = as.factor(is_date_passed))) +
  geom_vline(xintercept = 0) +
  geom_point(size = 0.75) +
  theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5), text = element_text(size = 15)) +
  geom_smooth(method = "lm", se = TRUE, fullrange = FALSE, level = 0.95,
              aes(group = is_date_passed), linewidth = 1.5, formula = y ~ x) +
  labs(title = "Indeed Job Postings (Normalized by State and Week)",
       x = "Relative Weeks From Treatment", y = "Indeed Job Posting Index",
       color = "Treatment Status") +
  scale_color_manual(name = "Treatment Status",
                     labels = c("Pretreatment States", "PostTreatment States"),
                     values = c("#5ab4ac", "#E69F00"))

ggsave(file.path(FIG, "Figure1_preliminary_exploration.png"), printedPlot, width = 8, height = 7, dpi = 200)

## numbers quoted in the text about this figure
fits <- dfTreatedOnly %>% group_by(is_date_passed) %>%
  do(broom::tidy(lm(ddIndeed ~ countdown, data = .))) %>% ungroup()
cat("OLS fits drawn in Figure 1 (ddIndeed ~ countdown, by treatment status):\n")
print(as.data.frame(fits), row.names = FALSE)
cat(sprintf("\nMean normalized index: pre = %.2f, post = %.2f (raw difference %.2f)\n",
            mean(dfTreatedOnly$ddIndeed[dfTreatedOnly$is_date_passed == 0]),
            mean(dfTreatedOnly$ddIndeed[dfTreatedOnly$is_date_passed == 1]),
            mean(dfTreatedOnly$ddIndeed[dfTreatedOnly$is_date_passed == 1]) -
              mean(dfTreatedOnly$ddIndeed[dfTreatedOnly$is_date_passed == 0])))
