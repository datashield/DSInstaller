test_that("bundled registry is valid", {
  reg <- ds_registry(system.file("extdata", "registry.json", package = "DSInstaller"))
  expect_s3_class(reg, "ds_registry")
  expect_true(all(reg$aliases %in% names(reg$distributions)))
})

test_that("default source follows option, then env var, then bundled file", {
  path <- write_registry(valid_registry())
  withr::local_options(dsinstaller.registry = NULL)
  withr::local_envvar(DSINSTALLER_REGISTRY = "")
  expect_equal(registry_source(), default_registry())
  withr::local_envvar(DSINSTALLER_REGISTRY = path)
  expect_equal(registry_source(), path)
  withr::local_options(dsinstaller.registry = "other.json")
  expect_equal(registry_source(), "other.json")
})

test_that("valid registry is normalized", {
  reg <- load_registry(valid_registry())
  expect_equal(reg$aliases, c(stable = "2026.04", testing = "2026.10"))
  expect_named(reg$distributions, c("2026.04", "2026.10"))
  d <- reg$distributions[["2026.04"]]
  expect_equal(d$groups$survival$requires, "base")
  expect_equal(d$groups$base$requires, character())
  expect_equal(d$packages[[1]]$source, list(type = "cran"))
  expect_equal(d$packages[[1]]$groups, "base")
})

test_that("aliases and names resolve to distributions", {
  reg <- load_registry(valid_registry())
  expect_equal(resolve_distribution(reg, "stable")$name, "2026.04")
  expect_equal(resolve_distribution(reg, "testing")$name, "2026.10")
  expect_equal(resolve_distribution(reg, "2026.10")$name, "2026.10")
  expect_error(resolve_distribution(reg, "2020.01"), "Unknown distribution or alias '2020.01'")
})

test_that("missing or unreadable files are reported", {
  expect_error(ds_registry(tempfile()), "Registry file not found")
  bad <- tempfile(fileext = ".json")
  writeLines("{ not json", bad)
  expect_error(ds_registry(bad), "Cannot read registry")
})

# Each case breaks the valid registry in one way and checks the error.
invalid_cases <- list(
  list("unsupported schema", function(x) { x$schema <- 2; x }),
  list("non-empty array", function(x) { x$distributions <- list(); x }),
  list("duplicated distribution name '2026.04'", function(x) { x$distributions[[2]]$name <- "2026.04"; x }),
  list("must be date-based", function(x) { x$distributions[[2]]$name <- "bookworm"; x }),
  list("unknown alias 'lts'", function(x) { x$aliases$lts <- "2026.04"; x }),
  list("alias 'testing' targets unknown distribution '2027.01'", function(x) { x$aliases$testing <- "2027.01"; x }),
  list("'stable' target and must define 'repos'", function(x) { x$distributions[[1]]$repos <- NULL; x }),
  list("'status' must be one of", function(x) { x$distributions[[1]]$status <- "old"; x }),
  list("'released' must be a YYYY-MM-DD date", function(x) { x$distributions[[1]]$released <- "April"; x }),
  list("'r' must be a version constraint", function(x) { x$distributions[[1]]$r <- "4.3"; x }),
  list("'groups' must be a non-empty object", function(x) { x$distributions[[1]]$groups <- NULL; x }),
  list("group 'survival' requires unknown group 'omics'", function(x) {
    x$distributions[[1]]$groups$survival$requires <- list("omics"); x }),
  list("cyclic group requirements: base -> survival -> base", function(x) {
    x$distributions[[1]]$groups$base$requires <- list("survival"); x }),
  list("'packages' must be a non-empty array", function(x) { x$distributions[[1]]$packages <- list(); x }),
  list("package 'dsBase': 'version' must be", function(x) { x$distributions[[1]]$packages[[1]]$version <- "latest"; x }),
  list("package 'dsBase': 'side' must be", function(x) { x$distributions[[1]]$packages[[1]]$side <- "both"; x }),
  list("package 'dsBase': 'groups' must not be empty", function(x) { x$distributions[[1]]$packages[[1]]$groups <- list(); x }),
  list("package 'dsBase': undeclared group 'omics'", function(x) { x$distributions[[1]]$packages[[1]]$groups <- list("omics"); x }),
  list("duplicated package dsBase (server)", function(x) {
    x$distributions[[1]]$packages[[3]] <- x$distributions[[1]]$packages[[1]]; x }),
  list("'source.type' must be one of", function(x) { x$distributions[[1]]$packages[[1]]$source <- list(type = "svn"); x }),
  list("github source requires 'repo' and 'ref'", function(x) { x$distributions[[1]]$packages[[3]]$source$ref <- NULL; x }),
  list("url source requires 'url'", function(x) { x$distributions[[1]]$packages[[1]]$source <- list(type = "url"); x })
)

for (case in invalid_cases) {
  test_that(paste("invalid registry:", case[[1]]), {
    expect_error(load_registry(case[[2]](valid_registry())), case[[1]], fixed = TRUE)
  })
}
