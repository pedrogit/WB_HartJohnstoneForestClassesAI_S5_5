simPaths <- function(name) {
  root <- file.path(scratch, name)
  list(modulePath = dirname(moduleDir), inputPath = file.path(root, "inputs"),
       outputPath = file.path(root, "outputs"), cachePath = file.path(root, "cache"))
}
moduleName <- "WB_HartJohnstoneForestClassesAI_S5_5"

withSpades <- function(code) {
  oldOptions <- options(spades.useRequire = FALSE, Require.install = FALSE, Require.offlineMode = TRUE)
  on.exit(options(oldOptions))
  force(code)
}

test_that("parameters match the original and Sol6_1 non-drainage set", {
  skip_if_not_installed("SpaDES.core")
  withSpades({
    sim <- SpaDES.core::simInit(modules = moduleName, objects = syntheticForestInputs(),
                                times = list(start = 3, end = 24, timeunit = "year"),
                                paths = simPaths("s5-params"))
    p <- SpaDES.core::params(sim)[[moduleName]]
    expected <- list(.plots = "screen", .plotInitialTime = NA_real_, .plotInterval = NA_real_,
      WB_HJForestClassesTimeStep = NA_real_, .saveInitialTime = NA_real_, .saveInterval = NA_real_,
      .useCache = FALSE, jackPineSp = "Pinu_ban", larchSp = "Lari", spruceSp = "Pice",
      otherConiferSp = c("Abie", "Calc", "Cham", "Juni", "Pinu", "Pseu", "Sequ", "Taxu", "Thuj", "Tsug"),
      writeClassificationCsv = FALSE)
    for (name in names(expected)) expect_equal(p[[name]], expected[[name]], info = name)
    expect_false(any(c("dominanceThreshold", "updateInterval", "useDrainage") %in% names(p)))
    sim <- SpaDES.core::spades(sim)
    done <- as.data.frame(SpaDES.core::completed(sim))
    events <- done[done$moduleName == moduleName & done$eventType == "reComputeHJForestClassesMap", ]
    expect_equal(events$eventTime, c(3, 13, 23))
    expect_true(all(events$eventPriority == 8.5))
    out <- sim$WB_HartJohnstoneForestClassesAI_S5_5_Map
    expect_equal(as.vector(values(out)), c(1:6, NA, NA))
    expect_equal(names(out), "standtype")
    outDir <- simPaths("s5-params")$outputPath
    expect_length(list.files(outDir, pattern = "\\.(csv|tif)$"), 0)
  })
})

test_that("CSV and save outputs are optional, uniquely named and scheduled independently", {
  skip_if_not_installed("SpaDES.core")
  withSpades({
    d <- data.table(pixelGroup = 1:4, speciesCode = factor(c("Jack", "Lar", "Spr", "Other")), B = 100)
    sim <- SpaDES.core::simInit(modules = moduleName,
      times = list(start = 3, end = 7, timeunit = "year"),
      params = list(WB_HartJohnstoneForestClassesAI_S5_5 = list(
        WB_HJForestClassesTimeStep = 2, writeClassificationCsv = TRUE, jackPineSp = "Jack",
        larchSp = "Lar", spruceSp = "Spr", otherConiferSp = "Other",
        .saveInitialTime = 4, .saveInterval = 3)),
      objects = list(cohortData = d, pixelGroupMap = rast(nrows = 1, ncols = 4, vals = 1:4)),
      paths = simPaths("s5-outputs"))
    sim <- SpaDES.core::spades(sim)
    expect_equal(as.vector(values(sim$WB_HartJohnstoneForestClassesAI_S5_5_Map)), c(4, 5, 6, 3))
    outDir <- simPaths("s5-outputs")$outputPath
    expect_equal(sort(list.files(outDir, pattern = "\\.csv$")),
                 paste0("WB_HartJohnstoneForestClassesAI_S5_5_", c("003", "005", "007"), ".csv"))
    expect_equal(sort(list.files(outDir, pattern = "\\.tif$")),
                 paste0("WB_HartJohnstoneForestClassesAI_S5_5_Map_time_", c(4, 7), ".tif"))
    done <- as.data.frame(SpaDES.core::completed(sim))
    saves <- done[done$eventType == "save", ]
    expect_equal(saves$eventTime, c(4, 7))
    expect_true(all(saves$eventPriority == 9))
  })
})

test_that("missing inputs and invalid intervals stop with clear errors", {
  skip_if_not_installed("SpaDES.core")
  withSpades({
    expect_error(SpaDES.core::spades(SpaDES.core::simInit(modules = moduleName,
      times = list(start = 0, end = 1, timeunit = "year"), paths = simPaths("s5-missing"))),
      "must be supplied")
    makeSim <- function(name, interval, coreInterval = NULL) {
      sim <- SpaDES.core::simInit(modules = moduleName,
        times = list(start = 3, end = 3, timeunit = "year"),
        params = list(WB_HartJohnstoneForestClassesAI_S5_5 = list(WB_HJForestClassesTimeStep = interval)),
        objects = syntheticForestInputs(), paths = simPaths(name))
      if (!is.null(coreInterval)) SpaDES.core::params(sim)$Biomass_core <- list(successionTimestep = coreInterval)
      sim
    }
    expect_error(SpaDES.core::spades(makeSim("s5-mismatch", 3, 2)), "must match")
    expect_error(SpaDES.core::spades(makeSim("s5-invalid", 0)), "finite and positive")
  })
})
