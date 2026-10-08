# DSInstaller – Implementation Plan

## Goal

Define reproducible DataSHIELD runtime environments, on both the server (R server of Rock/Opal/Armadillo) and the client (analyst R session), by mapping package versions to a named **distribution**: a set of DataSHIELD packages known to work together.

The model is borrowed from Debian/Ubuntu:

- Each distribution has a **unique, immutable, date-based name** (`YYYY.MM`, e.g. `2026.10`).
- Two **aliases**, `stable` and `testing`, point to a distribution and move over time. `stable` only moves after a distribution has been validated.
- A distribution can be split into **groups** (domains such as `base`, `survival`, `omics`, `resources`) so users install only what they need.

The registry will eventually be published online. For a start it is a local JSON file.

## Concepts

| Concept | Description |
|---|---|
| Registry | A JSON document listing distributions and aliases. |
| Distribution | Unique name, metadata, and a list of pinned packages. Never modified once released (only its `status` can change). |
| Alias | `stable` or `testing`, which resolves to a distribution name. |
| Package | Name, exact version, side (`server` / `client`), install source, groups. |
| Group | A named domain subset of a distribution, with an optional dependency on other groups (e.g. `omics` requires `base`). |
| Side | `server` or `client`. One distribution covers both, so the server and client packages that must match are released together. |

## Registry format (v1)

```json
{
  "schema": 1,
  "aliases": {
    "stable": "2026.04",
    "testing": "2026.10"
  },
  "distributions": [
    {
      "name": "2026.10",
      "title": "DataSHIELD 2026.10",
      "released": "2026-10-01",
      "status": "testing",
      "r": ">= 4.3.0",
      "repos": "https://packagemanager.posit.co/cran/2026-10-01",
      "groups": {
        "base":     { "title": "Core DataSHIELD" },
        "survival": { "title": "Survival analysis", "requires": ["base"] },
        "omics":    { "title": "Omics", "requires": ["base", "resources"] },
        "resources":{ "title": "Resources" }
      },
      "packages": [
        { "name": "dsBase",           "version": "6.3.4", "side": "server", "groups": ["base"] },
        { "name": "dsBaseClient",     "version": "6.3.4", "side": "client", "groups": ["base"] },
        { "name": "DSI",              "version": "1.7.1", "side": "client", "groups": ["base"] },
        { "name": "DSOpal",           "version": "1.5.0", "side": "client", "groups": ["base"] },
        { "name": "resourcer",        "version": "1.5.0", "side": "server", "groups": ["resources"] },
        { "name": "dsSurvival",       "version": "2.3.0", "side": "server", "groups": ["survival"],
          "source": { "type": "github", "repo": "datashield/dsSurvival", "ref": "v2.3.0" } },
        { "name": "dsSurvivalClient", "version": "2.3.0", "side": "client", "groups": ["survival"],
          "source": { "type": "github", "repo": "datashield/dsSurvivalClient", "ref": "v2.3.0" } }
      ]
    }
  ]
}
```

(Versions above are only illustrative.)

Rules:

- `source` defaults to `{ "type": "cran" }`. Supported types: `cran` (installed at exactly `version`), `github` (`repo` + `ref`), and `url` (a tarball URL). Add more types only when a package actually needs one.
- `side` is either `"server"` or `"client"`. A package needed on both sides is listed twice.
- `name` matches `^\d{4}\.\d{2}(\.\d+)?$`. Distributions are immutable, so a fix to a released distribution is a new point release (e.g. `2026.10.1`).
- `r` is a single R version constraint that applies to both the server and the client.
- `repos` points to a dated CRAN snapshot so that **transitive dependencies** are reproducible too. It is optional in general but mandatory for the `stable` target. Without it, only the DataSHIELD packages are pinned and their dependencies come from current CRAN. At install time the user can override it to get updated dependencies (see `ds_install()`).
- `status` is one of `testing`, `stable`, `deprecated` or `eol`. It is informational, and installing an `eol` distribution emits a warning.
- `groups` on a package is required and must not be empty. A package belongs to every group it lists.

Validation (on load):

- `schema` is supported.
- Distribution names are unique and date-based.
- `aliases` only contains `stable` and/or `testing`, and each targets an existing distribution.
- The `stable` target has `repos`.
- Within a distribution, `(name, side)` is unique, every package group is declared, and `requires` references existing groups with no cycles.

## R API

All functions are exported with a `ds_` prefix.

