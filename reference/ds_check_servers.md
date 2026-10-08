# Check DataSHIELD servers against a distribution

Compares the server-side packages of a distribution with the packages
reported by the DataSHIELD servers, to tell whether the servers match
the distribution used on the client.

## Usage

``` r
ds_check_servers(
  conns,
  dist = "stable",
  groups = NULL,
  registry = ds_registry()
)
```

## Arguments

- conns:

  DataSHIELD connections, see \[DSI::datashield.login()\].

- dist:

  A distribution name or alias, or a \`ds_distribution\` object.

- groups:

  Groups to include, \`NULL\` for all. The groups they require are
  included too.

- registry:

  A registry, see \[ds_registry()\]. Not used when \`dist\` is a
  \`ds_distribution\` object.

## Value

A data.frame with one row per server and package: \`server\`, \`name\`,
\`version\` (expected), \`installed\` (reported by the server, \`NA\` if
not reported) and \`state\`, one of \`ok\`, \`missing\`, \`outdated\` or
\`newer\`.

## Details

Servers report the packages whose DataSHIELD methods are enabled in
their profile. A package that is not reported is \`missing\`: it is
either not installed, or its methods are not enabled.

## Examples

``` r
if (FALSE) { # \dontrun{
conns <- DSI::datashield.login(logindata)
ds_check_servers(conns, "stable")
} # }
```
