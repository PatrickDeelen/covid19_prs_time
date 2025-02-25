# Run longitudinal models

library(nlme)
library(heatmap3)
library(readr)
library(lme4)
library(future.apply)
library(survival)
library(parallel)

workdir <- "/groups/umcg-lifelines/tmp01/projects/ov20_0554/analysis/pgs_correlations/"
intermediatesdir <-  "/groups/umcg-lifelines/tmp01/projects/ov20_0554/analysis/pgs_correlations/longiIntermediates/"
preparedDataFile <- "longitudinal.RData"

setwd(workdir)
load(preparedDataFile)


#Functions:

inverseVarianceMeta <- function(resultsPerArray, seCol, valueCol){
  x <- as.data.frame(resultsPerArray[[1]][,FALSE])
  x$sumYDivSe2 <- 0
  x$sum1DivSe2 <- 0
  
  for(array in names(resultsPerArray)){
    se2 <- resultsPerArray[[array]][,seCol] * resultsPerArray[[array]][,seCol]
    x$sumYDivSe2 <- x$sumYDivSe2 + (resultsPerArray[[array]][,valueCol]/ se2)
    x$sum1DivSe2 <- x$sum1DivSe2 + (1/se2)
  }
  
  metaRes <- as.data.frame(resultsPerArray[[1]][,FALSE])
  metaRes$y <- x$sumYDivSe2/x$sum1DivSe2
  metaRes$se <- sqrt(1/x$sum1DivSe2)
  metaRes$z <- metaRes$y/metaRes$se 
  metaRes$p <- 2*pnorm(-abs(metaRes$z))
  return(metaRes)
}

