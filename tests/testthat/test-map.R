read <- synthetic_reader()
d1 <- as.POSIXct("2000-01-01", tz = "UTC")
xyt <- data.frame(x = rep(0.5, 4), y = rep(0.5, 4), t = d1 + (0:3) * 86400)
expected <- c(51.5, 52.5, 53.5, 54.5)

test_that("the answer does not depend on the order the slices are read in", {
  backwards <- function(X, FUN) rev(lapply(rev(seq_along(X)), function(i) FUN(X[[i]])))
  expect_equal(extract_xyt(read, xyt, map = backwards), expected)

  shuffled <- function(X, FUN) {
    o <- c(3L, 1L, 2L)
    out <- vector("list", length(X))
    for (i in o[o <= length(X)]) out[[i]] <- FUN(X[[i]])
    out
  }
  expect_equal(extract_xyt(read, xyt, map = shuffled), expected)
})

test_that("the first slice is read outside the map, the rest inside it", {
  seen <- new.env(parent = emptyenv())
  seen$n <- 0L
  counting <- function(X, FUN) {
    seen$n <- length(X)
    lapply(X, FUN)
  }
  expect_equal(extract_xyt(read, xyt, map = counting), expected)
  expect_equal(seen$n, 3L)
})

test_that("a task result carries no raster, only numbers and row indices", {
  captured <- new.env(parent = emptyenv())
  capturing <- function(X, FUN) {
    out <- lapply(X, FUN)
    captured$out <- out
    out
  }
  extract_xyt(read, xyt, map = capturing)
  one <- captured$out[[1L]]
  expect_true(all(names(one) %in% c("rows_lo", "lo", "rows_hi", "hi")))
  expect_true(all(vapply(one, is.numeric, logical(1))))
})

test_that("map = FALSE and map = lapply both read serially", {
  expect_equal(extract_xyt(read, xyt, map = FALSE), expected)
  expect_equal(extract_xyt(read, xyt, map = lapply), expected)
})

test_that("a map that is not a function is refused", {
  expect_error(extract_xyt(read, xyt, map = "parallel please"),
               "must be a function")
})

test_that("the mirai map says so plainly when mirai is not installed", {
  if (requireNamespace("mirai", quietly = TRUE)) {
    expect_true(is.function(xyt_map_mirai()))
  } else {
    expect_error(xyt_map_mirai(), "mirai is not installed")
  }
})

test_that("with no daemons the default map is serial", {
  m <- .resolve_map(NULL, verbose = FALSE, total = 3L)
  expect_true(is.function(m))
  expect_equal(m(list(1, 2), function(i) i * 2), list(2, 4))
})

test_that("a single needed slice never reaches the map at all", {
  never <- function(X, FUN) stop("the map should not have been called")
  one <- data.frame(x = 0.5, y = 0.5, t = d1)
  expect_equal(extract_xyt(read, one, map = never), 51.5)
})

## The tests below actually start daemons, so they are skipped on CRAN and
## anywhere mirai is absent. They exercise the real mirai path in map.R:
## .mirai_daemons() seeing running daemons, .resolve_map() dispatching to
## them, and xyt_map_mirai() collecting results and surfacing task failures.

test_that("xyt_map_mirai runs a job across daemons and returns results", {
  skip_on_cran()
  skip_if_not_installed("mirai")

  mirai::daemons(2)
  on.exit(mirai::daemons(0), add = TRUE)

  expect_gte(.mirai_daemons(), 1L)

  m <- xyt_map_mirai()
  expect_true(is.function(m))
  expect_equal(m(1:3, function(i) i * 2), list(2, 4, 6))
})

test_that("a failing task on a daemon is reported, not swallowed", {
  skip_on_cran()
  skip_if_not_installed("mirai")

  mirai::daemons(2)
  on.exit(mirai::daemons(0), add = TRUE)

  m <- xyt_map_mirai()
  expect_error(m(1:2, function(i) stop("boom")), "failed on a mirai daemon")
})

test_that("with daemons running the default map dispatches to mirai", {
  skip_on_cran()
  skip_if_not_installed("mirai")

  mirai::daemons(2)
  on.exit(mirai::daemons(0), add = TRUE)

  m <- .resolve_map(NULL, verbose = FALSE, total = 3L)
  expect_true(is.function(m))
  expect_equal(m(1:3, function(i) i + 1L), list(2, 3, 4))
})
