## Reproduce the golden values from the tests that were deleted from
## raadtools, using this package instead of the old extract() method.
##
## Only useful inside the network. Run it before and after any change to the
## reading path.
##
## Note on the coordinates. The old test built its points as
##
##   set.seed(1)
##   d <- data.frame(x = 1:10, y = rnorm(10), ...)
##   coordinates(d) <- ~x+y
##   proj4string(d) <- CRS("+proj=laea +ellps=sphere")
##
## so x and y are METRES in a Lambert azimuthal equal-area projection centred
## on 0, 0, not degrees. The old trip method transformed them to longlat
## before extracting. Inverse-projected they are all within a tenth of a
## millidegree of the origin: the ten values are the SST at one place near
## 0E 0N, on the first of each month of 2006, straddling the equator so they
## fall in two cells. Handing the raw 1:10 to a reader as longitude gives
## points spread across ten degrees of the Gulf of Guinea, one of them inland,
## which is a different question with a plausible-looking answer.

library(xyt)
library(raadtools)
source("dev/adapters.R")

## readsst raises the compat notice on every read, which is ten warnings in a
## comparison that is not about the compat layer
options(raadtools.shim.warn = FALSE)

## set.seed() immediately before rnorm(), every time: the whole comparison is
## against a recorded draw, and any intervening use of the generator moves it
set.seed(1)
laea <- cbind(1:10, rnorm(10))
ll <- terra::project(laea, from = "+proj=laea +ellps=sphere", to = "EPSG:4326")

xyt <- data.frame(x = ll[, 1L], y = ll[, 2L],
                  t = ISOdatetime(2006, 1:10, 1, 0, 0, 0, tz = "GMT"))

## from tests/testthat/test-trip-extract.R, deleted in 1904d84
sst_2014 <- c(27.3899993877858, 28.3199993669987, 29.3799993433058, 29.2199993468821,
              29.1699993479997, 27.2599993906915, 26.3899994101375, 23.0299994852394,
              25.7199994251132, 26.0999994166195)

## readsst still returns a RasterLayer on terra-refactor, so it goes through
## the transitional wrapper; drop it once read-sst.R is converted
now <- extract_xyt(as_terra_reader(readsst), xyt, when = "previous", verbose = FALSE)

print(data.frame(date = format(xyt$t, "%Y-%m-%d"),
                 golden_2014 = sst_2014,
                 now = now,
                 difference = now - sst_2014))

## The 18-point track and its oisst, aviso and nsidc goldens are in
## tests/testthat/testthat_extractxyt.R, deleted 2014-12-02 in fefbf78. The
## nsidc values there are percentages; divide by 100 to compare with the
## fraction that raadtools returns now.
