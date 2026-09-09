## Run the reader contract over raadtools' read functions.
##
## Only useful inside the network where raadfiles can see the collections.
## For each reader it reports whether the two calls xyt makes come back in the
## shape extract_xyt() needs, and then does one real extraction so the whole
## path is exercised end to end.
##
##   Rscript dev/check-raadtools-readers.R
##
## A reader that fails "it returns one layer" usually just needs an argument
## that picks a variable, e.g. readcurr(uonly = TRUE).

library(xyt)
library(raadtools)
source("dev/adapters.R")

## as_terra_reader() is a no-op for a reader that already returns a
## SpatRaster, so the same list works either side of the conversion.
readers <- lapply(list(
  readsst = readsst,
  readice = readice,
  readssh = readssh,
  readwind = readwind,
  readchla = readchla
), as_terra_reader)

## a couple of points somewhere with data in every collection
xyt <- data.frame(
  x = c(100, 110, 120),
  y = c(-60, -62, -58),
  t = as.POSIXct(c("2015-06-01", "2015-06-05", "2015-06-09"), tz = "UTC")
)

for (nm in names(readers)) {
  cat("\n==== ", nm, " ====\n", sep = "")
  out <- try(xyt_reader_check(readers[[nm]], error = FALSE), silent = TRUE)
  if (inherits(out, "try-error")) {
    cat("check itself failed: ", trimws(as.character(out)), "\n", sep = "")
    next
  }
  if (!all(out$ok)) {
    cat("-> not ready; see the FAIL lines above\n")
    next
  }
  v <- try(extract_xyt(readers[[nm]], xyt, verbose = FALSE), silent = TRUE)
  if (inherits(v, "try-error")) {
    cat("extraction failed: ", trimws(as.character(v)), "\n", sep = "")
  } else {
    cat("extracted: ", paste(format(v), collapse = ", "), "\n", sep = "")
  }
}
