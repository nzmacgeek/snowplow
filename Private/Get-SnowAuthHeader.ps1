function Get-SnowAuthHeader {
    <#
    .SYNOPSIS
        Returns an Authorization header for the session, refreshing the OAuth token when near expiry.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][pscustomobject]$Session)

    if ($Session.AuthMethod -eq 'Basic') {
        $pair = '{0}:{1}' -f $Session.Credential.UserName, $Session.Credential.GetNetworkCredential().Password
        return @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)) }
    }
    if (-not $Session.AccessToken -or [datetime]::UtcNow -ge $Session.ExpiresAt.AddSeconds(-60)) {
        $token = Request-SnowOAuthToken -Session $Session
        $Session.AccessToken = $token.AccessToken
        $Session.ExpiresAt = $token.ExpiresAt
    }
    $plain = [System.Net.NetworkCredential]::new('', $Session.AccessToken).Password
    @{ Authorization = "Bearer $plain" }
}
