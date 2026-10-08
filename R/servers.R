#' Check DataSHIELD servers against a distribution
#'
#' Compares the server-side packages of a distribution with the packages
#' reported by the DataSHIELD servers, to tell whether the servers match the
#' distribution used on the client.
#'
#' Servers report the packages whose DataSHIELD methods are enabled in their
#' profile. A package that is not reported is `missing`: it is either not
#' installed, or its methods are not enabled.
#'
#' @param conns DataSHIELD connections, see [DSI::datashield.login()].
#' @inheritParams ds_packages
#' @return A data.frame with one row per server and package: `server`, `name`,
#'   `version` (expected), `installed` (reported by the server, `NA` if not
#'   reported) and `state`, one of `ok`, `missing`, `outdated` or `newer`.
#' @examples
#' \dontrun{
#' conns <- DSI::datashield.login(logindata)
#' ds_check_servers(conns, "stable")
#' }
#' @export
ds_check_servers <- function(conns, dist = "stable", groups = NULL, registry = ds_registry()) {
  if (!requireNamespace("DSI", quietly = TRUE))
    stop("Package 'DSI' is required to check servers", call. = FALSE)
  pkgs <- ds_packages(dist, side = "server", groups = groups, registry = registry)
  versions <- DSI::datashield.pkg_status(conns)$version_status
  rows <- lapply(colnames(versions), function(server) {
    installed <- versions[match(pkgs$name, rownames(versions)), server]
    data.frame(server = server, name = pkgs$name, version = pkgs$version,
               installed = as.character(installed))
  })
  res <- do.call(rbind, rows)
  res$state <- version_state(res$installed, res$version)
  res
}
