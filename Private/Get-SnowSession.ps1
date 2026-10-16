function Get-SnowSession {
    [CmdletBinding()]
    param()
    if (-not $script:SnowplowSession) {
        throw [System.InvalidOperationException]::new('Not connected. Run Connect-Snowplow first.')
    }
    $script:SnowplowSession
}
