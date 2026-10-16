@{
    RootModule            = 'Snowplow.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '6f0f2d0e-3c55-4b0e-9d52-5a1f3b7c8e21'
    Author                = 'nzmacgeek'
    Description           = 'PowerShell module for ServiceNow administrators (REST Table API and now-sdk backends).'
    PowerShellVersion     = '7.2'
    CompatiblePSEditions  = @('Core')
    FunctionsToExport     = @(
        'Add-SnowplowProfile', 'Connect-Snowplow', 'Disconnect-Snowplow', 'Get-SnowplowConfiguration', 'Get-SnowplowProfile',
        'Get-SnowRecord', 'New-SnowRecord', 'Set-SnowRecord', 'Remove-SnowRecord',
        'Get-SnowTable', 'Get-SnowDictionary', 'Get-SnowCI', 'Get-SnowCIRelationship',
        'Export-SnowRecord', 'Compare-SnowRecord', 'New-SnowQuery', 'Where-SnowField',
        'Add-SnowOrderBy', 'New-SnowRelativeDate', 'Remove-SnowplowProfile',
        'Set-SnowplowConfiguration', 'Set-SnowplowProfile'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData           = @{ PSData = @{ Tags = @('ServiceNow', 'REST', 'Admin') } }
}
