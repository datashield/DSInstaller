# Replace install_packages() with a fake that writes DESCRIPTION files in lib.
# `versions` can force the installed version of a package (to simulate a bad
# install). Returns an environment recording calls.
mock_install <- function(versions = character(), env = parent.frame()) {
  calls <- new.env()
  calls$pkgs <- character()
  calls$repos <- NULL
  local_mocked_bindings(install_packages = function(pkgs, lib, repos) {
    calls$pkgs <- c(calls$pkgs, pkgs$name)
    calls$repos <- repos
    for (i in seq_len(nrow(pkgs))) {
      name <- pkgs$name[i]
      version <- if (name %in% names(versions)) versions[[name]] else pkgs$version[i]
      dir.create(file.path(lib, name), recursive = TRUE, showWarnings = FALSE)
      writeLines(c(paste("Package:", name), paste("Version:", version)),
                 file.path(lib, name, "DESCRIPTION"))
    }
  }, .env = env)
  calls
}

test_that("ds_install installs packages that are not ok", {
  reg <- load_registry(valid_registry())
  calls <- mock_install()
  lib <- fake_lib(c(dsBase = "6.3.1", dsSurvival = "2.3.0"))
  expect_message(st <- ds_install("stable", side = "server", lib = lib, registry = reg),
                 "Installing dsSurvival 2.2.0 (newer: 2.3.0)", fixed = TRUE)
  expect_equal(calls$pkgs, "dsSurvival")
  expect_equal(calls$repos, "https://packagemanager.posit.co/cran/2026-04-01")
  expect_equal(st$state, c("ok", "ok"))
  expect_message(ds_install("stable", side = "server", lib = lib, registry = reg), "are installed")
  expect_equal(calls$pkgs, "dsSurvival")
})

test_that("ds_install dry run installs nothing", {
  reg <- load_registry(valid_registry())
  calls <- mock_install()
  lib <- fake_lib(character())
  expect_message(st <- ds_install("stable", side = "client", lib = lib, dry_run = TRUE, registry = reg),
                 "Would install dsBaseClient 6.3.1")
  expect_equal(calls$pkgs, character())
  expect_equal(st$state, "missing")
})

test_that("ds_install repos can be overridden", {
  reg <- load_registry(valid_registry())
  calls <- mock_install()
  expect_message(ds_install("stable", lib = fake_lib(character()), repos = "https://cloud.r-project.org",
                            registry = reg), "dependencies are not pinned")
  expect_equal(calls$repos, "https://cloud.r-project.org")
})

test_that("ds_install falls back to the repos option without a snapshot", {
  reg <- load_registry(valid_registry())
  calls <- mock_install()
  withr::local_options(repos = c(CRAN = "https://example.org"))
  suppressMessages(ds_install("testing", side = "server", lib = fake_lib(character()), registry = reg))
  expect_equal(calls$repos, c(CRAN = "https://example.org"))
})

test_that("ds_install fails when a package is not at the expected version", {
  reg <- load_registry(valid_registry())
  mock_install(c(dsBaseClient = "6.4.0"))
  expect_error(suppressMessages(ds_install("stable", lib = fake_lib(character()), registry = reg)),
               "dsBaseClient 6.3.1 (newer)", fixed = TRUE)
})

test_that("ds_install checks the R version and status before installing", {
  x <- valid_registry()
  x$distributions[[1]]$r <- ">= 99.0"
  x$distributions[[2]]$status <- "eol"
  reg <- load_registry(x)
  calls <- mock_install()
  expect_error(ds_install("stable", lib = fake_lib(character()), registry = reg), "requires R >= 99.0")
  expect_equal(calls$pkgs, character())
  expect_warning(suppressMessages(ds_install("testing", side = "server", lib = fake_lib(character()),
                                             registry = reg)), "end-of-life")
})

test_that("check_r_version evaluates constraints", {
  expect_true(check_r_version(">= 4.3.0", "4.4.2"))
  expect_true(check_r_version("== 4.4.2", "4.4.2"))
  expect_false(check_r_version("< 4.4", "4.4.2"))
  expect_false(check_r_version(">4.4.2", "4.4.2"))
})

test_that("install_packages calls pak once with all references", {
  call <- NULL
  local_mocked_bindings(pkg_install = function(...) call <<- list(..., repos = getOption("repos")),
                        .package = "pak")
  pkgs <- packages_df(list(
    list(name = "a", version = "1.0", side = "client", groups = "g", source = list(type = "cran")),
    list(name = "b", version = "1.0", side = "client", groups = "g",
         source = list(type = "github", repo = "org/b", ref = "v1.0")),
    list(name = "c", version = "1.0", side = "client", groups = "g",
         source = list(type = "url", url = "https://example.org/c_1.0.tar.gz"))))
  install_packages(pkgs, lib = "L", repos = "R")
  expect_equal(call[[1]], c("a@1.0", "org/b@v1.0", "url::https://example.org/c_1.0.tar.gz"))
  expect_equal(call$lib, "L")
  expect_true(call$upgrade)
  expect_equal(call$repos, c(CRAN = "R"))
  expect_false(identical(getOption("repos"), c(CRAN = "R")))
  local_mocked_bindings(repo_resolve = function(x) c(CRAN = "BIN"), .package = "pak")
  install_packages(pkgs, lib = "L", repos = "https://packagemanager.posit.co/cran/2026-04-01")
  expect_equal(call$repos, c(CRAN = "https://packagemanager.posit.co/cran/2026-04-01", P3M1 = "BIN"))
})

test_that("p3m_binary_url resolves P3M snapshots only", {
  local_mocked_bindings(repo_resolve = function(x) c(CRAN = paste0("resolved:", x)), .package = "pak")
  expect_equal(p3m_binary_url("https://packagemanager.posit.co/cran/2026-04-01"), "resolved:PPM@2026-04-01")
  expect_equal(p3m_binary_url("https://cloud.r-project.org"), "https://cloud.r-project.org")
})
