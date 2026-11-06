makeMap <- function(ids) {
  rast(nrows = 1, ncols = length(ids), xmin = 0, xmax = length(ids), ymin = 0, ymax = 1,
       crs = "EPSG:3347", vals = ids)
}

# One pixel group per set of (species, share); shares sum to 1
classifyShares <- function(species, shares, ...) {
  cd <- data.table(pixelGroup = 1L, speciesCode = factor(species), B = shares)
  as.vector(values(classifyForestClasses(cd, makeMap(1L), ...)))
}

test_that("defaults match the original module", {
  f <- formals(classifyForestClasses)
  expect_identical(eval(f$jackPineSp), "Pinu_ban")
  expect_identical(eval(f$larchSp), "Lari")
  expect_identical(eval(f$spruceSp), "Pice")
  expect_identical(eval(f$otherConiferSp),
                   c("Abie", "Calc", "Cham", "Juni", "Pinu", "Pseu", "Sequ", "Taxu", "Thuj", "Tsug"))
  expect_null(f$classificationTablePath)
  expect_identical(names(f)[1:6], c("cohortData", "pixelGroupMap", "jackPineSp", "larchSp",
                                    "spruceSp", "classificationTablePath"))
})

test_that("synthetic inputs cover the six classes and the result carries its legend", {
  s <- syntheticForestInputs()
  out <- classifyForestClasses(s$cohortData, s$pixelGroupMap)
  expect_equal(as.vector(values(out)), c(1:6, NA, NA))
  expect_equal(names(out), "standtype")
  expect_equal(varnames(out), "standtype")
  expect_equal(cats(out)[[1]][[2]], c("deci", "mixed", "conimix", "jackpine", "larch", "spruce"))
  expect_equal(unname(unlist(coltab(out)[[1]][1:6, 1])), 1:6)
})

test_that("thresholds are 2/3 for jack pine, spruce and deciduous, and 0.75 for larch, all inclusive", {
  below <- 2/3 - 1e-8; above <- 2/3 + 1e-8
  expect_equal(classifyShares(c("Pinu_ban", "Popu_tre"), c(2/3, 1/3)), 4)
  expect_equal(classifyShares(c("Pinu_ban", "Popu_tre"), c(below, 1 - below)), 2)
  expect_equal(classifyShares(c("Pice_mar", "Popu_tre"), c(above, 1 - above)), 6)
  expect_equal(classifyShares(c("Lari_lar", "Popu_tre"), c(.70, .30)), 3)
  expect_equal(classifyShares(c("Lari_lar", "Popu_tre"), c(.75, .25)), 5)
  expect_equal(classifyShares(c("Lari_lar", "Pice_mar"), c(.70, .30)), 3)
  expect_equal(classifyShares(c("Popu_tre", "Pice_mar"), c(above, 1 - above)), 1)
  expect_equal(classifyShares(c("Popu_tre", "Pice_mar"), c(.66, .34)), 2)
  expect_equal(classifyShares(c("Popu_tre", "Pice_mar"), c(.67, .33)), 1)
  # Exactly on the deciduous boundary: the non-conifer share 1 - (1 - 2/3) equals 2/3 in
  # floating point, and the inclusive rule (Appendix S3: >= 66% broadleaf) gives deci, not mixed.
  expect_equal(classifyShares(c("Abie_bal", "Popu_tre"), c(1 - 2/3, 2/3)), 1)
  # Just below the boundary the stand is mixed.
  expect_equal(classifyShares(c("Abie_bal", "Popu_tre"), c(1 - 2/3 + 1e-8, 2/3 - 1e-8)), 2)
})

test_that("only Pinu_ban is jack pine by default; other pines and fir are other conifers", {
  expect_equal(classifyShares("Pinu_con", 1), 3)
  expect_equal(classifyShares("Abie_bal", 1), 3)
  expect_equal(classifyShares("Pinu_con", 1, jackPineSp = "Pinu"), 4)
  expect_equal(classifyShares("Abie_bal", 1, otherConiferSp = character(0)), 1)
})

