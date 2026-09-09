#' Extract raster time series values at points in space and time
#'
#' The package has one job: given a series of rasters that is described by a
#' *reader function* rather than held in memory, and a set of points that each
#' carry their own date-time, return the value of the series at each point.
#'
#' The series can be far larger than memory, and can live anywhere the reader
#' can reach, because only the time slices actually needed are read, and each
#' is read exactly once.
#'
#' @section The reader contract:
#'
#' A reader is any function supporting two calls.
#'
#' \preformatted{
#'   read(returnfiles = TRUE, ...)        # -> data.frame with a `date` column
#'   read(date, inputfiles = files, ...)  # -> single-layer SpatRaster
#' }
#'
#' The first call is the catalogue: one row per available time slice, in
#' ascending date order. The second reads one slice. `inputfiles` is the
#' catalogue handed back so the reader does not have to rebuild it.
#'
#' Use [xyt_reader_check()] to test a function against the contract before
#' handing it to [extract_xyt()].
#'
#' @seealso [extract_xyt()], [xyt_reader_check()], [synthetic_reader()]
#' @keywords internal
#' @importFrom terra rast ext crs same.crs project extract aggregate nlyr
#' @importFrom terra values time values<- time<- res ncell xyFromCell
#' @importFrom stats median
#' @importFrom utils head
"_PACKAGE"
