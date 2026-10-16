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
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)][string]$Instance,
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Profile -Word $word } $wordToComplete })]
        [string]$Profile,
        [ValidateSet('OAuth', 'Basic')][string]$AuthMethod = 'OAuth',
        # OAuth client id (UserName) and client secret (Password).
        [pscredential]$ClientCredential,
        # Basic auth user, or the user for the legacy OAuth password grant.
        [pscredential]$Credential,
        # SecretManagement secret names (must resolve to a PSCredential).
        [string]$ClientCredentialSecretName,
        [string]$CredentialSecretName,
        [string]$Vault,
        [switch]$AllowWrite,
        [switch]$SkipValidation
    )

    $storedProfile = $null
    if ($Profile) {
        $storedProfile = Get-SnowStoredProfile -Name $Profile
        if (-not $Instance) { $Instance = $storedProfile.Instance }
        if (-not $PSBoundParameters.ContainsKey('AuthMethod')) { $AuthMethod = $storedProfile.AuthMethod }
        if (-not $PSBoundParameters.ContainsKey('ClientCredentialSecretName') -and -not $PSBoundParameters.ContainsKey('ClientCredential')) { $ClientCredentialSecretName = $storedProfile.ClientCredentialSecretName }
        if (-not $PSBoundParameters.ContainsKey('CredentialSecretName') -and -not $PSBoundParameters.ContainsKey('Credential')) { $CredentialSecretName = $storedProfile.CredentialSecretName }
        if (-not $PSBoundParameters.ContainsKey('Vault')) { $Vault = $storedProfile.Vault }
    }

    if (-not $Instance) {
        throw [System.ArgumentException]::new('Specify -Instance or -Profile.')
    }

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
        if (-not $Credential) {
            if ($Profile) {
                $Credential = Get-Credential -Message "Enter the basic authentication credential for Snowplow profile '$Profile'"
            }
            else {
                throw [System.ArgumentException]::new('Basic auth requires -Credential or -CredentialSecretName.')
            }
        }
        Write-Warning 'Basic authentication is deprecated for ServiceNow integrations. Prefer OAuth (-ClientCredential).'
    }
    else {
        if (-not $ClientCredential) {
            if ($Profile) {
                $ClientCredential = Get-Credential -Message "Enter the OAuth client credential for Snowplow profile '$Profile'"
            }
            else {
                throw [System.ArgumentException]::new('OAuth requires -ClientCredential or -ClientCredentialSecretName.')
            }
        }
        if ($Credential) { Write-Warning 'The OAuth password grant is legacy; prefer client credentials where your release supports it.' }
    }

    $environment = if ($storedProfile) { $storedProfile.Environment } else { $null }
    $readOnly = $environment -eq 'Prod' -and -not $AllowWrite
    if ($environment -eq 'Prod') {
        if ($readOnly) {
            Write-Warning "Connected to Prod profile '$Profile'. Snowplow is read-only by default; reconnect with -AllowWrite to enable writes."
        }
        else {
            Write-Warning "Connected to Prod profile '$Profile'. Write operations require confirmation."
        }
    }

    $session = [pscustomobject]@{
        BaseUri          = $baseUri
        AuthMethod       = $AuthMethod
        Credential       = $Credential
        ClientCredential = $ClientCredential
        AccessToken      = $null
        ExpiresAt        = [datetime]::MinValue
        ConnectedAt      = [datetime]::UtcNow
        Profile          = $Profile
        Environment      = $environment
        DefaultBackend   = if ($storedProfile) { $storedProfile.DefaultBackend } else { $script:SnowplowConfig.DefaultBackend }
        AllowWrite       = [bool]$AllowWrite
        ReadOnly         = $readOnly
    }

    $previous = $script:SnowplowSession
    $previousDefaultBackend = $script:SnowplowConfig.DefaultBackend
    if ($storedProfile) {
        $script:SnowplowConfig.DefaultBackend = $storedProfile.DefaultBackend
    }
    $script:SnowplowSession = $session
    try {
        if (-not $SkipValidation) {
            # Fetches a token (OAuth) and proves the credentials can reach the Table API.
            $null = Invoke-SnowRequest -Table sys_user -Fields sys_id -First 1 -PageSize 1
        }
    }
    catch {
        $script:SnowplowSession = $previous
        $script:SnowplowConfig.DefaultBackend = $previousDefaultBackend
        throw
    }

    $script:SnowSchemaCache.Tables = $null
    $script:SnowSchemaCache.Fields = @{}

    [pscustomobject]@{
        PSTypeName = 'Snowplow.Session'
        Instance   = $baseUri.Host
        BaseUri    = $baseUri
        AuthMethod = $AuthMethod
        Profile    = $Profile
        Environment = $environment
        DefaultBackend = $script:SnowplowConfig.DefaultBackend
        ReadOnly   = $readOnly
    }
}
