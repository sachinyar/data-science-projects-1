## Instruction to reviewer: Please make sure to set current working directory to same directory
## where all the files are present

## IIITB - Group_Facilitator_RollNo: DDA1730041
## Team:
## 1) Fayiz Mayam Veettil
## 2) Merin Jose
## 3) Deepak Aneja
## 4) Suresh Balla
################################################################################################################################################

## Business Objective
## Develop a market mix model to observe the actual impact of different marketing variables over the last year
## Recommend the optimal budget allocation for different marketing levers for the next year
## Improve the revenue response either by cutting down the marketing budget or reallocating it optimally across marketing levers

## Begin of Install and load required libraries

load.libraries <- c('reshape', 'stringr', 'dplyr', 'data.table', 'e1071', 'gridExtra', 'corrplot', 'ggplot2', 'tidyr', 'MASS', 'car', 'caret', 'GGally', 'mice','cowplot','caTools', 'DataCombine')
install.lib <- load.libraries[!load.libraries %in% installed.packages()]
for(libs in install.lib) install.packages(libs, dependencies = TRUE)
sapply(load.libraries, require, character = TRUE)

## End of Install and load required libraries
################################################################################################################################################


## Load data sets
#DA Handed the \N for Null values
consumerElectronicsData <- read.csv("ConsumerElectronics.csv", stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = c("\\N", "NA","NaN","","#DIV/0!"))
budgetAllocationsWeekly <- read.csv("budget_allocation_weekly.csv", stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = c("NA","NaN","","#DIV/0!"))

#DA Load Sales Event and NPS data
salesEventsWeeklyLevel <- read.csv("events_salesdays.csv", stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = c("NA","NaN","","#DIV/0!"))
npsWeeklyLevel <- read.csv("NPS.csv", stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = c("NA","NaN","","#DIV/0!"))

colnames(budgetAllocationsWeekly)[1] <- "Year"
colnames(salesEventsWeeklyLevel)[1] <- "Year"

nrow(consumerElectronicsData)
nrow(distinct(consumerElectronicsData))

consumerElectronicsData <- distinct(consumerElectronicsData)

## End of load data sets
################################################################################################################################################

## Reusable function to plot in grid for given configuration of number of columns
doPlots <- function(data_in, fun, ii, ncol=3) {
  pp <- list()
  for (i in ii) {
    p <- fun(data_in=data_in, i=i)
    pp <- c(pp, list(p))
  }
  do.call("grid.arrange", c(pp, ncol=ncol))
}

plotCorrAgainstRevenueGmv <- function(data_in, i){
  data <- data.frame(x = data_in[[i]], gmv = data_in$gmv)
  p <- ggplot(data, aes(x = x, y = gmv)) + geom_point(shape = 1, na.rm = TRUE) + geom_smooth(method = lm ) + xlab(paste0(colnames(data_in)[i], '\n', 'R-Squared: ', round(cor(data_in[[i]], data$gmv, use = 'complete.obs'), 2))) + theme_light()
  return(suppressWarnings(p))
}

################################################################################################################################################

## Filter data for July 2015 to June 2016.

consumerElectronicsData$Month <- as.numeric(consumerElectronicsData$Month)
consumerElectronicsData$Year <- as.numeric(consumerElectronicsData$Year)
consumerElectronicsDataForAnalysis <- consumerElectronicsData %>% filter((Year == 2015 & Month >= 7) | (Year == 2016 & Month <= 6))

consumerElectronicsDataForAnalysis$offer_percentage = (consumerElectronicsDataForAnalysis$product_mrp*consumerElectronicsDataForAnalysis$units - consumerElectronicsDataForAnalysis$gmv)/consumerElectronicsDataForAnalysis$product_mrp*consumerElectronicsDataForAnalysis$units

## Lets calculate if a product is premium or not based on its MRP in its own category

products_quantiles <- consumerElectronicsDataForAnalysis %>% group_by(product_analytic_category, product_analytic_sub_category, product_analytic_vertical) %>% summarise(`75%`=quantile(product_mrp, probs=0.75), `25%`=quantile(product_mrp, probs=0.25))

