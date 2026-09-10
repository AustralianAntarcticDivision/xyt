## Is the catalogue what makes daemons disappointing?
##
## extract_xyt() builds one closure per run and mirai sends it with every
## task. That closure captures the catalogue, so a 16000-row raadfiles
## catalogue of long paths goes down the wire once per slice. This measures
## whether that is actually the cost, before anyone adds a dependency to fix
## it.
##
## Four rows: serial, daemons with the catalogue as it comes, daemons with
## the catalogue cut to the rows the query needs, and daemons with it in
## shared memory via mori. The middle one needs no new package, so if it
## closes the gap, mori is not needed.
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
v1 <- timeit("serial, full", files = files, map = lapply)

mirai::daemons(6)
mirai::everywhere({ library(raadtools); library(xyt) })
v2 <- timeit("6 daemons, full", files = files)
v3 <- timeit("6 daemons, slim", files = slim)
v4 <- if (have_mori) timeit("6 daemons, mori", files = shared) else NULL
mirai::daemons(0)

cat("\nsame answer as serial:\n")
cat("  full ", isTRUE(all.equal(v1, v2)), "\n")
cat("  slim ", isTRUE(all.equal(v1, v3)), "\n")
if (have_mori) cat("  mori ", isTRUE(all.equal(v1, v4)), "\n")
