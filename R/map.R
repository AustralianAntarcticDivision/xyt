#' Run the per-slice reads on mirai daemons
#'
#' The work [extract_xyt()] does divides cleanly: one slice is read, the
#' points that want it are extracted, and a plain numeric vector comes back.
#' Nothing is shared between slices and no SpatRaster crosses a process
#' boundary, so the reads can be spread over daemons with no change to the
#' answer.
#'
#' Start daemons in the usual way and [extract_xyt()] will use them without
#' being told to:
#'
#' \preformatted{
#'   mirai::daemons(6)
#'   mirai::everywhere({ library(raadtools) })   # whatever the reader needs
#'   extract_xyt(read, xyt)
#'   mirai::daemons(0)
#' }
#'
#' `mirai::everywhere()` matters: a daemon runs the reader in a fresh session,
#' so any package the reader reaches for has to be loaded there. The reader
#' itself is sent along with the task.
#'
#' @param ... passed to [mirai::mirai_map()].
#'
#' @return a function of `(X, FUN)`, for [extract_xyt()]'s `map` argument.
#'
#' @details
#' Whether this is faster depends on where the bytes come from. Reading a
#' hundred slices off a remote store is latency bound and parallelises well.
#' Reading ten slices off a local disk that is already saturated will not.
#'
#' @seealso [extract_xyt()]
#' @export
xyt_map_mirai <- function(...) {
  if (!requireNamespace("mirai", quietly = TRUE)) {
    stop("mirai is not installed; install it or pass map = lapply", call. = FALSE)
  }
  args <- list(...)
  function(X, FUN) {
    m <- do.call(mirai::mirai_map, c(list(.x = X, .f = FUN), args))
    out <- m[]
    bad <- vapply(out, inherits, logical(1), "miraiError")
    if (any(bad)) {
      stop("a slice failed on a mirai daemon: ",
           conditionMessage(out[[which(bad)[1L]]]),
           "\n  a daemon starts with a bare session; mirai::everywhere() is where",
           "\n  the packages your reader needs get loaded", call. = FALSE)
    }
    out
  }
}

## Number of running daemons, or 0 if mirai is absent or none are up. Wrapped
## because status() is the sort of thing that changes shape between versions,
## and an unavailable count should mean "read serially", not "fail".
.mirai_daemons <- function() {
  if (!requireNamespace("mirai", quietly = TRUE)) return(0L)
  st <- try(mirai::status(), silent = TRUE)
  if (inherits(st, "try-error") || is.null(st)) return(0L)
  n <- st$connections
  if (is.null(n) && !is.null(st$daemons)) {
    n <- if (is.matrix(st$daemons) || is.data.frame(st$daemons)) nrow(st$daemons) else length(st$daemons)
  }
  if (is.null(n) || length(n) != 1L || is.na(n)) return(0L)
  max(0L, as.integer(n))
}

## Serial reads, with the progress reporting: a slice read is the only thing
## in here that takes any time, so it is the only thing worth announcing.
.serial_map <- function(verbose, total) {
  function(X, FUN) {
    lapply(seq_along(X), function(i) {
      if (verbose) message(sprintf("reading slice %i of %i", i + 1L, total))
      FUN(X[[i]])
    })
  }
}

.resolve_map <- function(map, verbose = FALSE, total = 0L) {
  if (isFALSE(map)) return(.serial_map(verbose, total))
  if (is.null(map)) {
    nd <- .mirai_daemons()
    if (nd > 0L) {
      if (verbose) {
        message(sprintf("reading %i slices across %i mirai daemons", total, nd))
      }
      return(xyt_map_mirai())
    }
    return(.serial_map(verbose, total))
  }
  if (!is.function(map)) {
    stop("'map' must be a function of (X, FUN), like lapply(), or NULL",
         call. = FALSE)
  }
  map
}
