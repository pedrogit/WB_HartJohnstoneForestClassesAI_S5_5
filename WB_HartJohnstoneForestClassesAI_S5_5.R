# Everything in this file gets sourced during simInit, and all functions and objects
# are put into the simList. To use objects and functions, use sim$xxx.
defineModule(sim, list(
  name = "WB_HartJohnstoneForestClassesAI_S5_5",
  description = paste("Converts the Biomass_core `cohortData` and `pixelGroupMap` into a map of",
                      "forest classes adapted from Table 1 of Hart et al. (2019), using biomass as",
                      "the proxy for tree species dominance. It uses the same parameters and",
                      "six-class rules as WB_HartJohnstoneForestClasses, without the drainage",
                      "refinement. The classification itself is done by the reusable function",
                      "`classifyForestClasses()` in the `R` folder."),
  keywords = c("forest classes", "vegetation state", "Hart et al. 2019", "Biomass_core"),
  authors = c(
    person("Pierre", "Racine", email = "pierre.racine@sbf.ulaval.ca", role = c("aut", "cre"))
  ),
  childModules = character(0),
  version = list(WB_HartJohnstoneForestClassesAI_S5_5 = numeric_version("0.1.0")),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("README.md", "NEWS.md"),
  reqdPkgs = list("data.table", "terra", "reproducible", "SpaDES.core (>= 2.0.0)"),
  loadOrder = list(after = "Biomass_core"),
  parameters = bindrows(
    defineParameter(".plots", "character", "screen", NA, NA,
                    desc = "Use `\"screen\"` to plot the forest class map at each plot event."),
    defineParameter(".plotInitialTime", "numeric", NA_real_, NA, NA,
                    desc = "Simulation time of the first plot. `NA` means no plotting."),
    defineParameter(".plotInterval", "numeric", NA_real_, NA, NA,
                    desc = "Years between plots. `NA` follows the classification interval."),
    defineParameter("WB_HJForestClassesTimeStep", "numeric", NA_real_, NA, NA,
                    desc = "NA follows the core succession interval (10 years standalone); an explicit value must match the core when coupled."),
    defineParameter(".saveInitialTime", "numeric", NA_real_, NA, NA,
                    desc = "Simulation time of the first save of the map as a GeoTIFF in `outputPath(sim)`. `NA` means no saving."),
    defineParameter(".saveInterval", "numeric", NA_real_, NA, NA,
                    desc = "Years between saves. `NA` follows the classification interval."),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    desc = paste("Cache the classification with `reproducible::Cache()`? Ignored (no caching)",
                                 "when `writeClassificationCsv` is TRUE, so that the CSV is always written.")),
    defineParameter("jackPineSp", "character", c("Pinu_ban"), NA, NA,
                    desc = "Literal case-insensitive jack pine species-code prefixes."),
    defineParameter("larchSp", "character", c("Lari"), NA, NA,
                    desc = "Literal case-insensitive larch species-code prefixes."),
    defineParameter("spruceSp", "character", c("Pice"), NA, NA,
                    desc = "Literal case-insensitive spruce species-code prefixes."),
    defineParameter("otherConiferSp", "character",
                    c("Abie", "Calc", "Cham", "Juni", "Pinu", "Pseu", "Sequ", "Taxu", "Thuj", "Tsug"), NA, NA,
                    desc = "Additional conifer prefixes, applied after jack pine, larch and spruce. An empty character vector disables this group."),
    defineParameter("writeClassificationCsv", "logical", FALSE, NA, NA,
                    desc = "Whether to write a classification summary CSV in the output path at each classification.")
  ),
  inputObjects = bindrows(
    expectsInput("cohortData", "data.table",
                 desc = paste("Cohort table created by Biomass_core. Needs the columns `pixelGroup`",
                              "(integer), `speciesCode` (factor, LandR species codes) and `B` (biomass, in g/m^2).")),
    expectsInput("pixelGroupMap", "SpatRaster",
                 desc = "Map of pixel group ids created by Biomass_core. Ids without cohorts become NA.")
  ),
  outputObjects = bindrows(
    createsOutput("WB_HartJohnstoneForestClassesAI_S5_5_Map", "SpatRaster",
                  desc = paste("Forest class map (layer `standtype`) with the geometry of `pixelGroupMap`.",
                               "Values: 1 = deci, 2 = mixed, 3 = conimix, 4 = jackpine, 5 = larch,",
                               "6 = spruce, NA = no cohorts. Carries class names and a colour table."))
  )
))

