# Install a distribution

Installs the packages of a distribution that are not already installed
at the expected version: missing and outdated packages, and also newer
ones, which get downgraded to the pinned version.

## Usage

``` r
ds_install(
  dist = "stable",
  side = "client",
  groups = NULL,
  lib = .libPaths()[1],
  repos = NULL,
  dry_run = FALSE,
  registry = ds_registry()
)
```

## Arguments

- dist:

  A distribution name or alias, or a \`ds_distribution\` object.

- side:

  Side(s) to install: \`"client"\`, \`"server"\` or both.

- groups:

  Groups to include, \`NULL\` for all. The groups they require are
  included too.

- lib:

  Library to install into.

- repos:

  Repositories to install from. \`NULL\` uses the distribution's
  snapshot, or \`getOption("repos")\` if it has none.

- dry_run:

  If \`TRUE\`, only report what would be installed.

- registry:

  A registry, see \[ds_registry()\]. Not used when \`dist\` is a
  \`ds_distribution\` object.

## Value

The \[ds_status()\] data.frame after installation (before it when
\`dry_run\` is \`TRUE\`), invisibly. An error is raised if any package
is not at the expected version once installation is done.

## Details

Package dependencies come from the distribution's CRAN snapshot
(\`repos\` field), so that they are reproducible too. Pass \`repos\` to
override it, for instance \`repos = getOption("repos")\` to get
up-to-date dependencies.

## Examples

``` r
if (FALSE) { # \dontrun{
ds_install("stable", side = "client", groups = "survival", dry_run = TRUE)
} # }
```
