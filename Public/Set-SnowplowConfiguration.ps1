function Set-SnowplowConfiguration {
    <#
        .SYNOPSIS
        Sets module-level settings.
        .DESCRIPTION
        Currently sets the default backend used when a cmdlet is called without -Backend.
        .PARAMETER DefaultBackend
        Rest, Sdk or Auto. Auto currently selects Rest.
        .EXAMPLE
        Set-SnowplowConfiguration -DefaultBackend Rest

        Pins the module to the REST backend, which does not need Node.js.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateSet('Rest', 'Sdk', 'Auto')][string]$DefaultBackend)
    if ($DefaultBackend -and $PSCmdlet.ShouldProcess('Snowplow configuration', "Set DefaultBackend=$DefaultBackend")) {
        $script:SnowplowConfig.DefaultBackend = $DefaultBackend
    }
}
