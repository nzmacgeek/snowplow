function Connect-Snowplow {
    <#
    .SYNOPSIS
        Connects to a ServiceNow instance and stores the session in module scope.
    .DESCRIPTION
        OAuth is the default and recommended method (client_credentials grant when only
        -ClientCredential is supplied; legacy password grant if -Credential is added too).
        Basic auth is supported for legacy use only, must be requested explicitly and warns.
        Secrets are only accepted as PSCredential or SecretManagement secret names.
    .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential)
    .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientCredentialSecretName SnowClient -Vault MyVault
    #>
    [CmdletBinding(DefaultParameterSetName = 'OAuth')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Instance,
        [ValidateSet('OAuth', 'Basic')][string]$AuthMethod = 'OAuth',
        # OAuth client id (UserName) and client secret (Password).
        [pscredential]$ClientCredential,
        # Basic auth user, or the user for the legacy OAuth password grant.
        [pscredential]$Credential,
        # SecretManagement secret names (must resolve to a PSCredential).
        [string]$ClientCredentialSecretName,
        [string]$CredentialSecretName,
        [string]$Vault,
        [switch]$SkipValidation
    )

    $baseUri = Resolve-SnowInstanceUri -Instance $Instance

    $fromVault = {
        param($name)
        if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
            throw [System.InvalidOperationException]::new('Microsoft.PowerShell.SecretManagement is required to use secret names.')
        }
        $args2 = @{ Name = $name; ErrorAction = 'Stop' }
        if ($Vault) { $args2.Vault = $Vault }
        $secret = Get-Secret @args2
        if ($secret -isnot [pscredential]) {
            throw [System.ArgumentException]::new("Secret '$name' must be a PSCredential.")
        }
        $secret
    }
    if ($ClientCredentialSecretName) { $ClientCredential = & $fromVault $ClientCredentialSecretName }
    if ($CredentialSecretName) { $Credential = & $fromVault $CredentialSecretName }

    if ($AuthMethod -eq 'Basic') {
        if (-not $Credential) { throw [System.ArgumentException]::new('Basic auth requires -Credential or -CredentialSecretName.') }
        Write-Warning 'Basic authentication is deprecated for ServiceNow integrations. Prefer OAuth (-ClientCredential).'
    }
    else {
        if (-not $ClientCredential) { throw [System.ArgumentException]::new('OAuth requires -ClientCredential or -ClientCredentialSecretName.') }
        if ($Credential) { Write-Warning 'The OAuth password grant is legacy; prefer client credentials where your release supports it.' }
    }

    $session = [pscustomobject]@{
        BaseUri          = $baseUri
        AuthMethod       = $AuthMethod
        Credential       = $Credential
        ClientCredential = $ClientCredential
        AccessToken      = $null
        ExpiresAt        = [datetime]::MinValue
        ConnectedAt      = [datetime]::UtcNow
    }

    $previous = $script:SnowplowSession
    $script:SnowplowSession = $session
    try {
        if (-not $SkipValidation) {
            # Fetches a token (OAuth) and proves the credentials can reach the Table API.
            $null = Invoke-SnowRequest -Table sys_user -Fields sys_id -First 1 -PageSize 1
        }
    }
    catch {
        $script:SnowplowSession = $previous
        throw
    }

    [pscustomobject]@{
        PSTypeName = 'Snowplow.Session'
        Instance   = $baseUri.Host
        BaseUri    = $baseUri
        AuthMethod = $AuthMethod
    }
}
