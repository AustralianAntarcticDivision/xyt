# Run the per-slice reads on mirai daemons

The work
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
does divides cleanly: one slice is read, the points that want it are
extracted, and a plain numeric vector comes back. Nothing is shared
between slices and no SpatRaster crosses a process boundary, so the
reads can be spread over daemons with no change to the answer.

## Usage

``` r
xyt_map_mirai(...)
```

## Arguments

- ...:

  passed to
  [`mirai::mirai_map()`](https://mirai.r-lib.org/reference/mirai_map.html).

## Value

a function of `(X, FUN)`, for
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)'s
`map` argument.

## Details

Start daemons in the usual way and
[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)
will use them without being told to:


      mirai::daemons(6)
      mirai::everywhere({ library(raadtools) })   # whatever the reader needs
      extract_xyt(read, xyt)
      mirai::daemons(0)

[`mirai::everywhere()`](https://mirai.r-lib.org/reference/everywhere.html)
matters: a daemon runs the reader in a fresh session, so any package the
reader reaches for has to be loaded there. The reader itself is sent
along with the task.

Whether this is faster depends on where the bytes come from. Reading a
hundred slices off a remote store is latency bound and parallelises
well. Reading ten slices off a local disk that is already saturated will
not.

## See also

[`extract_xyt()`](https://australianantarcticdivision.github.io/xyt/reference/extract_xyt.md)

## Examples

``` r
if (requireNamespace("mirai", quietly = TRUE)) {
  ## a mapper to hand to extract_xyt(map = )
  mapper <- xyt_map_mirai()
  mapper
}
#> function (X, FUN) 
#> {
#>     m <- do.call(mirai::mirai_map, c(list(.x = X, .f = FUN), 
#>         args))
#>     out <- m[]
#>     bad <- vapply(out, inherits, logical(1), "miraiError")
#>     if (any(bad)) {
#>         stop("a slice failed on a mirai daemon: ", conditionMessage(out[[which(bad)[1L]]]), 
#>             "\n  a daemon starts with a bare session; mirai::everywhere() is where", 
#>             "\n  the packages your reader needs get loaded", 
#>             call. = FALSE)
#>     }
#>     out
#> }
#> <bytecode: 0x55696e495258>
#> <environment: 0x55696e4940a0>
```
