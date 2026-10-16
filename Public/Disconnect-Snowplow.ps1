function Disconnect-Snowplow {
    <# .SYNOPSIS Discards the stored session and any cached token. #>
    [CmdletBinding()]
    param()
    $script:SnowplowSession = $null
}
