## Time handling.
##
## Everything in here is deliberately explicit about what "the value at this
## time" means. raadtools documented `ctstime = FALSE` as "find the nearest
## value in time" but implemented it with findInterval(), which finds the
## *previous* slice. Both behaviours are useful and both are available, but
## the caller has to say which one, and the default matches the documentation
## rather than the accident.

## Coerce anything date-like to POSIXct/UTC. Numeric input is refused because
## there is no honest guess at the epoch.
.xyt_times <- function(x, what = "times") {
  if (inherits(x, "POSIXct")) {
    attr(x, "tzone") <- "UTC"
    return(x)
  }
  if (inherits(x, "Date")) {
    return(as.POSIXct(format(x), tz = "UTC"))
  }
  if (is.character(x) || is.factor(x)) {
    out <- .parse_character_times(as.character(x))
    if (any(is.na(out) & !is.na(x))) {
      stop(sprintf("could not read %s as date-times: %s", what,
                   paste(utils::head(unique(as.character(x)[is.na(out) & !is.na(x)]), 3L),
                         collapse = ", ")), call. = FALSE)
    }
    return(out)
  }
  if (inherits(x, "POSIXlt")) {
    return(as.POSIXct(x, tz = "UTC"))
  }
  stop(sprintf("%s must be POSIXct, Date or character, not %s",
               what, paste(class(x), collapse = "/")), call. = FALSE)
}

## Character input is parsed one format at a time, longest first, rather than
## handed to as.POSIXct() in one go.
##
## as.POSIXct() on a character vector picks a format from the first element
## that parses and then applies it to the whole vector. So
## c("2000-01-01", "2000-01-01 06:00:00") comes back as two midnights: the
## first element only matches "%Y-%m-%d", and that format then silently
## truncates the second. A track written out with whole days at the start and
## times later would lose every time of day, with no error and no warning.
.parse_character_times <- function(x) {
  out <- rep(as.POSIXct(NA_character_, tz = "UTC"), length(x))
  fmts <- c("%Y-%m-%d %H:%M:%OS", "%Y/%m/%d %H:%M:%OS",
            "%Y-%m-%dT%H:%M:%OS", "%Y-%m-%d %H:%M", "%Y/%m/%d %H:%M",
            "%Y-%m-%dT%H:%M", "%Y-%m-%d", "%Y/%m/%d")
  todo <- !is.na(x) & nzchar(trimws(x))
  for (f in fmts) {
    if (!any(todo)) break
    got <- as.POSIXct(strptime(trimws(x[todo]), format = f, tz = "UTC"), tz = "UTC")
    ok <- !is.na(got)
    if (any(ok)) {
      out[which(todo)[ok]] <- got[ok]
      todo[which(todo)[ok]] <- FALSE
    }
  }
  out
}

## Typical spacing of the series, in days. Median rather than min or mean so a
## single gap in an otherwise daily series does not redefine the resolution.
.time_resolution <- function(dates) {
  if (length(dates) < 2L) return(NA_real_)
  stats::median(as.numeric(diff(sort(dates)), units = "days"))
}

## Default tolerance: how far a point may sit from the slice used for it
## before the answer is refused. 1.5 times the series resolution, so a daily
## series tolerates 1.5 days, matching what raadtools used for daily data.
.tolerance_days <- function(dates) {
  res <- .time_resolution(dates)
  if (is.na(res)) return(Inf)
  1.5 * res
}

## Index of the slice at or before each time, clamped to the ends.
.previous_index <- function(times, dates) {
  i <- findInterval(as.numeric(times), as.numeric(dates))
  i[i < 1L] <- 1L
  i[i > length(dates)] <- length(dates)
  i
}

## Index of the slice bracketing each time from above, clamped to the ends.
.next_index <- function(times, dates) {
  pmin(.previous_index(times, dates) + 1L, length(dates))
}

## Index of the closest slice in time.
.nearest_index <- function(times, dates) {
  lo <- .previous_index(times, dates)
  hi <- .next_index(times, dates)
  dlo <- abs(as.numeric(times) - as.numeric(dates)[lo])
  dhi <- abs(as.numeric(times) - as.numeric(dates)[hi])
  ifelse(dhi < dlo, hi, lo)
}

.slice_index <- function(times, dates, when = c("nearest", "previous")) {
  when <- match.arg(when)
  switch(when,
         nearest = .nearest_index(times, dates),
         previous = .previous_index(times, dates))
}

## Points further than `tolerance` days from the slice they were matched to
## are not answered. raadtools stopped outright when every point was out of
## range; here they come back NA with one warning, so a track that runs off
## the end of a collection still returns the part that is covered.
.tolerance_mask <- function(times, dates, index, tolerance) {
  if (!is.finite(tolerance)) return(rep(TRUE, length(times)))
  gap <- abs(as.numeric(difftime(times, dates[index], units = "days")))
  ok <- gap <= tolerance
  if (any(!ok)) {
    warning(sprintf("%i of %i points are more than %.4g days from any slice; returning NA for those",
                    sum(!ok), length(ok), tolerance), call. = FALSE)
  }
  ok
}

## Position of each time between its bracketing slices, in [0, 1].
## Zero where the two slices are the same, which is what happens at both ends
## of the series and for a series of length one.
.proportion <- function(times, dates, lo, hi) {
  span <- as.numeric(dates[hi]) - as.numeric(dates[lo])
  p <- rep(0, length(times))
  moving <- span > 0
  p[moving] <- (as.numeric(times)[moving] - as.numeric(dates)[lo[moving]]) / span[moving]
  ## a time outside the series clamps to the slice, it does not extrapolate
  pmin(pmax(p, 0), 1)
}
