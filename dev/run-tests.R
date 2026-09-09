## Run the testthat files without testthat.
##
## The package's tests are ordinary testthat files and run under testthat in
## the usual way. This script exists so they can also be run somewhere that
## has terra and nothing else, which is a common state for a container built
## to read data rather than to develop packages. It defines just enough of
## the expect_* vocabulary to run these files, sources the package, and runs
## them.
##
##   Rscript dev/run-tests.R
##
## It is not a testthat replacement and is not part of the package. If a test
## file starts needing a feature this does not have, add the feature to the
## test's own terms or run it under testthat.

suppressMessages(library(terra))

.failures <- 0L
.passes <- 0L
.context <- ""

fail <- function(what, detail = "") {
  .failures <<- .failures + 1L
  cat(sprintf("  FAIL  %s%s\n", what, if (nzchar(detail)) paste0(" -- ", detail) else ""))
}
pass <- function() .passes <<- .passes + 1L

test_that <- function(desc, code) {
  .context <<- desc
  ok <- tryCatch({
    force(code)
    TRUE
  }, error = function(e) {
    fail(desc, paste("unexpected error:", conditionMessage(e)))
    FALSE
  })
  if (ok) cat(sprintf("  ok    %s\n", desc))
  invisible(NULL)
}

expect_equal <- function(object, expected, tolerance = 1e-8, ...) {
  cmp <- all.equal(object, expected, tolerance = tolerance,
                   check.attributes = FALSE)
  if (!isTRUE(cmp)) {
    stop(sprintf("expect_equal: %s", paste(cmp, collapse = "; ")), call. = FALSE)
  }
  pass()
  invisible(object)
}

expect_identical <- function(object, expected, ...) {
  if (!identical(object, expected)) stop("expect_identical failed", call. = FALSE)
  pass()
  invisible(object)
}

expect_true <- function(object, ...) {
  if (!isTRUE(object)) stop("expect_true failed", call. = FALSE)
  pass()
  invisible(object)
}

expect_false <- function(object, ...) {
  if (!isFALSE(object)) stop("expect_false failed", call. = FALSE)
  pass()
  invisible(object)
}

expect_type <- function(object, type, ...) {
  if (!identical(typeof(object), type)) {
    stop(sprintf("expect_type: got %s, wanted %s", typeof(object), type),
         call. = FALSE)
  }
  pass()
  invisible(object)
}

expect_length <- function(object, n, ...) {
  if (length(object) != n) {
    stop(sprintf("expect_length: got %i, wanted %i", length(object), n),
         call. = FALSE)
  }
  pass()
  invisible(object)
}

expect_error <- function(object, regexp = NULL, ...) {
  e <- tryCatch({
    force(object)
    NULL
  }, error = function(e) e)
  if (is.null(e)) stop("expect_error: no error was raised", call. = FALSE)
  if (!is.null(regexp) && !grepl(regexp, conditionMessage(e), fixed = FALSE)) {
    stop(sprintf("expect_error: message was '%s', wanted /%s/",
                 conditionMessage(e), regexp), call. = FALSE)
  }
  pass()
  invisible(e)
}

expect_warning <- function(object, regexp = NULL, ...) {
  w <- NULL
  val <- withCallingHandlers(force(object),
                             warning = function(cond) {
                               w <<- c(w, conditionMessage(cond))
                               invokeRestart("muffleWarning")
                             })
  if (is.null(w)) stop("expect_warning: no warning was raised", call. = FALSE)
  if (!is.null(regexp) && !any(grepl(regexp, w))) {
    stop(sprintf("expect_warning: messages were '%s', wanted /%s/",
                 paste(w, collapse = " | "), regexp), call. = FALSE)
  }
  pass()
  invisible(val)
}

## source the package, then the tests
.this_file <- sub("^--file=", "",
                  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
pkg <- if (length(.this_file) == 1L) dirname(dirname(normalizePath(.this_file))) else "."
if (!dir.exists(file.path(pkg, "R"))) {
  stop("run this from the package root, or as Rscript dev/run-tests.R", call. = FALSE)
}
for (f in list.files(file.path(pkg, "R"), pattern = "[.][Rr]$", full.names = TRUE)) {
  source(f)
}

files <- list.files(file.path(pkg, "tests", "testthat"),
                    pattern = "^test.*[.][Rr]$", full.names = TRUE)
for (f in files) {
  cat(sprintf("\n%s\n", basename(f)))
  ## each file gets its own environment, as testthat gives it
  env <- new.env(parent = globalenv())
  res <- tryCatch(sys.source(f, envir = env, keep.source = TRUE),
                  error = function(e) {
                    fail(basename(f), conditionMessage(e))
                    NULL
                  })
}

cat(sprintf("\n%i expectations passed, %i tests failed\n", .passes, .failures))
if (.failures > 0L) quit(status = 1L)
