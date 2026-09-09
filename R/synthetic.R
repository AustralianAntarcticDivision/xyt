#' A reader function with no data behind it
#'
#' Builds a reader that satisfies the contract [extract_xyt()] expects, over
#' a small in-memory series whose values are known in closed form. It exists
#' so the extraction machinery can be exercised, and its answers checked
#' against arithmetic, without any files, network or credentials.
#'
#' Each slice holds the value
#'
#' \preformatted{   value = 100 * x + y + i }
#'
#' where `x` and `y` are the coordinates of the cell centre and `i` is the
#' one-based position of the slice in the series. Two properties follow, and
#' both are used in the tests. The field is linear in `x` and `y`, so
#' `method = "bilinear"` returns `100 * x + y + i` exactly anywhere in the
#' interior. And it is linear in `i`, so `ctstime = TRUE` at a fraction `p`
#' between slices `i` and `i + 1` returns exactly `100 * x + y + i + p`.
#'
#' @param n number of time slices.
#' @param start date-time of the first slice.
#' @param by spacing between slices, as understood by [seq.POSIXt()].
#' @param crs coordinate reference system of the slices.
#' @param extent extent of the slices, as xmin, xmax, ymin, ymax.
#' @param res cell size.
#'
#' @return a function of the form `read(date, returnfiles = FALSE,
#'   inputfiles = NULL, offset = 0, ...)`. `offset` is added to every value,
#'   and is there so a test can prove that `...` reaches the reader.
#'
#' @examples
#' read <- synthetic_reader()
#' head(read(returnfiles = TRUE))
#' read(as.POSIXct("2000-01-03", tz = "UTC"))
#' @export
synthetic_reader <- function(n = 10L,
                             start = "2000-01-01",
                             by = "1 day",
                             crs = "EPSG:4326",
                             extent = c(0, 4, 0, 4),
                             res = 1) {
  dates <- seq(as.POSIXct(start, tz = "UTC"), by = by, length.out = n)
  files <- data.frame(date = dates,
                      fullname = sprintf("synthetic-%03i", seq_len(n)),
                      stringsAsFactors = FALSE)

  function(date, returnfiles = FALSE, inputfiles = NULL, offset = 0, ...) {
    if (isTRUE(returnfiles)) return(files)
    f <- if (is.null(inputfiles)) files else inputfiles
    if (missing(date)) date <- max(f$date)
    date <- .xyt_times(date, "date")[1L]
    i <- which.min(abs(as.numeric(difftime(date, f$date, units = "days"))))

    r <- terra::rast(terra::ext(extent), resolution = res, crs = crs)
    xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
    terra::values(r) <- 100 * xy[, 1L] + xy[, 2L] + i + offset
    names(r) <- format(f$date[i], "%Y-%m-%d")
    terra::time(r) <- f$date[i]
    r
  }
}

#' Value of the synthetic series, computed directly
#'
#' The closed form of what [synthetic_reader()] holds, for writing expected
#' values in tests without going through a raster.
#'
#' @param x,y coordinates. For `method = "simple"` these are snapped to the
#'   containing cell centre; for `"bilinear"` they are used as given.
#' @param i slice number, one-based. May be fractional, which is what
#'   `ctstime = TRUE` returns.
#' @param method `"simple"` or `"bilinear"`.
#' @param res cell size of the series.
#' @param origin lower left corner of the series.
#'
#' @return a numeric vector.
#' @examples
#' synthetic_value(0.7, 2.2, i = 3)
#' synthetic_value(0.7, 2.2, i = 3, method = "bilinear")
#' @export
synthetic_value <- function(x, y, i, method = c("simple", "bilinear"),
                            res = 1, origin = c(0, 0)) {
  method <- match.arg(method)
  if (identical(method, "simple")) {
    x <- origin[1L] + (floor((x - origin[1L]) / res) + 0.5) * res
    y <- origin[2L] + (floor((y - origin[2L]) / res) + 0.5) * res
  }
  100 * x + y + i
}
