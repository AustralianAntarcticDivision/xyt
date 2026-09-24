# Check a function against the reader contract

Runs the calls
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
will make, in the order it will make them, and reports what came back.
Use it when wiring up a new source, so a mismatch is a sentence about
the contract rather than an error from inside the extraction loop.

## Usage

``` r
xyt_reader_check(read, error = TRUE, ...)
```

## Arguments

- read:

  the function to check.

- error:

  stop on failure (the default), or return the report quietly.

- ...:

  passed to `read`, exactly as
  [`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
  would pass it.

## Value

invisibly, a data.frame with one row per check: `check`, `ok` and
`note`.

## Examples

``` r
xyt_reader_check(synthetic_reader())
#> PASS is a function
#> PASS read(returnfiles = TRUE) succeeds
#> PASS the catalogue is a data.frame: data.frame
#> PASS the catalogue has a 'date' column: date, fullname
#> PASS the dates are date-times: POSIXct/POSIXt
#> PASS the dates have no missing values
#> PASS the dates are in ascending order
#> PASS the catalogue has at least one row: 10 rows
#> PASS the series has a resolution: 1 days
#> PASS read(date, inputfiles = files) succeeds
#> PASS it returns a SpatRaster: SpatRaster
#> PASS it returns one layer: 1 layers
#> PASS it declares a coordinate reference system
#> PASS a second date reads too
#> PASS the two slices have the same geometry
#> PASS the two slices differ in value: identical slices usually mean the date argument was ignored
```
