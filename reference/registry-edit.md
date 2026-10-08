# Edit a distributions registry

Helpers for registry maintainers, to edit a registry without
hand-editing its JSON document. Each function returns the modified
registry, validated like \[ds_registry()\] does: an invalid change fails
with an error and nothing is modified. Save the result with
\`ds_write_registry()\`, which validates the registry again before
writing it.

## Usage

``` r
ds_set_distribution(registry, name, ..., from = NULL)

ds_remove_distribution(registry, name)

ds_set_alias(registry, alias, name)

ds_set_package(registry, dist, name, side, ...)

ds_remove_package(registry, dist, name, side = c("client", "server"))

ds_write_registry(registry, path)
```

## Arguments

- registry:

  A registry, see \[ds_registry()\].

- name:

  Distribution name (\`ds_set_distribution()\`), distribution name or
  alias (\`ds_remove_distribution()\`, \`ds_set_alias()\`), or package
  name.

- ...:

  Named fields to set.

- from:

  Name or alias of an existing distribution to copy the fields from,
  when creating a new distribution.

- alias:

  Alias to set, \`"stable"\` or \`"testing"\`. A \`NULL\` \`name\`
  removes the alias.

- dist:

  Name or alias of the distribution holding the package.

- side:

  Side of the package, \`"server"\` or \`"client"\`. When removing a
  package, both sides by default.

- path:

  Path of the JSON file to write.

## Value

The modified registry, an object of class \`ds_registry\` (invisibly for
\`ds_write_registry()\`).

## Details

Fields are given as named arguments in \`...\`, as in the JSON document
(e.g. \`status = "stable"\`, \`groups = c("base")\`, \`source =
list(type = "github", repo = "datashield/dsBase", ref = "v6.4.0")\`). A
field set to \`NULL\` is removed. Fields replace the existing value as a
whole: to add a group to a distribution, pass all its groups.

## Examples

``` r
reg <- ds_registry(system.file("extdata", "registry.json", package = "DSInstaller"))
# prepare the next release from the testing one
reg <- ds_set_distribution(reg, "2027.04", from = "testing", title = "DataSHIELD 2027.04",
                           released = NULL, repos = "https://packagemanager.posit.co/cran/2027-04-01")
reg <- ds_set_package(reg, "2027.04", "dsBase", "server", version = "6.5.0")
reg <- ds_remove_package(reg, "2027.04", "DSMolgenisArmadillo")
# promote it
reg <- ds_set_distribution(reg, "2026.10", status = "stable")
reg <- ds_set_alias(reg, "stable", "testing")
reg <- ds_set_alias(reg, "testing", "2027.04")
ds_write_registry(reg, tempfile(fileext = ".json"))
```
