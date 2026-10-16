function Request-SnowOAuthToken {
    <#
    .SYNOPSIS
        Obtains an OAuth access token from /oauth_token.do and returns it as a SecureString
        plus expiry. Uses client_credentials, or the legacy password grant if a user credential is given.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject]$Session)

    $form = @{
        client_id     = $Session.ClientCredential.UserName
        client_secret = $Session.ClientCredential.GetNetworkCredential().Password
    }
    if ($Session.Credential) {
        $form.grant_type = 'password'
        $form.username = $Session.Credential.UserName
        $form.password = $Session.Credential.GetNetworkCredential().Password
    }
    else {
        $form.grant_type = 'client_credentials'
    }
    try {
        $resp = Invoke-RestMethod -Uri ([uri]::new($Session.BaseUri, '/oauth_token.do')) -Method Post `
            -Body $form -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' } `
            -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-SnowErrorRecord -ErrorRecord $_ -Target 'oauth_token.do'))
    }
    finally { $form = $null }

    $accessToken = $resp.PSObject.Properties['access_token']
    if (-not $accessToken -or -not $accessToken.Value) {
        throw [System.InvalidOperationException]::new('OAuth token response did not contain an access_token.')
    }
    $expiresIn = $resp.PSObject.Properties['expires_in']
    $lifetime = if ($expiresIn -and $expiresIn.Value) { [int]$expiresIn.Value } else { 1800 }
    [pscustomobject]@{
        AccessToken = ConvertTo-SecureString -String ([string]$accessToken.Value) -AsPlainText -Force
        ExpiresAt   = [datetime]::UtcNow.AddSeconds($lifetime)
    }
}
