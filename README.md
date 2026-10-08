# DSInstaller

Reproducible DataSHIELD runtime environments, on both the server and the client.

Website and function reference: <https://datashield.github.io/DSInstaller/>

A **distribution** is a set of DataSHIELD packages, at pinned versions, that are known to work together. Distributions have unique, date-based names (`2026.04`, `2026.10`, …) and are never modified once released. Two aliases point to them and move over time, as in Debian:

- `stable`: the conservative choice, validated, with dependencies pinned through a dated CRAN snapshot.
- `testing`: the upcoming distribution.

A distribution is split into **groups** (`base`, `resources`, `survival`, …), so you can install only the packages of the domains you need. A group can require other groups, which are then included too.

## Installation

```r
# install.packages("remotes")
remotes::install_github("datashield/DSInstaller")
```

## Registry

Distributions are listed in a JSON registry, maintained in this repository (`inst/extdata/registry.json`) and published with the package website at <https://datashield.github.io/DSInstaller/registry.json>. That's the registry DSInstaller uses by default. To use another registry, set an option or an environment variable to a file path or URL:

```r
options(dsinstaller.registry = "https://example.org/datashield/registry.json")
# or: Sys.setenv(DSINSTALLER_REGISTRY = "/path/to/registry.json")
```

A downloaded registry is kept for the R session and cached on disk, so the cached copy is used when you are offline. Without a cached copy, the registry bundled with the installed DSInstaller version is used.

```r
library(DSInstaller)

ds_registry()                  # registry summary
ds_registry(refresh = TRUE)    # download it again
ds_distributions()             # one row per distribution, with its aliases
ds_distribution("stable")      # details: status, R version, CRAN snapshot, groups, packages
```

## Client

List the client packages of a distribution, for some groups:

```r
ds_packages("stable", side = "client", groups = "survival")
```

Compare them with what is installed:

```r
ds_status("stable", side = "client")
#>                  name version installed    state
#>          dsBaseClient   6.3.1     6.3.0 outdated
#>                   DSI   1.7.1     1.8.0    newer
#>                DSOpal   1.5.0     1.5.0       ok
#>   DSMolgenisArmadillo   2.0.9      <NA>  missing
#>      dsSurvivalClient   2.2.0      <NA>  missing
```

(Output trimmed to the relevant columns.)

Install what is not at the expected version. Missing and outdated packages are installed, and newer ones are downgraded:

```r
ds_install("stable", side = "client", groups = "survival", dry_run = TRUE)  # what would be done
ds_install("stable", side = "client", groups = "survival")
```

Dependencies come from the distribution's CRAN snapshot. To keep the DataSHIELD packages pinned but get up-to-date dependencies, override the repositories:

```r
ds_install("stable", side = "client", repos = getOption("repos"))
```

## Server

The same functions install the server-side packages, for instance in an R server image:

```dockerfile
RUN Rscript -e 'DSInstaller::ds_install("stable", side = "server", groups = c("base", "resources"))'
```

From the client, check that the servers you are connected to match your distribution:

```r
conns <- DSI::datashield.login(logindata)
ds_check_servers(conns, "stable")
#>  server       name version installed   state
#>  study1     dsBase   6.3.1     6.3.1      ok
#>  study1  resourcer   1.5.0     1.5.0      ok
#>  study2     dsBase   6.3.1     6.3.0 outdated
#>  study2  resourcer   1.5.0      <NA>  missing
```

A package that a server doesn't report is `missing`: either it is not installed, or its DataSHIELD methods are not enabled in the server profile.

## Registry format

```json
{
  "schema": 1,
  "aliases": { "stable": "2026.04", "testing": "2026.10" },
  "distributions": [
    {
      "name": "2026.04",
      "title": "DataSHIELD 2026.04",
      "released": "2026-04-01",
      "status": "stable",
      "r": ">= 4.3.0",
      "repos": "https://packagemanager.posit.co/cran/2026-04-01",
      "groups": {
        "base": { "title": "Core DataSHIELD" },
        "survival": { "title": "Survival analysis", "requires": ["base"] }
      },
      "packages": [
        { "name": "dsBase", "version": "6.3.1", "side": "server", "groups": ["base"] },
        { "name": "dsBaseClient", "version": "6.3.1", "side": "client", "groups": ["base"] },
        { "name": "dsSurvival", "version": "2.2.0", "side": "server", "groups": ["survival"],
          "source": { "type": "github", "repo": "datashield/dsSurvival", "ref": "v2.2.0" } }
      ]
    }
  ]
}
```

- `name`: `YYYY.MM`, or `YYYY.MM.N` for a point release.
- `status`: `testing`, `stable`, `deprecated` or `eol`. Installing an `eol` distribution emits a warning.
- `r`: the R version required on both the server and the client.
- `repos`: a dated CRAN snapshot used for dependencies. It is required for the distribution that `stable` points to.
- Package `source`: `cran` (the default, installed at exactly `version`), `github` (`repo` and `ref`) or `url` (a source tarball URL).

The registry is validated when it is loaded, and errors name the distribution and package at fault. The full design is in [dev/PLAN.md](https://github.com/datashield/DSInstaller/blob/main/dev/PLAN.md).

### Editing a registry

Rather than editing the JSON by hand, load it, change it with the editing helpers and write it back. Every change is validated, so a mistake fails right away and the file is never left invalid:

```r
reg <- ds_registry("inst/extdata/registry.json")
reg <- ds_set_distribution(reg, "2027.04", from = "testing", released = NULL,
                           repos = "https://packagemanager.posit.co/cran/2027-04-01")
reg <- ds_set_package(reg, "2027.04", "dsBase", "server", version = "6.5.0")
reg <- ds_remove_package(reg, "2027.04", "DSMolgenisArmadillo")
reg <- ds_set_alias(reg, "testing", "2027.04")
ds_write_registry(reg, "inst/extdata/registry.json")
```

To check a registry file without changing it, load it with `ds_registry(path)`.
