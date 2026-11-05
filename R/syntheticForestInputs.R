# Small synthetic cohortData and pixelGroupMap for examples and tests. Never called by the
# module itself: production runs must supply their own inputs.
# Pixel groups 1 to 6 give one example of each forest class; the last two pixels are non-forest.
syntheticForestInputs <- function() {
  cohortData <- data.table::data.table(
    pixelGroup = c(1L, 2L, 2L, 3L, 3L, 4L, 4L, 5L, 6L),
    speciesCode = factor(c("Popu_tre",
                           "Popu_tre", "Pice_mar",
                           "Pice_mar", "Abie_bal",
                           "Pinu_ban", "Pinu_con",
                           "Lari_lar", "Pice_gla")),
    B = c(100,
          50, 50,
          50, 50,
          80, 20,
          100, 100)
  )
  pixelGroupMap <- terra::rast(nrows = 2, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 2,
                               crs = "EPSG:3347")
  terra::values(pixelGroupMap) <- c(1L, 2L, 3L, 4L, 5L, 6L, NA, NA)
  names(pixelGroupMap) <- "pixelGroup"
  list(cohortData = cohortData, pixelGroupMap = pixelGroupMap)
}
