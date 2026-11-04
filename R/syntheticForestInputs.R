# Small synthetic cohortData and pixelGroupMap so the module can run by itself.
# Pixel groups 1 to 6 give one example of each forest class; the last pixel is non-forest.
syntheticForestInputs <- function() {
  cohortData <- data.table::data.table(
    pixelGroup = c(1L, 2L, 2L, 3L, 3L, 3L, 4L, 5L, 6L),
    speciesCode = c("Popu_tre",
                    "Popu_tre", "Pice_gla",
                    "Pice_gla", "Pinu_con", "Lari_lar",
                    "Pinu_con", "Lari_lar", "Pice_gla"),
    B = c(100,
          50, 50,
          40, 30, 30,
          100, 100, 100)
  )
  pixelGroupMap <- terra::rast(nrows = 2, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 2,
                               crs = "EPSG:3347")
  terra::values(pixelGroupMap) <- c(1L, 2L, 3L, 4L, 5L, 6L, 0L, NA)
  names(pixelGroupMap) <- "pixelGroup"
  list(cohortData = cohortData, pixelGroupMap = pixelGroupMap)
}
