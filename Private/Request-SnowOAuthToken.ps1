function Get-SnowOAuthErrorCode {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    $errorBody = if ($ErrorRecord.ErrorDetails) { $ErrorRecord.ErrorDetails.Message } else { $null }
    $response = if ($ErrorRecord.Exception.PSObject.Properties['Response']) { $ErrorRecord.Exception.Response } else { $null }
    if (-not $errorBody -and $response -and $response.PSObject.Properties['Content']) {
        try { $errorBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
        catch { $errorBody = $null }
    }
    if (-not $errorBody) { return $null }
    try {
        $payload = ConvertFrom-Json -InputObject $errorBody -ErrorAction Stop
        if ($payload.error -is [string]) { return $payload.error }
    }
    catch { return $null }
    $null
}

function Request-SnowOAuthToken {
    <#
    .SYNOPSIS
        Obtains an OAuth access token from /oauth_token.do and returns it as a SecureString
        plus expiry. Supports authorization_code with PKCE, refresh_token, client_credentials,
        and the legacy password grant.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Session)

    $clientCredential = if ($Session.PSObject.Properties['ClientCredential']) { $Session.ClientCredential } else { $null }
    $userCredential = if ($Session.PSObject.Properties['Credential']) { $Session.Credential } else { $null }
    $clientId = if ($Session.PSObject.Properties['ClientId'] -and $Session.ClientId) {
        $Session.ClientId
    }
    elseif ($clientCredential) {
        $clientCredential.UserName
    }
    else { $null }
    $sessionRefreshToken = if ($Session.PSObject.Properties['RefreshToken']) { $Session.RefreshToken } else { $null }
    $form = @{ client_id = $clientId }
    $refreshing = $false
    if ($sessionRefreshToken) {
        $refreshing = $true
        $form.grant_type = 'refresh_token'
        $form.refresh_token = [System.Net.NetworkCredential]::new('', $sessionRefreshToken).Password
        if ($clientCredential) { $form.client_secret = $clientCredential.GetNetworkCredential().Password }
    }
    elseif ($Session.PSObject.Properties['GrantType'] -and $Session.GrantType -eq 'authorization_code') {
        $authorization = Invoke-SnowOAuthAuthorization -BaseUri $Session.BaseUri -ClientId $Session.ClientId `
            -RedirectPort $Session.RedirectPort -NoBrowser:$Session.NoBrowser
        $form.grant_type = 'authorization_code'
        $form.code = $authorization.Code
        $form.redirect_uri = $authorization.RedirectUri.AbsoluteUri
        $form.code_verifier = $authorization.Verifier
    }
    elseif ($userCredential) {
        if ($clientCredential) { $form.client_secret = $clientCredential.GetNetworkCredential().Password }
        $form.grant_type = 'password'
        $form.username = $userCredential.UserName
        $form.password = $userCredential.GetNetworkCredential().Password
    }
    else {
        if (-not $clientCredential) {
            throw [System.InvalidOperationException]::new('No usable OAuth credentials are available. Run Connect-Snowplow again.')
        }
        $form.client_secret = $clientCredential.GetNetworkCredential().Password
        $form.grant_type = 'client_credentials'
    }
    try {
        $resp = Invoke-RestMethod -Uri ([uri]::new($Session.BaseUri, '/oauth_token.do')) -Method Post `
            -Body $form -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' } `
            -TimeoutSec 60 -ErrorAction Stop
    }
    catch {
        if ($refreshing -and (Get-SnowOAuthErrorCode -ErrorRecord $_) -eq 'invalid_grant') {
            $Session.RefreshToken = $null
            Clear-SnowOAuthRefreshToken -BaseUri $Session.BaseUri -ClientId $clientId
            throw [System.InvalidOperationException]::new('The saved OAuth refresh token was rejected. Run Connect-Snowplow again to sign in.')
        }
        $status = if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) {
            [int]$_.Exception.Response.StatusCode
        }
        else { $null }
        $statusText = if ($status) { " (HTTP $status)" } else { '' }
        if ($refreshing) {
            throw [System.InvalidOperationException]::new("OAuth refresh request failed$statusText. The saved refresh token was retained; retry the request.")
        }
        throw [System.InvalidOperationException]::new("OAuth token request failed$statusText. Check the OAuth application, redirect URI, and scopes.")
    }
    finally { $form = $null }

    $accessToken = $resp.PSObject.Properties['access_token']
    if (-not $accessToken -or -not $accessToken.Value) {
        throw [System.InvalidOperationException]::new('OAuth token response was invalid. Run Connect-Snowplow again to sign in.')
    }
    $expiresIn = $resp.PSObject.Properties['expires_in']
    $lifetime = if ($expiresIn -and $expiresIn.Value) { [int]$expiresIn.Value } else { 1800 }
    $refreshToken = $resp.PSObject.Properties['refresh_token']
    if ($refreshToken -and $refreshToken.Value) {
        $Session.RefreshToken = ConvertTo-SecureString -String ([string]$refreshToken.Value) -AsPlainText -Force
    }
    $clientId = if ($Session.PSObject.Properties['ClientId']) { $Session.ClientId } else { $null }
    $sessionRefreshToken = if ($Session.PSObject.Properties['RefreshToken']) { $Session.RefreshToken } else { $null }
    if ($sessionRefreshToken -and $clientId) {
        Write-SnowOAuthRefreshToken -BaseUri $Session.BaseUri -ClientId $clientId -RefreshToken $sessionRefreshToken
    }
    [pscustomobject]@{
        AccessToken = ConvertTo-SecureString -String ([string]$accessToken.Value) -AsPlainText -Force
        ExpiresAt   = [datetime]::UtcNow.AddSeconds($lifetime)
    }
}
