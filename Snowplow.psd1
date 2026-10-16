@{
    RootModule            = 'Snowplow.psm1'
    ModuleVersion         = '0.1.0'
    GUID                  = '6f0f2d0e-3c55-4b0e-9d52-5a1f3b7c8e21'
    Author                = 'nzmacgeek'
    Description           = 'PowerShell module for ServiceNow administrators (REST Table API and now-sdk backends).'
    PowerShellVersion     = '7.2'
    CompatiblePSEditions  = @('Core')
    FunctionsToExport     = @('Connect-Snowplow', 'Disconnect-Snowplow', 'Get-SnowplowConfiguration', 'Set-SnowplowConfiguration')
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData           = @{ PSData = @{ Tags = @('ServiceNow', 'REST', 'Admin') } }
}