consumerElectronicsDataForAnalysis <- merge(consumerElectronicsDataForAnalysis, products_quantiles, all.x = TRUE)
consumerElectronicsDataForAnalysis$product_mrp_class <- ifelse(consumerElectronicsDataForAnalysis$product_mrp >= consumerElectronicsDataForAnalysis$`75%`, "premium", ifelse(consumerElectronicsDataForAnalysis$product_mrp < consumerElectronicsDataForAnalysis$`25%`, "cheap", "medium"))

colnames(consumerElectronicsDataForAnalysis)

consumerElectronicsDataForAnalysis <- subset(consumerElectronicsDataForAnalysis, select = -c(`75%`, `25%`))

## Handling of NA's
NA.proportion <- function(x) mean(is.na(x))
table(NA.proportion=round(sapply(consumerElectronicsDataForAnalysis, NA.proportion), 2))

colSums(is.na(consumerElectronicsDataForAnalysis))
colMeans(is.na(consumerElectronicsDataForAnalysis))
barplot(colMeans(is.na(consumerElectronicsDataForAnalysis)))

## gmv, pincode and custid has null values
#DA: consumerElectronicsDataForAnalysis$gmv is NA for .29%. These records should be excluded from analysis.
#same records have cust_id as blank
consumerElectronicsDataForAnalysis <- consumerElectronicsDataForAnalysis %>% filter(!is.na(gmv))

## Lets confirm NA's again
colSums(is.na(consumerElectronicsDataForAnalysis))
colMeans(is.na(consumerElectronicsDataForAnalysis))
barplot(colMeans(is.na(consumerElectronicsDataForAnalysis)))

## No more NA's that we need to worry

## Remove near zero variance variables which doesnt makese sense (For example, col having only one value is of no use)
nearZeroVariances <- nearZeroVar(consumerElectronicsDataForAnalysis, saveMetrics = TRUE)
nearZeroVariances_trues_indexes <- which(nearZeroVariances$nzv == TRUE)

## Units, deliverybdays, deliverycdays and product_analytic_super_category are columns that are near zero variance.

if (length(nearZeroVariances_trues_indexes) > 0) {
  consumerElectronicsDataForAnalysis <- consumerElectronicsDataForAnalysis[, -(nearZeroVariances_trues_indexes)]
}

## Based on above operation, columns contains single value are removed
################################################################################################################################################

consumerElectronicsDataForAnalysis$order_date <- as.Date(consumerElectronicsDataForAnalysis$order_date)
consumerElectronicsDataForAnalysis$week <- as.numeric(format(consumerElectronicsDataForAnalysis$order_date,"%W"))
consumerElectronicsDataForAnalysis$day <- as.numeric(format(consumerElectronicsDataForAnalysis$order_date,"%d"))

consumerElectronicsDataForAnalysis <- distinct(consumerElectronicsDataForAnalysis)
consumerElectronicsDataForAnalysis <- merge(consumerElectronicsDataForAnalysis, salesEventsWeeklyLevel, by = c("Year", "Month", "week"), all.x = TRUE)

################################################################################################################################################

## Check for records with orders with revenue per unit more than MRP, negative SLA or product_procurement_sla. Cap the GMV accordingly so we do not loose revenue as we budget for all days in a month
nrow(consumerElectronicsDataForAnalysis %>% filter(offer_percentage < 0 | sla < 0 | product_procurement_sla < 0))
consumerElectronicsDataForAnalysis$gmv = ifelse(consumerElectronicsDataForAnalysis$offer_percentage < 0, consumerElectronicsDataForAnalysis$product_mrp*consumerElectronicsDataForAnalysis$units, consumerElectronicsDataForAnalysis$gmv)
consumerElectronicsDataForAnalysis$sla = ifelse(consumerElectronicsDataForAnalysis$sla < 0, NULL, consumerElectronicsDataForAnalysis$sla)
consumerElectronicsDataForAnalysis$product_procurement_sla = ifelse(consumerElectronicsDataForAnalysis$product_procurement_sla < 0, 0, consumerElectronicsDataForAnalysis$product_procurement_sla)
consumerElectronicsDataForAnalysis$offer_percentage = ifelse(consumerElectronicsDataForAnalysis$offer_percentage < 0, 0, consumerElectronicsDataForAnalysis$offer_percentage)
nrow(consumerElectronicsDataForAnalysis %>% filter(offer_percentage < 0 | sla < 0 | product_procurement_sla < 0))

