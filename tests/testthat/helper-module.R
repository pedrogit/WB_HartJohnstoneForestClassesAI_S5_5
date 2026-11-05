# Source the module's R folder so the tests run without simInit.
moduleDir <- normalizePath(file.path(testthat::test_path(), "..", ".."), winslash = "/")
for (f in list.files(file.path(moduleDir, "R"), pattern = "\\.[Rr]$", full.names = TRUE))
  source(f, local = FALSE)
library(data.table)
library(terra)
scratch <- Sys.getenv("HART_TEST_OUTPUT_DIR")
if (!nzchar(scratch)) scratch <- file.path(tempdir(), "s5_5-tests")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
