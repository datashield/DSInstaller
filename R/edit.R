#' Edit a distributions registry
#'
#' Helpers for registry maintainers, to edit a registry without hand-editing
#' its JSON document. Each function returns the modified registry, validated
#' like [ds_registry()] does: an invalid change fails with an error and
#' nothing is modified. Save the result with `ds_write_registry()`, which
#' validates the registry again before writing it.
#'
#' Fields are given as named arguments in `...`, as in the JSON document
#' (e.g. `status = "stable"`, `groups = c("base")`,
#' `source = list(type = "github", repo = "datashield/dsBase", ref = "v6.4.0")`).
#' A field set to `NULL` is removed. Fields replace the existing value as a
#' whole: to add a group to a distribution, pass all its groups.
#'
#' @param registry A registry, see [ds_registry()].
#' @param name Distribution name (`ds_set_distribution()`), distribution name
#'   or alias (`ds_remove_distribution()`, `ds_set_alias()`), or package name.
#' @param ... Named fields to set.
#' @param from Name or alias of an existing distribution to copy the fields
#'   from, when creating a new distribution.
#' @param alias Alias to set, `"stable"` or `"testing"`. A `NULL` `name`
#'   removes the alias.
#' @param dist Name or alias of the distribution holding the package.
#' @param side Side of the package, `"server"` or `"client"`. When removing a
#'   package, both sides by default.
#' @param path Path of the JSON file to write.
#' @return The modified registry, an object of class `ds_registry`
#'   (invisibly for `ds_write_registry()`).
#' @examples
#' reg <- ds_registry(system.file("extdata", "registry.json", package = "DSInstaller"))
#' # prepare the next release from the testing one
#' reg <- ds_set_distribution(reg, "2027.04", from = "testing", title = "DataSHIELD 2027.04",
#'                            released = NULL, repos = "https://packagemanager.posit.co/cran/2027-04-01")
#' reg <- ds_set_package(reg, "2027.04", "dsBase", "server", version = "6.5.0")
#' reg <- ds_remove_package(reg, "2027.04", "DSMolgenisArmadillo")
#' # promote it
#' reg <- ds_set_distribution(reg, "2026.10", status = "stable")
#' reg <- ds_set_alias(reg, "stable", "testing")
#' reg <- ds_set_alias(reg, "testing", "2027.04")
#' ds_write_registry(reg, tempfile(fileext = ".json"))
#' @name registry-edit
NULL

#' @rdname registry-edit
#' @export
ds_set_distribution <- function(registry, name, ..., from = NULL) {
  if (!is_string(name)) stop("Distribution name must be a single string", call. = FALSE)
  d <- registry$distributions[[name]]
  if (!is.null(from)) {
    if (!is.null(d)) stop("Distribution '", name, "' already exists", call. = FALSE)
    d <- resolve_distribution(registry, from)
  }
  if (is.null(d)) d <- list()
  d$name <- name
  registry$distributions[[name]] <- set_fields(d, list(...))
  revalidate(registry)
}

#' @rdname registry-edit
#' @export
ds_remove_distribution <- function(registry, name) {
  # an alias still targeting it makes the registry invalid
  registry$distributions[[resolve_distribution(registry, name)$name]] <- NULL
  revalidate(registry)
}

#' @rdname registry-edit
#' @export
ds_set_alias <- function(registry, alias, name) {
  alias <- match.arg(alias, ALIASES)
  aliases <- registry$aliases[names(registry$aliases) != alias]
  if (!is.null(name)) aliases[[alias]] <- resolve_distribution(registry, name)$name
  registry$aliases <- aliases
  revalidate(registry)
}

#' @rdname registry-edit
#' @export
ds_set_package <- function(registry, dist, name, side, ...) {
  side <- match.arg(side, SIDES)
  d <- resolve_distribution(registry, dist)
  i <- package_index(d, name, side)
  if (length(i) == 0) i <- length(d$packages) + 1
  p <- if (i <= length(d$packages)) d$packages[[i]] else list(name = name, side = side)
  d$packages[[i]] <- set_fields(p, list(...))
  registry$distributions[[d$name]] <- d
  revalidate(registry)
}

#' @rdname registry-edit
#' @export
ds_remove_package <- function(registry, dist, name, side = c("client", "server")) {
  side <- match.arg(side, SIDES, several.ok = TRUE)
  d <- resolve_distribution(registry, dist)
  i <- package_index(d, name, side)
  if (length(i) == 0)
    stop("No ", paste(side, collapse = "/"), " package '", name, "' in distribution '", d$name, "'",
         call. = FALSE)
  d$packages <- d$packages[-i]
  registry$distributions[[d$name]] <- d
  revalidate(registry)
}

#' @rdname registry-edit
#' @export
ds_write_registry <- function(registry, path) {
  x <- validate_registry(unclass(registry))
  x$aliases <- as.list(x$aliases)
  # drop the defaults added by validation, and keep arrays of one element as arrays
  x$distributions <- unname(lapply(x$distributions, function(d) {
    d$groups <- lapply(d$groups, function(g) {
      g$requires <- if (length(g$requires)) I(g$requires)
      if (length(g)) g else structure(list(), names = character())
    })
    d$packages <- lapply(d$packages, function(p) {
      p$groups <- I(p$groups)
      if (identical(p$source, list(type = "cran"))) p$source <- NULL
      p
    })
    d
  }))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE)
  invisible(registry)
}

set_fields <- function(x, fields) {
  if (length(fields) && (is.null(names(fields)) || !all(nzchar(names(fields)))))
    stop("Fields must be named arguments", call. = FALSE)
  for (f in names(fields)) x[[f]] <- fields[[f]]
  x
}

package_index <- function(dist, name, side) {
  which(vapply(dist$packages, function(p) p$name == name && p$side %in% side, NA))
}
