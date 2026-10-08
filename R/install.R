#' Compare installed packages with a distribution
#'
#' @inheritParams ds_packages
#' @param side Side(s) to check: `"client"`, `"server"` or both.
#' @param lib Library path(s) to look into. As with [library()], the first
#'   library where a package is found is the one that counts.
#' @return The [ds_packages()] data.frame with two more columns: `installed`
#'   (installed version, `NA` if missing) and `state`, one of `ok`, `missing`,
#'   `outdated` (older than expected) or `newer` (more recent than expected).
#' @examples
#' ds_status("stable", side = "client")
#' @export
ds_status <- function(dist = "stable", side = "client", groups = NULL, lib = .libPaths(),
                      registry = ds_registry()) {
  pkgs <- ds_packages(dist, side = side, groups = groups, registry = registry)
  pkgs$installed <- vapply(pkgs$name, function(p)
    as.character(suppressWarnings(utils::packageDescription(p, lib.loc = lib, fields = "Version"))),
    "", USE.NAMES = FALSE)
  pkgs$state <- vapply(seq_len(nrow(pkgs)), function(i) {
    if (is.na(pkgs$installed[i])) return("missing")
    installed <- package_version(pkgs$installed[i])
    expected <- package_version(pkgs$version[i])
    if (installed == expected) "ok" else if (installed < expected) "outdated" else "newer"
  }, "")
  pkgs
}
