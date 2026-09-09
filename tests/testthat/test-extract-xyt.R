read <- synthetic_reader()
d1 <- as.POSIXct("2000-01-01", tz = "UTC")

## A reader that records how many times each slice was read.
counting_reader <- function(...) {
  inner <- synthetic_reader(...)
  count <- new.env(parent = emptyenv())
  count$n <- 0L
  f <- function(date, returnfiles = FALSE, ...) {
    if (!isTRUE(returnfiles)) count$n <- count$n + 1L
    inner(date, returnfiles = returnfiles, ...)
  }
  attr(f, "count") <- count
  f
}

test_that("a point lands on the cell it is in, at the slice it asks for", {
  xyt <- data.frame(x = c(0.5, 2.5), y = c(0.5, 3.5),
                    t = d1 + c(0, 4) * 86400)
  expect_equal(extract_xyt(read, xyt), c(51.5, 258.5))
  expect_equal(extract_xyt(read, xyt),
               synthetic_value(c(0.5, 2.5), c(0.5, 3.5), i = c(1, 5)))
})

test_that("the value comes from the cell, not the coordinate", {
  ## anywhere in the cell gives the cell centre's value
  xyt <- data.frame(x = c(0.01, 0.99), y = c(0.01, 0.99), t = rep(d1, 2))
  expect_equal(extract_xyt(read, xyt), c(51.5, 51.5))
})

test_that("bilinear reads the plane exactly", {
  xyt <- data.frame(x = 0.7, y = 2.2, t = d1 + 2 * 86400)
  expect_equal(extract_xyt(read, xyt, method = "bilinear"), 75.2)
  expect_equal(extract_xyt(read, xyt, method = "bilinear"),
               synthetic_value(0.7, 2.2, i = 3, method = "bilinear"))
})

test_that("nearest and previous disagree, visibly", {
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1 + 18 * 3600)
  expect_equal(extract_xyt(read, xyt, when = "nearest"), 52.5)
  expect_equal(extract_xyt(read, xyt, when = "previous"), 51.5)
})

test_that("ctstime interpolates linearly between the bracketing slices", {
  xyt <- data.frame(x = rep(0.5, 3), y = rep(0.5, 3),
                    t = d1 + c(0, 6, 12) * 3600)
  expect_equal(extract_xyt(read, xyt, ctstime = TRUE), c(51.5, 51.75, 52.0))
  expect_equal(extract_xyt(read, xyt, ctstime = TRUE),
               synthetic_value(0.5, 0.5, i = c(1, 1.25, 1.5)))
})

test_that("ctstime does not extrapolate past the ends", {
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1 - 3600)
  expect_equal(extract_xyt(read, xyt, ctstime = TRUE), 51.5)
})

test_that("every needed slice is read exactly once, whatever the row order", {
  cr <- counting_reader()
  xyt <- data.frame(x = rep(0.5, 6), y = rep(0.5, 6),
                    t = d1 + c(0, 0, 1, 1, 2, 2) * 86400)
  v <- extract_xyt(cr, xyt)
  expect_equal(v, rep(c(51.5, 52.5, 53.5), each = 2))
  expect_equal(attr(cr, "count")$n, 3L)

  cr2 <- counting_reader()
  shuffled <- xyt[c(5, 2, 6, 1, 4, 3), ]
  expect_equal(extract_xyt(cr2, shuffled), v[c(5, 2, 6, 1, 4, 3)])
  expect_equal(attr(cr2, "count")$n, 3L)
})

test_that("ctstime reads each slice once, not once per interval", {
  cr <- counting_reader()
  xyt <- data.frame(x = rep(0.5, 3), y = rep(0.5, 3),
                    t = d1 + c(0.5, 1.5, 2.5) * 86400)
  extract_xyt(cr, xyt, ctstime = TRUE)
  ## slices 1..4 bracket those three times
  expect_equal(attr(cr, "count")$n, 4L)
})

test_that("dots reach the reader and nothing else", {
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_equal(extract_xyt(read, xyt, offset = 1000), 1051.5)

  ## a reader with no dots of its own proves where the dots went: an argument
  ## meant for the extraction would be an error here, and is not offered
  strict <- function(date, returnfiles = FALSE, inputfiles = NULL) {
    if (isTRUE(returnfiles)) return(read(returnfiles = TRUE))
    read(date, inputfiles = inputfiles)
  }
  inner <- data.frame(x = 1.5, y = 1.5, t = d1)
  expect_equal(extract_xyt(strict, inner, method = "bilinear", ctstime = FALSE,
                           when = "nearest", tolerance = 2, verbose = FALSE),
               152.5)
  expect_error(extract_xyt(strict, xyt, offset = 1000), "unused argument")
})

test_that("fact aggregates the slice before extracting", {
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_equal(extract_xyt(read, xyt, fact = 2), 102)
})

test_that("points too far from any slice come back NA, with a warning", {
  xyt <- data.frame(x = c(0.5, 0.5), y = c(0.5, 0.5),
                    t = d1 + c(0, 60) * 86400)
  expect_warning(v <- extract_xyt(read, xyt), "more than")
  expect_equal(v, c(51.5, NA_real_))
})

test_that("tolerance can be widened by hand", {
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1 + 60 * 86400)
  expect_equal(extract_xyt(read, xyt, tolerance = 100), 60.5)
})

test_that("coordinates are transformed into the raster's system", {
  merc <- synthetic_reader(crs = "EPSG:3857", extent = c(0, 4e5, 0, 4e5), res = 1e5)
  ## a point given in longitude and latitude, whose projected position is known
  ll <- terra::project(cbind(50000, 50000), from = "EPSG:3857", to = "EPSG:4326")
  xyt <- data.frame(x = ll[1, 1], y = ll[1, 2], t = d1)
  expect_equal(extract_xyt(merc, xyt), 100 * 50000 + 50000 + 1)
})

test_that("input shape is checked before anything is read", {
  expect_error(extract_xyt(read, data.frame(x = 1, y = 2)), "three columns")
  expect_error(extract_xyt(read, data.frame(x = "a", y = "b", t = d1)), "numeric")
  expect_error(extract_xyt("not a function", data.frame(x = 1, y = 1, t = d1)),
               "must be a function")
  expect_error(extract_xyt(read, data.frame(x = numeric(0), y = numeric(0),
                                            t = as.POSIXct(character(0), tz = "UTC"))),
               "no rows")
})

test_that("a matrix is accepted as well as a data.frame", {
  m <- cbind(x = 0.5, y = 0.5, t = as.numeric(d1))
  ## numeric time is refused: there is no honest guess at the epoch
  expect_error(extract_xyt(read, m), "POSIXct")
})

test_that("a multi-layer slice is refused with an actionable message", {
  two_layer <- function(date, returnfiles = FALSE, inputfiles = NULL, ...) {
    if (isTRUE(returnfiles)) return(read(returnfiles = TRUE))
    r <- read(date, inputfiles = inputfiles)
    c(r, r)
  }
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_error(extract_xyt(two_layer, xyt), "selects one")
})

test_that("a badly shaped catalogue is caught at the catalogue call", {
  no_date <- function(date, returnfiles = FALSE, ...) {
    if (isTRUE(returnfiles)) return(data.frame(when = Sys.time()))
    read(date, ...)
  }
  not_a_frame <- function(date, returnfiles = FALSE, ...) {
    if (isTRUE(returnfiles)) return(list(date = Sys.time()))
    read(date, ...)
  }
  xyt <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_error(extract_xyt(no_date, xyt), "'date' column")
  expect_error(extract_xyt(not_a_frame, xyt), "data.frame")
})
