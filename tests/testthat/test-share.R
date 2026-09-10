## The catalogue is captured by the task closure, so it travels to every
## daemon. mori maps it instead of copying it. What matters here is that the
## reader cannot tell the difference.

read10 <- synthetic_reader()
cat10 <- read10(returnfiles = TRUE)
have_mori <- requireNamespace("mori", quietly = TRUE)

test_that("share = FALSE leaves the catalogue alone", {
  expect_identical(xyt:::.share_catalogue(cat10, FALSE), cat10)
})

test_that("the default does not share when nothing else would read it", {
  ## no daemons running in a test run, so there is no one to map it
  out <- xyt:::.share_catalogue(cat10, NULL)
  expect_identical(out, cat10)
})

test_that("share = TRUE shares, and the content survives", {
  if (!have_mori) {
    expect_error(xyt:::.share_catalogue(cat10, TRUE), "mori")
  } else {
    out <- xyt:::.share_catalogue(cat10, TRUE)
    expect_true(mori::is_shared(out))
    expect_true(is.data.frame(out))
    expect_equal(as.data.frame(out), as.data.frame(cat10))
    ## and sharing it again is a no-op rather than a second region
    expect_true(mori::is_shared(xyt:::.share_catalogue(out, TRUE)))
  }
})

test_that("a shared catalogue gives the same answers as a plain one", {
  if (!have_mori) {
    expect_true(TRUE)
  } else {
    dense <- data.frame(x = c(0.5, 1.5, 2.5, 3.5), y = c(0.5, 1.5, 2.5, 3.5),
                        t = as.POSIXct("2000-01-01", tz = "UTC") +
                            c(0, 2, 5, 8) * 86400)
    ## the case that rules out cutting the catalogue down instead: only two of
    ## the ten slices are wanted, and they are not adjacent
    sparse <- data.frame(x = c(0.5, 2.5), y = c(0.5, 3.5),
                         t = as.POSIXct(c("2000-01-02", "2000-01-09"),
                                        tz = "UTC"))
    for (d in list(dense, sparse)) {
      for (cts in c(FALSE, TRUE)) {
        plain <- extract_xyt(read10, d, ctstime = cts, files = cat10,
                             share = FALSE, map = lapply, verbose = FALSE)
        shared <- extract_xyt(read10, d, ctstime = cts, files = cat10,
                              share = TRUE, map = lapply, verbose = FALSE)
        expect_equal(shared, plain)
      }
    }
  }
})

test_that("a shared catalogue serialises to a fraction of its size", {
  if (!have_mori) {
    expect_true(TRUE)
  } else {
    big <- data.frame(
      date = as.POSIXct("2000-01-01", tz = "UTC") + seq_len(5000) * 86400,
      fullname = sprintf("/a/reasonably/long/path/to/a/file/slice-%05i.nc",
                         seq_len(5000)),
      stringsAsFactors = FALSE)
    plain <- length(serialize(big, NULL))
    shared <- length(serialize(xyt:::.share_catalogue(big, TRUE), NULL))
    expect_true(shared < plain / 100)
  }
})
