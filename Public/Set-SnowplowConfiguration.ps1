function Set-SnowplowConfiguration {
    <#
    .SYNOPSIS
        Sets module-level settings (default backend: Rest, Sdk, Auto).
    .EXAMPLE
        Set-SnowplowConfiguration -DefaultBackend Rest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateSet('Rest', 'Sdk', 'Auto')][string]$DefaultBackend)
    if ($DefaultBackend -and $PSCmdlet.ShouldProcess('Snowplow configuration', "Set DefaultBackend=$DefaultBackend")) {
        $script:SnowplowConfig.DefaultBackend = $DefaultBackend
    }
}
