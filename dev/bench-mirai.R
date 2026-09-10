## What the catalogue costs the daemons, and what to do about it.
##
## extract_xyt() builds one closure per run and mirai sends it with every
## task. That closure captures the catalogue, so a 16000-row raadfiles
## catalogue of long paths goes down the wire once per slice.
##
## Measured, six daemons, 200 OISST slices: 16.8 s copied, 9.4 s slimmed,
## 9.2 s shared. The payload was the cost.
##
## extract_xyt() shares by default now, so the rows below ask for
## share = FALSE where they mean the old behaviour.
##
## The slim row is kept as the road not taken. It is as fast, and it is NOT
## safe: it changes what the reader is handed, and a reader may look at more
## of the catalogue than the row it matched. synthetic_reader() takes its
## slice number from the row's position, so slimming moves its answers on a
## sparse track. Sharing changes nothing the reader can see.
##
##   Rscript dev/bench-mirai.R

library(xyt)
library(raadtools)
options(raadtools.shim.warn = FALSE)

n <- 200
xyt <- data.frame(
  x = seq(90, 150, length.out = n),
  y = seq(-65, -50, length.out = n),
  t = seq(as.POSIXct("2015-01-01", tz = "UTC"), by = "1 day", length.out = n)
)

## readsst returns a SpatRaster directly now, so it meets the reader contract
## without an adapter.
read <- readsst
files <- read(returnfiles = TRUE)

## The catalogue cut to what this query can reach. .processFiles() indexes with
## findInterval(), so keep one row either side of the range rather than exactly
## the range.
span <- range(xyt$t)
i <- which(files$date >= span[1L] & files$date <= span[2L])
i <- seq(max(1L, min(i) - 1L), min(nrow(files), max(i) + 1L))
slim <- files[i, , drop = FALSE]

payload <- function(x) length(serialize(x, NULL))

cat("catalogue rows: full", nrow(files), " slim", nrow(slim), "\n")
cat("serialised bytes per task:\n")
cat(sprintf("  full  %10d\n", payload(files)))
cat(sprintf("  slim  %10d\n", payload(slim)))

have_mori <- requireNamespace("mori", quietly = TRUE)
if (have_mori) {
  shared <- mori::share(files)
  cat(sprintf("  mori  %10d   (%s)\n", payload(shared), mori::shared_name(shared)))
} else {
  cat("  mori         -   not installed\n")
}

timeit <- function(label, ...) {
  t <- system.time(v <- extract_xyt(read, xyt, verbose = FALSE, ...))
  cat(sprintf("%-22s %6.1f s\n", label, t[["elapsed"]]))
  invisible(v)
}

cat("\n")
v1 <- timeit("serial, full", files = files, share = FALSE, map = lapply)

mirai::daemons(6)
mirai::everywhere({ library(raadtools); library(xyt) })
v2 <- timeit("6 daemons, copied", files = files, share = FALSE)
v3 <- timeit("6 daemons, slim", files = slim, share = FALSE)
v4 <- if (have_mori) timeit("6 daemons, shared", files = files) else NULL
mirai::daemons(0)

cat("\nsame answer as serial:\n")
cat("  copied ", isTRUE(all.equal(v1, v2)), "\n")
cat("  slim   ", isTRUE(all.equal(v1, v3)), "   (true here, not in general)\n")
if (have_mori) cat("  shared ", isTRUE(all.equal(v1, v4)), "\n")
