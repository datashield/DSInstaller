#' List the distributions of a registry
#'
#' @param registry A registry, see [ds_registry()].
#' @return A data.frame with one row per distribution: `name`, `title`,
#'   `released`, `status` and `aliases` (comma-separated).
#' @examples
#' ds_distributions()
#' @export
ds_distributions <- function(registry = ds_registry()) {
  dists <- registry$distributions
  field <- function(f) vapply(dists, function(d) if (is.null(d[[f]])) NA_character_ else d[[f]], "")
  data.frame(
    name = names(dists),
    title = field("title"),
    released = field("released"),
    status = field("status"),
    aliases = vapply(names(dists), function(n) paste(names(registry$aliases)[registry$aliases == n], collapse = ", "), ""),
    row.names = NULL
  )
}

#' Get a distribution
#'
#' @param name Distribution name (e.g. `"2026.04"`) or alias (`"stable"`,
#'   `"testing"`).
#' @param registry A registry, see [ds_registry()].
#' @return The distribution, an object of class `ds_distribution`.
#' @examples
#' ds_distribution("stable")
#' @export
ds_distribution <- function(name = "stable", registry = ds_registry()) {
  structure(resolve_distribution(registry, name), class = "ds_distribution")
}

#' List the packages of a distribution
#'
#' @param dist A distribution name or alias, or a `ds_distribution` object.
#' @param side Side(s) to include: `"client"`, `"server"` or both.
#' @param groups Groups to include, `NULL` for all. The groups they require
#'   are included too.
#' @param registry A registry, see [ds_registry()]. Not used when `dist` is a
#'   `ds_distribution` object.
#' @return A data.frame with one row per package: `name`, `version`, `side`,
#'   `groups` (comma-separated), `source` (`cran`, `github` or `url`) and
#'   `remote` (`repo@ref` for github, the URL for url, `NA` for cran).
#' @examples
#' ds_packages("stable", side = "client", groups = "survival")
#' @export
ds_packages <- function(dist = "stable", side = c("client", "server"), groups = NULL,
                        registry = ds_registry()) {
  if (!inherits(dist, "ds_distribution")) dist <- ds_distribution(dist, registry)
  side <- match.arg(side, SIDES, several.ok = TRUE)
  groups <- expand_groups(dist, groups)
  pkgs <- Filter(function(p) p$side %in% side && any(p$groups %in% groups), dist$packages)
  packages_df(pkgs)
}

# Groups plus everything they (transitively) require; NULL means all groups.
expand_groups <- function(dist, groups) {
  if (is.null(groups)) return(names(dist$groups))
  unknown <- setdiff(groups, names(dist$groups))
  if (length(unknown))
    stop("Unknown group '", unknown[1], "' in distribution '", dist$name, "'. Available: ",
         paste(names(dist$groups), collapse = ", "), call. = FALSE)
  repeat {
    expanded <- union(groups, unlist(lapply(dist$groups[groups], `[[`, "requires")))
    if (length(expanded) == length(groups)) return(groups)
    groups <- expanded
  }
}

packages_df <- function(pkgs) {
  chr <- function(f) vapply(pkgs, f, "")
  data.frame(
    name = chr(function(p) p$name),
    version = chr(function(p) p$version),
    side = chr(function(p) p$side),
    groups = chr(function(p) paste(p$groups, collapse = ", ")),
    source = chr(function(p) p$source$type),
    remote = chr(function(p) switch(p$source$type,
                                    cran = NA_character_,
                                    github = paste0(p$source$repo, "@", p$source$ref),
                                    url = p$source$url))
  )
}

#' @export
print.ds_registry <- function(x, ...) {
  cat("DataSHIELD registry with", length(x$distributions), "distribution(s)\n\n")
  print(ds_distributions(x), row.names = FALSE)
  invisible(x)
}

#' @export
print.ds_distribution <- function(x, ...) {
  cat("Distribution", x$name, if (!is.null(x$title)) paste("-", x$title), "\n")
  cat("  Status:  ", x$status, "\n")
  if (!is.null(x$released)) cat("  Released:", x$released, "\n")
  if (!is.null(x$r)) cat("  R:       ", x$r, "\n")
  if (!is.null(x$repos)) cat("  Repos:   ", x$repos, "\n")
  cat("  Groups:\n")
  for (g in names(x$groups)) {
    grp <- x$groups[[g]]
    cat("    -", g, if (!is.null(grp$title)) paste0("(", grp$title, ")"),
        if (length(grp$requires)) paste("requires", paste(grp$requires, collapse = ", ")), "\n")
  }
  cat("  Packages:\n")
  print(packages_df(x$packages), row.names = FALSE)
  invisible(x)
}
