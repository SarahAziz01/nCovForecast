## ---------------------------
##
## Script name: 
##
## Purpose of script:
##
## Author: Ben Phillips
##
## Date Created: 2020-03-12
##
## Email: phillipsb@unimelb.edu.au
##
## ---------------------------
##
## Notes:
##   
##
## --------------------------
## load up the packages we will need 
library(shiny)
library(plotly)
## ---------------------------

## source files
source("functions.R") # makes functions available to the instance.
source("getDataLocal.R") #makes data available to the instance.

## ---------------------------
options(scipen=9)


# Define server logic 
server <- function(input, output, session) {

  list2env(dataList[["Global"]], envir = environment()) # make global data available to session

#### Observer function -- Global or Country level ####
  # if we observe that global_or_country is changing, then update the choices in countryFinder
  observe({
    list2env(dataList[[input$global_or_country]], envir = parent.env(environment()))
    if (input$global_or_country == 'Global') {
      updateSelectizeInput(session, "countryFinder",     selected = "US", choices = ddReg)
      updateSelectizeInput(session, "countryGrowthRate", selected = c("US", "Italy", "Australia", "China"), choices = ddReg)
    } else {
      if (input$global_or_country == 'Australia') {
        updateSelectizeInput(session, "countryFinder",     choices = ddReg)
        updateSelectizeInput(session, "countryGrowthRate", selected = c("New South Wales","Victoria"), choices = ddReg )
      } else if (input$global_or_country == 'Canada') {
        ddReg = ddReg[! ddReg %in% c('Diamond Princess','Recovered')] # for some reason, these states do not work.  TOFIX.
        updateSelectizeInput(session, "countryFinder",     choices = ddReg)
        updateSelectizeInput(session, "countryGrowthRate", selected = c("Ontario","Quebec"), choices = ddReg )
      } else if (input$global_or_country == 'China') {
        ddReg = ddReg[! ddReg %in% c('Anhui', 'Guangxi', 'Guizhou', 'Hainan', 'Ningxia', 'Qinghai', 'Tibet', 'Xinjiang')] # for some reason, these states do not work.  TOFIX.
        updateSelectizeInput(session, "countryFinder",     choices = ddReg)
        updateSelectizeInput(session, "countryGrowthRate", selected = c("Hubei","Henan","Heilongjiang"), choices = ddReg)
      } else if (input$global_or_country == 'US') {
        ddReg = ddReg[! ddReg %in% c('American Samoa')] # for some reason, these states do not work.  TOFIX.
        updateSelectizeInput(session, "countryFinder",     choices = ddReg)
        updateSelectizeInput(session, "countryGrowthRate", selected = c("Michigan","New Jersey","New York"), choices = ddReg)
      } else {
        updateSelectizeInput(session, "countryFinder",     choices = ddReg)
        updateSelectizeInput(session, "countryGrowthRate", choices = ddReg)
      }
    }
  })


#### Reactive expressions for forecast page ####
  yfCast <-reactive({ # subset country for forecast page
    yI <- tsSub(timeSeriesInfections,timeSeriesInfections$Region %in% input$countryFinder)  
    yD <- tsSub(timeSeriesDeaths,timeSeriesDeaths$Region %in% input$countryFinder) 
    yR <- tsSub(timeSeriesRecoveries,timeSeriesRecoveries$Region %in% input$countryFinder)  
    yA <- tsSub(timeSeriesActive,timeSeriesActive$Region %in% input$countryFinder)
    list(yI = yI, yD = yD, yR = yR, yA = yA)
  })
  
  projfCast <- reactive({ # projection for forecast
    projSimple(yfCast()$yA, dates, inWindow = input$fitWinSlider)
  })
  
  plotRange <- reactive({ # get date range to plot
    yA <- yfCast()$yA
    dFrame <- data.frame(dates = as.Date(names(yA), format = "%m.%d.%y"), yA)
    if (max(dFrame$yA)>200) {minDate <- min(dFrame$dates[dFrame$yA>20]); maxDate <- max(dFrame$dates)+10} else {
      minDate <- min(dFrame$dates); maxDate <- max(dFrame$dates)+10
    }
    list(minDate, maxDate)
  })
  
  ##### Raw stats #####  
  output$rawStats <- renderTable({
    yA <- yfCast()$yA
    yD <- yfCast()$yD
    yI <- yfCast()$yI
    nn <-length(yI)
    if (is.na(yA[nn])) nn <- nn-1
    out <- as.integer(c(yI[nn], yD[nn]))
    dim(out) <-c(1,2)
    colnames(out) <- c("Total", "Deaths")
    format(out, big.mark = ",")
  }, rownames = FALSE)
  
##### Raw plot #####
  output$rawPlot <- renderPlotly({
    yA <- yfCast()$yA
    yA <- data.frame(dates = as.Date(names(yA), format = "%m.%d.%y"), yA)
    lDat <- projfCast()
    pDat <- merge(yA, lDat, all = TRUE)
    yMax <- max(c(lDat$fit, yA$yA), na.rm = TRUE)*1.05
    clrDark<-"#273D6E"
    clrLight<-"#B2C3D5"
    #yTxt <- "Confirmed active cases"
    fig <- plot_ly(pDat, type = "scatter", mode = "none") %>%
              add_trace(y = ~fit,
                        x = ~dates, 
                        mode = "lines", 
                        line = list(color = clrDark), 
                        name = "Best fit", 
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$fit, 0), big.mark = ","))) %>%
              add_trace(y = ~lwr,
                        x = ~dates,
                        mode = "lines", 
                        line = list(color = clrDark, dash = "dash"), 
                        name = "CI lower bound",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$lwr, 0), big.mark = ","))) %>%
              add_trace(y = ~upr, 
                        x = ~dates,
                        mode = "lines", 
                        line = list(color = clrDark, dash = "dash"), 
                        name = "CI upper bound",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$upr, 0), big.mark = ","))) %>%
              add_trace(y = ~yA, 
                        x = ~dates,
                        mode = "markers", 
                        marker = list(color = clrLight), 
                        name = "Active cases",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$yA, 0), big.mark = ","))) %>%
              layout(showlegend = FALSE, 
                     yaxis = list(range = list(0, yMax),
                                  title = list(text = "Confirmed active cases"),
                                  fixedrange = TRUE),
                     xaxis = list(range = plotRange(),
                                  title = list(text = ""),
                                  fixedrange = TRUE),
                     title = list(text = input$countryFinder)
              ) %>%
              config(displayModeBar = FALSE)
  })
  
