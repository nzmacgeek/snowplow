function Get-SnowplowConfiguration {
    <# .SYNOPSIS Returns module-level settings. #>
    [CmdletBinding()]
    param()
    [pscustomobject]$script:SnowplowConfig
}
