#' Check a function against the reader contract
#'
#' Runs the calls [extract_xyt()] will make, in the order it will make them,
#' and reports what came back. Use it when wiring up a new source, so a
#' mismatch is a sentence about the contract rather than an error from inside
#' the extraction loop.
#'
#' @param read the function to check.
#' @param error stop on failure (the default), or return the report quietly.
#' @param ... passed to `read`, exactly as [extract_xyt()] would pass it.
#'
#' @return invisibly, a data.frame with one row per check: `check`, `ok` and
#'   `note`.
#'
#' @examples
#' xyt_reader_check(synthetic_reader())
#' @export
xyt_reader_check <- function(read, error = TRUE, ...) {
  checks <- list()
  add <- function(check, ok, note = "") {
    checks[[length(checks) + 1L]] <<- data.frame(check = check, ok = ok,
                                                 note = note,
                                                 stringsAsFactors = FALSE)
    isTRUE(ok)
  }

  report <- function() {
    out <- do.call(rbind, checks)
    for (i in seq_len(nrow(out))) {
      message(sprintf("%s %s%s",
                      if (out$ok[i]) "PASS" else "FAIL",
                      out$check[i],
                      if (nzchar(out$note[i])) paste0(": ", out$note[i]) else ""))
    }
    if (error && any(!out$ok)) {
      stop("the reader does not satisfy the contract; see the failures above",
           call. = FALSE)
    }
    invisible(out)
  }

  if (!add("is a function", is.function(read))) return(report())

  files <- try(read(returnfiles = TRUE, ...), silent = TRUE)
  if (!add("read(returnfiles = TRUE) succeeds", !inherits(files, "try-error"),
           if (inherits(files, "try-error")) trimws(as.character(files)) else "")) {
    return(report())
  }
  if (!add("the catalogue is a data.frame", is.data.frame(files),
           paste(class(files), collapse = "/"))) return(report())
  if (!add("the catalogue has a 'date' column", "date" %in% names(files),
           paste(names(files), collapse = ", "))) return(report())

  dates <- try(.xyt_times(files$date, "catalogue dates"), silent = TRUE)
  if (!add("the dates are date-times", !inherits(dates, "try-error"),
           paste(class(files$date), collapse = "/"))) return(report())

  add("the dates have no missing values", !any(is.na(dates)))
  add("the dates are in ascending order", !is.unsorted(dates))
  add("the catalogue has at least one row", nrow(files) > 0L,
      sprintf("%i rows", nrow(files)))
  if (nrow(files) < 1L) return(report())

  add("the series has a resolution", !is.na(.time_resolution(dates)),
      sprintf("%.4g days", .time_resolution(dates)))

  r <- try(read(dates[1L], inputfiles = files, ...), silent = TRUE)
  if (!add("read(date, inputfiles = files) succeeds", !inherits(r, "try-error"),
           if (inherits(r, "try-error")) trimws(as.character(r)) else "")) {
    return(report())
  }
  if (!add("it returns a SpatRaster", inherits(r, "SpatRaster"),
           paste(class(r), collapse = "/"))) return(report())
  add("it returns one layer", terra::nlyr(r) == 1L,
      sprintf("%i layers", terra::nlyr(r)))
  add("it declares a coordinate reference system", nzchar(terra::crs(r)))

  if (nrow(files) > 1L) {
    j <- nrow(files)
    r2 <- try(read(dates[j], inputfiles = files, ...), silent = TRUE)
    if (add("a second date reads too", !inherits(r2, "try-error"),
            if (inherits(r2, "try-error")) trimws(as.character(r2)) else "")) {
      add("the two slices have the same geometry",
          isTRUE(all.equal(as.vector(terra::ext(r)), as.vector(terra::ext(r2)))) &&
            all(dim(r) == dim(r2)))
      add("the two slices differ in value",
          !isTRUE(all.equal(terra::values(r), terra::values(r2))),
          "identical slices usually mean the date argument was ignored")
    }
  }

  report()
}
