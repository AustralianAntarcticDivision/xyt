## Submission

This is a new submission of the xyt package.

xyt extracts values from a raster time series at points that each carry their
own date-time. It is a standalone reimplementation, against 'terra', of the
point-in-time extraction machinery from the 'raadtools' package. It is not
derived from a published method, so there is no associated reference to cite in
the Description.

## Test environments

* local: Ubuntu 24.04, R 4.6.1
* GitHub Actions (planned): Windows, macOS, Ubuntu (release, devel, oldrel)

## R CMD check results

0 errors | 0 warnings | 1 note

The one NOTE is the expected first-submission note:

    checking CRAN incoming feasibility ... NOTE
    Maintainer: 'Michael D. Sumner <mdsumner@gmail.com>'
    New submission

## Notes for reviewers

* Examples, tests and the vignette run against a self-contained synthetic
  reader (`synthetic_reader()`) with no files, network or credentials behind
  it, so they build and run anywhere 'terra' is installed.
* The vignette's real-data section (using the 'geodata' package) is not
  evaluated, so building the vignette does not reach the network.
* mirai, mori and geodata are used only in Suggests and are guarded with
  `requireNamespace()`.