##### Log plot #####
  output$logPlot <- renderPlotly({
    yA <- yfCast()$yA
    yA <- data.frame(dates = as.Date(names(yA), format = "%m.%d.%y"), yA)
    lDat <- projfCast()
    pDat <- merge(yA, lDat, all = TRUE)
    yMax <- max(c(lDat$fit, yA$yA), na.rm = TRUE)*1.05
    clrDark<-"#273D6E"
    clrLight<-"#B2C3D5"
    #yTxt <- "Confirmed active cases"
    fig <- plot_ly(pDat, type = "scatter", mode = "none") %>%
              add_trace(y = ~fit,
                        x = ~dates,
                        mode = "lines", 
                        line = list(color = clrDark), 
                        name = "Best fit",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$fit, 0), big.mark = ","))) %>%
              add_trace(y = ~lwr, 
                        x = ~dates,
                        mode = "lines", 
                        line = list(color = clrDark, dash = "dash"), 
                        name = "CI lower bound",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$lwr, 0), big.mark = ","))) %>%
              add_trace(y = ~upr, 
                        x = ~dates,
                        mode = "lines", 
                        line = list(color = clrDark, dash = "dash"), 
                        name = "CI upper bound",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$upr, 0), big.mark = ","))) %>%
              add_trace(y = ~yA, 
                        x = ~dates,
                        mode = "markers", 
                        marker = list(color = clrLight), 
                        name = "Active cases",
                        hoverinfo = "text+name", 
                        text = paste(format(pDat$dates, "%b %d"), format(round(pDat$yA, 0), big.mark = ","))) %>%
              layout(showlegend = FALSE, 
                     yaxis = list(type = "log",
                                  range = list(log10(0.1), log10(yMax)),
                                  title = list(text = "Confirmed active cases (log scale)"),
                                  fixedrange = TRUE),
                     xaxis = list(range = plotRange(),
                                  title = list(text = ""),
                                  fixedrange = TRUE)
              ) %>%
              config(displayModeBar = FALSE)
  })

##### New cases ##### 
  output$newCases <- renderPlotly({
    yI <- yfCast()$yI
    yA <- yfCast()$yA
    newCases <- diff(yI)
    newCases <- data.frame(dates = as.Date(names(newCases), format = "%m.%d.%y"), newCases)
    fig <- plot_ly(newCases, 
                   x = ~dates, 
                   y = ~newCases, 
                   type = "bar", 
                   showlegend = FALSE, 
                   name = "New cases",
                   hoverinfo = "text+name", 
                   text = paste(format(newCases$dates, "%b %d"), format(round(newCases$newCases, 0), big.mark = ",")))
    fig <- fig %>% layout(xaxis = list(range = plotRange(),
                                      title = list(text = "Date")),
                          yaxis = list(title = list(text = "Number of new cases"))
                    ) %>%
                    config(displayModeBar = FALSE)
  })
  
  
##### Detection rate #####    
  output$detRate <- renderText({
    yI <- yfCast()$yI
    yD <- yfCast()$yD
    dR<-round(detRate(yI, yD), 4)*100
    if (is.na(dR)) "Insufficient data for estimation" else paste(dR,'%')
  })
  
