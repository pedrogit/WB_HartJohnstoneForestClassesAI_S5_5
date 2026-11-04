# Everything in this file gets sourced during simInit, and all functions and objects
# are put into the simList. To use objects and functions, use sim$xxx.
defineModule(sim, list(
  name = "WB_HartJohnstoneForestClassesAI_S5_5",
  description = paste("Converts the Biomass_core `cohortData` and `pixelGroupMap` into a map of",
                      "forest classes adapted from Table 1 of Hart et al. (2019), using biomass as",
                      "the proxy for tree species dominance. The classes are 1 = deciduous,",
                      "2 = coni-deci mix, 3 = conifer mix, 4 = pine, 5 = larch and 6 = spruce;",
                      "non-forest pixels are NA. The classification itself is done by the",
                      "reusable function `classifyForestClasses()` in the `R` folder."),
  keywords = c("forest classes", "vegetation state", "Hart et al. 2019", "Biomass_core"),
  authors = c(
    person("Pierre", "Racine", email = "pierre.racine@sbf.ulaval.ca", role = c("aut", "cre"))
  ),
  childModules = character(0),
  version = list(WB_HartJohnstoneForestClassesAI_S5_5 = numeric_version("0.0.1")),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("README.md", "NEWS.md"),
  reqdPkgs = list("data.table", "terra", "reproducible", "SpaDES.core (>= 2.0.0)"),
  loadOrder = list(after = "Biomass_core"),
  parameters = bindrows(
    defineParameter("dominanceThreshold", "numeric", 0.66, 0.01, 1,
                    desc = paste("Minimum share (0 to 1) of the total biomass of a pixel group that a",
                                 "species group (deciduous, pine, larch or spruce) must reach to be",
                                 "dominant. Hart et al. (2019) use 0.66.")),
    defineParameter("updateInterval", "numeric", NA_real_, 0, NA,
                    desc = "NA follows the core succession interval (10 years standalone); an explicit value must match the core when coupled."),
    defineParameter(".plots", "character", NA_character_, NA, NA,
                    desc = "Use `\"screen\"` to plot the forest class map at each update. `NA` means no plotting."),
    defineParameter(".plotInitialTime", "numeric", NA_real_, NA, NA,
                    desc = "Simulation time of the first plot of the forest class map. `NA` means no plotting."),
    defineParameter(".plotInterval", "numeric", NA_real_, NA, NA,
                    desc = "Years between plots. `NA` means plot at each update."),
    defineParameter(".saveInitialTime", "numeric", NA_real_, NA, NA,
                    desc = paste("Simulation time of the first save of the forest class map as a GeoTIFF in",
                                 "`outputPath(sim)`. `NA` means no saving.")),
    defineParameter(".saveInterval", "numeric", NA_real_, NA, NA,
                    desc = "Years between saves. `NA` means save at each update."),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    desc = "Cache the classification with `reproducible::Cache()`?")
  ),
  inputObjects = bindrows(
    expectsInput("cohortData", "data.table",
                 desc = paste("Cohort table created by Biomass_core. Needs the columns `pixelGroup`",
                              "(integer), `speciesCode` (factor or character, LandR species codes)",
                              "and `B` (biomass, in g/m^2).")),
    expectsInput("pixelGroupMap", "SpatRaster",
                 desc = paste("Map of pixel group ids created by Biomass_core. Pixels with 0 or NA are",
                              "non-forest."))
  ),
  outputObjects = bindrows(
    createsOutput("WB_HartJohnstoneForestClassesAIMap", "SpatRaster",
                  desc = paste("Forest class map with the geometry of `pixelGroupMap`. Values: 1 =",
                               "deciduous, 2 = coni-deci mix, 3 = conifer mix, 4 = pine, 5 = larch,",
                               "6 = spruce, NA = non-forest. Carries class names and a colour table."))
  )
))

