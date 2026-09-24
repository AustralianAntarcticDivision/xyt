# Extract values from a raster time series at points in space and time

Each row of `xyt` is a location and a date-time. The value returned for
it is read from the time slice nearest that date-time, or, with
`ctstime = TRUE`, interpolated linearly between the two slices that
bracket it.

## Usage

``` r
extract_xyt(
  read,
  xyt,
  ctstime = FALSE,
  when = c("nearest", "previous"),
  method = c("simple", "bilinear"),
  fact = NULL,
  crs = "EPSG:4326",
  files = NULL,
  share = NULL,
  tolerance = NULL,
  map = NULL,
  verbose = interactive(),
  ...
)
```

## Arguments

- read:

  a reader function. See the reader contract in
  [xyt](https://australianantarcticdivision.github.io/xyt/reference/xyt-package.md),
  [`xyt_reader_check()`](https://australianantarcticdivision.github.io/xyt/reference/xyt_reader_check.md)
  and
  [`xyt_source()`](https://australianantarcticdivision.github.io/xyt/reference/xyt_source.md).

- xyt:

  a data.frame or matrix with three columns: x, y and time. Extra
  columns are ignored. The time column may be POSIXct, Date or
  character.

- ctstime:

  interpolate linearly in time between bracketing slices (`TRUE`), or
  take the value from one slice (`FALSE`, the default).

- when:

  which slice a point takes its value from when `ctstime = FALSE`: the
  closest in time (`"nearest"`, the default) or the most recent one at
  or before it (`"previous"`).

- method:

  how the value is taken from the raster: `"simple"` for the value of
  the cell the point falls in, `"bilinear"` for a distance weighted
  average of the four nearest cell centres.

- fact:

  optional aggregation factor applied to each slice before extraction,
  as in
  [`terra::aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html).
  One integer, or two for the horizontal and vertical factors.

- crs:

  coordinate reference system of the coordinates in `xyt`, defaulting to
  longitude/latitude on WGS84. Points are transformed to the raster's
  own system before extraction.

- files:

  the catalogue, if you already have it: a data.frame with a `date`
  column. Supplied here, `read(returnfiles = TRUE)` is never called, so
  a reader only has to do the one job of reading a slice. See also
  [`xyt_source()`](https://australianantarcticdivision.github.io/xyt/reference/xyt_source.md).

- share:

  put the catalogue into shared memory with
  [`mori::share()`](https://rdrr.io/pkg/mori/man/share.html), so that it
  is mapped by the daemons rather than copied to each of them. `NULL`,
  the default, does it when mori is installed and mirai daemons are
  running, and otherwise leaves the catalogue alone. `TRUE` insists,
  `FALSE` refuses.

- tolerance:

  how far, in days, a point may sit from the slice matched to it before
  its value is refused and returned as `NA`. `NULL`, the default,
  derives it from the spacing of the series.

- map:

  how the per-slice reads are run. `NULL`, the default, uses mirai
  daemons if any are running and reads serially otherwise. Pass
  [`base::lapply()`](https://rdrr.io/r/base/lapply.html) to force
  serial, or see
  [`xyt_map_mirai()`](https://australianantarcticdivision.github.io/xyt/reference/xyt_map_mirai.md).

- verbose:

  report progress as slices are read.

- ...:

  passed to `read`, and only to `read`.

## Value

a numeric vector with one value per row of `xyt`.

## Details

Only the slices that some point actually needs are read, and each of
those is read exactly once.

`...` reaches the reader alone. This is a deliberate departure from the
version of this code that lived in raadtools, where `...` was passed to
both the reader and the extraction, so that an argument meant for one
was silently offered to the other. Arguments controlling the extraction
are named here instead.

## Examples

``` r
read <- synthetic_reader()
xyt <- data.frame(x = c(0.5, 2.5), y = c(0.5, 3.5),
                  t = as.POSIXct(c("2000-01-01", "2000-01-05"), tz = "UTC"))
extract_xyt(read, xyt)
#> [1]  51.5 258.5
extract_xyt(read, xyt, ctstime = TRUE)
#> [1]  51.5 258.5
```
