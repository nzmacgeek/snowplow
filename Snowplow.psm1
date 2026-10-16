#Requires -Version 7.2
Set-StrictMode -Version Latest

# All state lives in module scope; nothing is published as a global.
$script:SnowplowSession = $null
$script:SnowplowConfig = @{
    DefaultBackend = 'Rest'   # Rest | Sdk | Auto
}

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $private + $public) { . $file.FullName }

Export-ModuleMember -Function $public.BaseName
