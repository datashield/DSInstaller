# Compare installed packages with a distribution

Compare installed packages with a distribution

## Usage

``` r
ds_status(
  dist = "stable",
  side = "client",
  groups = NULL,
  lib = .libPaths(),
  registry = ds_registry()
)
```

## Arguments

- dist:

  A distribution name or alias, or a \`ds_distribution\` object.

- side:

  Side(s) to check: \`"client"\`, \`"server"\` or both.

- groups:

  Groups to include, \`NULL\` for all. The groups they require are
  included too.

- lib:

  Library path(s) to look into. As with \[library()\], the first library
  where a package is found is the one that counts.

- registry:

  A registry, see \[ds_registry()\]. Not used when \`dist\` is a
  \`ds_distribution\` object.

## Value

The \[ds_packages()\] data.frame with two more columns: \`installed\`
(installed version, \`NA\` if missing) and \`state\`, one of \`ok\`,
\`missing\`, \`outdated\` (older than expected) or \`newer\` (more
recent than expected).

## Examples

``` r
ds_status("stable", side = "client")
#>                  name version   side   groups source
#> 1        dsBaseClient   6.3.1 client     base   cran
#> 2                 DSI   1.7.1 client     base   cran
#> 3              DSOpal   1.5.0 client     base   cran
#> 4 DSMolgenisArmadillo   2.0.9 client     base   cran
#> 5    dsSurvivalClient   2.2.0 client survival github
#>                               remote installed   state
#> 1                               <NA>      <NA> missing
#> 2                               <NA>     1.8.0   newer
#> 3                               <NA>      <NA> missing
#> 4                               <NA>      <NA> missing
#> 5 datashield/dsSurvivalClient@v2.2.0      <NA> missing
```
