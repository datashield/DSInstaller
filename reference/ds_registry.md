# Load a distributions registry

Reads and validates a registry of DataSHIELD distributions from a JSON
file or URL.

## Usage

``` r
ds_registry(source = NULL, refresh = FALSE)
```

## Arguments

- source:

  Path or URL of the registry JSON document.

- refresh:

  If \`TRUE\`, download the registry again even if it was already
  downloaded in this R session.

## Value

A validated registry, an object of class \`ds_registry\` with elements
\`schema\`, \`aliases\` (named character vector) and \`distributions\`
(list named by distribution name).

## Details

When \`source\` is \`NULL\`, the registry location is taken from the
\`dsinstaller.registry\` option, then from the \`DSINSTALLER_REGISTRY\`
environment variable, and finally defaults to the registry published on
the DSInstaller website.

A registry downloaded from a URL is kept for the rest of the R session,
and a copy is saved in the user cache directory (see
\[tools::R_user_dir()\]). When the download fails, that copy is used
instead, with a warning. For the default registry, if there is no such
copy either, the registry bundled with the package is used, also with a
warning.

## Examples

``` r
reg <- ds_registry()
names(reg$distributions)
#> [1] "2026.04" "2026.10"
```
