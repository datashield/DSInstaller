test_that("ds_check_servers compares reported versions per server", {
  skip_if_not_installed("DSI")
  reg <- load_registry(valid_registry())
  versions <- matrix(c("6.3.1", "6.3.0", "2.3.0", NA), nrow = 2, byrow = TRUE,
                     dimnames = list(c("dsBase", "dsSurvival"), c("s1", "s2")))
  local_mocked_bindings(datashield.pkg_status = function(conns) list(version_status = versions),
                        .package = "DSI")
  res <- ds_check_servers(NULL, "stable", registry = reg)
  expect_equal(res$server, c("s1", "s1", "s2", "s2"))
  expect_equal(res$name, c("dsBase", "dsSurvival", "dsBase", "dsSurvival"))
  expect_equal(res$installed, c("6.3.1", "2.3.0", "6.3.0", NA))
  expect_equal(res$state, c("ok", "newer", "outdated", "missing"))
})

test_that("ds_check_servers works with DSLite servers", {
  skip_if_not_installed("DSLite")
  skip_if_not_installed("dsBase")
  x <- valid_registry()
  x$distributions[[1]]$packages[[1]]$version <- as.character(packageVersion("dsBase"))
  reg <- load_registry(x)

  server <- DSLite::newDSLiteServer(config = DSLite::defaultDSConfiguration(include = "dsBase"))
  # DSLite looks up the server object by name in the global environment
  assign("dsinstaller_test_server", server, envir = globalenv())
  withr::defer(rm("dsinstaller_test_server", envir = globalenv()))
  builder <- DSI::newDSLoginBuilder()
  builder$append(server = "s1", url = "dsinstaller_test_server", driver = "DSLiteDriver")
  conns <- suppressMessages(DSI::datashield.login(builder$build()))
  withr::defer(DSI::datashield.logout(conns))

  res <- ds_check_servers(conns, "stable", groups = "base", registry = reg)
  expect_equal(res$name, "dsBase")
  expect_equal(res$state, "ok")
})
