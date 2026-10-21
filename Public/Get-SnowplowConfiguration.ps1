function Get-SnowplowConfiguration {
    <#
        .SYNOPSIS
        Returns module-level settings.
        .DESCRIPTION
        Returns settings such as the default backend.
        .EXAMPLE
        Get-SnowplowConfiguration

        Shows the current settings.
    #>
    [CmdletBinding()]
    param()
    [pscustomobject]$script:SnowplowConfig
}
