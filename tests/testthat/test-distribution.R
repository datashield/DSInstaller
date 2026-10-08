test_that("ds_distributions lists distributions with their aliases", {
  reg <- load_registry(valid_registry())
  df <- ds_distributions(reg)
  expect_equal(df$name, c("2026.04", "2026.10"))
  expect_equal(df$aliases, c("stable", "testing"))
  expect_equal(df$released, c("2026-04-01", NA))
})

test_that("ds_distribution resolves aliases", {
  reg <- load_registry(valid_registry())
  d <- ds_distribution("stable", reg)
  expect_s3_class(d, "ds_distribution")
  expect_equal(d$name, "2026.04")
})

test_that("ds_packages filters by side", {
  reg <- load_registry(valid_registry())
  expect_equal(ds_packages("stable", side = "server", registry = reg)$name, c("dsBase", "dsSurvival"))
  expect_equal(ds_packages("stable", side = "client", registry = reg)$name, "dsBaseClient")
  expect_equal(nrow(ds_packages("stable", registry = reg)), 3)
  expect_error(ds_packages("stable", side = "both", registry = reg))
})

test_that("ds_packages expands required groups", {
  reg <- load_registry(valid_registry())
  expect_equal(ds_packages("stable", groups = "base", registry = reg)$name, c("dsBase", "dsBaseClient"))
  expect_equal(ds_packages("stable", groups = "survival", registry = reg)$name,
               c("dsBase", "dsBaseClient", "dsSurvival"))
  expect_error(ds_packages("stable", groups = "omics", registry = reg), "Unknown group 'omics'")
})

test_that("group expansion is transitive", {
  d <- list(name = "x", groups = list(a = list(requires = "b"), b = list(requires = "c"),
                                      c = list(requires = character()), d = list(requires = character())))
  expect_setequal(expand_groups(d, "a"), c("a", "b", "c"))
})

test_that("ds_packages describes sources", {
  reg <- load_registry(valid_registry())
  df <- ds_packages(ds_distribution("stable", reg), side = "server")
  expect_equal(df$source, c("cran", "github"))
  expect_equal(df$remote, c(NA, "datashield/dsSurvival@v2.2.0"))
})

test_that("print methods render", {
  reg <- load_registry(valid_registry())
  expect_output(print(reg), "2 distribution")
  expect_output(print(ds_distribution("stable", reg)), "survival.*requires base")
})
