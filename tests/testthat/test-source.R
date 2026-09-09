d1 <- as.POSIXct("2000-01-01", tz = "UTC")
cat3 <- data.frame(date = d1 + (0:2) * 86400,
                   fullname = sprintf("slice-%i", 1:3),
                   stringsAsFactors = FALSE)

## a slice function with an ordinary signature and no flag in sight
plain_slice <- function(date, files, offset = 0, ...) {
  i <- which(files$date == date)
  r <- terra::rast(terra::ext(0, 4, 0, 4), resolution = 1, crs = "EPSG:4326")
  terra::values(r) <- i + offset
  r
}

test_that("a source built from two plain functions satisfies the contract", {
  src <- xyt_source(plain_slice, cat3)
  out <- suppressMessages(xyt_reader_check(src))
  expect_true(all(out$ok))
  expect_true(inherits(src, "xyt_reader"))
})

test_that("a source extracts the same way a hand-written reader does", {
  src <- xyt_source(plain_slice, cat3)
  xyt <- data.frame(x = c(0.5, 0.5), y = c(0.5, 0.5), t = d1 + c(0, 2) * 86400)
  expect_equal(extract_xyt(src, xyt), c(1, 3))
  expect_equal(extract_xyt(src, xyt, ctstime = TRUE), c(1, 3))
  expect_equal(extract_xyt(src, xyt, offset = 10), c(11, 13))
})

test_that("a catalogue function is called once, not once per read", {
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  src <- xyt_source(plain_slice, function(...) {
    calls$n <- calls$n + 1L
    cat3
  })
  xyt <- data.frame(x = rep(0.5, 3), y = rep(0.5, 3), t = d1 + (0:2) * 86400)
  extract_xyt(src, xyt)
  extract_xyt(src, xyt)
  expect_equal(calls$n, 1L)
})

test_that("a catalogue handed to extract_xyt means returnfiles is never called", {
  slice_only <- function(date, inputfiles, ...) plain_slice(date, inputfiles, ...)
  refuses <- function(date, ..., returnfiles = FALSE, inputfiles = NULL) {
    if (isTRUE(returnfiles)) stop("this reader has no catalogue")
    slice_only(date, inputfiles, ...)
  }
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1 + 86400)
  expect_error(extract_xyt(refuses, xyt), "no catalogue")
  expect_equal(extract_xyt(refuses, xyt, files = cat3), 2)
})

test_that("a bad catalogue argument is refused before anything is read", {
  src <- xyt_source(plain_slice, cat3)
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_error(extract_xyt(src, xyt, files = list(date = d1)), "must be a data.frame")
  expect_error(extract_xyt(src, xyt, files = data.frame(when = d1)), "'date' column")
  expect_error(extract_xyt(src, xyt, files = cat3[c(3, 1, 2), ]), "ascending")
})

test_that("the source constructor checks what it was given", {
  expect_error(xyt_source("not a function", cat3), "'slice' must be a function")
  expect_error(xyt_source(plain_slice, "not a catalogue"), "data.frame or a function")
})
