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
