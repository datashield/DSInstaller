# Remote registries are tested with file:// URLs, served by download.file().
local_remote <- function(x, env = parent.frame()) {
  withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir(.local_envir = env), .local_envir = env)
  rm(list = ls(session_registries), envir = session_registries)
  path <- write_registry(x)
  paste0("file://", normalizePath(path))
}

test_that("a remote registry is downloaded, cached and kept for the session", {
  url <- local_remote(valid_registry())
  reg <- ds_registry(url)
  expect_s3_class(reg, "ds_registry")
  cached <- list.files(tools::R_user_dir("DSInstaller", "cache"), full.names = TRUE)
  expect_length(cached, 1)

  # the remote changes: the session copy is used until refresh
  x <- valid_registry()
  x$aliases$testing <- "2026.04"
  jsonlite::write_json(x, sub("^file://", "", url), auto_unbox = TRUE)
  expect_equal(ds_registry(url)$aliases[["testing"]], "2026.10")
  expect_equal(ds_registry(url, refresh = TRUE)$aliases[["testing"]], "2026.04")
})

test_that("the cached copy is used when the download fails", {
  url <- local_remote(valid_registry())
  ds_registry(url)
  unlink(sub("^file://", "", url))
  expect_warning(reg <- ds_registry(url, refresh = TRUE), "using the copy cached")
  expect_equal(reg$aliases[["stable"]], "2026.04")
})

test_that("a failed download without cache is an error", {
  url <- local_remote(valid_registry())
  unlink(sub("^file://", "", url))
  expect_error(ds_registry(url), "Cannot download registry")
})

test_that("an invalid remote registry is not cached", {
  x <- valid_registry()
  x$schema <- 2
  url <- local_remote(x)
  expect_error(ds_registry(url), "unsupported schema")
  expect_length(list.files(tools::R_user_dir("DSInstaller", "cache")), 0)
})