qPrs <- qVsPrsRecodeValidation[1,]
fitModel <- function(qPrs, selectedQ, arrayList){
  
  print(str(qPrs))
  print(ls())
  
  print(qPrs["question"])
  
  print(paste(qPrs["question"], qPrs["prsTrait"], sep = " - "))
  
  q <- qPrs["question2"]
  print(q)
  
  
  intermediateFile <- make.names(paste0(qPrs["question"], "_", qPrs["prsTrait"]))
  intermediatePath <- paste0(intermediatesdir, "/" , intermediateFile, ".rds")
  
  fullRes <- NA
  
  if(file.exists(intermediatePath) ){
    #file.exists(intermediatePath)
    #Load exising results
    fullRes <- readRDS(intermediatePath)
  } else {
    #calculate new results
    
    if(!q %in% rownames(selectedQ)){
      print("skip")
      print(ls())
      return(list("resPerArray" = NA, "metaRes" = NA, "qPrs" = qPrs, "error" = "Not in selected Q"))
    }
    
    qInfo <- selectedQ[q,]
    
    if(!qInfo["Used_in_longitudinal_analysis"]){
      print("skip")
      return(list("resPerArray" = NA, "metaRes" = NA, "qPrs" = qPrs, "error" = "Not longitudinal"))
    }
    
    
    
    usedPrs <- qPrs["prsTrait"]
    # usedPrs <- usedPrs[!usedPrs %in% "Cigarettes.per.day"]
    #usedPrs <- c("BMI_gwas", "Life.satisfaction", "Neuroticism")
    #usedPrs <- "Life.satisfaction"
    #usedPrs <- "Neuroticism"
    #usedPrs <- "BMI_gwas"
    #usedPrs <- "Cigarettes.per.day"
    #usedPrs <- "COVID.19.susceptibility"
    #usedPrs <- "Anxiety.tension"
    #usedPrs <- "COVID.19.severity"
    #usedPrs <- "Worry.vulnerability"
    
    fixedString <- paste(q, "~((gender_recent+age_recent+age2_recent+household_recent+have_childs_at_home_recent+chronic_recent +", paste0(usedPrs, collapse = " + ") ,")*days + I(days^2) ) ")
    randomString <- "1+days+days2|PROJECT_PSEUDO_ID"#
    fixedModel <- as.formula(fixedString)
    randomModel <- as.formula(paste0("~",randomString))
    fullModel <- as.formula(paste0(fixedString, "+ (", randomString, ")"))
    
    resultsPerArray <- tryCatch(
      {
        lapply(arrayList, function(array){
          
          d <- vragenLong[!is.na(vragenLong[,q]) & vragenLong$array == array,c("PROJECT_PSEUDO_ID", q,usedPrs,"gender_recent","age_recent","age2_recent","household_recent","have_childs_at_home_recent","chronic_recent", "days", "days2", "days3", "vl")]
          table(d[,q])
          coef <- NA
          
          if(qInfo["TypeLongitudinal"] == "gaussian" & qInfo["Mixed"]){
            print("test1")
            res <-  lme(fixed = fixedModel, random=randomModel, data=d,na.action=na.omit, control = lmeControl(opt = "optim"))#
            return(res)
          } else if (qInfo["TypeLongitudinal"] == "gaussian" & !qInfo["Mixed"]) {
            print("test2")
            stop("Not implement")
          } else if (qInfo["TypeLongitudinal"] == "binomial" & qInfo["Mixed"]) {
            print("test3")
            if(max(d[,q])==2){
              d[,q] <- d[,q] -1
            }
            if(sum(range(d[,q])==0:1)!=2){
              stop("not binomal: " )
            }
            if(is.character(d[,q])){
              d[,q] <- as.numeric(d[,q])
            }
            glmMerFit <- glmer(fullModel, data = d, family = binomial, nAGQ=0 )
            return(glmMerFit)
          } else if (qInfo["TypeLongitudinal"] == "binomial" & !qInfo["Mixed"]) {
            print("test4")
            d[,q] <- as.factor(d[,q])
            glmBinomFit <- glm(fixedModel ,family=binomial(link='logit'),data=d)
            return(glmBinomFit)
          } else {
            stop("no model")
          }
          
          qreturn(coef)
        })
      },
      error=function(cond){
        print("ERROR")
        message(paste("ERROR:", qPrs["question"], qPrs["prsTrait"],cond))
        fullRes <- list("resPerArray" = NA, "metaRes" = NA, "qPrs" = qPrs, "error" = cond$message)
        return(fullRes)
      }
    )#end try catch
    
    
    if(is.na(resultsPerArray[1])){
      #contains list with info
      saveRDS(resultsPerArray, intermediatePath)
      return(resultsPerArray)
    }
    
    
    coefPerArray <- lapply(resultsPerArray, function(res){
      coef <- 0
      if(qInfo["TypeLongitudinal"] == "gaussian" & qInfo["Mixed"]){
        print("test1")
        coef <- summary(res)$tTable
      } else if (qInfo["TypeLongitudinal"] == "gaussian" & !qInfo["Mixed"]) {
        print("test2")
        stop("Not implement")
      } else if (qInfo["TypeLongitudinal"] == "binomial" & qInfo["Mixed"]) {
        print("test3")
        coef <- summary(res)$coefficients
        colnames(coef)[1:2]<-c("Value", "Std.Error")
      } else if (qInfo["TypeLongitudinal"] == "binomial" & !qInfo["Mixed"]) {
        print("test4b")
        coef <- summary(res)$coefficients
        colnames(coef)[1:2]<-c("Value", "Std.Error")
      }
      return(coef)
    })
    
    metaRes <- as.matrix(inverseVarianceMeta(coefPerArray, "Std.Error", "Value"))
    
    coefPerArray[[1]]
    coefPerArray[[2]]
    
    fullRes <- list("resPerArray" = resultsPerArray, "metaRes" = metaRes, "qPrs" = qPrs, "error" = NA, "fixedModel" = fixedModel, "randomModel" = randomModel, "fullModel" = fullModel)
    saveRDS(fullRes, intermediatePath)
  }
  
  return(fullRes)
  
}


qVsPrs <- read.delim("gwasses_to_perform_filtered_include_14_days.txt", stringsAsFactors = F)
if(!all(qVsPrs$X %in% rownames(qNameMap))){
  stop("Not all Q found")
}
qVsPrs$saveName <- qNameMap[qVsPrs$X,2]
rownames(qVsPrs) <- qVsPrs$saveName

