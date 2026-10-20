# Installation and first connection

## Requirements

- PowerShell 7.2 or later (Windows, Linux or macOS).
- A ServiceNow instance reachable over HTTPS.
- An OAuth application registered in ServiceNow (see [Authentication](authentication.md)).
- Optional: `Microsoft.PowerShell.SecretManagement` and a vault, for unattended use.
- Optional: Node.js and `now-sdk`, only for the experimental Sdk backend.

## Install

Install from the PowerShell Gallery:

```powershell
Install-Module Snowplow -Scope CurrentUser -AllowPrerelease
Import-Module Snowplow -NoClobber
```

Or run from a clone of the repository:

```powershell
git clone https://github.com/nzmacgeek/snowplow.git
Import-Module ./snowplow/Snowplow.psd1 -NoClobber
```

`-NoClobber` stops the module's aliases (`snow`, `snowc`, `snowo`, `snowl`) from replacing
aliases you already have.

## Connect interactively

```powershell
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>'
```

Your browser opens for sign-in, so SSO and MFA work normally. On a headless machine add
`-NoBrowser` and open the printed URL elsewhere.

## Run your first query

```powershell
Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description -Limit 5
```

## Save a profile

Profiles save the instance and a *reference* to a secret, never the secret itself.

```powershell
Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Environment Dev
Connect-Snowplow -Profile dev -ClientCredentials
```

Tag production with `-Environment Prod`; Snowplow then warns on connect and blocks writes unless
you add `-AllowWrite`.

## Disconnect

```powershell
Disconnect-Snowplow
```

## Tips

- Run `Get-SnowTable -All | Out-Null` and `Get-SnowDictionary -Table incident -All | Out-Null`
  once to fill the cache that powers tab completion for `-Table` and `-Fields`.
- Use `Get-Help Get-SnowRecord -Examples` for built-in help, or the [cmdlet reference](cmdlets/index.md).
