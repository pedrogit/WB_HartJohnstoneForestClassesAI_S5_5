# Each pixel group is one pixel, so the map is a 1 x N raster of pixel group ids.
makeMap <- function(ids) {
  r <- terra::rast(nrows = 1, ncols = length(ids), xmin = 0, xmax = length(ids), ymin = 0, ymax = 1,
                   crs = "EPSG:3347")
  terra::values(r) <- ids
  r
}

makeCohorts <- function(...) {
  data.table::rbindlist(list(...), use.names = TRUE)
}

coh <- function(pg, sp, B) data.table::data.table(pixelGroup = pg, speciesCode = sp, B = B)

test_that("each class is assigned from biomass shares", {
  cd <- makeCohorts(
    coh(1L, c("Popu_tre", "Pice_mar"), c(700, 300)),            # deciduous 70%
    coh(2L, c("Popu_tre", "Pice_mar", "Pinu_con"), c(400, 300, 300)), # nothing dominant, conifer 60%
    coh(3L, c("Pice_mar", "Pinu_con", "Lari_lar"), c(350, 350, 300)), # conifer 100%, none >= 66%
    coh(4L, c("Pinu_ban", "Pinu_con", "Pice_mar"), c(400, 300, 300)), # pine 70%
    coh(5L, c("Lari_lar", "Pice_mar"), c(800, 200)),            # larch 80%
    coh(6L, c("Pice_mar", "Pice_gla", "Popu_tre"), c(500, 300, 200)) # spruce 80%
  )
  out <- classifyForestClasses(cd, makeMap(1:6))
  expect_s4_class(out, "SpatRaster")
  expect_equal(as.integer(terra::values(out)), c(1L, 2L, 3L, 4L, 5L, 6L))
})

test_that("a share of exactly 66% is dominant", {
  cd <- coh(1L, c("Popu_tre", "Pice_mar"), c(66, 34))
  expect_equal(as.integer(terra::values(classifyForestClasses(cd, makeMap(1L)))), 1L)
  cd <- coh(1L, c("Popu_tre", "Pice_mar"), c(65, 35))
  expect_equal(as.integer(terra::values(classifyForestClasses(cd, makeMap(1L)))), 2L)
})

test_that("non-forest is pixelGroupMap 0 or NA only", {
  cd <- coh(1L, "Pice_mar", 100)
  out <- classifyForestClasses(cd, makeMap(c(0L, NA, 1L)))
  expect_equal(as.integer(terra::values(out)), c(NA, NA, 6L))
})

test_that("a forest pixel with no group biomass is class 2", {
  cd <- makeCohorts(coh(1L, "Pice_mar", 0), coh(2L, "Abie_bal", 100))
  out <- classifyForestClasses(cd, makeMap(1:2))
  expect_equal(as.integer(terra::values(out)), c(2L, 2L))
})

test_that("pixel groups without cohorts are non-forest and reported", {
  cd <- coh(1L, "Pice_mar", 100)
  expect_message(out <- classifyForestClasses(cd, makeMap(c(1L, 9L))), "no rows in `cohortData`")
  expect_equal(as.integer(terra::values(out)), c(6L, NA))
})

test_that("the result carries class names and colours, and cohortData is not modified", {
  cd <- coh(1L, "Pice_mar", 100)
  cdBefore <- data.table::copy(cd)
  out <- classifyForestClasses(cd, makeMap(1L))
  expect_equal(terra::levels(out)[[1]][[2]], defaultForestClassLabels())
  expect_true(terra::has.colors(out))
  expect_equal(cd, cdBefore)
})

test_that("bad inputs stop early", {
  expect_error(classifyForestClasses(coh(1L, "Pice_mar", 1), "x"), "SpatRaster")
  expect_error(classifyForestClasses(data.table::data.table(pixelGroup = 1L), makeMap(1L)), "missing the column")
  expect_error(classifyForestClasses(coh(1L, "Pice_mar", 1), makeMap(1L), dominanceThreshold = 2), "dominanceThreshold")
})

test_that("the written GeoTIFF keeps colours and class names without a sidecar", {
  cd <- makeCohorts(coh(1L, "Popu_tre", 100), coh(2L, "Pice_mar", 100))
  out <- classifyForestClasses(cd, makeMap(1:2))
  f <- tempfile(fileext = ".tif")
  writeForestClassRaster(out, f)
  expect_false(file.exists(paste0(f, ".aux.xml")))
  back <- terra::rast(f)
  expect_true(terra::has.colors(back))
  tags <- terra::metags(back)
  expect_equal(unname(tags[tags[, 1] == "class_6", 2]), "Spruce")

  f2 <- tempfile(fileext = ".tif")
  writeForestClassRaster(out, f2, sidecar = TRUE)
  expect_true(file.exists(paste0(f2, ".aux.xml")))
  expect_equal(terra::levels(terra::rast(f2))[[1]][[2]][1:6], defaultForestClassLabels())
})
