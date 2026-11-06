library(dplyr)
library(tidyr)

df <- read.csv('JoinedDF_age081924.csv')

df$date <- as.Date(df$week_ending, format = "%Y-%m-%d")

df$weeks <- ceiling(as.numeric(difftime(df$date, as.Date('2020-02-01', '%Y-%m-%d'), units = 'weeks')))

df$waitingToTreat <- 1-df$is_date_passed

treatmentGroup<-df %>%
  group_by(state) %>%
  summarize(groupedByTreatLength = sum(waitingToTreat))

treatmentGroup[treatmentGroup$groupedByTreatLength == table(df$state)[1],'groupedByTreatLength'] <- 0

df<-left_join(df, treatmentGroup)

df<-df %>% rename(total_weekly_deathRate = Total.Deaths.Per.100000..age.adjusted.)

df<-df %>%
  group_by(state) %>%
  mutate(dweekly_deathRate = total_weekly_deathRate - lag(total_weekly_deathRate))

df[is.na(df$dweekly_deathRate), "dweekly_deathRate"] <-  0

tableA2 <- df %>%
  group_by(transparentState = groupedByTreatLength > 0) %>%
  summarize(covidDeathsPer100k = mean(dweekly_deathRate),
            covidDeathsPer100k_sd = sd(dweekly_deathRate),
            indeedPostingsIndex = mean(indeed_job_postings_index),
            indeedPostingsIndex_sd = sd(indeed_job_postings_index),
            treatedPct = mean(is_date_passed)) %>%
  arrange(desc(transparentState))

print(as.data.frame(tableA2))

twfe <- lm(indeed_job_postings_index ~ factor(state) + factor(weeks) + is_date_passed + dweekly_deathRate, data = df)

tableA3 <- summary(twfe)$coefficients[c("(Intercept)", "is_date_passed", "dweekly_deathRate"), ]

print(round(tableA3, 3))
print(c(R2 = summary(twfe)$r.squared, N = nobs(twfe)))
