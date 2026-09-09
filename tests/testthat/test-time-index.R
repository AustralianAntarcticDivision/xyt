dates <- seq(as.POSIXct("2000-01-01", tz = "UTC"), by = "1 day", length.out = 5)

test_that("times are coerced without a local time zone creeping in", {
  expect_equal(.xyt_times(as.Date("2000-01-01")),
               as.POSIXct("2000-01-01", tz = "UTC"))
  expect_equal(.xyt_times("2000-01-01 06:00:00"),
               as.POSIXct("2000-01-01 06:00:00", tz = "UTC"))
  expect_error(.xyt_times(12345), "POSIXct")
})

test_that("mixed-precision character times keep their times of day", {
  ## as.POSIXct() on this vector returns two midnights: it takes the format
  ## from the first element and applies it to the rest
  x <- c("2000-01-01", "2000-01-01 06:00:00")
  expect_equal(as.numeric(diff(.xyt_times(x))), 6)
  expect_equal(.xyt_times(x)[2L],
               as.POSIXct("2000-01-01 06:00:00", tz = "UTC"))
  expect_equal(.xyt_times(c("2000-01-01 06:00", "2000-01-02T12:30:00")),
               as.POSIXct(c("2000-01-01 06:00:00", "2000-01-02 12:30:00"), tz = "UTC"))
  expect_error(.xyt_times(c("2000-01-01", "not a date")), "could not read")
})

test_that("resolution is the median spacing, not the smallest", {
  expect_equal(.time_resolution(dates), 1)
  gappy <- dates[c(1, 2, 3, 5)]
  expect_equal(.time_resolution(gappy), 1)
  expect_true(is.na(.time_resolution(dates[1])))
})

test_that("previous and nearest differ, and the default is nearest", {
  t <- as.POSIXct(c("2000-01-01 18:00:00", "2000-01-02 06:00:00"), tz = "UTC")
  expect_equal(.previous_index(t, dates), c(1L, 2L))
  expect_equal(.nearest_index(t, dates), c(2L, 2L))
  expect_equal(.slice_index(t, dates), .nearest_index(t, dates))
  expect_equal(.slice_index(t, dates, "previous"), .previous_index(t, dates))
})

test_that("indices clamp at both ends of the series", {
  t <- as.POSIXct(c("1999-01-01", "2001-01-01"), tz = "UTC")
  expect_equal(.previous_index(t, dates), c(1L, 5L))
  expect_equal(.next_index(t, dates), c(2L, 5L))
  expect_equal(.nearest_index(t, dates), c(1L, 5L))
})

test_that("proportion is a fraction of the gap and never extrapolates", {
  t <- .xyt_times(c("2000-01-01", "2000-01-01 06:00:00", "2000-01-02"))
  lo <- .previous_index(t, dates)
  hi <- .next_index(t, dates)
  expect_equal(.proportion(t, dates, lo, hi), c(0, 0.25, 0))
  outside <- as.POSIXct("2001-01-01", tz = "UTC")
  expect_equal(.proportion(outside, dates,
                           .previous_index(outside, dates),
                           .next_index(outside, dates)), 0)
})

test_that("the default tolerance follows the series", {
  expect_equal(.tolerance_days(dates), 1.5)
  monthly <- seq(as.POSIXct("2000-01-01", tz = "UTC"), by = "1 month", length.out = 6)
  expect_true(.tolerance_days(monthly) > 40)
})
