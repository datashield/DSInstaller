#' Load a distributions registry
#'
#' Reads and validates a registry of DataSHIELD distributions from a JSON file
#' or URL.
#'
#' When `source` is `NULL`, the registry location is taken from the
#' `dsinstaller.registry` option, then from the `DSINSTALLER_REGISTRY`
#' environment variable, and finally defaults to the registry published on the
#' DSInstaller website.
#'
#' A registry downloaded from a URL is kept for the rest of the R session, and
#' a copy is saved in the user cache directory (see [tools::R_user_dir()]).
#' When the download fails, that copy is used instead, with a warning. For the
#' default registry, if there is no such copy either, the registry bundled with
#' the package is used, also with a warning.
#'
#' @param source Path or URL of the registry JSON document.
#' @param refresh If `TRUE`, download the registry again even if it was already
#'   downloaded in this R session.
#' @return A validated registry, an object of class `ds_registry` with elements
#'   `schema`, `aliases` (named character vector) and `distributions` (list
#'   named by distribution name).
#' @examples
#' reg <- ds_registry()
#' names(reg$distributions)
#' @export
ds_registry <- function(source = NULL, refresh = FALSE) {
  if (is.null(source)) source <- registry_source()
  if (!grepl("^(https?|file)://", source)) return(read_registry(source))
  if (!refresh && !is.null(session_registries[[source]])) return(session_registries[[source]])

  cache <- file.path(tools::R_user_dir("DSInstaller", "cache"),
                     paste0(gsub("[^A-Za-z0-9._-]", "_", source), ".json"))
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  downloaded <- tryCatch({
    utils::download.file(source, tmp, quiet = TRUE, mode = "wb")
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (downloaded) {
    # an invalid registry fails here and is not cached
    reg <- read_registry(tmp, label = source)
    dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
    file.copy(tmp, cache, overwrite = TRUE)
  } else if (file.exists(cache)) {
    warning("Cannot download registry from ", source, ", using the copy cached on ",
            format(file.mtime(cache)), call. = FALSE)
    reg <- read_registry(cache, label = source)
  } else if (identical(source, default_registry())) {
    warning("Cannot download registry from ", source, ", using the copy bundled with DSInstaller ",
            utils::packageVersion("DSInstaller"), call. = FALSE)
    reg <- read_registry(system.file("extdata", "registry.json", package = "DSInstaller"))
  } else {
    stop("Cannot download registry from ", source, call. = FALSE)
  }
  session_registries[[source]] <- reg
  reg
}

session_registries <- new.env()

read_registry <- function(path, label = path) {
  if (!file.exists(path)) stop("Registry file not found: ", path, call. = FALSE)
  x <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                error = function(e) stop("Cannot read registry '", label, "': ",
                                         conditionMessage(e), call. = FALSE))
  structure(validate_registry(x), class = "ds_registry")
}

registry_source <- function() {
  src <- getOption("dsinstaller.registry")
  if (is.null(src)) src <- Sys.getenv("DSINSTALLER_REGISTRY")
  if (!nzchar(src)) src <- default_registry()
  src
}

# The registry published with the package website, see .github/workflows/pkgdown.yaml.
default_registry <- function() "https://datashield.github.io/DSInstaller/registry.json"

# Resolve an alias or distribution name to the distribution object.
resolve_distribution <- function(registry, name) {
  if (!is_string(name)) stop("Distribution name must be a single string", call. = FALSE)
  if (name %in% names(registry$aliases)) name <- registry$aliases[[name]]
  dist <- registry$distributions[[name]]
  if (is.null(dist))
    stop("Unknown distribution or alias '", name, "'. Available: ",
         paste(c(names(registry$aliases), names(registry$distributions)), collapse = ", "),
         call. = FALSE)
  dist
}

ALIASES <- c("stable", "testing")
STATUSES <- c("testing", "stable", "deprecated", "eol")
SIDES <- c("server", "client")
SOURCE_TYPES <- c("cran", "github", "url")

# Check the registry structure and normalize it: arrays become character
# vectors, distributions are named, and package sources get their default.
validate_registry <- function(x) {
  fail <- function(...) stop("Invalid registry: ", ..., call. = FALSE)
  if (!is.list(x) || is.null(names(x))) fail("expected a JSON object")
  if (!(is.numeric(x$schema) && length(x$schema) == 1 && x$schema == 1)) fail("unsupported schema '", format(x$schema), "', expected 1")

  if (!is.list(x$distributions) || length(x$distributions) == 0)
    fail("'distributions' must be a non-empty array")
  dists <- lapply(x$distributions, validate_distribution, fail = fail)
  dist_names <- vapply(dists, `[[`, "", "name")
  dup <- dist_names[duplicated(dist_names)]
  if (length(dup)) fail("duplicated distribution name '", dup[1], "'")
  names(dists) <- dist_names

  aliases <- x$aliases
  if (is.null(aliases)) aliases <- list()
  if (!is.list(aliases) || (length(aliases) && is.null(names(aliases))))
    fail("'aliases' must be an object")
  for (a in names(aliases)) {
    if (!a %in% ALIASES) fail("unknown alias '", a, "', expected one of: ", paste(ALIASES, collapse = ", "))
    if (!is_string(aliases[[a]]) || !aliases[[a]] %in% dist_names)
      fail("alias '", a, "' targets unknown distribution '", format(aliases[[a]]), "'")
  }
  aliases <- vapply(aliases, identity, "")
  if ("stable" %in% names(aliases) && is.null(dists[[aliases[["stable"]]]]$repos))
    fail("distribution '", aliases[["stable"]], "' is the 'stable' target and must define 'repos'")

  list(schema = x$schema, aliases = aliases, distributions = dists)
}

validate_distribution <- function(d, fail) {
  if (!is.list(d) || !is_string(d$name)) fail("each distribution must have a 'name'")
  if (!grepl("^[0-9]{4}\\.[0-9]{2}(\\.[0-9]+)?$", d$name))
    fail("distribution name '", d$name, "' must be date-based: YYYY.MM or YYYY.MM.N")
  fail_d <- function(...) fail("distribution '", d$name, "': ", ...)

  if (!is_string(d$status) || !d$status %in% STATUSES)
    fail_d("'status' must be one of: ", paste(STATUSES, collapse = ", "))
  if (!is.null(d$released) && (!is_string(d$released) || is.na(as.Date(d$released, format = "%Y-%m-%d"))))
    fail_d("'released' must be a YYYY-MM-DD date")
  if (!is.null(d$r) && (!is_string(d$r) || !grepl("^(>=|>|<=|<|==)\\s*[0-9]+(\\.[0-9]+)*$", d$r)))
    fail_d("'r' must be a version constraint such as '>= 4.3.0'")
  if (!is.null(d$repos) && !is_string(d$repos)) fail_d("'repos' must be a URL")

  if (!is.list(d$groups) || length(d$groups) == 0 || is.null(names(d$groups)))
    fail_d("'groups' must be a non-empty object")
  group_names <- names(d$groups)
  for (g in group_names) {
    req <- as.character(unlist(d$groups[[g]]$requires))
    unknown <- setdiff(req, group_names)
    if (length(unknown)) fail_d("group '", g, "' requires unknown group '", unknown[1], "'")
    d$groups[[g]]$requires <- req
  }
  cycle <- find_cycle(lapply(d$groups, `[[`, "requires"))
  if (length(cycle)) fail_d("cyclic group requirements: ", paste(cycle, collapse = " -> "))

  if (!is.list(d$packages) || length(d$packages) == 0) fail_d("'packages' must be a non-empty array")
  d$packages <- lapply(d$packages, validate_package, groups = group_names, fail = fail_d)
  keys <- vapply(d$packages, function(p) paste0(p$name, " (", p$side, ")"), "")
  dup <- keys[duplicated(keys)]
  if (length(dup)) fail_d("duplicated package ", dup[1])
  d
}

validate_package <- function(p, groups, fail) {
  if (!is.list(p) || !is_string(p$name)) fail("each package must have a 'name'")
  fail_p <- function(...) fail("package '", p$name, "': ", ...)
  if (!is_string(p$version) || !grepl("^[0-9]+([.-][0-9]+)+$", p$version))
    fail_p("'version' must be a valid R package version")
  if (!is_string(p$side) || !p$side %in% SIDES) fail_p("'side' must be 'server' or 'client'")

  p$groups <- as.character(unlist(p$groups))
  if (length(p$groups) == 0) fail_p("'groups' must not be empty")
  unknown <- setdiff(p$groups, groups)
  if (length(unknown)) fail_p("undeclared group '", unknown[1], "'")

  src <- if (is.null(p$source)) list(type = "cran") else p$source
  if (!is.list(src) || !is_string(src$type) || !src$type %in% SOURCE_TYPES)
    fail_p("'source.type' must be one of: ", paste(SOURCE_TYPES, collapse = ", "))
  if (src$type == "github" && !(is_string(src$repo) && is_string(src$ref)))
    fail_p("github source requires 'repo' and 'ref'")
  if (src$type == "url" && !is_string(src$url)) fail_p("url source requires 'url'")
  p$source <- src
  p
}

# Return the first cycle found in a named list of dependencies, or NULL.
find_cycle <- function(deps) {
  state <- rep("new", length(deps))
  names(state) <- names(deps)
  visit <- function(node, path) {
    if (state[[node]] == "active") return(c(path[which(path == node):length(path)], node))
    if (state[[node]] == "done") return(NULL)
    state[[node]] <<- "active"
    for (dep in deps[[node]]) {
      cycle <- visit(dep, c(path, node))
      if (length(cycle)) return(cycle)
    }
    state[[node]] <<- "done"
    NULL
  }
  for (node in names(deps)) {
    cycle <- visit(node, character())
    if (length(cycle)) return(cycle)
  }
  NULL
}

is_string <- function(x) is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)