```r
# Registry
ds_registry(source = getOption("dsinstaller.registry"))  # path or URL -> validated list (S3 "ds_registry")
ds_distributions(registry = ds_registry())               # data.frame: name, title, released, status, aliases

# Resolution
ds_distribution(name = "stable", registry = ds_registry())  # alias or name -> distribution object
ds_packages(dist = "stable", side = c("client", "server"),
            groups = NULL, registry = ds_registry())        # data.frame of packages, groups expanded with `requires`

# Local state
ds_status(dist = "stable", side = "client", groups = NULL,
          lib = .libPaths())     # data.frame: package, expected, installed, state (ok/missing/outdated/newer)

# Installation
ds_install(dist = "stable", side = "client", groups = NULL,
           lib = .libPaths()[1], repos = NULL,
           dry_run = FALSE)  # installs only what is not "ok", returns ds_status() invisibly
```

Default registry resolution: the `dsinstaller.registry` option, then the `DSINSTALLER_REGISTRY` environment variable, then the example registry bundled in `inst/extdata/registry.json`. Once a canonical online URL exists, it replaces the bundled file as the final fallback.

`groups = NULL` means all groups. Requested groups are expanded with their `requires` closure.

In `ds_install()`, `repos = NULL` uses the distribution's CRAN snapshot (or `getOption("repos")` if it has none). Pass `repos = getOption("repos")` to install the pinned DataSHIELD packages with up-to-date dependencies.

## Dependencies

- `jsonlite` (Imports): reads the registry.
- `remotes` (Imports): `install_version()` for CRAN, `install_github()`, `install_url()`. `pak` would be faster, but it is a heavier dependency. Reconsider if install speed becomes an issue.
- `testthat` (Suggests).

Everything else uses base R and `utils` (`packageVersion`, `installed.packages`, `compareVersion`).

## Files

```
R/registry.R      ds_registry(), validation, alias resolution
R/distribution.R  ds_distributions(), ds_distribution(), ds_packages()
R/install.R       ds_status(), ds_install()
inst/extdata/registry.json   example registry
tests/testthat/   fixtures (valid and invalid registries) + tests
```

Delete `R/hello.R`, `R/client.R` and `man/hello.Rd`.

## Phases

### 1. Registry: load, validate and resolve
- JSON reader (`jsonlite::fromJSON(simplifyVector = FALSE)`), normalized to plain lists. Packages become a data.frame in `ds_packages()` (phase 2).
- Validation rules above, with errors that name the offending distribution or package.
- Alias resolution.
- Bundled example registry.
- Tests: valid fixture, one fixture per validation rule, alias resolution, and an unknown name.

### 2. Query
- `ds_distributions()`, `ds_distribution()`, `ds_packages()` with side/group filtering and `requires` expansion.
- `print` methods for a readable console summary.
- Tests: group closure, side filtering.

### 3. Status
- `ds_status()` compares the installed versions in `lib` with the distribution. As with `library()`, the first library where a package is found counts, so `lib` defaults to all of `.libPaths()`. It returns the `ds_packages()` data.frame plus `installed` and `state`, so `ds_install()` can work from it directly.
- Tests: use a temporary library with fake `DESCRIPTION` files, so nothing is installed.

### 4. Install
- `ds_install()`: computes the status, then installs the `missing`, `outdated` and `newer` packages. Pinning means downgrading a newer package too, and the dry run shows this.
- Dependencies come from the distribution's `repos` snapshot unless the user overrides it with the `repos` argument. An override is reported in the output, since the environment is then no longer fully reproducible.
- Checks the `r` constraint against `getRversion()` before installing anything.
- Ends with a `ds_status()` check and fails if anything is still not `ok`.
- Server usage: the same function is called from a Rock image build or an R server session, e.g.
  `Rscript -e 'DSInstaller::ds_install("stable", side = "server", groups = "base")'`.

### 5. Online registry
- `source` accepts a URL (download to `tempfile()`, then the same reader as for local files).
- Cache the downloaded registry per session (or in `tools::R_user_dir("DSInstaller", "cache")`) and fall back to the cache when offline.
- Host the canonical registry in a dedicated git repo (e.g. `datashield/distributions`). Changes go through pull requests, and CI validates them with `ds_registry()`.

### 6. Later, only on demand
- **Server conformance check from the client**: use `DSI::datashield.pkg_status()` on the connections and compare the versions with the distribution's `server` packages, to tell the analyst whether the servers match their client distribution.
- Export a distribution as an `renv.lock` or a Dockerfile snippet.
- Signed/checksummed registry.

## Decisions

1. **Aliases**: Debian-style, `stable` and `testing` only.
2. **Naming**: date-based, `YYYY.MM` with an optional `.N` for point releases.
3. **CRAN snapshot**: mandatory for the `stable` target, and the user can override it at install time to get updated dependencies.
4. **R version**: one `r` constraint per distribution, shared by the server and the client.