doEvent.WB_HartJohnstoneForestClassesAI_S5_5 <- function(sim, eventTime, eventType) {
  # Runs after Biomass_core's succession events (priorities 4 to 8.25) and before its plots (9)
  updatePriority <- 8.5

  switch(
    eventType,
    init = {
      interval <- P(sim)$updateInterval
      coreInterval <- params(sim)$Biomass_core$successionTimestep
      if (is.na(interval)) interval <- if (is.null(coreInterval)) 10 else coreInterval
      if (length(interval) != 1L || !is.finite(interval) || interval <= 0)
        stop("Classification interval must be finite and positive.")
      if (!is.null(coreInterval) && !isTRUE(all.equal(interval, as.numeric(coreInterval))))
        stop("updateInterval must match Biomass_core successionTimestep.")
      mod$classificationInterval <- interval
      mod$classificationIndex <- 0L
      sim <- scheduleEvent(sim, time(sim),
                           "WB_HartJohnstoneForestClassesAI_S5_5", "update", updatePriority)
      if (!is.na(P(sim)$.plotInitialTime))
        sim <- scheduleEvent(sim, P(sim)$.plotInitialTime,
                             "WB_HartJohnstoneForestClassesAI_S5_5", "plot", updatePriority + 0.25)
      if (!is.na(P(sim)$.saveInitialTime))
        sim <- scheduleEvent(sim, P(sim)$.saveInitialTime,
                             "WB_HartJohnstoneForestClassesAI_S5_5", "save", updatePriority + 0.5)
    },
    update = {
      sim <- Init(sim)
      mod$classificationIndex <- mod$classificationIndex + 1L
      nextTime <- start(sim) + mod$classificationIndex * mod$classificationInterval
      if (nextTime <= end(sim))
        sim <- scheduleEvent(sim, nextTime,
                             "WB_HartJohnstoneForestClassesAI_S5_5", "update", updatePriority)
    },
    plot = {
      sim <- plotForestClassMap(sim)
      plotInterval <- if (is.na(P(sim)$.plotInterval)) mod$classificationInterval else P(sim)$.plotInterval
      if (!is.finite(plotInterval) || plotInterval <= 0) stop("Plot interval must be finite and positive.")
      sim <- scheduleEvent(sim, time(sim) + plotInterval,
                           "WB_HartJohnstoneForestClassesAI_S5_5", "plot", updatePriority + 0.25)
    },
    save = {
      sim <- saveForestClassMap(sim)
      saveInterval <- if (is.na(P(sim)$.saveInterval)) mod$classificationInterval else P(sim)$.saveInterval
      if (!is.finite(saveInterval) || saveInterval <= 0) stop("Save interval must be finite and positive.")
      sim <- scheduleEvent(sim, time(sim) + saveInterval,
                           "WB_HartJohnstoneForestClassesAI_S5_5", "save", updatePriority + 0.5)
    },
    warning(paste("Undefined event type: '", eventType, "' in module '", currentModule(sim), "'", sep = ""))
  )
  return(invisible(sim))
}

## Event functions

Init <- function(sim) {
  if (isTRUE(P(sim)$.useCache)) {
    sim$WB_HartJohnstoneForestClassesAIMap <- Cache(
      classifyForestClasses,
      cohortData = sim$cohortData,
      pixelGroupMap = sim$pixelGroupMap,
      dominanceThreshold = P(sim)$dominanceThreshold,
      userTags = c(currentModule(sim), "classifyForestClasses"),
      omitArgs = "userTags"
    )
  } else {
    sim$WB_HartJohnstoneForestClassesAIMap <- classifyForestClasses(
      cohortData = sim$cohortData,
      pixelGroupMap = sim$pixelGroupMap,
      dominanceThreshold = P(sim)$dominanceThreshold
    )
  }
  return(invisible(sim))
}

plotForestClassMap <- function(sim) {
  if (identical(P(sim)$.plots, "screen"))
    terra::plot(sim$WB_HartJohnstoneForestClassesAIMap,
                main = paste("Forest classes, year", time(sim)))
  return(invisible(sim))
}

saveForestClassMap <- function(sim) {
  fn <- file.path(outputPath(sim), paste0("WB_HartJohnstoneForestClassesAI_S5_5_Map_year", time(sim), ".tif"))
  writeForestClassRaster(sim$WB_HartJohnstoneForestClassesAIMap, fn)
  return(invisible(sim))
}

.inputObjects <- function(sim) {
  # Synthetic defaults so the module runs alone; Biomass_core's objects take precedence
  if (!suppliedElsewhere("cohortData", sim) || !suppliedElsewhere("pixelGroupMap", sim)) {
    synthetic <- syntheticForestInputs()
    if (!suppliedElsewhere("cohortData", sim)) sim$cohortData <- synthetic$cohortData
    if (!suppliedElsewhere("pixelGroupMap", sim)) sim$pixelGroupMap <- synthetic$pixelGroupMap
  }
  return(invisible(sim))
}
