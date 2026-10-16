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
        # The now-sdk backend is not implemented yet, so Auto currently means Rest.
        return 'Rest'
    }
    if ($Backend -eq 'Sdk') {
        throw [System.NotImplementedException]::new('The Sdk backend is not implemented yet.')
    }
    $Backend
}
