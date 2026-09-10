#' Extract values from a raster time series at points in space and time
#'
#' Each row of `xyt` is a location and a date-time. The value returned for it
#' is read from the time slice nearest that date-time, or, with
#' `ctstime = TRUE`, interpolated linearly between the two slices that bracket
#' it.
#'
#' Only the slices that some point actually needs are read, and each of those
#' is read exactly once.
#'
#' @param read a reader function. See the reader contract in [xyt],
#'   [xyt_reader_check()] and [xyt_source()].
#' @param xyt a data.frame or matrix with three columns: x, y and time. Extra
#'   columns are ignored. The time column may be POSIXct, Date or character.
#' @param ctstime interpolate linearly in time between bracketing slices
#'   (`TRUE`), or take the value from one slice (`FALSE`, the default).
#' @param when which slice a point takes its value from when
#'   `ctstime = FALSE`: the closest in time (`"nearest"`, the default) or the
#'   most recent one at or before it (`"previous"`).
#' @param method how the value is taken from the raster: `"simple"` for the
#'   value of the cell the point falls in, `"bilinear"` for a distance
#'   weighted average of the four nearest cell centres.
#' @param fact optional aggregation factor applied to each slice before
#'   extraction, as in [terra::aggregate()]. One integer, or two for the
#'   horizontal and vertical factors.
#' @param crs coordinate reference system of the coordinates in `xyt`,
#'   defaulting to longitude/latitude on WGS84. Points are transformed to the
#'   raster's own system before extraction.
#' @param files the catalogue, if you already have it: a data.frame with a
#'   `date` column. Supplied here, `read(returnfiles = TRUE)` is never called,
#'   so a reader only has to do the one job of reading a slice. See also
#'   [xyt_source()].
#' @param share put the catalogue into shared memory with
#'   [mori::share()], so that it is mapped by the daemons rather than copied
#'   to each of them. `NULL`, the default, does it when mori is installed and
#'   mirai daemons are running, and otherwise leaves the catalogue alone.
#'   `TRUE` insists, `FALSE` refuses.
#' @param tolerance how far, in days, a point may sit from the slice matched
#'   to it before its value is refused and returned as `NA`. `NULL`, the
#'   default, derives it from the spacing of the series.
#' @param map how the per-slice reads are run. `NULL`, the default, uses
#'   mirai daemons if any are running and reads serially otherwise. Pass
#'   [base::lapply()] to force serial, or see [xyt_map_mirai()].
#' @param verbose report progress as slices are read.
#' @param ... passed to `read`, and only to `read`.
#'
#' @return a numeric vector with one value per row of `xyt`.
#'
#' @details
#' `...` reaches the reader alone. This is a deliberate departure from the
#' version of this code that lived in raadtools, where `...` was passed to
#' both the reader and the extraction, so that an argument meant for one was
#' silently offered to the other. Arguments controlling the extraction are
#' named here instead.
#'
#' @examples
#' read <- synthetic_reader()
#' xyt <- data.frame(x = c(0.5, 2.5), y = c(0.5, 3.5),
#'                   t = as.POSIXct(c("2000-01-01", "2000-01-05"), tz = "UTC"))
#' extract_xyt(read, xyt)
#' extract_xyt(read, xyt, ctstime = TRUE)
#' @export
extract_xyt <- function(read, xyt,
                        ctstime = FALSE,
                        when = c("nearest", "previous"),
                        method = c("simple", "bilinear"),
                        fact = NULL,
                        crs = "EPSG:4326",
                        files = NULL,
                        share = NULL,
                        tolerance = NULL,
                        map = NULL,
                        verbose = interactive(),
                        ...) {
  if (!is.function(read)) stop("'read' must be a function", call. = FALSE)
  when <- match.arg(when)
  method <- match.arg(method)
  dots <- list(...)

  input <- .xyt_input(xyt)
  xy <- input$xy
  times <- input$times
  n <- nrow(xy)

  files <- if (is.null(files)) .catalogue(read, dots) else .check_catalogue(files)
  dates <- .xyt_times(files$date, "catalogue dates")

  if (is.null(tolerance)) tolerance <- .tolerance_days(dates)

  if (ctstime) {
    lo <- .previous_index(times, dates)
    hi <- .next_index(times, dates)
    p <- .proportion(times, dates, lo, hi)
    ## tolerance is judged against the closer of the two bracketing slices
    keep <- .tolerance_mask(times, dates, .nearest_index(times, dates), tolerance)
    needed <- sort(unique(c(lo[keep], hi[keep])))
  } else {
    lo <- .slice_index(times, dates, when)
    hi <- lo
    p <- rep(0, n)
    keep <- .tolerance_mask(times, dates, lo, tolerance)
    needed <- sort(unique(lo[keep]))
  }

  v_lo <- rep(NA_real_, n)
  v_hi <- rep(NA_real_, n)
  if (length(needed) < 1L) return(v_lo)

  ## which rows each slice owes a value to, decided once, up front, so a task
  ## depends on nothing but its own slice number
  rows_lo <- lapply(needed, function(j) which(keep & lo == j))
  rows_hi <- lapply(needed, function(j) which(keep & hi == j & p > 0))

  ## The first slice is read here rather than in a task. It gives the target
  ## coordinate system, which every other task needs, and it fails fast: a
  ## reader that is going to raise is better raising once than in every
  ## daemon at once.
  if (verbose) message(sprintf("reading slice 1 of %i", length(needed)))
  r1 <- .read_slice(read, dates[needed[1L]], files, fact, dots)
  xy_target <- .to_crs(xy, from = crs, to = terra::crs(r1))
  first <- .slice_values(r1, xy_target, rows_lo[[1L]], rows_hi[[1L]], method)
  rm(r1)

  rest <- seq_along(needed)[-1L]
  if (length(rest) > 0L) {
    map <- .resolve_map(map, verbose, length(needed))
    ## Everything this closure captures is sent with every task, and the
    ## catalogue is the big part of it: a 16000-row raadfiles catalogue of
    ## long paths serialises to about 3.2 MB, once per slice. Shared, it
    ## serialises to its name and the daemons map the same pages.
    ##
    ## The reader still receives the same catalogue, with the same rows in the
    ## same order. That is the point of doing it this way rather than cutting
    ## the catalogue down to the slices being read: a reader is entitled to
    ## look at more of it than the row it matched, and xyt's own
    ## synthetic_reader() does exactly that.
    files <- .share_catalogue(files, share)
    task <- function(k) {
      r <- .read_slice(read, dates[needed[k]], files, fact, dots)
      .slice_values(r, xy_target, rows_lo[[k]], rows_hi[[k]], method)
    }
    got <- map(rest, task)
  } else {
    got <- list()
  }

  for (res in c(list(first), got)) {
    v_lo[res$rows_lo] <- res$lo
    v_hi[res$rows_hi] <- res$hi
  }

  out <- v_lo
  moving <- !is.na(v_lo) & p > 0
  out[moving] <- v_lo[moving] * (1 - p[moving]) + v_hi[moving] * p[moving]
  out
}

