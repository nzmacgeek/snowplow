# Snowplow

[![CI](https://github.com/nzmacgeek/snowplow/actions/workflows/ci.yml/badge.svg)](https://github.com/nzmacgeek/snowplow/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Snowplow?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Snowplow)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Snowplow?label=downloads)](https://www.powershellgallery.com/packages/Snowplow)

Snowplow is a PowerShell module for reading and administering ServiceNow instances
through the Table API.

## Quick start

```powershell
Import-Module ./Snowplow.psd1 -NoClobber
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>'

# For unattended automation, use a dedicated service account and secret store:
$client = Get-Secret SnowplowOAuth
Connect-Snowplow -Instance dev12345 -ClientCredential $client -ClientCredentials

# Or save and reuse a named profile.
Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowClient -Environment Dev
Connect-Snowplow -Profile dev -ClientCredentials

# Read records (output objects have the Snowplow.Record.<table> type name).
Get-SnowRecord -Table incident -Query 'active=true' `
    -Fields number,short_description -Limit 20

# Build encoded queries instead of hand-writing separators.
$query = New-SnowQuery -Conditions ([ordered]@{
    active = 'true'
    priority = @{ Operator = 'IN'; Value = @('1', '2'); Joiner = 'OR' }
})
Get-SnowRecord -Table incident -Query $query

# Fluent conditions, relative dates, and ordering are also supported.
$query = New-SnowQuery |
    Where-SnowField sys_created_on -Operator '>' -Value (New-SnowRelativeDate -Last 7 -Unit Days) |
    Add-SnowOrderBy sys_created_on -Descending
Get-SnowRecord -Table incident -Query $query

# Writes support PowerShell ShouldProcess.
New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline' } -WhatIf
Set-SnowRecord -Table incident -SysId '<32-character-sys_id>' -Values @{ priority = '2' } -WhatIf
Remove-SnowRecord -Table incident -SysId '<32-character-sys_id>' -WhatIf

Disconnect-Snowplow
```

## Administrator cmdlets

- `Get-SnowRecord` reads from any table. Use `-Limit` to cap results or `-All` to
  page through every matching record. Its `-Query` parameter also accepts raw
  encoded query strings.
- `New-SnowQuery` builds encoded queries from a hashtable. `Where-SnowField` adds
  conditions, `Add-SnowOrderBy` adds sorting, and `New-SnowRelativeDate` creates
  `javascript:gs` relative-date values. Query-builder field parameters complete
  from the schema cache populated by `Get-SnowDictionary -All`.
- `New-SnowRecord`, `Set-SnowRecord`, and `Remove-SnowRecord` create, update, and
  delete records. They honor `-WhatIf` and `-Confirm`; updates use PATCH unless
  `-Replace` selects PUT.
- `Get-SnowTable` and `Get-SnowDictionary` inspect table and field definitions.
  Their results populate the cache used by `-Table` and `-Fields` tab completion.
- `Get-SnowCI` and `Get-SnowCIRelationship` provide convenience access to
  `cmdb_ci` and `cmdb_rel_ci`.
- `Export-SnowRecord` writes pipeline objects as CSV or JSON, to a file with
  `-Path` or as text on the pipeline.
- `Compare-SnowRecord -Reference $left -Difference $right` returns changed,
  added, and missing properties. Fetch the two input objects from separate
  connected instances to compare records across instances.
- `Get-SnowLink` builds a record, list, or table-definition URL. Use `-Number`
  instead of `-SysId` to resolve a record, `-Format Markdown|Html` for formatted
  links, `-Clipboard` to copy when clipboard support is available, and
  `-UseNavTo` for a classic frame-wrapped URL. `Open-SnowRecord` opens the same
  URLs in the default browser; it accepts `Get-SnowRecord` pipeline output,
  opens list views with `-Query`, and opens a table definition with `-Schema`.
  It returns URLs without opening the browser when passed `-PassThru`. Pipeline
  batches over five records ask for confirmation unless `-Force` is supplied.

## Interactive conveniences

The module exports these explicit aliases: `snow` for `Get-SnowRecord`, `snowc`
for `Connect-Snowplow`, `snowo` for `Open-SnowRecord`, and `snowl` for
`Get-SnowLink`. They are module-scoped aliases with names that do not overlap
PowerShell's built-in aliases on Windows, Linux, or macOS. Remove one after
import with `Remove-Item Alias:snow`, or override it with
`Set-Alias snow Get-SnowTable`. Import with `-NoClobber` to preserve any
same-named aliases already defined in the importing scope.

`Get-SnowplowPromptSegment` returns a colored segment for the active profile (or
instance); Prod is red and Test is yellow. It returns nothing when disconnected.
The module never changes your prompt or profile automatically. To add the
segment to a custom PowerShell prompt:

```powershell
function prompt {
    "$(Get-SnowplowPromptSegment) PS $($executionContext.SessionState.Path.CurrentLocation)> "
}
```

## Configuration and backends

Sessions are stored in module scope and require HTTPS. Authorization code with
PKCE is the default for interactive use; client credentials are intended for
unattended automation using a dedicated service account. Explicit Basic
authentication emits a deprecation warning. Credentials can be provided as
`PSCredential` objects or resolved from SecretManagement secret names.
Named profiles are stored per-user (`$HOME/.snowplow/profiles.json` on Unix-like
systems, the platform-equivalent config path on Windows) and store only instance,
auth, backend, environment, and optional SecretManagement secret references.
Prod-tagged profiles warn on connect, default to read-only, and require explicit
`-AllowWrite` plus confirmation for writes.
The REST backend retries 429/5xx responses with backoff (POST is retried on 429
only). `-Backend Rest|Sdk|Auto` is available on data cmdlets; Auto currently
selects REST. Sdk requires Node.js and a Node-resolvable `now-sdk` module; when
either is missing, the cmdlet reports a clear dependency message and recommends
REST.

### Client credentials profile with SecretStore

For unattended or repeat automation, store the OAuth client ID and client secret
as a `PSCredential` in a SecretManagement vault, then save only the secret name
in a Snowplow profile:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name SnowplowVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

# Enter the OAuth client secret at the secure password prompt.
$oauthClient = Get-Credential -UserName '<oauth-client-id>' -Message 'OAuth client credentials'
Set-Secret -Name SnowplowOAuth -Secret $oauthClient -Vault SnowplowVault

Add-SnowplowProfile -Name dev -Instance dev12345 `
    -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -Environment Dev
Connect-Snowplow -Profile dev -ClientCredentials

# Disconnect when finished.
Disconnect-Snowplow
```

The credential's username is the OAuth client ID and its password is the client
secret. Snowplow resolves the named secret from the specified vault when
connecting; the profile file contains the secret reference, not the credential.
SecretManagement and the SecretStore extension must be installed in the same
PowerShell environment used to connect.

Linux-specific installation, XDG paths, permissions, proxy/TLS configuration,
non-interactive credentials, and known limitations are described in
[docs/linux.md](docs/linux.md).

See [Authentication](docs/authentication.md) for grant selection, ServiceNow
OAuth application setup, refresh-token persistence, and troubleshooting.

On Linux, browser opening requires a graphical session and `xdg-open`; clipboard
copying requires an available desktop clipboard utility. The optional Sdk
backend's table adapter is not yet implemented, so use Rest.

Run the Pester tests with `Invoke-Pester ./Tests`.
