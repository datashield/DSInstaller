# List the packages of a distribution

List the packages of a distribution

## Usage

``` r
ds_packages(
  dist = "stable",
  side = c("client", "server"),
  groups = NULL,
  registry = ds_registry()
)
```

## Arguments

- dist:

  A distribution name or alias, or a \`ds_distribution\` object.

- side:

  Side(s) to include: \`"client"\`, \`"server"\` or both.

- groups:

  Groups to include, \`NULL\` for all. The groups they require are
  included too.

- registry:

  A registry, see \[ds_registry()\]. Not used when \`dist\` is a
  \`ds_distribution\` object.

## Value

A data.frame with one row per package: \`name\`, \`version\`, \`side\`,
\`groups\` (comma-separated), \`source\` (\`cran\`, \`github\` or
\`url\`) and \`remote\` (\`repo@ref\` for github, the URL for url,
\`NA\` for cran).

## Examples

``` r
ds_packages("stable", side = "client", groups = "survival")
#>                  name version   side   groups source
#> 1        dsBaseClient   6.3.1 client     base   cran
#> 2                 DSI   1.7.1 client     base   cran
#> 3              DSOpal   1.5.0 client     base   cran
#> 4 DSMolgenisArmadillo   2.0.9 client     base   cran
#> 5    dsSurvivalClient   2.2.0 client survival github
#>                               remote
#> 1                               <NA>
#> 2                               <NA>
#> 3                               <NA>
#> 4                               <NA>
#> 5 datashield/dsSurvivalClient@v2.2.0
```