## Everything one slice contributes, as plain vectors: nothing here holds a
## SpatRaster, so a task's result crosses a process boundary intact.
.slice_values <- function(r, xy_target, rows_lo, rows_hi, method) {
  list(rows_lo = rows_lo,
       lo = if (length(rows_lo)) .extract_points(r, xy_target[rows_lo, , drop = FALSE], method) else numeric(0),
       rows_hi = rows_hi,
       hi = if (length(rows_hi)) .extract_points(r, xy_target[rows_hi, , drop = FALSE], method) else numeric(0))
}

## Split the input into a coordinate matrix and a vector of times.
.xyt_input <- function(xyt) {
  if (is.matrix(xyt)) xyt <- as.data.frame(xyt, stringsAsFactors = FALSE)
  if (!is.data.frame(xyt)) {
    stop("'xyt' must be a data.frame or matrix of x, y, time", call. = FALSE)
  }
  if (ncol(xyt) < 3L) {
    stop("'xyt' needs three columns: x, y, time", call. = FALSE)
  }
  if (nrow(xyt) < 1L) stop("'xyt' has no rows", call. = FALSE)

  x <- xyt[[1L]]
  y <- xyt[[2L]]
  if (!is.numeric(x) || !is.numeric(y)) {
    stop("the first two columns of 'xyt' must be numeric coordinates", call. = FALSE)
  }
  times <- .xyt_times(xyt[[3L]], "the third column of 'xyt'")
  if (any(is.na(times))) stop("'xyt' contains missing times", call. = FALSE)

  list(xy = cbind(x, y), times = times)
}