test_that("matching is literal, case-insensitive and first group wins", {
  expect_equal(classifyShares("PICE_mar", 1), 6)
  expect_equal(classifyShares("Pice_mar", 1, spruceSp = "Pice.*"), 1)
  expect_equal(classifyShares("Pice_mar", 1, jackPineSp = "P", larchSp = "P", spruceSp = "P"), 4)
  expect_equal(classifyShares("Unknown", 1), 1)
  expect_equal(classifyShares("Pice_mar", 1, spruceSp = character(0)), 1)
})

test_that("invalid prefixes and non-factor species codes are rejected", {
  expect_error(classifyShares("Pice_mar", 1, larchSp = NA_character_), "larchSp")
  expect_error(classifyShares("Pice_mar", 1, spruceSp = " Pice"), "spruceSp")
  expect_error(classifyShares("Pice_mar", 1, otherConiferSp = ""), "otherConiferSp")
  expect_error(classifyForestClasses(data.table(pixelGroup = 1L, speciesCode = "Pice_mar", B = 1),
                                     makeMap(1L)), "factor")
})

test_that("zero ids with cohorts are classified, ids without cohorts and NA are NA, zero totals are mixed", {
  cd <- data.table(pixelGroup = c(0L, 1L, 2L), speciesCode = factor(c("Pice_mar", "Pice_mar", "Pice_mar")),
                   B = c(100, 0, 50))
  out <- classifyForestClasses(cd, makeMap(c(0L, 1L, 2L, 9L, NA)))
  expect_equal(as.vector(values(out)), c(6, 2, 6, NA, NA))
  empty <- classifyForestClasses(cd[0], makeMap(1:2))
  expect_true(all(is.na(values(empty))))
})

test_that("inputs are not modified and malformed input is rejected", {
  cd <- data.table(pixelGroup = 1L, speciesCode = factor("Pice_mar"), B = 100)
  before <- copy(cd); map <- makeMap(1L); mv <- values(map)
  classifyForestClasses(cd, map)
  expect_identical(cd, before)
  expect_identical(values(map), mv)
  expect_error(classifyForestClasses(cd, "x"), "SpatRaster")
  expect_error(classifyForestClasses(data.table(pixelGroup = 1L), makeMap(1L)), "must contain")
  expect_error(classifyForestClasses(copy(cd)[, B := -1], makeMap(1L)), "nonnegative")
  expect_error(classifyForestClasses(copy(cd)[, B := NA_real_], makeMap(1L)), "finite")
})

test_that("the optional CSV has the original columns and truncated percentages", {
  cd <- data.table(pixelGroup = 1L, speciesCode = factor(c("Pice_mar", "Popu_tre")), B = c(70, 30))
  f <- file.path(scratch, "s5-table", "table.csv")
  classifyForestClasses(cd, makeMap(1L), classificationTablePath = f)
  lines <- readLines(f)
  expect_equal(lines[1], ",pixelGroup,B,jackPinePct,larchPct,sprucePct,otherConiferPct,coniferPct,classInt,classText")
  expect_equal(lines[2], "1,1,100,0,0,70,0,70,6,spruce")
})

test_that("the written GeoTIFF keeps colours and class names, and refuses to overwrite", {
  s <- syntheticForestInputs()
  out <- classifyForestClasses(s$cohortData, s$pixelGroupMap)
  dir.create(file.path(scratch, "s5-write"), showWarnings = FALSE)
  f <- file.path(scratch, "s5-write", paste0("w", as.integer(Sys.time()), ".tif"))
  writeForestClassRaster(out, f)
  expect_false(file.exists(paste0(f, ".aux.xml")))
  back <- rast(f)
  expect_true(has.colors(back))
  tags <- metags(back)
  expect_equal(unname(tags[tags[, 1] == "class_6", 2]), "spruce")
  expect_error(writeForestClassRaster(out, f), "refusing to overwrite")
  f2 <- sub("\\.tif$", "_side.tif", f)
  writeForestClassRaster(out, f2, sidecar = TRUE)
  expect_true(file.exists(paste0(f2, ".aux.xml")))
})
