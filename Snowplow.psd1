@{
    RootModule            = 'Snowplow.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '6f0f2d0e-3c55-4b0e-9d52-5a1f3b7c8e21'
    Author                = 'William McGrath (nzmacgeek)'
    Description           = 'Snowplow is a PowerShell module for automating ServiceNow development, administration, and integration tasks from the command line. For more information, visit https://vworp.net/snowplow/'
    PowerShellVersion     = '7.2'
    CompatiblePSEditions  = @('Core')
    FunctionsToExport     = @(
        'Add-SnowOrderBy', 'Add-SnowplowProfile', 'Compare-SnowRecord', 'Connect-Snowplow',
        'Disconnect-Snowplow', 'Export-SnowRecord', 'Find-SnowField', 'Get-SnowCI',
        'Get-SnowCIRelationship', 'Get-SnowDictionary', 'Get-SnowLink',
        'Get-SnowRecord', 'Get-SnowSyslog', 'Get-SnowTable', 'Get-SnowplowConfiguration',
        'Get-SnowplowProfile', 'Get-SnowplowPromptSegment', 'New-SnowQuery',
        'New-SnowRecord', 'New-SnowRelativeDate', 'Open-SnowRecord',
        'Remove-SnowRecord', 'Remove-SnowplowProfile', 'Set-SnowRecord',
        'Set-SnowplowConfiguration', 'Set-SnowplowProfile'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @('snow', 'snowc', 'snowl', 'snowo', 'Where-SnowField')
    PrivateData           = @{ PSData = @{
            Tags = @('ServiceNow', 'REST', 'Admin')
            Prerelease = 'beta4'
        }
    }
}