doEvent.WB_HartJohnstoneForestClassesAI_S5_5 <- function(sim, eventTime, eventType) {
  moduleName <- "WB_HartJohnstoneForestClassesAI_S5_5"
  outputName <- paste0(moduleName, "_Map")
  # Runs after Biomass_core's growth (6) and summary (8.25) and before its plots (9)
  classifyPriority <- 8.5

  switch(
    eventType,
    init = {
      if (is.null(sim$cohortData) || is.null(sim$pixelGroupMap))
        stop("cohortData and pixelGroupMap must be supplied before classification initialization.")
      interval <- P(sim)$WB_HJForestClassesTimeStep
      coreInterval <- params(sim)$Biomass_core$successionTimestep
      if (is.na(interval)) interval <- if (is.null(coreInterval)) 10 else coreInterval
      if (!is.numeric(interval) || length(interval) != 1L || !is.finite(interval) || interval <= 0)
        stop("Classification interval must be finite and positive.")
      if (!is.null(coreInterval) && !isTRUE(all.equal(interval, as.numeric(coreInterval))))
        stop("WB_HJForestClassesTimeStep must match Biomass_core successionTimestep.")
      mod$classificationInterval <- interval
      mod$classificationIndex <- 0L
      sim <- scheduleEvent(sim, time(sim), moduleName, "reComputeHJForestClassesMap", classifyPriority)
      if (!is.na(P(sim)$.plotInitialTime))
        sim <- scheduleEvent(sim, P(sim)$.plotInitialTime, moduleName, "plot", 8.75)
      if (!is.na(P(sim)$.saveInitialTime))
        sim <- scheduleEvent(sim, P(sim)$.saveInitialTime, moduleName, "save", 9)
    },
    reComputeHJForestClassesMap = {
      sim <- reComputeHJForestClassesMap(sim)
      mod$classificationIndex <- mod$classificationIndex + 1L
      nextTime <- start(sim) + mod$classificationIndex * mod$classificationInterval
      if (nextTime <= end(sim))
        sim <- scheduleEvent(sim, nextTime, moduleName, "reComputeHJForestClassesMap", classifyPriority)
    },
    plot = {
      if (identical(P(sim)$.plots, "screen"))
        Plot(sim[[outputName]])
      interval <- if (is.na(P(sim)$.plotInterval)) mod$classificationInterval else P(sim)$.plotInterval
      if (!is.finite(interval) || interval <= 0) stop("Plot interval must be finite and positive.")
      sim <- scheduleEvent(sim, time(sim) + interval, moduleName, "plot", 8.75)
    },
    save = {
      fn <- file.path(outputPath(sim), paste0(outputName, "_time_", sprintf("%.17g", time(sim)), ".tif"))
      dir.create(outputPath(sim), recursive = TRUE, showWarnings = FALSE)
      writeForestClassRaster(sim[[outputName]], fn)
      interval <- if (is.na(P(sim)$.saveInterval)) mod$classificationInterval else P(sim)$.saveInterval
      if (!is.finite(interval) || interval <= 0) stop("Save interval must be finite and positive.")
      sim <- scheduleEvent(sim, time(sim) + interval, moduleName, "save", 9)
    },
    stop("Unknown ", moduleName, " event: ", eventType)
  )
  return(invisible(sim))
}

## Event functions

reComputeHJForestClassesMap <- function(sim) {
  moduleName <- "WB_HartJohnstoneForestClassesAI_S5_5"
  outputName <- paste0(moduleName, "_Map")
  csv <- NULL
  if (isTRUE(P(sim)$writeClassificationCsv)) {
    csv <- file.path(outputPath(sim), paste0(moduleName, "_", sprintf("%03d", time(sim)), ".csv"))
    if (file.exists(csv)) stop("Output already exists; refusing to overwrite: ", csv)
    dir.create(outputPath(sim), recursive = TRUE, showWarnings = FALSE)
  }
  args <- list(
    cohortData = sim$cohortData,
    pixelGroupMap = sim$pixelGroupMap,
    jackPineSp = P(sim)$jackPineSp,
    larchSp = P(sim)$larchSp,
    spruceSp = P(sim)$spruceSp,
    otherConiferSp = P(sim)$otherConiferSp,
    classificationTablePath = csv
  )
  if (isTRUE(P(sim)$.useCache) && is.null(csv)) {
    sim[[outputName]] <- do.call(Cache, c(
      list(classifyForestClasses), args,
      list(userTags = c(currentModule(sim), "classifyForestClasses"), omitArgs = "userTags")))
  } else {
    sim[[outputName]] <- do.call(classifyForestClasses, args)
  }
  return(invisible(sim))
}

.inputObjects <- function(sim) {
  for (input in c("cohortData", "pixelGroupMap")) {
    if (is.null(sim[[input]]) && !suppliedElsewhere(input, sim))
      stop(input, " must be supplied; construct demonstration inputs explicitly with syntheticForestInputs().")
  }
  return(invisible(sim))
}
