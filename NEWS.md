# xyt 0.1.0

First release. `xyt` lifts the `extract(<read function>, <data.frame>)`
machinery out of raadtools, rewrites it against terra, and gives it a test
suite that runs with no data behind it.

* New `extract_xyt(read, xyt, ...)` extracts values from a raster time series
  at points that each carry their own date-time. The series is described by a
  reader function rather than held in memory, so only the slices some point
  needs are read, and each of those is read exactly once, in catalogue order,
  whatever order the rows arrive in.
* The reader contract is two calls: `read(returnfiles = TRUE, ...)` returns a
  catalogue data.frame with a `date` column, and `read(date, inputfiles =
  files, ...)` returns a single-layer SpatRaster. raadtools readers satisfy it
  unchanged.
* New `xyt_reader_check()` runs those calls in the order `extract_xyt()` will
  make them and reports PASS/FAIL for each step of the contract.
* New `xyt_source(slice, catalogue)` builds a reader from two ordinary
  functions, so the `returnfiles` switch never has to be written by hand. A
  catalogue given as a function is called once, on first use, and reused for
  the life of the source. Sources have a `print()` method.
* `extract_xyt(files = )` accepts a pre-built catalogue, in which case the
  `returnfiles` call is never made and the reader only has to read slices.
* New `synthetic_reader()` and `synthetic_value()` provide a series with no
  files behind it, with a closed-form value at any (x, y, t), so tests and
  examples run anywhere terra is installed.
* `when = c("nearest", "previous")` makes the time-matching rule explicit.
  raadtools documented `ctstime = FALSE` as nearest-in-time but implemented
  it with `findInterval()`, i.e. the previous slice. `"nearest"` is the
  default and matches the documentation; `"previous"` reproduces the
  raadtools numbers.
* `ctstime = TRUE` interpolates linearly between the two slices that bracket
  each point; `method = "bilinear"` interpolates in space as well.
* `fact` aggregates each slice before extraction, and `crs` sets the
  coordinate system the input points are in (default `"EPSG:4326"`); points
  are projected to the raster's CRS as needed.
* Points beyond the collection in time return `NA` with a warning rather
  than stopping the call. `tolerance` sets how far is too far, defaulting to
  1.5 times the spacing of the series.
* `...` is passed to the reader only. In raadtools it also went to
  `extract()`, which was the source of the `xylim argument ignored` and
  `inputfiles argument ignored` warnings. Extraction is controlled by named
  arguments.
* Character times are parsed one element at a time, so a track mixing
  whole days and date-times no longer has its times of day silently dropped
  by `as.POSIXct()` picking one format from the first element.
* Slice reads can run in parallel on mirai daemons. If `mirai::daemons()`
  are running, `extract_xyt()` uses them without being told to; `map` takes
  any function of `(X, FUN)`, so `map = lapply` forces serial reads and any
  other mapper can be dropped in. New `xyt_map_mirai()` is the mapper used.
  The first slice is always read in the calling session, so it supplies the
  target CRS for every other task and a failing reader fails once rather
  than once per daemon.
* When mori is installed and daemons are running, the catalogue is placed in
  shared memory with `mori::share()` rather than serialised into every task
  (about 2.7 MB down to 284 bytes per task on a 16,000-row OISST catalogue,
  roughly halving wall time on six daemons). `share = TRUE` insists, `share
  = FALSE` refuses, and with no mori installed nothing changes.
* No S4. raadtools registered this as a method on raster's `extract`
  generic, which welded it to raster; `extract_xyt()` is a plain function
  with terra as the only hard dependency. mirai, mori and testthat are in
  Suggests.
* `dev/bench-mirai.R` benchmarks serial against daemon reads for a given
  collection and reports the serialised size of the catalogue payload.