consumerElectronicsDataForAnalysisForAggregation <- subset(consumerElectronicsDataForAnalysis, select = -c(X.U.FEFF.fsn_id, order_date)) %>% filter(product_analytic_sub_category == "HomeAudio" )

categorical_variables_indexes <- as.integer(which(sapply(consumerElectronicsDataForAnalysisForAggregation, is.character)))

weekAggregationSplit1 <- consumerElectronicsDataForAnalysisForAggregation %>% dplyr::select(Year, week, gmv, product_mrp) %>% group_by(Year, week) %>% summarise_all(funs(sum), na.rm = TRUE)
weekAggregationSplit2 <- consumerElectronicsDataForAnalysisForAggregation %>% dplyr::select(Year, week, deliverycdays, deliverybdays, product_procurement_sla, offer_percentage) %>% group_by(Year, week) %>% summarise_all(funs(mean), na.rm = TRUE)

consumerElectronicsDataForAnalysisWeeklyAggregation <- merge(weekAggregationSplit1, weekAggregationSplit2, by = c("Year", "week"), all.x=TRUE)

for (category_variable_index in categorical_variables_indexes) {
  dataFrameTemp <- consumerElectronicsDataForAnalysisForAggregation %>% 
    dplyr::select(Year, week, !!colnames(consumerElectronicsDataForAnalysisForAggregation)[category_variable_index]) %>% 
    group_by_at(c("Year", "week", colnames(consumerElectronicsDataForAnalysisForAggregation)[category_variable_index])) %>%
    summarise(count = n()) %>% 
    mutate(prop = count / sum(count) )
  
  dataFrameTemp[[3]] <- paste0(colnames(consumerElectronicsDataForAnalysisForAggregation)[category_variable_index], "_", dataFrameTemp[[3]])
  temp <- dcast(dataFrameTemp, paste0("Year + week ~ ", colnames(consumerElectronicsDataForAnalysisForAggregation)[category_variable_index]), value.var="prop")
  consumerElectronicsDataForAnalysisWeeklyAggregation <- merge(consumerElectronicsDataForAnalysisWeeklyAggregation, temp, by = c("Year", "week"), all.x=TRUE)
  remove(dataFrameTemp)
  remove(temp)
}

consumerElectronicsDataForAnalysisWeeklyAggregation <- merge(consumerElectronicsDataForAnalysisWeeklyAggregation, npsWeeklyLevel, by = c("Year", "week"), all = TRUE)
consumerElectronicsDataForAnalysisWeeklyAggregation <- merge(consumerElectronicsDataForAnalysisWeeklyAggregation, budgetAllocationsWeekly, by = c("Year", "week"), all = TRUE)

nrow(consumerElectronicsDataForAnalysisWeeklyAggregation)

colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Total.Investment'] <- 'investment'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'TV'] <- 'investmentTV'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Digital'] <- 'investmentDigital'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Sponsorship'] <- 'investmentSponsorship'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Content.Marketing'] <- 'investmentContentMarketing'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Online.marketing'] <- 'investmentOnlinemarketing'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Affiliates'] <- 'investmentAffiliates'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'SEM'] <- 'investmentSEM'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Radio'] <- 'investmentRadio'
colnames(consumerElectronicsDataForAnalysisWeeklyAggregation)[colnames(consumerElectronicsDataForAnalysisWeeklyAggregation) == 'Other'] <- 'investmentOther'

################################################################################################################################################

## Side by side analysis of investment and revenue

weeklyRevenueVsInvestment <- consumerElectronicsDataForAnalysisWeeklyAggregation %>% dplyr::select(Year, week, gmv, investment)
temp <- as.data.frame((weeklyRevenueVsInvestment %>% filter(Year == 2015))[c(2,3,4)])
melted <- melt(temp, id.vars='week')

