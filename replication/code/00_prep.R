## 00_prep.R
## -----------------------------------------------------------------------------
## Shared data-management block, same as `TransparencyAndIndeed2024_09_12.R` /
## `RCode.R` (lines 8-37).
## Every analysis script source()s this file.
## -----------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(did)
})

# Run every script from the replication folder:  Rscript code/03_summary_stats.R
ROOT <- Sys.getenv("REPL_ROOT", unset = getwd())
PROC <- file.path(ROOT, "data", "processed")
FIG  <- file.path(ROOT, "output", "figures")
TAB  <- file.path(ROOT, "output", "tables")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)

load_panel <- function(path = file.path(PROC, "JoinedDF_age.csv")) {
  df <- read.csv(path)

  df$date  <- as.Date(df$week_ending, format = "%Y-%m-%d")
  # weeks since 2020-02-01 (the Indeed baseline day); week_ending 2020-02-01 -> 0
  df$weeks <- ceiling(as.numeric(difftime(df$date, as.Date('2020-02-01', '%Y-%m-%d'),
                                          units = 'weeks')))

  df$waitingToTreat <- 1 - df$is_date_passed

  # A "group" (in Callaway-Sant'Anna terms) is the first period of treatment.
  # sum(waitingToTreat) = number of untreated weeks = index of first treated week
  # because `weeks` starts at 0.
  treatmentGroup <- df %>%
    group_by(state) %>%
    summarize(groupedByTreatLength = sum(waitingToTreat), .groups = "drop")
  # never-treated states (all 234 weeks untreated) are coded 0
  treatmentGroup[treatmentGroup$groupedByTreatLength == table(df$state)[1],
                 'groupedByTreatLength'] <- 0

  df <- left_join(df, treatmentGroup, by = "state")

  df <- df %>% rename(total_weekly_deathRate = Total.Deaths.Per.100000..age.adjusted.)

  # The CDC series is CUMULATIVE deaths per 100k; first-difference it to get the
  # weekly death RATE. First week of each state is NA -> 0.
  df <- df %>%
    group_by(state) %>%
    mutate(dweekly_deathRate = total_weekly_deathRate - lag(total_weekly_deathRate)) %>%
    ungroup()
  df[is.na(df$dweekly_deathRate), "dweekly_deathRate"] <- 0

  df$stateNum <- as.numeric(as.factor(df$state))   # did::att_gt needs numeric ids
  df$month    <- format(df$date, "%Y-%m")          # month FE used in Table A.3
  as.data.frame(df)
}

state_names <- c(
  ak = "Alaska", al = "Alabama", ar = "Arkansas", az = "Arizona", ca = "California",
  co = "Colorado", ct = "Connecticut", dc = "District of Columbia", de = "Delaware",
  fl = "Florida", ga = "Georgia", hi = "Hawaii", ia = "Iowa", id = "Idaho",
  il = "Illinois", `in` = "Indiana", ks = "Kansas", ky = "Kentucky", la = "Louisiana",
  ma = "Massachusetts", md = "Maryland", me = "Maine", mi = "Michigan",
  mn = "Minnesota", mo = "Missouri", ms = "Mississippi", mt = "Montana",
  nc = "North Carolina", nd = "North Dakota", ne = "Nebraska", nh = "New Hampshire",
  nj = "New Jersey", nm = "New Mexico", nv = "Nevada", ny = "New York", oh = "Ohio",
  ok = "Oklahoma", or = "Oregon", pa = "Pennsylvania", ri = "Rhode Island",
  sc = "South Carolina", sd = "South Dakota", tn = "Tennessee", tx = "Texas",
  ut = "Utah", va = "Virginia", vt = "Vermont", wa = "Washington", wi = "Wisconsin",
  wv = "West Virginia", wy = "Wyoming")
