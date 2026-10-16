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
  pkgs$state <- version_state(pkgs$installed, pkgs$version)
  pkgs
}

# Compare installed versions (NA when not installed) with expected ones.
version_state <- function(installed, expected) {
  vapply(seq_along(installed), function(i) {
    if (is.na(installed[i])) return("missing")
    inst <- package_version(installed[i])
    exp <- package_version(expected[i])
    if (inst == exp) "ok" else if (inst < exp) "outdated" else "newer"
  }, "")
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
  }
  if (dry_run) return(invisible(status))
  install_packages(todo, lib = lib, repos = repos)

  status <- ds_status(dist, side = side, groups = groups, lib = lib)
  bad <- status[status$state != "ok", ]
  if (nrow(bad))
    stop("Packages not at the expected version after installation: ",
         paste0(bad$name, " ", bad$version, " (", bad$state, ")", collapse = ", "), call. = FALSE)
  invisible(status)
}

# Install rows of ds_packages() with pak, in a single solve: conflicting pins
# fail before anything is installed. Dependencies are upgraded to the version
# available in repos, which aligns them on the distribution snapshot.
install_packages <- function(pkgs, lib, repos) {
  # an unnamed repos would make pak add its default CRAN mirror next to it
  if (is.null(names(repos))) names(repos) <- c("CRAN", rep("", length(repos) - 1))
  bin <- setdiff(vapply(repos, p3m_binary_url, ""), repos)
  if (length(bin)) repos <- c(repos, stats::setNames(bin, paste0("P3M", seq_along(bin))))
  old <- options(repos = repos)
  on.exit(options(old))
  pak::pkg_install(package_refs(pkgs), lib = lib, upgrade = TRUE, ask = FALSE)
}

# pak only gets Linux binaries from a P3M snapshot when given its platform
# specific URL, which repo_resolve() builds (other platforms get the URL as is).
# It is added next to the snapshot URL, not in place of it: with the binary URL
# only, pak silently ignores pins on archived versions.
p3m_binary_url <- function(url) {
  pattern <- "^https://packagemanager\\.posit\\.co/cran/(\\d{4}-\\d{2}-\\d{2})/?$"
  if (!grepl(pattern, url)) return(url)
  unname(pak::repo_resolve(paste0("PPM@", sub(pattern, "\\1", url))))
}

# pak package references of rows of ds_packages().
package_refs <- function(pkgs) {
  ifelse(pkgs$source == "cran", paste0(pkgs$name, "@", pkgs$version),
         ifelse(pkgs$source == "url", paste0("url::", pkgs$remote), pkgs$remote))
}

# Check an R version constraint such as ">= 4.3.0".
check_r_version <- function(constraint, r = getRversion()) {
  op <- sub("^(>=|>|<=|<|==).*$", "\\1", constraint)
  version <- trimws(substring(constraint, nchar(op) + 1))
  do.call(op, list(package_version(r), package_version(version)))
}