ggplot(melted, aes(x=week, y=value, fill=variable)) +
  geom_bar(stat='identity', position='dodge')

temp2 <- as.data.frame((weeklyRevenueVsInvestment %>% filter(Year == 2016))[c(2,3,4)])
melted2 <- melt(temp2, id.vars='week')

ggplot(melted2, aes(x=week, y=value, fill=variable)) +
  geom_bar(stat='identity', position='dodge')

################################################################################################################################################

correlationMatrixWeekly <- cor(consumerElectronicsDataForAnalysisWeeklyAggregation, use = "pairwise.complete.obs")
#corrplot(correlationMatrixWeekly, method = "color", type = "lower", order = "FPC", tl.cex = 0.6)

## Plot scatter plot for variables that have high correlation.
highcorrWeekly <- c(names(correlationMatrixWeekly[,'gmv'])[which(correlationMatrixWeekly[,'gmv'] > 0.8)], names(correlationMatrixWeekly[,'gmv'])[which(correlationMatrixWeekly[,'gmv'] < -0.8)])
data_corr_weekly <- consumerElectronicsDataForAnalysisWeeklyAggregation[,highcorrWeekly]
doPlots(data_corr_weekly, fun = plotCorrAgainstRevenueGmv, ii = 1:ncol(data_corr_weekly))

##---------------------------------------------------
## lets check only for investment against gmv
correlationMatrixWeeklyOnlyForInvestments <- cor(consumerElectronicsDataForAnalysisWeeklyAggregation %>% dplyr::select(union(starts_with("Investment"), starts_with("gmv"))), use = "pairwise.complete.obs")
corrplot(correlationMatrixWeeklyOnlyForInvestments, method = "color", type = "lower", order = "FPC", tl.cex = 0.6)

## Plot scatter plot for variables that have high correlation.
highcorrWeeklyOnlyForInvestments <- c(names(correlationMatrixWeeklyOnlyForInvestments[,'gmv'])[which(correlationMatrixWeeklyOnlyForInvestments[,'gmv'] > 0.3)], names(correlationMatrixWeeklyOnlyForInvestments[,'gmv'])[which(correlationMatrixWeeklyOnlyForInvestments[,'gmv'] < -0.3)])
data_corr_weekly_only_for_investments <- consumerElectronicsDataForAnalysisWeeklyAggregation[,highcorrWeeklyOnlyForInvestments]
doPlots(data_corr_weekly_only_for_investments, fun = plotCorrAgainstRevenueGmv, ii = 1:ncol(data_corr_weekly_only_for_investments))
##---------------------------------------------------

################################################################################################################################################



dataset_final_analysis <- consumerElectronicsDataForAnalysisWeeklyAggregation
colnames(dataset_final_analysis)
dataset_final_analysis <- dataset_final_analysis[-c(9:21)]
dataset_final_analysis <- dataset_final_analysis[-c(4)]
#View(dataset_final_analysis)

is.nan.data.frame <- function(x)
  do.call(cbind, lapply(x, is.nan))


##---------------- Start: Linear Regression model -------------##

linear_data_set <- dataset_final_analysis
linear_data_set[is.nan(linear_data_set)] <- 0
linear_data_set[is.na(linear_data_set)] <- 0


# separate training and testing data
set.seed(100)
trainindices= sample(1:nrow(linear_data_set), 0.8*nrow(linear_data_set))
train = linear_data_set[trainindices,]
test = linear_data_set[-trainindices,]

# Build model 1 containing all variables
model_1 <-lm(gmv ~ .,data=train)
summary(model_1)

step <- stepAIC(model_1, direction="both")
step

model_2 <- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
                investmentSponsorship + investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = train)

#let's check the summary of the model for R-squared and Adjusted R-squared
summary(model_2)


#let's check for Multicollinearity
vif(model_2)


#-------------------------------------------------

#investmentSEM
model_3 <- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
                investmentSponsorship + investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentRadio + 
                investmentOther, data = train)

#let's check the summary of the model for R-squared and Adjusted R-squared
summary(model_3)

#let's check for Multicollinearity
vif(model_3)



