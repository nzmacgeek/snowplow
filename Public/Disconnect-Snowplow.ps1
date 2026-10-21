function Disconnect-Snowplow {
    <#
        .SYNOPSIS
        Discards the stored session and any cached token.
        .DESCRIPTION
        Run this when you finish, particularly on shared machines or at the end of a pipeline job.
        .EXAMPLE
        Disconnect-Snowplow

        Ends the session.
        .EXAMPLE
        try { Connect-Snowplow -Profile dev -ClientCredentials; Get-SnowRecord -Table incident -Limit 1 } finally { Disconnect-Snowplow }

        Guarantees the token is discarded even if a command fails.
    #>
    [CmdletBinding()]
    param()
    $script:SnowplowSession = $null
    $script:SnowSchemaCache.Tables = $null
    $script:SnowSchemaCache.Fields = @{}
}
