function Resolve-SnowBackend {
    <#
    .SYNOPSIS
        Maps a requested backend (Rest, Sdk, Auto, or $null for module default) to a concrete one.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend)

    if (-not $Backend) { $Backend = $script:SnowplowConfig.DefaultBackend }
    if ($Backend -eq 'Auto') {
        # Prefer the built-in REST backend unless the user explicitly selects the optional SDK.
        return 'Rest'
    }
    $Backend
}
