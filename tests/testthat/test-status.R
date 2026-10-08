# A library with fake installed packages, given as c(name = version).
fake_lib <- function(versions) {
  lib <- tempfile("lib")
  for (p in names(versions)) {
    dir.create(file.path(lib, p), recursive = TRUE)
    writeLines(c(paste("Package:", p), paste("Version:", versions[[p]])),
               file.path(lib, p, "DESCRIPTION"))
  }
  lib
}

test_that("ds_status reports ok, missing, outdated and newer packages", {
  reg <- load_registry(valid_registry())
  lib <- fake_lib(c(dsBase = "6.3.1", dsSurvival = "2.1.9"))
  st <- ds_status("stable", side = "server", lib = lib, registry = reg)
  expect_equal(st$name, c("dsBase", "dsSurvival"))
  expect_equal(st$installed, c("6.3.1", "2.1.9"))
  expect_equal(st$state, c("ok", "outdated"))

  lib <- fake_lib(c(dsBase = "6.3.10"))
  st <- ds_status("stable", side = "server", lib = lib, registry = reg)
  expect_equal(st$installed, c("6.3.10", NA))
  expect_equal(st$state, c("newer", "missing"))
})

test_that("ds_status uses the first library where a package is found", {
  reg <- load_registry(valid_registry())
  libs <- c(fake_lib(c(dsBaseClient = "6.3.0")), fake_lib(c(dsBaseClient = "6.3.1")))
  expect_equal(ds_status("stable", lib = libs, registry = reg)$state, "outdated")
  expect_equal(ds_status("stable", lib = rev(libs), registry = reg)$state, "ok")
})

test_that("ds_status passes side and groups filters", {
  reg <- load_registry(valid_registry())
  st <- ds_status("stable", side = "server", groups = "base", lib = fake_lib(character()), registry = reg)
  expect_equal(st$name, "dsBase")
  expect_equal(st$state, "missing")
})

test_that("ds_status handles an empty selection", {
  reg <- load_registry(valid_registry())
  st <- ds_status("testing", side = "client", lib = fake_lib(character()), registry = reg)
  expect_equal(nrow(st), 0)
  expect_type(st$state, "character")
})
