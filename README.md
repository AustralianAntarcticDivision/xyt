# xyt

Extract values from a raster time series at points that each carry their own
date-time.

This is the `extract(<read function>, <data.frame>)` machinery from
[raadtools](https://github.com/AustralianAntarcticDivision/raadtools), lifted
out on its own, rewritten against terra, and given a test suite that runs
with no data behind it.

The name is a placeholder.

## The idea

The series is described by a *reader function* rather than held in memory, so
it can be far larger than memory and can live anywhere the reader can reach.
Only the slices some point actually needs are read, and each of those is read
exactly once.

``` r
library(xyt)

read <- synthetic_reader()          # a series with no files behind it

xyt <- data.frame(
  x = c(0.5, 2.5),
  y = c(0.5, 3.5),
  t = as.POSIXct(c("2000-01-01", "2000-01-05"), tz = "UTC")
)

extract_xyt(read, xyt)
#> [1]  51.5 258.5

extract_xyt(read, xyt, ctstime = TRUE)   # interpolate in time
extract_xyt(read, xyt, method = "bilinear")   # and in space
```

## The reader contract

A reader is any function supporting two calls.

``` r
read(returnfiles = TRUE, ...)        # -> data.frame with a `date` column
read(date, inputfiles = files, ...)  # -> single-layer SpatRaster
```

That is the whole interface. Nothing in it is specific to any data
collection, which is why the tests can run against a synthetic series and why
raadtools' readers work unchanged.

`xyt_reader_check()` runs those calls in the order `extract_xyt()` will make
them and says what came back:

``` r
xyt_reader_check(synthetic_reader())
#> PASS is a function
#> PASS read(returnfiles = TRUE) succeeds
#> PASS the catalogue is a data.frame
#> ...
```

Point it at a raadtools reader inside the network and it reports whether that
reader is ready to be used here.

## Writing a reader without the flag

The `returnfiles` switch exists so that functions written before this package
satisfy the contract untouched. It is a poor thing to write by hand, because
the return type depends on the value of an argument. Two ways to avoid it,
neither of which changes the contract.

Hand the catalogue to `extract_xyt()` and the `returnfiles` call is never
made, so the reader only has to do the one job:

``` r
extract_xyt(function(date, inputfiles, ...) terra::rast(...),
            xyt, files = raadfiles::sst_daily_files())
```

Or build the reader from its two jobs, each an ordinary function:

``` r
src <- xyt_source(
  slice     = function(date, files, ...) terra::rast(files$fullname[files$date == date]),
  catalogue = raadfiles::sst_daily_files
)

extract_xyt(src, xyt)
```

A catalogue given as a function is called once, the first time it is needed,
and reused for the life of the source, which matters when building it costs a
directory listing.

## What changed from the raadtools version

Behaviour that was implicit is now an argument, and a few things were wrong.

- **`when`**. raadtools documented `ctstime = FALSE` as "find the nearest
  value in time" and implemented it with `findInterval()`, which finds the
  *previous* slice. Both are available: `when = "nearest"` is the default and
  matches the documentation, `when = "previous"` reproduces the old numbers.

- **`...` goes to the reader only.** In raadtools it went to the reader *and*
  to `extract()`, so an argument meant for one was silently offered to the
  other, which is where the `xylim argument ignored` and `inputfiles argument
  ignored` warnings came from. Extraction is controlled by named arguments
  here.

- **Each slice is read once, in catalogue order, whatever order the rows
  arrive in.** The old loop walked the slices in sequence and matched rows to
  the slice it was holding.

- **Points beyond the collection return `NA` with a warning**, rather than
  the whole call stopping. `tolerance` sets how far is too far, and defaults
  to 1.5 times the spacing of the series.

- **No S4.** raadtools registered this as a method on *raster's* `extract`
  generic, which is what welded it to raster. This is a plain function.

- **Character times are parsed one format at a time.** `as.POSIXct()` on a
  character vector picks a format from the first element and applies it to
  the whole vector, so `c("2000-01-01", "2000-01-01 06:00:00")` comes back as
  two midnights. A track written with whole days at the start and times later
  would lose every time of day, silently.

## Building it

There are no `man/` pages in the repository yet: run `roxygen2::roxygenise()`
once and they are generated from the sources.

The tests are ordinary testthat files. They can also be run somewhere that
has terra and nothing else:

``` sh
Rscript dev/run-tests.R
```

That script defines just enough of the `expect_*` vocabulary to run the same
test files, sources `R/`, and runs them. It is not part of the package.
