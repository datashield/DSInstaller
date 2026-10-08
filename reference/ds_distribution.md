# Get a distribution

Get a distribution

## Usage

``` r
ds_distribution(name = "stable", registry = ds_registry())
```

## Arguments

- name:

  Distribution name (e.g. \`"2026.04"\`) or alias (\`"stable"\`,
  \`"testing"\`).

- registry:

  A registry, see \[ds_registry()\].

## Value

The distribution, an object of class \`ds_distribution\`.

## Examples

``` r
ds_distribution("stable")
#> Warning: Cannot download registry from https://datashield.github.io/DSInstaller/registry.json, using the copy bundled with DSInstaller 0.1.0
#> Distribution 2026.04 - DataSHIELD 2026.04 
#>   Status:   stable 
#>   Released: 2026-04-01 
#>   R:        >= 4.3.0 
#>   Repos:    https://packagemanager.posit.co/cran/2026-04-01 
#>   Groups:
#>     - base (Core DataSHIELD) 
#>     - resources (Resources) 
#>     - survival (Survival analysis) requires base 
#>   Packages:
#>                 name version   side    groups source
#>               dsBase   6.3.1 server      base   cran
#>         dsBaseClient   6.3.1 client      base   cran
#>                  DSI   1.7.1 client      base   cran
#>               DSOpal   1.5.0 client      base   cran
#>  DSMolgenisArmadillo   2.0.9 client      base   cran
#>            resourcer   1.5.0 server resources   cran
#>           dsSurvival   2.2.0 server  survival github
#>     dsSurvivalClient   2.2.0 client  survival github
#>                              remote
#>                                <NA>
#>                                <NA>
#>                                <NA>
#>                                <NA>
#>                                <NA>
#>                                <NA>
#>        datashield/dsSurvival@v2.2.0
#>  datashield/dsSurvivalClient@v2.2.0
```
