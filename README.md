# Snowplow

[![CI](https://github.com/nzmacgeek/snowplow/actions/workflows/ci.yml/badge.svg)](https://github.com/nzmacgeek/snowplow/actions/workflows/ci.yml)
[![Docs](https://github.com/nzmacgeek/snowplow/actions/workflows/docs.yml/badge.svg)](https://nzmacgeek.github.io/snowplow/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Snowplow?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Snowplow)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Snowplow?label=downloads)](https://www.powershellgallery.com/packages/Snowplow)

Snowplow is a PowerShell module for reading and administering ServiceNow instances through the
Table API. It was built with AI assistance, then reviewed and tested by a ServiceNow admin.

**Documentation:** <https://nzmacgeek.github.io/snowplow/> — getting started, real-world workflows
and a full cmdlet reference.

## Requirements

- PowerShell 7.2 or later on Windows, Linux or macOS
- A ServiceNow instance reachable over HTTPS
- An OAuth application on the instance ([setup guide](docs/authentication.md))

## Install

```powershell
Install-Module Snowplow -Scope CurrentUser -AllowPrerelease
Import-Module Snowplow -NoClobber
```

Or from a clone: `Import-Module ./Snowplow.psd1 -NoClobber`.

## Connect

```powershell
# Interactive: opens your browser (SSO and MFA work). Add -NoBrowser on headless machines.
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>'

# Unattended: client credentials from a dedicated service account
Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Secret SnowplowOAuth) -ClientCredentials

# Saved profile (stores a secret *name*, never the secret)
Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Environment Dev
Connect-Snowplow -Profile dev -ClientCredentials

Disconnect-Snowplow
```

Profiles tagged `-Environment Prod` warn on connect, are read-only by default and need
`-AllowWrite` plus confirmation to write.

## First commands

```powershell
# Read
Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description -Limit 20

# Build queries instead of hand-writing separators
$query = New-SnowQuery |
    Where-SnowField sys_created_on -Operator '>' -Value (New-SnowRelativeDate -Last 7 -Unit Days) |
    Add-SnowOrderBy sys_created_on -Descending
Get-SnowRecord -Table incident -Query $query

# Write (supports -WhatIf / -Confirm)
New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline' } -WhatIf
Set-SnowRecord -Table incident -SysId '<32-character-sys_id>' -Values @{ priority = '2' } -WhatIf

# Report
Get-SnowRecord -Table incident -Query 'active=true' -All | Export-SnowRecord -Format Csv -Path incidents.csv

# Follow the system log
Get-SnowSyslog -Level error -Wait -Pretty
```

Get help in the console with `Get-Help Get-SnowRecord -Examples`.

## Cmdlets

| Area | Cmdlets |
|------|---------|
| Connection | `Connect-Snowplow`, `Disconnect-Snowplow` |
| Profiles | `Add-`, `Get-`, `Set-`, `Remove-SnowplowProfile` |
| Records | `Get-SnowRecord`, `New-SnowRecord`, `Set-SnowRecord`, `Remove-SnowRecord`, `Export-SnowRecord`, `Compare-SnowRecord` |
| Queries | `New-SnowQuery`, `Find-SnowField` (alias `Where-SnowField`), `Add-SnowOrderBy`, `New-SnowRelativeDate` |
| Schema and CMDB | `Get-SnowTable`, `Get-SnowDictionary`, `Get-SnowCI`, `Get-SnowCIRelationship` |
| Logs and links | `Get-SnowSyslog`, `Get-SnowLink`, `Open-SnowRecord` |
| Settings and prompt | `Get-SnowplowConfiguration`, `Set-SnowplowConfiguration`, `Get-SnowplowPromptSegment` |

Aliases: `snow` (`Get-SnowRecord`), `snowc` (`Connect-Snowplow`), `snowo` (`Open-SnowRecord`),
`snowl` (`Get-SnowLink`). Import with `-NoClobber` to keep same-named aliases you already have.
Details for every cmdlet are in the [cmdlet reference](docs/cmdlets/index.md).

## Workflows

- [Incident triage](docs/workflows/incident-triage.md)
- [Querying and reporting](docs/workflows/querying-and-reporting.md)
- [Bulk updates safely](docs/workflows/bulk-updates.md)
- [CMDB investigation](docs/workflows/cmdb.md)
- [Comparing instances](docs/workflows/compare-instances.md)
- [Troubleshooting with the system log](docs/workflows/syslog.md)
- [Unattended automation](docs/workflows/automation.md)

## Configuration notes

- Sessions live in module scope and require HTTPS. Authorization code with PKCE is the
  default; client credentials are for unattended jobs. Basic authentication is deprecated.
- Profiles are stored per user (`$HOME/.snowplow/profiles.json` on Unix-like systems) and hold only
  instance, auth, backend, environment and secret references.
- The REST backend retries 429/5xx responses with backoff (POST only on 429). `-Backend Rest|Sdk|Auto`
  is available on data cmdlets; Auto currently selects REST. The Sdk backend needs Node.js and
  `now-sdk` and its table adapter is not yet implemented.
- Linux specifics (XDG paths, proxies, headless use): [docs/linux.md](docs/linux.md).
- Grant selection, OAuth app setup and troubleshooting: [docs/authentication.md](docs/authentication.md).

## Prompt indicator

```powershell
function prompt {
    "$(Get-SnowplowPromptSegment) PS $($executionContext.SessionState.Path.CurrentLocation)> "
}
```

Prod is shown in red and Test in yellow. The module never edits your prompt or profile.

## Contributing and docs

Run tests with `Invoke-Pester ./Tests`. Cmdlet documentation lives in each function's comment-based
help; regenerate the platyPS markdown with `./tools/Build-Docs.ps1` and preview the site with:

```bash
pip install -r docs/requirements.txt
mkdocs serve
```

The `Docs` workflow rebuilds and publishes the site to GitHub Pages on every push to `main`
(enable **Settings → Pages → Source: GitHub Actions** once). See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

See [LICENSE](LICENSE).
