# Build a reader from a catalogue and a slice function

The reader contract is one function that does two jobs, switched by
`returnfiles`. That shape exists so that functions written before this
package, raadtools' `read*` among them, satisfy it without being
touched. It is not a nice thing to write by hand: the return type
depends on the value of an argument, which is awkward to document and
easy to get subtly wrong.

## Usage

``` r
xyt_source(slice, catalogue)
```

## Arguments

- slice:

  a function of `(date, files, ...)` returning a single-layer SpatRaster
  for `date`. `files` is the catalogue.

- catalogue:

  the catalogue: a data.frame with a `date` column, or a function
  returning one. A function is called once, the first time it is needed,
  and the result is reused for the life of the source. Build a separate
  source if you need a different catalogue.

## Value

a function of class `xyt_reader` satisfying the reader contract.

## Details

`xyt_source()` writes it for you. You supply the two jobs separately,
each as an ordinary function with an ordinary signature, and get back
something
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
accepts.

## See also

[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
takes a `files` argument too, which is the other way to avoid writing
the flag: hand it the catalogue directly and the `returnfiles` call is
never made.

## Examples

``` r
## a series of two rasters held in a list
r <- lapply(1:2, function(i) {
  x <- terra::rast(terra::ext(0, 4, 0, 4), resolution = 1, crs = "EPSG:4326")
  terra::values(x) <- i
  x
})
src <- xyt_source(
  slice = function(date, files, ...) r[[which(files$date == date)]],
  catalogue = data.frame(date = as.POSIXct(c("2000-01-01", "2000-01-02"),
                                           tz = "UTC"))
)
extract_xyt(src, data.frame(x = 1, y = 1,
                            t = as.POSIXct("2000-01-02", tz = "UTC")))
#> [1] 2
```
