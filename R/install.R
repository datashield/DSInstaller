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

#' Install a distribution
#'
#' Installs the packages of a distribution that are not already installed at
#' the expected version: missing and outdated packages, and also newer ones,
#' which get downgraded to the pinned version.
#'
#' Package dependencies come from the distribution's CRAN snapshot (`repos`
#' field), so that they are reproducible too. Pass `repos` to override it, for
#' instance `repos = getOption("repos")` to get up-to-date dependencies.
#'
#' @inheritParams ds_packages
#' @param side Side(s) to install: `"client"`, `"server"` or both.
#' @param lib Library to install into.
#' @param repos Repositories to install from. `NULL` uses the distribution's
#'   snapshot, or `getOption("repos")` if it has none.
#' @param dry_run If `TRUE`, only report what would be installed.
#' @return The [ds_status()] data.frame after installation (before it when
#'   `dry_run` is `TRUE`), invisibly. An error is raised if any package is
#'   not at the expected version once installation is done.
#' @examples
#' \dontrun{
#' ds_install("stable", side = "client", groups = "survival", dry_run = TRUE)
#' }
#' @export
ds_install <- function(dist = "stable", side = "client", groups = NULL, lib = .libPaths()[1],
                       repos = NULL, dry_run = FALSE, registry = ds_registry()) {
  if (!inherits(dist, "ds_distribution")) dist <- ds_distribution(dist, registry)
  if (dist$status == "eol") warning("Distribution '", dist$name, "' is end-of-life", call. = FALSE)
  if (!is.null(dist$r) && !check_r_version(dist$r))
    stop("Distribution '", dist$name, "' requires R ", dist$r, ", running ", getRversion(), call. = FALSE)
  if (is.null(repos)) {
    repos <- if (is.null(dist$repos)) getOption("repos") else dist$repos
  } else if (!is.null(dist$repos) && !identical(repos, dist$repos)) {
    message("Not using the distribution snapshot ", dist$repos, ": dependencies are not pinned")
  }

  status <- ds_status(dist, side = side, groups = groups, lib = lib)
  todo <- status[status$state != "ok", ]
  if (nrow(todo) == 0) {
    message("All packages of distribution '", dist$name, "' are installed")
    return(invisible(status))
  }
  for (i in seq_len(nrow(todo))) {
    pkg <- todo[i, ]
    message(if (dry_run) "Would install " else "Installing ", pkg$name, " ", pkg$version,
            if (is.na(pkg$installed)) "" else paste0(" (", pkg$state, ": ", pkg$installed, ")"))
    if (!dry_run) install_package(pkg, lib = lib, repos = repos)
  }
  if (dry_run) return(invisible(status))

  status <- ds_status(dist, side = side, groups = groups, lib = lib)
  bad <- status[status$state != "ok", ]
  if (nrow(bad))
    stop("Packages not at the expected version after installation: ",
         paste0(bad$name, " ", bad$version, " (", bad$state, ")", collapse = ", "), call. = FALSE)
  invisible(status)
}

# Install one row of ds_packages(). Dependencies are upgraded to the version
# available in repos, which aligns them on the distribution snapshot. This can
# also move a pinned package installed earlier, if repos has a more recent
# version of it: ds_install() then fails on its final check.
install_package <- function(pkg, lib, repos) {
  switch(pkg$source,
         cran = remotes::install_version(pkg$name, pkg$version, repos = repos, lib = lib,
                                         upgrade = "always", force = TRUE),
         github = remotes::install_github(pkg$remote, repos = repos, lib = lib,
                                          upgrade = "always", force = TRUE),
         url = remotes::install_url(pkg$remote, repos = repos, lib = lib,
                                    upgrade = "always", force = TRUE))
}

# Check an R version constraint such as ">= 4.3.0".
check_r_version <- function(constraint, r = getRversion()) {
  op <- sub("^(>=|>|<=|<|==).*$", "\\1", constraint)
  version <- trimws(substring(constraint, nchar(op) + 1))
  do.call(op, list(package_version(r), package_version(version)))
}
