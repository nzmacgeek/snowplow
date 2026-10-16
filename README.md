# Snowplow

Snowplow is a PowerShell module for reading and administering ServiceNow instances
through the Table API.

## Quick start

```powershell
Import-Module ./Snowplow.psd1
Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential)

# Or save and reuse a named profile.
Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowClient -Environment Dev
Connect-Snowplow -Profile dev

# Read records (output objects have the Snowplow.Record.<table> type name).
Get-SnowRecord -Table incident -Query 'active=true' `
    -Fields number,short_description -Limit 20

# Writes support PowerShell ShouldProcess.
New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline' } -WhatIf
Set-SnowRecord -Table incident -SysId '<32-character-sys_id>' -Values @{ priority = '2' } -WhatIf
Remove-SnowRecord -Table incident -SysId '<32-character-sys_id>' -WhatIf

Disconnect-Snowplow
```

## Administrator cmdlets

- `Get-SnowRecord` reads from any table. Use `-Limit` to cap results or `-All` to
  page through every matching record.
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

## Configuration and backends

Sessions are stored in module scope and require HTTPS. OAuth is preferred;
explicit Basic authentication emits a deprecation warning. Credentials can be
provided as `PSCredential` objects or resolved from SecretManagement secret names.
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

Run the Pester tests with `Invoke-Pester ./Tests`.
