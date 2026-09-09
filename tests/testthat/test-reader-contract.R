test_that("the synthetic reader satisfies its own contract", {
  out <- suppressMessages(xyt_reader_check(synthetic_reader()))
  expect_true(all(out$ok))
  expect_true(all(c("check", "ok", "note") %in% names(out)))
})

test_that("a reader that ignores the date is caught", {
  frozen <- function(date, returnfiles = FALSE, inputfiles = NULL, ...) {
    inner <- synthetic_reader()
    if (isTRUE(returnfiles)) return(inner(returnfiles = TRUE))
    inner(as.POSIXct("2000-01-01", tz = "UTC"))
  }
  out <- suppressMessages(xyt_reader_check(frozen, error = FALSE))
  expect_false(all(out$ok))
  expect_false(out$ok[out$check == "the two slices differ in value"])
})

test_that("a reader with the wrong catalogue is caught, and stops by default", {
  bad <- function(date, returnfiles = FALSE, ...) {
    if (isTRUE(returnfiles)) return(data.frame(when = Sys.time()))
    synthetic_reader()(date)
  }
  expect_error(suppressMessages(xyt_reader_check(bad)), "does not satisfy")
  out <- suppressMessages(xyt_reader_check(bad, error = FALSE))
  expect_false(all(out$ok))
})

test_that("a reader that is not a function is caught first", {
  out <- suppressMessages(xyt_reader_check("nope", error = FALSE))
  expect_equal(nrow(out), 1L)
  expect_false(out$ok)
})
