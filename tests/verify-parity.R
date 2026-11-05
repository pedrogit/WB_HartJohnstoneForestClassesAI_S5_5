# Development verification only; neither reference module is a runtime dependency.
# Compares S5_5 with the original (drainageMap = NULL) and with Sol6_1 on identical inputs.
verifyParity <- function(originalModule, sol6Module, s5Module, snapshots, outputDirectory) {
  if (dir.exists(outputDirectory)) stop("Use a new output directory.")
  dir.create(outputDirectory, recursive = TRUE)
  original <- new.env(parent = globalenv())
  sol6 <- new.env(parent = globalenv())
  s5 <- new.env(parent = globalenv())
  sys.source(file.path(originalModule, "R/WB_HartJohnstoneForestClasses.r"), original)
  sys.source(file.path(sol6Module, "R/classifyHartJohnstoneForest.R"), sol6)
  sys.source(file.path(s5Module, "R/classifyForestClasses.R"), s5)
  rows <- list()
  same <- function(a, b, variableName = TRUE) {
    x <- as.numeric(terra::values(a)); y <- as.numeric(terra::values(b))
    stopifnot(terra::compareGeom(a, b), identical(is.na(x), is.na(y)),
              identical(x[!is.na(x)], y[!is.na(y)]),
              identical(terra::cats(a), terra::cats(b)),
              identical(terra::coltab(a), terra::coltab(b)),
              identical(names(a), names(b)))
    if (variableName) stopifnot(identical(terra::varnames(a), terra::varnames(b)))
    invisible(TRUE)
  }
  run <- function(label, cohorts, map, parameters = list(), roundtrip = FALSE) {
    baseline <- data.table::copy(cohorts)
    mapValues <- terra::values(map)
    folder <- file.path(outputDirectory, label)
    dir.create(folder)
    csv <- file.path(folder, c(original = "original.csv", sol6 = "sol6.csv", s5 = "s5.csv"))
    a <- do.call(original$classifyStand, c(list(
      cohortData = data.table::copy(cohorts), pixelGroupMap = terra::deepcopy(map),
      drainageMap = NULL, classificationTablePath = csv[[1]]), parameters))
    b <- do.call(sol6$classifyHartJohnstoneForest, c(list(
      cohortData = data.table::copy(cohorts), pixelGroupMap = terra::deepcopy(map),
      classificationTablePath = csv[[2]]), parameters))
    copied <- data.table::copy(cohorts)
    c5 <- do.call(s5$classifyForestClasses, c(list(
      cohortData = copied, pixelGroupMap = terra::deepcopy(map),
      classificationTablePath = csv[[3]]), parameters))
    same(a, c5); same(b, c5)
    stopifnot(isTRUE(all.equal(copied, baseline)), isTRUE(all.equal(cohorts, baseline)),
              identical(terra::values(map), mapValues),
              identical(readLines(csv[[1]]), readLines(csv[[3]])),
              identical(readLines(csv[[2]]), readLines(csv[[3]])))
    if (roundtrip) {
      terra::writeRaster(a, file.path(folder, "original.tif"), datatype = "INT1U")
      terra::writeRaster(c5, file.path(folder, "s5.tif"), datatype = "INT1U")
      ra <- terra::rast(file.path(folder, "original.tif"))
      rc <- terra::rast(file.path(folder, "s5.tif"))
      # GeoTIFF restores varnames from differing file basenames, not raster data.
      same(ra, rc, variableName = FALSE)
    }
    rows[[length(rows) + 1L]] <<- data.frame(
      case = label, cells = terra::ncell(map), mapped = sum(!is.na(terra::values(c5))),
      mismatches = 0L, againstOriginal = "identical", againstSol6 = "identical",
      csv = "identical", roundtrip = roundtrip)
    invisible(NULL)
  }
  map <- terra::rast(nrows = 2, ncols = 6, vals = c(0:9, 99, NA))
  cohorts <- data.table::data.table(
    pixelGroup = c(0, 1, 2, 3, 4, 5, 6, 6, 7, 7, 8, 8, 9, 100),
    speciesCode = factor(c("Pinu_ban", "Pinu_con", "Lari_lar", "Pice_mar", "Abie_las",
                           "Unknown", "Pice_mar", "Popu_tre", "Lari_lar", "Popu_tre",
                           "Pice_mar", "Popu_tre", NA, "unused")),
    B = c(100, 100, 100, 100, 100, 100, 2, 1, 3, 1, 0, 0, 100, 100))
  configurations <- list(
    defaults = list(), allPine = list(jackPineSp = "Pinu"),
    empty = list(jackPineSp = character(), larchSp = character(),
                 spruceSp = character(), otherConiferSp = character()),
    overlap = list(jackPineSp = "p", larchSp = "P", spruceSp = "P", otherConiferSp = "P"),
    literal = list(jackPineSp = "Pinu.*", larchSp = "^Lari", spruceSp = "pIcE"))
  for (label in names(configurations)) run(paste0("synthetic-", label), cohorts, map, configurations[[label]])
  for (parameter in c("jackPineSp", "larchSp", "spruceSp", "otherConiferSp")) {
    run(paste0("empty-", parameter), cohorts, map, stats::setNames(list(character()), parameter))
  }
  shares <- c(2/3 - 1e-8, 2/3, 2/3 + 1e-8, .70, .75 - 1e-8, .75, .75 + 1e-8)
  species <- c("Pinu_ban", "Lari_lar", "Pice_mar", "Abie_las", "Popu_tre")
  boundary <- data.table::rbindlist(lapply(seq_along(shares), function(i) {
    data.table::rbindlist(lapply(seq_along(species), function(j) {
      data.table::data.table(pixelGroup = (i - 1L) * 5L + j,
        speciesCode = c(species[j], if (j == 5L) "Abie_las" else "Popu_tre"),
        B = c(shares[i], 1 - shares[i]))
    }))
  }))
  boundary[, speciesCode := factor(speciesCode)]
  run("thresholds", boundary, terra::rast(nrows = 5, ncols = 7, vals = 1:35))
  run("all-missing", cohorts, terra::init(map, NA_real_))
  manifest <- utils::read.csv(file.path(snapshots, "artifact_hashes.csv"))
  manifest <- manifest[grepl("/(cohortData.rds|pixelGroupMap.tif)$", manifest$path), ]
  stopifnot(nrow(manifest) == 6L,
            identical(unname(tools::md5sum(file.path(snapshots, manifest$path))), manifest$md5))
  utils::write.csv(manifest, file.path(outputDirectory, "input_hashes.csv"), row.names = FALSE)
  for (year in c(0, 50, 100)) {
    folder <- file.path(snapshots, sprintf("year_%03d", year))
    d <- readRDS(file.path(folder, "cohortData.rds"))
    m <- terra::rast(file.path(folder, "pixelGroupMap.tif"))
    run(sprintf("year-%03d-defaults", year), d, m, roundtrip = TRUE)
    run(sprintf("year-%03d-all-pine", year), d, m, list(jackPineSp = "Pinu"), roundtrip = TRUE)
  }
  result <- do.call(rbind, rows)
  utils::write.csv(result, file.path(outputDirectory, "comparisons.csv"), row.names = FALSE)
  files <- unlist(lapply(c(originalModule, sol6Module, s5Module), list.files,
                         recursive = TRUE, full.names = TRUE))
  files <- files[!file.info(files)$isdir & !grepl("/\\.git/", files)]
  utils::write.csv(data.frame(path = files, md5 = unname(tools::md5sum(files))),
                   file.path(outputDirectory, "source_hashes.csv"), row.names = FALSE)
  saveRDS(list(session = sessionInfo(), defaults = formals(s5$classifyForestClasses),
               configurations = configurations, drainage = "disabled"),
          file.path(outputDirectory, "provenance.rds"))
  result
}