##### Prediction table confirmed #####    
  output$tablePredConf <- renderTable({
    yA <- yfCast()$yA
    lDat <- projfCast()
    nowThen <- format(as.integer(c(tail(yA[!is.na(yA)], 1), tail(lDat$lwr,1), tail(lDat$upr,1))), big.mark = ",")
    nowThen <- c(nowThen[1], paste(nowThen[2], "-", nowThen[3]))
    dim(nowThen) <- c(1, 2)
    colnames(nowThen)<-c("Now", "In 10 days (min-max)")
    nowThen
  }, rownames = FALSE)
  
##### Prediction table true #####    
  output$tablePredTrue <- renderTable({
    yA <- yfCast()$yA
    yD <- yfCast()$yD
    yI <- yfCast()$yI
    dRate <- detRate(yI, yD)
    nowDiag <- tail(yA[!is.na(yA)], 1)
    nowUndet <- nowDiag/dRate - nowDiag
    nowUndiag <- active.cases[active.cases$Region==input$countryFinder, ncol(active.cases)] - nowDiag
    if (nowUndiag<0) nowUndiag <- 0
    nowTotal <- nowDiag+nowUndiag+nowUndet
    nowTable <- format(round(c(nowDiag, nowUndiag, nowUndet, nowTotal), 0), big.mark = ",")
    dim(nowTable) <- c(4, 1)
    rownames(nowTable)<-c("Diagnosed", "Undiagnosed", "Undetected", "Total")
    nowTable
  }, rownames = TRUE, colnames = FALSE)
  
##### Reactive expressions for growth page #####    
  growthSub <- reactive({
    subset(timeSeriesActive, timeSeriesActive$Region %in% input$countryGrowthRate)
  })

##### Curve-flattening #####    
  output$cfi <- renderPlotly({
    pDat <- growthSub()
    pMat<-as.matrix(log(pDat[,-1]))
    row.names(pMat)<-pDat$Region
    cfiDat<-apply(pMat, MARGIN = 1, FUN = "cfi")
    cfiDat[!is.finite(cfiDat)]<-0
    dateSub<-3:length(dates) # date subset
    for (cc in 1:ncol(cfiDat)){
      cfiSmooth<-loess(cfiDat[,cc]~as.numeric(dates[dateSub]))
      cfiDat[,cc] <- predict(cfiSmooth, newdata = as.numeric(dates[dateSub]))
    }
    yRange <- as.list(range(cfiDat)*1.05)
    cfiDat <- data.frame(dates = dates[dateSub], cfiDat)
    fig <- plot_ly(type = "scatter", mode = "none", name = "")
    for (cc in 2:ncol(cfiDat)){
      fig <- fig %>% add_trace(y = cfiDat[,cc],
                               x = dates[dateSub],
                               mode = "lines",
                               name = colnames(cfiDat)[cc],
                               hoverinfo = "text+name", 
                               text = paste(format(cfiDat$dates, "%b %d"), round(cfiDat[,cc], 2)))
    }
    fig <- fig %>% layout(xaxis = list(title = list(text = "Date")),
                          yaxis = list(title = list(text = "Curve-flattening index"),
                                       range = yRange)
                          ) %>%
                   config(displayModeBar = FALSE)
     
  })
  
##### Growth rate #####    
  output$growthRate <- renderPlotly({
    pDat <- growthSub()
    gRate <- as.matrix(growthRate(pDat[,-1], inWindow = ncol(pDat)-2)) #daily growth over all time
    gRateMA <- apply(gRate, # get moving average (three day window)
                     MARGIN = 1, 
                     FUN = function(x, n = 3){stats::filter(x, rep(1 / n, n), sides = 1)})
    gRateMA[is.infinite(gRateMA)]<-NA #remove Infs
    # reorganise for plotting
    gRateMA <- data.frame(dates = as.Date(colnames(gRate), format = "%m.%d.%y"), gRateMA)
    if (nrow(gRateMA)>20) gRateMA <-tail(gRateMA, 20)
    colnames(gRateMA)[-1] <- pDat$Region
    # and plot
    fig <- plot_ly(gRateMA, type = "scatter", mode = "none")
    for (cc in 2:ncol(gRateMA)){
      fig <- fig %>% add_trace(y = gRateMA[,cc],
                               x = ~dates,
                               mode = "lines", 
                               name = colnames(gRateMA)[cc],
                               hoverinfo = "text+name", 
                               text = paste(format(gRateMA$dates, "%b %d"), round(gRateMA[,cc], 1), "%"))
    }
    fig <- fig %>% layout(xaxis = list(title = list(text = "Date")),
                          yaxis = list(title = list(text = "Growth rate (% per day)"))
                    ) %>%
                    config(displayModeBar = FALSE)
  })
  
##### Doubling time ##### 
  output$doubTime <- renderText({
      pDat <- yfCast()$yA
      dTime <- paste(round(doubTime(pDat, dates, inWindow = input$fitWinSlider), 1), ' days')
  })

} # end of server expression

shinyApp(ui = htmlTemplate('base.html'), server)

