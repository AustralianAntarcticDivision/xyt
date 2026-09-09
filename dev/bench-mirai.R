## Measure whether daemons are worth it for a given collection.
##
## Parallel reads help when the reads are latency bound and hurt when they
## are not, so this is a measurement rather than a recommendation.
##
##   Rscript dev/bench-mirai.R

library(xyt)
library(raadtools)
source("dev/adapters.R")
options(raadtools.shim.warn = FALSE)

## a track that touches a lot of distinct days, which is what makes the read
## count large enough to be worth spreading
n <- 200
xyt <- data.frame(
  x = seq(90, 150, length.out = n),
  y = seq(-65, -50, length.out = n),
  t = seq(as.POSIXct("2015-01-01", tz = "UTC"), by = "1 day", length.out = n)
)

read <- as_terra_reader(readsst)
files <- read(returnfiles = TRUE)

serial <- system.time(v1 <- extract_xyt(read, xyt, files = files,
                                        map = lapply, verbose = FALSE))

mirai::daemons(6)
mirai::everywhere({ library(raadtools); library(xyt) })
par <- system.time(v2 <- extract_xyt(read, xyt, files = files, verbose = FALSE))
mirai::daemons(0)

cat("serial  ", serial[["elapsed"]], "s\n")
cat("6 daemons", par[["elapsed"]], "s\n")
cat("same answer: ", isTRUE(all.equal(v1, v2)), "\n")
