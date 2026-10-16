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

    if (-not $resp.access_token) {
        throw [System.InvalidOperationException]::new('OAuth token response did not contain an access_token.')
    }
    $lifetime = if ($resp.expires_in) { [int]$resp.expires_in } else { 1800 }
    [pscustomobject]@{
        AccessToken = ConvertTo-SecureString -String ([string]$resp.access_token) -AsPlainText -Force
        ExpiresAt   = [datetime]::UtcNow.AddSeconds($lifetime)
    }
}
