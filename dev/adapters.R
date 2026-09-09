## Transitional wrapper for raadtools readers that still return Raster*
## objects.
##
## Michael's shape, generalised. Once a reader has been converted on the
## terra-refactor branch the wrapper is a no-op and can be dropped: the
## conversion is what removes the need for it, not a change here.
##
##   rsst <- as_terra_reader(raadtools::readsst)
##   xyt_reader_check(rsst)
##   extract_xyt(rsst, xyt)
##
## `returnfiles` sits after the dots deliberately, so it can only be matched
## by its full name and the date can still be passed positionally.

as_terra_reader <- function(read) {
  force(read)
  function(x, ..., returnfiles = FALSE) {
    if (isTRUE(returnfiles)) return(read(returnfiles = TRUE, ...))
    r <- read(x, ...)
    if (inherits(r, "SpatRaster")) r else terra::rast(r)
  }
}
