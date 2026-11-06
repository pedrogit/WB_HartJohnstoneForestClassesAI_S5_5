#' Classify LandR forest communities using relative cohort biomass
#'
#' Uses the same six-class biomass rules as the original WB_HartJohnstoneForestClasses
#' module, without the drainage refinement. Species groups use case-insensitive literal
#' prefixes; each cohort belongs to the first matching group (jack pine, larch, spruce,
#' other conifer), otherwise to the residual non-conifer group.
#'
#' Classes, tested in this order on the aggregate biomass of each pixel group:
#' \enumerate{
#'   \item `4` jackpine: jack pine share >= 2/3.
#'   \item `5` larch: larch share >= 0.75.
#'   \item `6` spruce: spruce share >= 2/3.
#'   \item `3` conimix: the four conifer groups together >= 2/3.
#'   \item `1` deci: `1 - conifer share >= 2/3` (the non-conifer share; inclusive boundary).
#'   \item `2` mixed: everything else, including groups with no biomass.
#' }
#'
#' @param cohortData A data.frame/data.table with `pixelGroup`, `speciesCode` (a factor)
#'   and nonnegative finite `B`. Not modified.
#' @param pixelGroupMap Single-layer terra SpatRaster of integer community IDs. IDs
#'   without cohorts become NA; zero is a valid group ID.
#' @param jackPineSp,larchSp,spruceSp,otherConiferSp Literal species prefixes. An empty
#'   character vector matches nothing.
#' @param classificationTablePath Optional CSV summary destination.
#' @return A categorical SpatRaster with codes 1:6, six labels and a colour table, named
#'   `standtype`. The CSV is written only when requested.
#' @export
classifyForestClasses <- function(
    cohortData, pixelGroupMap, jackPineSp = c("Pinu_ban"),
    larchSp = c("Lari"), spruceSp = c("Pice"), classificationTablePath = NULL,
    otherConiferSp = c("Abie", "Calc", "Cham", "Juni", "Pinu", "Pseu", "Sequ", "Taxu", "Thuj", "Tsug")) {
  if (!inherits(pixelGroupMap, "SpatRaster") || terra::nlyr(pixelGroupMap) != 1L) {
    stop("pixelGroupMap must be a single-layer terra SpatRaster.")
  }
  required <- c("pixelGroup", "speciesCode", "B")
  if (!is.data.frame(cohortData) || !all(required %in% names(cohortData))) {
    stop("cohortData must contain pixelGroup, speciesCode and B columns.")
  }
  if (!terra::hasValues(pixelGroupMap)) stop("pixelGroupMap has no cell values.")
  ids <- as.numeric(terra::unique(pixelGroupMap)[[1L]])
  ids <- ids[!is.na(ids)]
  if (any(!is.finite(ids) | ids < 0 | ids != trunc(ids))) {
    stop("pixelGroupMap IDs must be nonnegative finite integers or NA.")
  }
  dt <- data.table::copy(data.table::as.data.table(cohortData))
  if (!is.factor(dt$speciesCode)) stop("`speciesCode` must be a factor.")
  if (!is.numeric(dt$pixelGroup) || any(!is.finite(dt$pixelGroup) |
      dt$pixelGroup < 0 | dt$pixelGroup != trunc(dt$pixelGroup))) {
    stop("cohortData pixelGroup IDs must be nonnegative finite integers.")
  }
  if (!is.numeric(dt$B) || any(!is.finite(dt$B) | dt$B < 0)) {
    stop("cohortData B must be finite, nonnegative numeric biomass.")
  }
  prefixMatch <- function(prefixes, parameterName) {
    if (!is.character(prefixes) || anyNA(prefixes) ||
        any(!nzchar(trimws(prefixes)) | trimws(prefixes) != prefixes)) {
      stop("`", parameterName, "` must be a character vector of nonblank prefixes without surrounding whitespace.")
    }
    codes <- levels(dt$speciesCode)
    matching <- rep(FALSE, length(codes))
    for (prefix in unique(tolower(prefixes))) {
      matching <- matching | startsWith(tolower(codes), prefix)
    }
    dt$speciesCode %in% codes[matching]
  }
  # Validate every parameter even if an earlier group matches all cohorts.
  jackPine <- prefixMatch(jackPineSp, "jackPineSp")
  larch <- prefixMatch(larchSp, "larchSp")
  spruce <- prefixMatch(spruceSp, "spruceSp")
  otherConifer <- prefixMatch(otherConiferSp, "otherConiferSp")
  dt[, speciesNb := data.table::fcase(
    jackPine, 1, larch, 2, spruce, 3, otherConifer, 4, default = 5)]
  totals <- dt[, list(
    totB = sum(B), jackPineTotB = sum(B[speciesNb == 1]),
    larchTotB = sum(B[speciesNb == 2]), spruceTotB = sum(B[speciesNb == 3]),
    otherConiferTotB = sum(B[speciesNb == 4])), by = pixelGroup]
  totals[, coniferTotB := jackPineTotB + larchTotB + spruceTotB + otherConiferTotB]
  # Expression order and boundaries are identical to the original module. Every dominance
  # rule is inclusive (>=), including deciduous (the non-conifer share), as in Appendix S3 of
  # Greuel et al. (2021, after Hart et al. 2019). Before 2026-11-06 deciduous used a strict ">".
  totals[, class := data.table::fcase(
    jackPineTotB / totB >= 2/3, 4L, larchTotB / totB >= 0.75, 5L,
    spruceTotB / totB >= 2/3, 6L, coniferTotB / totB >= 2/3, 3L,
    1 - coniferTotB / totB >= 2/3, 1L, default = 2L)]
  labels <- defaultForestClassLabels()
  if (!is.null(classificationTablePath)) {
    dir.create(dirname(classificationTablePath), recursive = TRUE, showWarnings = FALSE)
    summary <- totals[, list(
      pixelGroup = pixelGroup, B = totB,
      jackPinePct = as.integer(jackPineTotB / totB * 100),
      larchPct = as.integer(larchTotB / totB * 100),
      sprucePct = as.integer(spruceTotB / totB * 100),
      otherConiferPct = as.integer(otherConiferTotB / totB * 100),
      coniferPct = as.integer(coniferTotB / totB * 100),
      classInt = class, classText = factor(class, levels = 1:6, labels = labels))]
    utils::write.csv(summary, classificationTablePath, quote = FALSE)
  }
  if (nrow(totals)) {
    lookup <- as.matrix(totals[, c("pixelGroup", "class"), with = FALSE])
    result <- terra::classify(pixelGroupMap, lookup, others = NA)
  } else {
    result <- terra::init(terra::rast(pixelGroupMap), NA_real_)
  }
  levels(result) <- data.frame(ID = 1:6, class = labels)
  terra::coltab(result) <- cbind(ID = 1:6, col = unname(defaultForestClassColours()))
  names(result) <- "standtype"
  terra::varnames(result) <- "standtype"
  result
}

#' Class names used by [classifyForestClasses()]
#'
#' @return the six class names, in the order of the class codes 1 to 6.
#' @export
defaultForestClassLabels <- function() {
  c("deci", "mixed", "conimix", "jackpine", "larch", "spruce")
}

#' Legend colours used by [classifyForestClasses()]
#'
#' @return six hex colours named `"1"` to `"6"`, the same as the original module.
#' @export
defaultForestClassColours <- function() {
  c("1" = "#66c2a5", "2" = "#fc8d62", "3" = "#8da0cb",
    "4" = "#e78ac3", "5" = "#a6d854", "6" = "#ffd92f")
}
