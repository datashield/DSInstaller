# List the distributions of a registry

List the distributions of a registry

## Usage

``` r
ds_distributions(registry = ds_registry())
```

## Arguments

- registry:

  A registry, see \[ds_registry()\].

## Value

A data.frame with one row per distribution: \`name\`, \`title\`,
\`released\`, \`status\` and \`aliases\` (comma-separated).

## Examples

``` r
ds_distributions()
#>      name              title   released  status aliases
#> 1 2026.04 DataSHIELD 2026.04 2026-04-01  stable  stable
#> 2 2026.10 DataSHIELD 2026.10 2026-10-01 testing testing
```