#-------------------------------------------------
#investmentOnlinemarketing
model_4 <- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
                investmentSponsorship + investmentContentMarketing + 
                investmentAffiliates + investmentRadio + 
                investmentOther, data = train)
summary(model_4)
vif(model_4)



#investmentOther
model_5 <- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
                investmentSponsorship + investmentContentMarketing + 
                investmentAffiliates + investmentRadio
              , data = train)
summary(model_5)
vif(model_5)
#investmentAffiliates

model_6<- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
               investmentSponsorship + investmentContentMarketing + 
               investmentRadio
             , data = train)
summary(model_6)
vif(model_6)


#investmentContentMarketing

model_6<- lm(formula = gmv ~ week + investment + investmentTV + investmentDigital + 
               investmentSponsorship + 
               investmentRadio
             , data = train)
summary(model_6)

#investmentDigital
model_7<- lm(formula = gmv ~ week + investment + investmentTV + 
               investmentSponsorship + 
               investmentRadio
             , data = train)
summary(model_7)

#week
model_7<- lm(formula = gmv ~ investment + investmentTV + 
               investmentSponsorship + 
               investmentRadio
             , data = train)
summary(model_7)


# Linear Model Prediction - Home Audio
Predict_1 <- predict(model_7,test)
test$test_gmv <- Predict_1
# Now, we need to test the r square between actual and predicted sales. 
r <- cor(test$gmv,test$test_gmv)
rsquared <- cor(test$gmv,test$test_gmv)^2
rsquared

##---------------- End: Linear Regression model -------------##


###### Multiplicative model

log_date_set <- dataset_final_analysis
log_date_set[is.nan(log_date_set)] <- 0
log_date_set[is.na(log_date_set)] <- 0

log_date_set <log(log_date_set)

model_1 <- lm(gmv~.,log_date_set)

summary(model_1)

step <- stepAIC(model_1, direction="both")
step

model_2 <- lm(formula = gmv ~ Year + week + deliverycdays + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + investment + 
                investmentTV + investmentDigital + investmentSponsorship + 
                investmentRadio, data = log_date_set)

summary(model_2)


vif(model_2)

#deliverycdays
model_3 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + investment + 
                investmentTV + investmentDigital + investmentSponsorship + 
                investmentRadio, data = log_date_set)

summary(model_3)


#investment
model_4 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + 
                investmentTV + investmentDigital + investmentSponsorship + 
                investmentRadio, data = log_date_set)

summary(model_4)


#investmentDigital


model_5 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + 
                investmentTV  + investmentSponsorship + 
                investmentRadio, data = log_date_set)

summary(model_5)


#investmentTV

model_6 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + 
                investmentSponsorship + 
                investmentRadio, data = log_date_set)

summary(model_6)

#investmentRadio

model_7 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday + 
                investmentSponsorship
              , data = log_date_set)

summary(model_7)


#investmentSponsorship

model_8 <- lm(formula = gmv ~ Year + week + product_procurement_sla + 
                s1_fact.order_payment_type_COD + s1_fact.order_payment_type_Prepaid + 
                product_mrp_class_cheap + product_mrp_class_medium + product_mrp_class_premium + 
                Event_BED + Event_BSD + `Event_Christmas & New Year` + Event_Diwali + 
                Event_Dussehra + `Event_Eid & Rathayatra` + Event_FHSD + 
                Event_NA + Event_Pacman + Event_Republic + Event_Vday 
              , data = log_date_set)

summary(model_8)

# Multiplicative Model Prediction - Home Audio
Predict_1 <- predict(model_8,log_date_set)
log_date_set$test_gmv <- Predict_1
# Now, we need to test the r square between actual and predicted sales. 
r <- cor(log_date_set$gmv,log_date_set$test_gmv)
rsquared <- cor(log_date_set$gmv,log_date_set$test_gmv)^2
rsquared

############################ Distributed lag models
library(DataCombine)

Dis_Model <- dataset_final_analysis
Dis_model_1 <- slide(Dis_Model, Var = "gmv",slideBy = -1)
#Dis_model_1 <- slide(Dis_model_1, Var = "gmv",slideBy = -2)
#Dis_model_1 <- slide(Dis_model_1, Var = "gmv",slideBy = -3)
Dis_model_1[is.nan(Dis_model_1)] <- 0
Dis_model_1[is.na(Dis_model_1)] <- 0
Dis_model_1 <- Dis_model_1[-c(3)]


