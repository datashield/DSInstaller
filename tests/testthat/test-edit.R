test_that("distributions are added, copied, updated and removed", {
  reg <- load_registry(valid_registry())
  reg <- ds_set_distribution(reg, "2027.04", from = "testing", status = "testing", released = NULL)
  expect_equal(reg$distributions[["2027.04"]]$packages, reg$distributions[["2026.10"]]$packages)
  reg <- ds_set_distribution(reg, "2027.04", title = "Next")
  expect_equal(reg$distributions[["2027.04"]]$title, "Next")
  reg <- ds_remove_distribution(reg, "2027.04")
  expect_named(reg$distributions, c("2026.04", "2026.10"))

  expect_error(ds_set_distribution(reg, "2026.10", from = "stable"), "already exists")
  expect_error(ds_set_distribution(reg, "2026.10", status = "old"), "'status' must be one of")
  expect_error(ds_set_distribution(reg, "2026.10", "old"), "must be named")
  expect_error(ds_remove_distribution(reg, "testing"), "alias 'testing' targets unknown")
})

test_that("aliases are set and removed", {
  reg <- load_registry(valid_registry())
  reg <- ds_set_alias(reg, "testing", NULL)
  expect_equal(reg$aliases, c(stable = "2026.04"))
  expect_error(ds_set_alias(reg, "stable", "2026.10"), "must define 'repos'")
  reg <- ds_set_alias(reg, "testing", "stable")
  expect_equal(reg$aliases, c(stable = "2026.04", testing = "2026.04"))
})

test_that("packages are added, updated and removed", {
  reg <- load_registry(valid_registry())
  reg <- ds_set_package(reg, "testing", "dsBaseClient", "client", version = "6.4.0", groups = "base")
  reg <- ds_set_package(reg, "testing", "dsBase", "server", version = "6.4.1")
  pkgs <- ds_packages("testing", registry = reg)
  expect_equal(pkgs$version[pkgs$name == "dsBase"], "6.4.1")
  expect_equal(pkgs$side[pkgs$name == "dsBaseClient"], "client")

  expect_error(ds_set_package(reg, "testing", "dsX", "server", version = "1.0"), "'groups' must not be empty")
  expect_error(ds_remove_package(reg, "testing", "dsX"), "No client/server package 'dsX'")
  reg <- ds_remove_package(reg, "testing", "dsBaseClient")
  expect_equal(ds_packages("testing", registry = reg)$name, "dsBase")
})

test_that("written registry reads back the same and keeps arrays", {
  reg <- ds_registry(system.file("extdata", "registry.json", package = "DSInstaller"))
  path <- tempfile(fileext = ".json")
  ds_write_registry(reg, path)
  expect_equal(ds_registry(path), reg)
  json <- paste(readLines(path), collapse = "\n")
  expect_match(json, '"groups": ["base"]', fixed = TRUE)
  expect_match(json, '"requires": ["base"]', fixed = TRUE)
  expect_match(json, '"description"', fixed = TRUE)
  expect_no_match(json, '"type": "cran"', fixed = TRUE)
})
