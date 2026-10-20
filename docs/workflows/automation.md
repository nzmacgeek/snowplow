# Unattended automation

**Scenario:** a nightly job exports open P1/P2 incidents; a CI pipeline checks a property before a
deployment. Use the OAuth *client credentials* grant with a dedicated, least-privilege service
account.

## One-time setup

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name SnowplowVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

$oauthClient = Get-Credential -UserName '<oauth-client-id>' -Message 'OAuth client secret'
Set-Secret -Name SnowplowOAuth -Secret $oauthClient -Vault SnowplowVault

Add-SnowplowProfile -Name nightly -Instance acme -ClientCredentialSecretName SnowplowOAuth `
    -Vault SnowplowVault -Environment Test
```

## Scheduled script

```powershell
Import-Module Snowplow
$vaultPassword = ConvertTo-SecureString $env:SNOWPLOW_VAULT_PASSWORD -AsPlainText -Force
$unlockParameters = @{ Password = $vaultPassword }
Unlock-SecretStore @unlockParameters

try {
    Connect-Snowplow -Profile nightly -ClientCredentials
    Get-SnowRecord -Table incident -Query 'active=true^priorityIN1,2' `
        -Fields number,short_description,priority,assignment_group -All |
        Export-SnowRecord -Format Csv -Path "/reports/p1p2-$(Get-Date -Format yyyyMMdd).csv"
}
finally {
    Disconnect-Snowplow
}
```

Configure the scheduler to inject the SecretStore password as `SNOWPLOW_VAULT_PASSWORD`.

## GitHub Actions

Store the OAuth client ID and secret as repository secrets and build the credential in the job.

```yaml
- name: Check property
  shell: pwsh
  env:
    SNOW_CLIENT_ID: ${{ secrets.SNOW_CLIENT_ID }}
    SNOW_CLIENT_SECRET: ${{ secrets.SNOW_CLIENT_SECRET }}
  run: |
    Install-Module Snowplow -Scope CurrentUser -Force -AllowPrerelease
    $secret = ConvertTo-SecureString $env:SNOW_CLIENT_SECRET -AsPlainText -Force
    $cred = [pscredential]::new($env:SNOW_CLIENT_ID, $secret)
    Connect-Snowplow -Instance acme -ClientCredential $cred -ClientCredentials
    $p = Get-SnowRecord -Table sys_properties -Query 'name=my.feature.flag'
    if ($p.value -ne 'true') { throw 'Feature flag is not enabled.' }
```

## Tips

- Use a separate service account and OAuth app per environment.
- Never tag an automation profile `Prod` with `-AllowWrite` unless the job truly needs to write.
- Add `-WhatIf` to write cmdlets while developing a job.

See [Authentication](../authentication.md) for OAuth application setup.
