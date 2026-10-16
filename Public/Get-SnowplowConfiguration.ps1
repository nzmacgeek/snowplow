function Get-SnowplowConfiguration {
    <#
    .SYNOPSIS
        Returns module-level settings.
    .EXAMPLE
        Get-SnowplowConfiguration
    #>
    [CmdletBinding()]
    param()
    [pscustomobject]$script:SnowplowConfig
}
