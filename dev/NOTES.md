# Open notes

## The two OISST vectors: parked, and not explained by `when`

Three extractions over ten points (x = 1:10 as longitude, y = the
`set.seed(1)` draw, first of each month of 2006):

    extract(readsst, d)                      27.30 28.54 28.88 28.34 28.20 26.18 26.01 24.58 25.37 NA
    extract_xyt(src, d)                      27.30 28.54 28.56 28.13 27.89 27.62 24.28 22.41 24.94 NA
    extract_xyt(src, d, when = "previous")   27.30 28.54 28.88 28.34 28.20 26.18 26.01 24.58 25.37 NA

The third matches the first to the last stored digit, so it looks at a glance
as though `when` explains it. It does not.

The queries are midnight GMT and the catalogue dates are exact midnights,
confirmed in the network:

``` r
as.numeric(t) - as.numeric(f$date[findInterval(as.numeric(t), as.numeric(f$date))])
#> 0
```

When a query lands exactly on a file's date, `"previous"` and `"nearest"`
select the same slice by construction, and they do: over a 16443-day daily
catalogue matching the OISST one, `.previous_index()` and `.nearest_index()`
return identical vectors for the first of each month of 2006. So the `when`
argument cannot have moved any of those ten values, and the agreement of the
first and third rows is not evidence that it did.

What is left is that the first two rows were not computed over the same
input. `set.seed(1)` was confirmed to be in effect for the later runs, and
`dev/reproduce-2014-goldens.R` consumes the generator if it is run in the
same session, so a `d` built without re-seeding would carry a different `y`
and land in different cells at the same longitudes. That fits the shape of it
(identical in the smooth January warm pool where OISST's hundredths make
neighbouring cells equal, diverging through the sharpening cold tongue to
2.2 C in August) but it is a hypothesis, not a finding.

Michael's call, 2026-09-09, is to leave it for manual testing once the
refactor is done, noting that some of the source files will have been
reprocessed in the meantime, which is its own source of difference over a
twelve-year gap.

The one thing to carry forward: `when = "previous"` reproduces raadtools
exactly wherever the two genuinely differ, and `when = "nearest"` is the
documented behaviour. Deciding which is the default belongs with the fold
back into raadtools.
