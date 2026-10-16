#Requires -Version 7.2
Set-StrictMode -Version Latest

# All state lives in module scope; nothing is published as a global.
$script:SnowplowSession = $null
$script:SnowplowConfig = @{
    DefaultBackend = 'Rest'   # Rest | Sdk | Auto
}
$script:SnowSchemaCache = @{
    Tables = $null
    Fields = @{}
}

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $private + $public) { . $file.FullName }

$adminFunctions = @(
    'Get-SnowRecord', 'New-SnowRecord', 'Set-SnowRecord', 'Remove-SnowRecord',
    'Get-SnowTable', 'Get-SnowDictionary', 'Get-SnowCI', 'Get-SnowCIRelationship',
    'Export-SnowRecord', 'Compare-SnowRecord', 'Where-SnowField', 'Add-SnowOrderBy', 'New-SnowRelativeDate'
)
$profileFunctions = @('Add-SnowplowProfile', 'Get-SnowplowProfile', 'Remove-SnowplowProfile', 'Set-SnowplowProfile')
Export-ModuleMember -Function ((@($public.BaseName | Where-Object { $_ -notin @('Admin', 'Profiles') }) + $profileFunctions + $adminFunctions) | Sort-Object -Unique)
