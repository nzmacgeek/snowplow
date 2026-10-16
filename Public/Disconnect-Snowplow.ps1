function Disconnect-Snowplow {
    <#
    .SYNOPSIS
        Discards the stored session and any cached token.
    .EXAMPLE
        Disconnect-Snowplow
    #>
    [CmdletBinding()]
    param()
    $script:SnowplowSession = $null
}
