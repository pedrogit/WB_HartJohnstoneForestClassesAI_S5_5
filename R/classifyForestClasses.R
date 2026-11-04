#' Classify forest pixel groups into Hart et al. (2019)-style forest classes
#'
#' Converts a LandR `cohortData` table and its `pixelGroupMap` raster into a raster of
#' forest classes adapted from Table 1 of Hart et al. (2019). Tree species dominance is
#' based on biomass (`B`), not basal area or stem density. The drainage split of the
#' spruce and non-forest states is not applied.
#'
#' Pixels are classified from the share of the total biomass of their pixel group that
#' belongs to each species group. A share is "dominant" when it is at least
#' `dominanceThreshold`. Classes (raster values) are tested in this order of priority:
#' \enumerate{
#'   \item `1` Deciduous: deciduous share is dominant.
#'   \item `4` Pine: pine share is dominant.
#'   \item `5` Larch: larch share is dominant.
#'   \item `6` Spruce: spruce share is dominant.
#'   \item `3` Conifer mix: no single group above is dominant, but pine + larch + spruce
#'     together are.
#'   \item `2` Coni-deci mix: everything else (including pixel groups with no biomass, and
#'     pixel groups dominated by species that belong to none of the groups).
#' }
#' Pixels where `pixelGroupMap` is 0, `NA` (or whose pixel group is absent from
#' `cohortData`) are non-forest and are `NA` in the result.
#'
#' The returned raster carries its legend: class names (see [terra::levels()]) and a
#' colour table (see [terra::coltab()]). Use [writeForestClassRaster()] to write it to a
#' GeoTIFF that QGIS displays with that legend.
#'
#' @param cohortData a `data.table` with at least the columns `pixelGroup` (integer),
#'   `speciesCode` (character or factor, LandR species codes) and `B` (biomass, in
#'   g/m^2). Not modified.
#' @param pixelGroupMap a single-layer `SpatRaster` of pixel group ids matching
#'   `cohortData$pixelGroup`.
#' @param speciesGroups a named list with the elements `deciduous`, `pine`, `larch` and
#'   `spruce`. Each element is a character vector of regular expressions matched against
#'   `speciesCode`. Species matching no group count toward no group but stay in the
#'   biomass total. See [defaultForestSpeciesGroups()].
#' @param dominanceThreshold a number in (0, 1]; the minimum share of the pixel group's
#'   biomass for a species group to be dominant. Hart et al. (2019) use 0.66.
#' @param forestClassColours colours for the six classes, either named `"1"` to `"6"` or
#'   given in class order. See [defaultForestClassColours()].
#'
#' @return a `SpatRaster` with the geometry of `pixelGroupMap`, values 1 to 6 and `NA`
#'   for non-forest, with class names and a colour table attached.
#'
#' @references Hart, S.J., Henkelman, J., McLoughlin, P.D., Nielsen, S.E.,
#'   Truchon-Savard, A., Johnstone, J.F. (2019). Examining forest resilience to changing
#'   fire frequency in a fire-prone region of boreal forest. Global Change Biology 25,
#'   869-884. \doi{10.1111/gcb.14550}
#'
#' @export
classifyForestClasses <- function(cohortData, pixelGroupMap,
                                  speciesGroups = defaultForestSpeciesGroups(),
                                  dominanceThreshold = 0.66,
                                  forestClassColours = defaultForestClassColours()) {
  # Check inputs before doing any expensive work
  if (!inherits(pixelGroupMap, "SpatRaster"))
    stop("`pixelGroupMap` must be a terra SpatRaster.")
  if (terra::nlyr(pixelGroupMap) != 1L)
    stop("`pixelGroupMap` must have a single layer.")
  reqCols <- c("pixelGroup", "speciesCode", "B")
  missingCols <- setdiff(reqCols, names(cohortData))
  if (length(missingCols))
    stop("`cohortData` is missing the column(s): ", paste(missingCols, collapse = ", "), ".")
  groupNames <- c("deciduous", "pine", "larch", "spruce")
  if (!is.list(speciesGroups) || !all(groupNames %in% names(speciesGroups)))
    stop("`speciesGroups` must be a named list with the elements: ",
         paste(groupNames, collapse = ", "), ".")
  if (!is.numeric(dominanceThreshold) || length(dominanceThreshold) != 1L ||
      is.na(dominanceThreshold) || dominanceThreshold <= 0 || dominanceThreshold > 1)
    stop("`dominanceThreshold` must be a single number greater than 0 and at most 1.")
  if (length(forestClassColours) != 6L)
    stop("`forestClassColours` must have 6 colours, one per class.")
  if (!is.null(names(forestClassColours)))
    forestClassColours <- forestClassColours[as.character(1:6)]

  # Work on a small copy so the caller's cohortData is never modified
  cd <- data.table::data.table(pixelGroup = cohortData$pixelGroup,
                               speciesCode = as.character(cohortData$speciesCode),
                               B = cohortData$B)
  cd <- cd[!is.na(cd$pixelGroup) & cd$pixelGroup != 0]

  # Assign each cohort to the first species group it matches
  data.table::set(cd, j = "grp", value = NA_character_)
  for (g in groupNames) {
    hit <- grepl(paste(speciesGroups[[g]], collapse = "|"), cd$speciesCode)
    data.table::set(cd, i = which(is.na(cd$grp) & hit), j = "grp", value = g)
  }

  # Biomass per pixel group: total and by species group
  lookup <- cd[, list(totalB = sum(B, na.rm = TRUE)), by = "pixelGroup"]
  for (g in groupNames) {
    data.table::set(lookup, j = g, value = 0)
    gB <- cd[cd$grp %in% g, list(gB = sum(B, na.rm = TRUE)), by = "pixelGroup"]
    lookup[gB, on = "pixelGroup", (g) := i.gB]
  }

  # Lowest priority first, so higher-priority classes overwrite
  threshold <- dominanceThreshold * lookup$totalB * (1 - sqrt(.Machine$double.eps))
  hasB <- lookup$totalB > 0
  cls <- rep(2L, nrow(lookup))
  cls[hasB & (lookup$pine + lookup$larch + lookup$spruce) >= threshold] <- 3L
  cls[hasB & lookup$spruce >= threshold] <- 6L
  cls[hasB & lookup$larch >= threshold] <- 5L
  cls[hasB & lookup$pine >= threshold] <- 4L
  cls[hasB & lookup$deciduous >= threshold] <- 1L

  # Pixel groups on the map without cohorts are treated as non-forest
  inMap <- terra::unique(pixelGroupMap)[[1]]
  inMap <- inMap[!is.na(inMap) & inMap != 0]
  noCohorts <- setdiff(inMap, lookup$pixelGroup)
  if (length(noCohorts))
    message("classifyForestClasses: ", length(noCohorts), " pixel group(s) in `pixelGroupMap` ",
            "have no rows in `cohortData`; treated as non-forest.")

  if (nrow(lookup) > 0L) {
    out <- terra::subst(pixelGroupMap, from = lookup$pixelGroup, to = cls, others = NA)
  } else {
    out <- terra::init(pixelGroupMap, NA)
  }

  names(out) <- "forestClass"
  levels(out) <- data.frame(ID = 1:6, forestClass = defaultForestClassLabels())
  terra::coltab(out) <- data.frame(value = 1:6, col = unname(forestClassColours))
  out
}

