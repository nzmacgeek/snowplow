function Connect-Snowplow {
    <#
        .SYNOPSIS
        Connects to a ServiceNow instance and stores the session in module scope.
        .DESCRIPTION
        Authorization code with PKCE is the default interactive grant and opens a browser.
        Use -ClientCredentials for unattended automation with a dedicated service account.
        Basic authentication is retained for compatibility and emits a deprecation warning.
        Sessions require HTTPS. Prod-tagged profiles warn on connect and are read-only unless -AllowWrite
        is supplied.
        .PARAMETER Instance
        The instance name (dev12345) or a full https URL.
        .PARAMETER Profile
        The name of a saved profile created by Add-SnowplowProfile.
        .PARAMETER AuthMethod
        OAuth (default) or Basic.
        .PARAMETER ClientId
        The OAuth application client ID for the authorization code grant.
        .PARAMETER AuthorizationCode
        Explicitly selects the authorization code with PKCE grant.
        .PARAMETER ClientCredentials
        Selects the client credentials grant for unattended use.
        .PARAMETER RedirectPort
        The local loopback port (1024-65535) used to receive the authorization code.
        .PARAMETER NoBrowser
        Prints the sign-in URL instead of opening a browser, for SSH sessions and containers.
        .PARAMETER ClientCredential
        A PSCredential whose username is the OAuth client ID and password is the client secret.
        .PARAMETER Credential
        A PSCredential for Basic authentication.
        .PARAMETER AccessToken
        An existing bearer token to use as-is.
        .PARAMETER ClientCredentialSecretName
        The name of a SecretManagement secret holding the client credential.
        .PARAMETER CredentialSecretName
        The name of a SecretManagement secret holding the Basic credential.
        .PARAMETER Vault
        The SecretManagement vault to read secrets from.
        .PARAMETER AllowWrite
        Allows writes on a Prod-tagged profile.
        .PARAMETER SkipValidation
        Skips the connectivity check made after authenticating.
        .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientId 'your-oauth-client-id'

        Interactive sign-in. Your browser opens, you sign in (including SSO and MFA), and the module keeps the token.
        .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientId 'your-oauth-client-id' -NoBrowser

        Sign in from a headless machine; open the printed URL on any device.
        .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential) -ClientCredentials

        Unattended sign-in with a service account's client ID and secret.
        .EXAMPLE
        Connect-Snowplow -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -ClientCredentials

        Reads the client credential from SecretManagement so no secret appears in your script.
        .EXAMPLE
        Connect-Snowplow -Profile prod -ClientCredentials -AllowWrite

        Connects to a Prod profile with writes explicitly enabled.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)][string]$Instance,
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Profile -Word $word } $wordToComplete })]
        [string]$Profile,
        [ValidateSet('OAuth', 'Basic')][string]$AuthMethod = 'OAuth',
        [string]$ClientId,
        [switch]$AuthorizationCode,
        [switch]$ClientCredentials,
        [ValidateRange(1024, 65535)][int]$RedirectPort = 8765,
        [switch]$NoBrowser,
        # OAuth client id (UserName) and client secret (Password).
        [pscredential]$ClientCredential,
        # Basic auth user, or the user for the legacy OAuth password grant.
        [pscredential]$Credential,
        # Existing OAuth access token for headless or CI use; it is kept in memory only.
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$AccessToken,
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
        if (-not $PSBoundParameters.ContainsKey('ClientCredentialSecretName') -and -not $PSBoundParameters.ContainsKey('ClientCredential') -and -not $AccessToken) { $ClientCredentialSecretName = $storedProfile.ClientCredentialSecretName }
        if (-not $PSBoundParameters.ContainsKey('CredentialSecretName') -and -not $PSBoundParameters.ContainsKey('Credential') -and -not $AccessToken) { $CredentialSecretName = $storedProfile.CredentialSecretName }
        if (-not $PSBoundParameters.ContainsKey('Vault')) { $Vault = $storedProfile.Vault }
    }

    if ($AuthorizationCode -and $ClientCredentials) {
        throw [System.ArgumentException]::new('Choose either -AuthorizationCode or -ClientCredentials, not both.')
    }
    if ($AuthMethod -eq 'Basic' -and ($AuthorizationCode -or $ClientId -or $ClientCredentials)) {
        throw [System.ArgumentException]::new('OAuth grant parameters cannot be combined with -AuthMethod Basic.')
    }
    if (($AuthorizationCode -or $ClientId) -and ($ClientCredential -or $ClientCredentialSecretName -or $Credential -or $CredentialSecretName -or $AccessToken)) {
        throw [System.ArgumentException]::new('Authorization code cannot be combined with client credentials, user credentials, or -AccessToken.')
    }
    $useAuthorizationCode = $AuthMethod -eq 'OAuth' -and (
        $AuthorizationCode -or $ClientId -or
        (-not $ClientCredentials -and -not $ClientCredential -and -not $ClientCredentialSecretName -and
            -not $Credential -and -not $CredentialSecretName -and -not $AccessToken)
    )
    if ($ClientCredentials -and (-not $ClientCredential -and -not $ClientCredentialSecretName -or $Credential -or $CredentialSecretName)) {
        throw [System.ArgumentException]::new('-ClientCredentials requires a client credential and cannot be combined with a user credential.')
    }
    if ($useAuthorizationCode -and -not $ClientId) {
        throw [System.ArgumentException]::new('Authorization code requires -ClientId. For unattended use, specify -ClientCredentials and a client credential.')
    }

    if ($AccessToken -and ($AuthMethod -eq 'Basic' -or $ClientCredential -or $ClientCredentialSecretName -or $Credential -or $CredentialSecretName)) {
        throw [System.ArgumentException]::new('-AccessToken cannot be combined with Basic authentication or credential parameters.')
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
    elseif (-not $useAuthorizationCode) {
        if (-not $ClientCredential -and -not $AccessToken) {
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
        ClientId         = if ($ClientId) { $ClientId } elseif ($ClientCredential) { $ClientCredential.UserName } else { $null }
        GrantType        = if ($useAuthorizationCode) { 'authorization_code' } elseif ($Credential) { 'password' } else { 'client_credentials' }
        RedirectPort     = $RedirectPort
        NoBrowser        = [bool]$NoBrowser
        RefreshToken     = $null
        AccessToken      = if ($AccessToken) { ConvertTo-SecureString -String $AccessToken -AsPlainText -Force } else { $null }
        ExpiresAt        = if ($AccessToken) { [datetime]::MaxValue } else { [datetime]::MinValue }
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
        if ($useAuthorizationCode -and -not $AccessToken) {
            $session.RefreshToken = Read-SnowOAuthRefreshToken -BaseUri $baseUri -ClientId $session.ClientId
            $token = Request-SnowOAuthToken -Session $session
            $session.AccessToken = $token.AccessToken
            $session.ExpiresAt = $token.ExpiresAt
        }
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
