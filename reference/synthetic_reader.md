# A reader function with no data behind it

Builds a reader that satisfies the contract
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
expects, over a small in-memory series whose values are known in closed
form. It exists so the extraction machinery can be exercised, and its
answers checked against arithmetic, without any files, network or
credentials.

## Usage

``` r
synthetic_reader(
  n = 10L,
  start = "2000-01-01",
  by = "1 day",
  crs = "EPSG:4326",
  extent = c(0, 4, 0, 4),
  res = 1
)
```

## Arguments

- n:

  number of time slices.

- start:

  date-time of the first slice.

- by:

  spacing between slices, as understood by
  [`seq.POSIXt()`](https://rdrr.io/r/base/seq.POSIXt.html).

- crs:

  coordinate reference system of the slices.

- extent:

  extent of the slices, as xmin, xmax, ymin, ymax.

- res:

  cell size.

## Value

a function of the form
`read(date, returnfiles = FALSE, inputfiles = NULL, offset = 0, ...)`.
`offset` is added to every value, and is there so a test can prove that
`...` reaches the reader.

## Details

Each slice holds the value

       value = 100 * x + y + i 

where `x` and `y` are the coordinates of the cell centre and `i` is the
one-based position of the slice in the series. Two properties follow,
and both are used in the tests. The field is linear in `x` and `y`, so
`method = "bilinear"` returns `100 * x + y + i` exactly anywhere in the
interior. And it is linear in `i`, so `ctstime = TRUE` at a fraction `p`
between slices `i` and `i + 1` returns exactly `100 * x + y + i + p`.

## Examples

``` r
read <- synthetic_reader()
head(read(returnfiles = TRUE))
#>         date      fullname
#> 1 2000-01-01 synthetic-001
#> 2 2000-01-02 synthetic-002
#> 3 2000-01-03 synthetic-003
#> 4 2000-01-04 synthetic-004
#> 5 2000-01-05 synthetic-005
#> 6 2000-01-06 synthetic-006
read(as.POSIXct("2000-01-03", tz = "UTC"))
#> class       : SpatRaster
#> size        : 4, 4, 1  (nrow, ncol, nlyr)
#> resolution  : 1, 1  (x, y)
#> extent      : 0, 4, 0, 4  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> name        : 2000-01-03
#> min value   :       53.5
#> max value   :      356.5
#> time        : 2000-01-03 00:00:00zUTC
```
