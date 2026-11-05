# Run the module tests from any working directory. Set HART_TEST_OUTPUT_DIR to a disposable
# directory for test outputs; otherwise a session temporary directory is used.
local({
  sourceFiles <- Filter(function(path) is.character(path) && length(path) == 1L,
                        lapply(sys.frames(), function(frame) frame$ofile))
  if (!length(sourceFiles)) stop("Run this file with source().")
  testDir <- normalizePath(dirname(tail(sourceFiles, 1L)[[1L]]), winslash = "/")
  testthat::test_dir(file.path(testDir, "testthat"), stop_on_failure = TRUE)
})
