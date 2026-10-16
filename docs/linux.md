# Linux with PowerShell

Snowplow supports PowerShell 7.2 or later on Linux. The Ubuntu CI job and the
repository `Dockerfile` use PowerShell Core and run the Pester suite.

## Install and import

Install PowerShell 7 using your distribution's package instructions, then clone
or otherwise obtain this module and import its manifest:

```powershell
Import-Module ./Snowplow.psd1
Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential)
```

For CI or another non-interactive process, provide an OAuth access token without
prompting. Supply it from your CI secret store rather than embedding it in a
script:

```powershell
Connect-Snowplow -Instance dev12345 -AccessToken $env:SNOWPLOW_ACCESS_TOKEN
```

Tokens supplied this way are held only in the in-memory session and are not
written to profiles. Profiles store only connection metadata and secret names.
For OAuth credentials stored in SecretManagement, see the setup below. Linux
profile configuration is stored in `$XDG_CONFIG_HOME/snowplow` (default
`~/.config/snowplow`), with cache and data locations under the corresponding
XDG directories. The Snowplow config directory is restricted to the current
user.

## SecretManagement and SecretStore

Install and register the modules in the same PowerShell environment that runs
Snowplow:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name SnowplowVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

SecretStore prompts for a vault password on first use. Enter the password when
the interactive prompt appears; it is separate from the OAuth client secret.
Store an OAuth client credential and refer to it by name in a Snowplow profile:

```powershell
$client = Get-Credential -UserName '<oauth-client-id>' -Message 'OAuth client credentials'
Set-Secret -Name SnowplowOAuth -Secret $client -Vault SnowplowVault
Add-SnowplowProfile -Name dev -Instance dev12345 `
    -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -Environment Dev
Connect-Snowplow -Profile dev
```

For automation using password-protected SecretStore, provision the vault
interactively first and unlock it in the job before connecting:

```powershell
$vaultPassword = ConvertTo-SecureString $env:SNOWPLOW_VAULT_PASSWORD -AsPlainText -Force
$unlockParameters = @{ Password = $vaultPassword }
Unlock-SecretStore @unlockParameters
Connect-Snowplow -Profile dev
```

Alternatively, SecretStore can be configured without password authentication
and interaction for an isolated automation account:

```powershell
Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false
```

This removes the vault-password prompt but also removes password protection for
that account's vault. Do not use it on shared or otherwise untrusted machines.
Use CI's secret store for the vault password and OAuth material.

## Proxy and TLS

The REST backend uses PowerShell's `Invoke-RestMethod` and the platform's TLS
trust configuration. Set standard proxy environment variables before starting
PowerShell:

```sh
export HTTPS_PROXY=http://proxy.example:8080
export HTTP_PROXY=http://proxy.example:8080
export NO_PROXY=localhost,.internal.example
```

Install private certificate authorities into the operating system trust store.
`SSL_CERT_FILE` can point to a PEM bundle in environments where the .NET/OpenSSL
runtime uses that setting; the system trust store is the portable recommendation.
Snowplow does not disable certificate validation or install its own TLS handler.

## Desktop and known limitations

`Open-SnowRecord` uses `xdg-open` on Linux and returns a helpful error in a
headless session. `Get-SnowLink -Clipboard` uses available `wl-copy`, `xclip`, or
`xsel` utilities after trying PowerShell clipboard support; if none is usable,
it warns and still returns the link.

The optional Sdk backend currently requires Node.js and `now-sdk`, but its
Snowplow table-operation adapter is not implemented; use the Rest backend.
There is no Linux desktop integration in headless containers, and interactive
SecretStore password prompts require explicit unlocking or non-interactive
configuration as described above.

Run the tests locally with `Invoke-Pester ./Tests`, or reproduce the CI
environment with `docker build -t snowplow-linux .` and
`docker run --rm snowplow-linux`.