dist_model <- lm(`gmv-1`~.,Dis_model_1)
summary(dist_model)

step <- stepAIC(dist_model,direction = "both")
step

model_2 <- lm(formula = `gmv-1` ~ Year + week + deliverybdays + product_procurement_sla + 
                offer_percentage + s1_fact.order_payment_type_Prepaid + Event_Dussehra + 
                Event_FHSD + Event_NA + investmentTV + investmentDigital + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = Dis_model_1)
summary(model_2)
vif(model_2)

# - offer_percentage
model_3 <- lm(formula = `gmv-1` ~ Year + week + deliverybdays + product_procurement_sla + 
                s1_fact.order_payment_type_Prepaid + Event_Dussehra + 
                Event_FHSD + Event_NA + investmentTV + investmentDigital + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = Dis_model_1)
summary(model_3)
vif(model_3)

# - Event_Dussehra
model_4 <- lm(formula = `gmv-1` ~ Year + week + deliverybdays + product_procurement_sla + 
                s1_fact.order_payment_type_Prepaid +  
                Event_FHSD + Event_NA + investmentTV + investmentDigital + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = Dis_model_1)
summary(model_4)
vif(model_4)

# - Year
model_5 <- lm(formula = `gmv-1` ~ week + deliverybdays + product_procurement_sla + 
                s1_fact.order_payment_type_Prepaid +  
                Event_FHSD + Event_NA + investmentTV + investmentDigital + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = Dis_model_1)
summary(model_5)

# - s1_fact.order_payment_type_Prepaid
model_6 <- lm(formula = `gmv-1` ~ week + deliverybdays + product_procurement_sla + 
                Event_FHSD + Event_NA + investmentTV + investmentDigital + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = Dis_model_1)
summary(model_6)

# Distributed Lag Model Prediction - Home Audio
Predict_1 <- predict(model_6,Dis_model_1)
Dis_model_1$test_gmv <- Predict_1
# Now, we need to test the r square between actual and predicted sales. 
r <- cor(Dis_model_1$gmv,Dis_model_1$test_gmv)
rsquared <- cor(Dis_model_1$gmv,Dis_model_1$test_gmv)^2
rsquared

########### Multiplicative + distributed model
mult_Dis_Model <- dataset_final_analysis
mult_Dis_model_1 <- slide(mult_Dis_Model, Var = "gmv",slideBy = -1)
#mult_Dis_model_1 <- slide(mult_Dis_model_1, Var = "gmv",slideBy = -2)
#mult_Dis_model_1 <- slide(mult_Dis_model_1, Var = "gmv",slideBy = -3)
mult_Dis_model_1[is.nan(mult_Dis_model_1)] <- 0.01
mult_Dis_model_1[is.na(mult_Dis_model_1)] <- 0.01
mult_Dis_model_1 <- log(mult_Dis_model_1)
mult_Dis_model_1[mapply(is.infinite, mult_Dis_model_1)] <- 1


mult_dist_model <- lm(`gmv-1`~.,mult_Dis_model_1)
summary(mult_dist_model)

step <- stepAIC(mult_dist_model,direction = "both")
step

model_2 <- lm(formula = `gmv-1` ~ Year + gmv + product_procurement_sla + 
                offer_percentage + product_mrp_class_cheap + Event_Pacman + 
                NPS_WeekAvg + investment + investmentTV + investmentSponsorship + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = mult_Dis_model_1)
summary(model_2)
vif(model_2)

# - Event_Pacman
model_3 <- lm(formula = `gmv-1` ~ Year + gmv + product_procurement_sla + 
                offer_percentage + product_mrp_class_cheap +  
                NPS_WeekAvg + investment + investmentTV + investmentSponsorship + 
                investmentContentMarketing + investmentOnlinemarketing + 
                investmentAffiliates + investmentSEM + investmentRadio + 
                investmentOther, data = mult_Dis_model_1)
summary(model_3)


