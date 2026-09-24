# Value of the synthetic series, computed directly

The closed form of what
[`synthetic_reader()`](https://australianantarcticdivision.github.io/xyt/reference/synthetic_reader.md)
holds, for writing expected values in tests without going through a
raster.

## Usage

``` r
synthetic_value(
  x,
  y,
  i,
  method = c("simple", "bilinear"),
  res = 1,
  origin = c(0, 0)
)
```

## Arguments

- x, y:

  coordinates. For `method = "simple"` these are snapped to the
  containing cell centre; for `"bilinear"` they are used as given.

- i:

  slice number, one-based. May be fractional, which is what
  `ctstime = TRUE` returns.

- method:

  `"simple"` or `"bilinear"`.

- res:

  cell size of the series.

- origin:

  lower left corner of the series.

## Value

a numeric vector.

## Examples

``` r
synthetic_value(0.7, 2.2, i = 3)
#> [1] 55.5
synthetic_value(0.7, 2.2, i = 3, method = "bilinear")
#> [1] 75.2
```
