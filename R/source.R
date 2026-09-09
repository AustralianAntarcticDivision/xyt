#' Build a reader from a catalogue and a slice function
#'
#' The reader contract is one function that does two jobs, switched by
#' `returnfiles`. That shape exists so that functions written before this
#' package, raadtools' `read*` among them, satisfy it without being touched.
#' It is not a nice thing to write by hand: the return type depends on the
#' value of an argument, which is awkward to document and easy to get subtly
#' wrong.
#'
#' `xyt_source()` writes it for you. You supply the two jobs separately, each
#' as an ordinary function with an ordinary signature, and get back something
#' [extract_xyt()] accepts.
#'
#' @param slice a function of `(date, files, ...)` returning a single-layer
#'   SpatRaster for `date`. `files` is the catalogue.
#' @param catalogue the catalogue: a data.frame with a `date` column, or a
#'   function returning one. A function is called once, the first time it is
#'   needed, and the result is reused for the life of the source. Build a
#'   separate source if you need a different catalogue.
#'
#' @return a function of class `xyt_reader` satisfying the reader contract.
#'
#' @seealso [extract_xyt()] takes a `files` argument too, which is the other
#'   way to avoid writing the flag: hand it the catalogue directly and the
#'   `returnfiles` call is never made.
#'
#' @examples
#' ## a series of two rasters held in a list
#' r <- lapply(1:2, function(i) {
#'   x <- terra::rast(terra::ext(0, 4, 0, 4), resolution = 1, crs = "EPSG:4326")
#'   terra::values(x) <- i
#'   x
#' })
#' src <- xyt_source(
#'   slice = function(date, files, ...) r[[which(files$date == date)]],
#'   catalogue = data.frame(date = as.POSIXct(c("2000-01-01", "2000-01-02"),
#'                                            tz = "UTC"))
#' )
#' extract_xyt(src, data.frame(x = 1, y = 1,
#'                             t = as.POSIXct("2000-01-02", tz = "UTC")))
#' @export
xyt_source <- function(slice, catalogue) {
  if (!is.function(slice)) stop("'slice' must be a function", call. = FALSE)
  if (!is.function(catalogue) && !is.data.frame(catalogue)) {
    stop("'catalogue' must be a data.frame or a function returning one",
         call. = FALSE)
  }
  force(slice)
  force(catalogue)

  cache <- if (is.data.frame(catalogue)) catalogue else NULL
  files_of <- function(...) {
    if (is.null(cache)) cache <<- catalogue(...)
    cache
  }

  f <- function(date, ..., returnfiles = FALSE, inputfiles = NULL) {
    if (isTRUE(returnfiles)) return(files_of(...))
    slice(date, if (is.null(inputfiles)) files_of(...) else inputfiles, ...)
  }
  class(f) <- c("xyt_reader", "function")
  f
}

#' @export
print.xyt_reader <- function(x, ...) {
  cat("<xyt_reader>\n")
  cat("slice: ")
  print(args(environment(x)$slice))
  invisible(x)
}