# - investment - investmentContentMarketing -investmentSEM -investmentOther -investmentRadio -offer_percentage -product_mrp_class_cheap
# -investmentTV -investmentSponsorship
model_4 <- lm(formula = `gmv-1` ~ Year + gmv + product_procurement_sla + 
                NPS_WeekAvg + 
                investmentOnlinemarketing + 
                investmentAffiliates
                , data = mult_Dis_model_1)
summary(model_4)


# - Year -NPS_WeekAvg
model_5 <- lm(formula = `gmv-1` ~ gmv + product_procurement_sla + 
                investmentOnlinemarketing + 
                investmentAffiliates
              , data = mult_Dis_model_1)
summary(model_5)

# Multiplicative + Distributed model Prediction - Home Audio
Predict_1 <- predict(model_5,mult_Dis_model_1)
mult_Dis_model_1$test_gmv <- Predict_1
# Now, we need to test the r square between actual and predicted sales. 
r <- cor(mult_Dis_model_1$gmv,mult_Dis_model_1$test_gmv)
rsquared <- cor(mult_Dis_model_1$gmv,mult_Dis_model_1$test_gmv)^2
rsquared


########### Koyack Model - Home Audio
Koyck_Model <- dataset_final_analysis[,-c(13:23)]
Koyck_Model <- slide(Koyck_Model, Var = "gmv",slideBy = -1)
Koyck_Model <- na.omit(Koyck_Model)
#Koyck_Model <- scale(Koyck_Model)
#Koyck_Model <- data.frame(Koyck_Model)

Koyck_Model_1 <- lm(gmv~.,Koyck_Model)
summary(Koyck_Model_1)

step <- stepAIC(Koyck_Model_1,direction = "both")
step

model_2 <- lm(formula = gmv ~ Year + week + deliverycdays + deliverybdays + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                product_mrp_class_medium + NPS_WeekAvg + investment + investmentTV + 
                investmentDigital + investmentSponsorship + gmv.1, data = Koyck_Model)
summary(model_2)
vif(model_2)

# - product_mrp_class_medium
model_3 <- lm(formula = gmv ~ Year + week + deliverycdays + deliverybdays + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                NPS_WeekAvg + investment + investmentTV + 
                investmentDigital + investmentSponsorship + gmv.1, data = Koyck_Model)
summary(model_3)
vif(model_3)

# - gmv.1
model_4 <- lm(formula = gmv ~ Year + week + deliverycdays + deliverybdays + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                NPS_WeekAvg + investment + investmentTV + 
                investmentDigital + investmentSponsorship, data = Koyck_Model)
summary(model_4)
vif(model_4)


# - investment
model_5 <- lm(formula = gmv ~ Year + week + deliverycdays + deliverybdays + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                NPS_WeekAvg + investmentTV + 
                investmentDigital + investmentSponsorship, data = Koyck_Model)
summary(model_5)
vif(model_5)

# - NPS_WeekAvg - investmentTV
model_6 <- lm(formula = gmv ~ Year + week + deliverycdays + deliverybdays + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                investmentDigital + investmentSponsorship, data = Koyck_Model)
summary(model_6)
vif(model_6)

# - deliverycdays, deliverybdays
model_7 <- lm(formula = gmv ~ Year + week + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                investmentDigital + investmentSponsorship, data = Koyck_Model)
summary(model_7)


# - investmentSponsorship
model_8 <- lm(formula = gmv ~ Year + week + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap + 
                investmentDigital, data = Koyck_Model)
summary(model_8)


# - investmentDigital
model_9 <- lm(formula = gmv ~ Year + week + 
                product_procurement_sla + offer_percentage + product_mrp_class_cheap , data = Koyck_Model)
summary(model_9)


# Koyck model Prediction - Home Audio
Predict_1 <- predict(model_9, Koyck_Model)
Koyck_Model$test_gmv <- Predict_1
# Now, we need to test the r square between actual and predicted sales. 
r <- cor(Koyck_Model$gmv,Koyck_Model$test_gmv)
rsquared <- cor(Koyck_Model$gmv,Koyck_Model$test_gmv)^2
rsquared