## The catalogue call, with the checks that turn a wrong-shaped reader into a
## sentence rather than a subscript error twenty lines later.
.catalogue <- function(read, dots = list()) {
  files <- do.call(read, c(list(returnfiles = TRUE), dots))
  if (!is.data.frame(files)) {
    stop("read(returnfiles = TRUE) must return a data.frame, not ",
         paste(class(files), collapse = "/"), call. = FALSE)
  }
  if (!"date" %in% names(files)) {
    stop("read(returnfiles = TRUE) must return a data.frame with a 'date' column",
         call. = FALSE)
  }
  .check_catalogue(files, "the reader's catalogue")
}

## Hand the catalogue to the daemons by name rather than by value. Sharing is
## worth the copy into shared memory only when something else is going to read
## it out of another process, so by default this waits for daemons.
.share_catalogue <- function(files, share = NULL) {
  if (isFALSE(share)) return(files)
  have <- requireNamespace("mori", quietly = TRUE)
  if (!have) {
    if (isTRUE(share)) {
      stop("share = TRUE needs the 'mori' package:\n  install.packages(\"mori\")",
           call. = FALSE)
    }
    return(files)
  }
  if (isTRUE(mori::is_shared(files))) return(files)
  if (is.null(share) && .mirai_daemons() < 1L) return(files)
  shared <- try(mori::share(files), silent = TRUE)
  if (inherits(shared, "try-error")) {
    if (isTRUE(share)) stop(attr(shared, "condition")$message, call. = FALSE)
    return(files)
  }
  shared
}

.check_catalogue <- function(files, what = "'files'") {
  if (!is.data.frame(files)) {
    stop(what, " must be a data.frame, not ", paste(class(files), collapse = "/"),
         call. = FALSE)
  }
  if (!"date" %in% names(files)) {
    stop(what, " must have a 'date' column", call. = FALSE)
  }
  if (nrow(files) < 1L) stop(what, " has no rows", call. = FALSE)
  if (is.unsorted(files$date)) {
    stop(what, " is not in ascending date order", call. = FALSE)
  }
  files
}

## One slice, optionally aggregated. A reader is allowed to hand back
## something with more than one layer, but not to this function: the caller
## has to pick, with an argument the reader understands.
.read_slice <- function(read, date, files, fact = NULL, dots = list()) {
  r <- do.call(read, c(list(date), list(inputfiles = files), dots))
  if (!inherits(r, "SpatRaster")) {
    stop("the reader returned ", paste(class(r), collapse = "/"),
         ", not a SpatRaster", call. = FALSE)
  }
  if (terra::nlyr(r) != 1L) {
    stop(sprintf("the reader returned %i layers for %s; pass the reader an argument that selects one",
                 terra::nlyr(r), format(date)), call. = FALSE)
  }
  if (!is.null(fact)) {
    r <- terra::aggregate(r, fact = fact, fun = "mean", na.rm = TRUE)
  }
  r
}

## Transform query coordinates into the raster's system.
.to_crs <- function(xy, from, to) {
  if (is.na(to) || !nzchar(to)) {
    warning("the raster declares no coordinate reference system; assuming the points are already in it",
            call. = FALSE)
    return(xy)
  }
  if (terra::same.crs(from, to)) return(xy)
  out <- terra::project(xy, from = from, to = to)
  colnames(out) <- c("x", "y")
  out
}

## terra::extract() on a matrix returns a data.frame; the single layer is the
## only column that is not an ID.
.extract_points <- function(r, xy, method) {
  v <- terra::extract(r, xy, method = method)
  if (is.data.frame(v)) {
    v <- v[, setdiff(names(v), "ID"), drop = FALSE]
    v <- v[[1L]]
  }
  as.numeric(v)
}
