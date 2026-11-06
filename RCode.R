library(eventstudyr)
library(plm)
library(did)
library(dplyr)
library(vtable)
library(xtable)
####Data Management####
df <- read.csv('JoinedDF_age081924.csv')

df$date <- as.Date(df$week_ending, format = "%Y-%m-%d")

# df$days <- as.numeric(difftime(df$date, as.Date('2020/02/01', '%Y/%m/%d'), units = 'days'))
df$weeks <- ceiling(as.numeric(difftime(df$date, as.Date('2020-02-01', '%Y-%m-%d'), units = 'weeks')))

df$waitingToTreat <- 1-df$is_date_passed

treatmentGroup<-df %>% 
  group_by(state) %>%
  summarize(groupedByTreatLength = sum(waitingToTreat)) # A group is determined by first date of treatment.

treatmentGroup[treatmentGroup$groupedByTreatLength == table(df$state)[1],'groupedByTreatLength'] <- 0 #Groups that are never treated are set to 0.

df<-left_join(df, treatmentGroup)

# df<-df %>% select(!X)

names(df)

df<-df %>% rename(total_weekly_deathRate = Total.Deaths.Per.100000..age.adjusted.) 
# df<-df %>% rename(total_weekly_deathRate = total_deaths_per_100k_crude)


df<-df %>%
  group_by(state) %>%
  mutate(dweekly_deathRate = total_weekly_deathRate - lag(total_weekly_deathRate)) #don't want total deaths per 100k, want the RATE of deaths per 100k.

df[is.na(df$dweekly_deathRate), "dweekly_deathRate"] <-  0 #there are no covid deaths in the week before collecting.

df 

####Event Study####
myEventStudy15<-EventStudy(    
  estimator = "OLS",
  data = df,
  outcomevar = "indeed_job_postings_index",
  policyvar = "is_date_passed",
  control = "dweekly_deathRate",
  idvar = "state",
  timevar = "weeks",
  FE = TRUE, TFE = TRUE,
  post = 15, #overidpre = 24,
  pre  = 0, #overidpost = 24,
  normalize = -1,
  cluster = TRUE
)

myEventStudy30<-EventStudy(    
  estimator = "OLS",
  data = df,
  outcomevar = "indeed_job_postings_index",
  policyvar = "is_date_passed",
  control = "dweekly_deathRate",
  idvar = "state",
  timevar = "weeks",
  FE = TRUE, TFE = TRUE,
  post = 30, #overidpre = 24,
  pre  = 0, #overidpost = 24,
  normalize = -1,
  cluster = TRUE
)

myEventStudy60<-EventStudy(    
  estimator = "OLS",
  data = df,
  outcomevar = "indeed_job_postings_index",
  policyvar = "is_date_passed",
  control = "dweekly_deathRate",
  idvar = "state",
  timevar = "weeks",
  FE = TRUE, TFE = TRUE,
  post = 60, #overidpre = 24,
  pre  = 0, #overidpost = 24,
  normalize = -1,
  cluster = TRUE
) 

# 
# myEventStudy90<-EventStudy(    
#   estimator = "OLS",
#   data = df,
#   outcomevar = "indeed_job_postings_index",
#   policyvar = "is_date_passed",
#   control = "dweekly_deathRate",
#   idvar = "state",
#   timevar = "weeks",
#   FE = TRUE, TFE = TRUE,
#   post = 90, #overidpre = 24,
#   pre  = 0, #overidpost = 24,
#   normalize = -1,
#   cluster = TRUE
# )  
# 
# 
# 
# myEventStudy120<-EventStudy(
#   estimator = "OLS",
#   data = df,
#   outcomevar = "indeed_job_postings_index",
#   policyvar = "is_date_passed",
#   control = "dweekly_deathRate",
#   idvar = "state",
#   timevar = "weeks",
#   FE = TRUE, TFE = TRUE,
#   post = 120, #overidpre = 24,
#   pre  = 0, #overidpost = 24,
#   normalize = -1,
#   cluster = TRUE
# )

plt15 <- EventStudyPlot(estimates = myEventStudy15)
plt30 <- EventStudyPlot(estimates = myEventStudy30)
plt60 <- EventStudyPlot(estimates = myEventStudy60)
#plt90 <- EventStudyPlot(estimates = myEventStudy90)
#plt120 <- EventStudyPlot(estimates = myEventStudy120)
plt15; plt30; plt60;# plt90; plt120;


sumtable(df, group = "state", group.long = TRUE)

#may have to group data beforehand
#data table
library(dplyr)
xtable(df, type = "html")
####Calloway and San'tanna, historically required monthly data####

#Treatment groups for reference.
treatmentGroup[order(-treatmentGroup$groupedByTreatLength),]

df$stateNum<-as.numeric(as.factor(df$state))

example_attgt <- att_gt(yname = "indeed_job_postings_index",
                        tname = "weeks",
                        idname = "stateNum", #State, must be numeric
                        gname = "groupedByTreatLength", #Group, must be numeric
                        xformla = ~ dweekly_deathRate, # controls in this estimation, seems to accept polynomials.
                        # group="notyettreated", #Remove to use nevertreated as control.
                        data = df,
                        # cband = FALSE # turn off Confidance intervals if needed.
)

# summarize the results, complex from many groups and time periods.
summary(example_attgt)

#printing Data table 
groupedData<-df %>% 
group_by(state) 

groupedData %>%
  summarise_at(vars(weeks,dweekly_deathRate,indeed_job_postings_index),list( max = "max", mean = "mean", sd = "sd"), na.rm = TRUE)


# max min, mean, std, N
# print in excel 
# delete the columns you dont want and stuff like the week mean

#xtable(groupedData[,c(  'dweekly_deathRate', 'indeed_job_postings_index')], floating=FALSE,latex.environments=NULL,booktabs=TRUE)




# plot the results
ggdid(example_attgt, grtitle = "States Treated At Week:") #xgap leaves everything blurry.

### Simple interp:
agg.simple <- aggte(example_attgt, type = "simple", min_e = -52, max_e = 52, #Only look 52 weeks after treatment.
                    na.rm = TRUE)
summary(agg.simple)

## Dynamic interp:
agg.es <- aggte(example_attgt, type = "dynamic", min_e = -52, max_e = 52,
                na.rm = TRUE)
summary(agg.es)
ggdid(agg.es)

## Group inter:
agg.gs <- aggte(example_attgt, type = "group", min_e = -52, max_e = 52,
                na.rm = TRUE)
summary(agg.gs)
ggdid(agg.gs)

##Calendar Time Interps:
agg.ct <- aggte(example_attgt, type = "calendar", min_e = -52, max_e = 52,
                na.rm = TRUE)
summary(agg.ct)
ggdid(agg.ct)

if (interactive()) View(df[df$groupedByTreatLength == 205,])
if (interactive()) View(df[df$groupedByTreatLength == 190,])




