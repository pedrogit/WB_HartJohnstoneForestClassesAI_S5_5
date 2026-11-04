test_that("the module runs alone on its synthetic inputs", {
  skip_if_not_installed("SpaDES.core")
  skip_if_not_installed("reproducible")

  outDir <- tempfile("standalone")
  dir.create(outDir)
  on.exit(unlink(outDir, recursive = TRUE), add = TRUE)

  sim <- SpaDES.core::simInit(
    modules = "WB_HartJohnstoneForestClassesAI_S5_5",
    times = list(start = 0, end = 10),
    paths = list(modulePath = normalizePath(file.path(testthat::test_path(), "..", "..", "..")),
                 outputPath = outDir)
  )
  sim <- SpaDES.core::spades(sim)

  vals <- as.vector(terra::values(sim$WB_HartJohnstoneForestClassesAIMap))
  expect_equal(vals, c(1, 2, 3, 4, 5, 6, NA, NA))
  expect_equal(sum(is.na(vals)), 2L)
})