#' Default species groups for [classifyForestClasses()]
#'
#' Regular expressions matched against LandR species codes (`speciesCode`).
#' Jack pine (`Pinu_ban`) and lodgepole pine (`Pinu_con`) form one "pine" group.
#'
#' @return a named list of character vectors with the elements `deciduous`, `pine`,
#'   `larch` and `spruce`.
#' @export
defaultForestSpeciesGroups <- function() {
  list(deciduous = c("^Popu_", "^Betu_"),
       pine = c("^Pinu_ban", "^Pinu_con"),
       larch = "^Lari_",
       spruce = "^Pice_")
}

#' Class names used by [classifyForestClasses()]
#'
#' @return a character vector of the six class names, in the order of the class codes 1 to 6.
#' @export
defaultForestClassLabels <- function() {
  c("Deciduous", "Coni-deci mix", "Conifer mix", "Pine", "Larch", "Spruce")
}

#' Default legend colours for [classifyForestClasses()]
#'
#' @return a character vector of six hex colours named `"1"` to `"6"`.
#' @export
defaultForestClassColours <- function() {
  c("1" = "#8fbf4d", "2" = "#d9d27a", "3" = "#4f9d8f",
    "4" = "#e08a2e", "5" = "#b79ad6", "6" = "#2b6a4a")
}
