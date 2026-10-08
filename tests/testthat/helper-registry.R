# A minimal valid registry, as an R list mirroring the JSON document.
# JSON arrays are written as unnamed lists so they are not unboxed.
valid_registry <- function() {
  list(
    schema = 1,
    aliases = list(stable = "2026.04", testing = "2026.10"),
    distributions = list(
      list(
        name = "2026.04", status = "stable", released = "2026-04-01", r = ">= 4.3.0",
        repos = "https://packagemanager.posit.co/cran/2026-04-01",
        groups = list(base = list(title = "Core"), survival = list(requires = list("base"))),
        packages = list(
          list(name = "dsBase", version = "6.3.1", side = "server", groups = list("base")),
          list(name = "dsBaseClient", version = "6.3.1", side = "client", groups = list("base")),
          list(name = "dsSurvival", version = "2.2.0", side = "server", groups = list("survival"),
               source = list(type = "github", repo = "datashield/dsSurvival", ref = "v2.2.0"))
        )
      ),
      list(
        name = "2026.10", status = "testing",
        groups = list(base = list()),
        packages = list(
          list(name = "dsBase", version = "6.4.0", side = "server", groups = list("base"))
        )
      )
    )
  )
}

write_registry <- function(x) {
  path <- tempfile(fileext = ".json")
  jsonlite::write_json(x, path, auto_unbox = TRUE)
  path
}

load_registry <- function(x) ds_registry(write_registry(x))