qVsPrsRecode <- apply(qVsPrs, 1,function(x){
  prsTraits <- strsplit(x[2], ";")[[1]]
  combi <- cbind(x[1],x[3],prsTraits)
  return(combi)
})

qVsPrsRecode[[2]][1,3]

qVsPrsRecode2 <- do.call(rbind, qVsPrsRecode)
colnames(qVsPrsRecode2) <- c("question", "question2", "prsTrait")

head(qVsPrsRecode2)


#qPrs <- qVsPrsRecode2[1,]
#fitModel(qVsPrsRecode2[20,], selectedQ = selectedQ, arrayList = arrayList)

clust <- makeForkCluster(nnodes = 8)
clusterExport("vragenLong")
clusterExport("intermediatesdir")
clusterEvalQ(clust, {
  library(lme4)
  library(nlme)
})
resultList <- parApply(clust, qVsPrsRecode2, 1, fitModel, selectedQ = selectedQ, arrayList = arrayList)
stopCluster(clust)

#load existing results to continue at a later point
resultList <- sapply(list.files(intermediatesdir, pattern = "*.rds", full.names = T), readRDS)

#p-value threshold to select effects to validate using the subset of validation samples
pThreshold <- 0.01141707 

qVsPrsRecodeValidation <- lapply(resultList, function(x){
  
  if(!is.na(x["metaRes"])){
    r <- nrow(x[["metaRes"]])
    if(x[["metaRes"]][r,"p"] <= pThreshold & !selectedQ$skip_7_days[match(x[["qPrs"]]["question"], selectedQ$Question)]){
      return(x[["qPrs"]])
    }
  }
  
  
  
})

qVsPrsRecodeValidation <- qVsPrsRecodeValidation[!sapply(qVsPrsRecodeValidation,is.null)]
qVsPrsRecodeValidation <- do.call(rbind, qVsPrsRecodeValidation)
colnames(qVsPrsRecodeValidation) <- c("question", "question2", "prsTrait")

saveRDS(qVsPrsRecodeValidation, file = "qVsPrsRecodeValidation.rds")
qVsPrsRecodeValidation <- readRDS("qVsPrsRecodeValidation.rds")

vragenLongFull <- vragenLong


#Overwrite vragen long with validation data containing only validation samples and rounds
vragenLong <- vragenLongValidation
intermediatesdir <- paste0(intermediatesdir,"validation")
clust <- makeForkCluster(nnodes = 8)
clusterExport("vragenLong")
clusterExport("intermediatesdir")
clusterEvalQ(clust, {
  library(lme4)
  library(nlme)
  dim(vragenLong)
})
resultListValidation <- parApply(clust, qVsPrsRecodeValidation, 1, fitModel, selectedQ = selectedQ, arrayList = arrayList)
stopCluster(clust)


fitModel(qVsPrsRecodeValidation[1,], selectedQ = selectedQ, arrayList = arrayList)

resultListValidation2 <- parApply(clust, qVsPrsRecodeValidation, 1, fitModel, selectedQ = selectedQ, arrayList = arrayList)

resultListValidation[[1]]

summaryValidation <- lapply(resultListValidation, function(x){
  
  q <- x[["qPrs"]]["question"]
  q2 <- x[["qPrs"]]["question2"]
  t <- x[["qPrs"]]["prsTrait"]
  if(!is.na(x["metaRes"])){
    r <- nrow(x[["metaRes"]])
    z <- x[["metaRes"]][r,"z"]
    p <- x[["metaRes"]][r,"p"]
  } else{
    z <- NA
    p <- NA
  }
  e <- x[["error"]]
  
  return(data.frame(q,q2,t,p,z,e))
  
  
  
  
})

summaryValidation <- do.call(rbind, summaryValidation)



write.table(summaryValidation, file = "interactionSummaryValidation.txt", sep = "\t", quote = F, row.names = F)


