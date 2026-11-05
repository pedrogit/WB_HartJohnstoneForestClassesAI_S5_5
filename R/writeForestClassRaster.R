#' Write a forest class raster to a GeoTIFF with its legend
#'
#' Writes the output of [classifyForestClasses()] as an 8-bit GeoTIFF. The colour table is
#' stored inside the `.tif`, so QGIS shows the classes in their colours without any other
#' file. The class names are also stored as metadata tags `class_1` to `class_6`. GDAL and
#' QGIS only use them as legend labels when the `.aux.xml` sidecar is written
#' (`sidecar = TRUE`).
#'
#' @param x a `SpatRaster` returned by [classifyForestClasses()].
#' @param filename path of the `.tif` to write.
#' @param sidecar if `TRUE`, also write the `.aux.xml` file with the class names.
#' @param overwrite overwrite an existing file? Defaults to `FALSE`.
#'
#' @return `filename`, invisibly.
#' @export
writeForestClassRaster <- function(x, filename, sidecar = FALSE, overwrite = FALSE) {
  if (!inherits(x, "SpatRaster")) stop("`x` must be a terra SpatRaster.")
  labs <- terra::levels(x)[[1]]
  if (is.null(labs) || !terra::has.colors(x))
    stop("`x` has no class names or colour table; build it with classifyForestClasses().")
  if (!overwrite && file.exists(filename))
    stop("Output already exists; refusing to overwrite: ", filename)

  # Tag a copy so the caller's raster keeps its own metadata
  x <- terra::deepcopy(x)
  terra::metags(x) <- stats::setNames(as.character(labs[[2]]), paste0("class_", labs[[1]]))

  if (!sidecar) {
    # GDAL writes class names to a sidecar through its PAM layer; switch it off for this write
    wasOff <- identical(unname(terra::getGDALconfig("GDAL_PAM_ENABLED")), "NO")
    terra::setGDALconfig("GDAL_PAM_ENABLED", "NO")
    on.exit(terra::setGDALconfig("GDAL_PAM_ENABLED", if (wasOff) "NO" else "YES"), add = TRUE)
  }
  terra::writeRaster(x, filename, datatype = "INT1U", overwrite = overwrite)
  invisible(filename)
}
