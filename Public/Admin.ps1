function Get-SnowRecord {
    <#
    .SYNOPSIS
        Gets ServiceNow records from a table.
    .DESCRIPTION
        Returns each result as a PSCustomObject with a Snowplow.Record.<table> type name.
        By default, at most 100 records are returned; use -All to page through every match.
    .EXAMPLE
        Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description -Limit 25
    .EXAMPLE
        Get-SnowRecord -Table cmdb_ci -All | Where-Object name -like '*server*'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [string]$Query,
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters) & (Get-Module Snowplow) { param($table, $word) Get-SnowCompletionValue -Kind Field -Table $table -Word $word } $fakeBoundParameters.Table $wordToComplete })]
        [string[]]$Fields,
        [ValidateRange(1, 10000)][int]$Limit = 100,
        [switch]$All,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    $request = @{
        Table = $Table
        Query = $Query
        Fields = $Fields
        PageSize = [Math]::Min($Limit, 1000)
        Backend = $Backend
    }
    if (-not $All) { $request.First = $Limit }
    $records = Invoke-SnowBackendRequest @request
    foreach ($record in $records) {
        if ($record -is [System.Collections.IDictionary]) {
            $record = [pscustomobject]$record
        }
        if ($record -is [pscustomobject]) {
            $record.PSTypeNames.Insert(0, "Snowplow.Record.$Table")
        }
        $record
    }
}

function New-SnowRecord {
    <#
    .SYNOPSIS
        Creates a record in a ServiceNow table.
    .EXAMPLE
        New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline' }
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [Parameter(Mandatory, Position = 1)][System.Collections.IDictionary]$Values,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    if ($PSCmdlet.ShouldProcess($Table, 'Create record')) {
        $record = Invoke-SnowBackendRequest -Table $Table -Method POST -Body $Values -Backend $Backend
        if ($record -is [pscustomobject]) { $record.PSTypeNames.Insert(0, "Snowplow.Record.$Table") }
        $record
    }
}

function Set-SnowRecord {
    <#
    .SYNOPSIS
        Updates a ServiceNow record.
    .EXAMPLE
        Set-SnowRecord -Table incident -SysId $id -Values @{ priority = '2' }
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [Parameter(Mandatory, Position = 1)][ValidatePattern('^[0-9a-fA-F]{32}$')][string]$SysId,
        [Parameter(Mandatory, Position = 2)][System.Collections.IDictionary]$Values,
        [switch]$Replace,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    $method = if ($Replace) { 'PUT' } else { 'PATCH' }
    if ($PSCmdlet.ShouldProcess("$Table/$SysId", 'Update record')) {
        $record = Invoke-SnowBackendRequest -Table $Table -SysId $SysId -Method $method -Body $Values -Backend $Backend
        if ($record -is [pscustomobject]) { $record.PSTypeNames.Insert(0, "Snowplow.Record.$Table") }
        $record
    }
}

function Remove-SnowRecord {
    <#
    .SYNOPSIS
        Deletes a ServiceNow record.
    .EXAMPLE
        Remove-SnowRecord -Table incident -SysId $id -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [Parameter(Mandatory, Position = 1)][ValidatePattern('^[0-9a-fA-F]{32}$')][string]$SysId,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    if ($PSCmdlet.ShouldProcess("$Table/$SysId", 'Delete record')) {
        $null = Invoke-SnowBackendRequest -Table $Table -SysId $SysId -Method DELETE -Backend $Backend
    }
}

function Get-SnowTable {
    <#
    .SYNOPSIS
        Lists ServiceNow tables and their labels.
    .EXAMPLE
        Get-SnowTable -Query 'nameSTARTSWITHcmdb'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Query,
        [ValidateRange(1, 10000)][int]$Limit = 1000,
        [switch]$All,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    $request = @{
        Table = 'sys_db_object'
        Query = $Query
        Fields = @('sys_id', 'name', 'label', 'super_class')
        PageSize = [Math]::Min($Limit, 1000)
        Backend = $Backend
    }
    if (-not $All) { $request.First = $Limit }
    $tables = @(Invoke-SnowBackendRequest @request)
    $script:SnowSchemaCache.Tables = $tables
    $tables
}

function Get-SnowDictionary {
    <#
    .SYNOPSIS
        Gets field definitions from the ServiceNow dictionary.
    .EXAMPLE
        Get-SnowDictionary -Table incident
    .EXAMPLE
        Get-SnowDictionary -Table incident -Element priority
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [string]$Element,
        [ValidateRange(1, 10000)][int]$Limit = 1000,
        [switch]$All,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    $query = "name=$Table"
    if ($Element) { $query += "^element=$Element" }
    $request = @{
        Table = 'sys_dictionary'
        Query = $query
        Fields = @('name', 'element', 'column_label', 'internal_type', 'reference', 'mandatory', 'read_only')
        PageSize = [Math]::Min($Limit, 1000)
        Backend = $Backend
    }
    if (-not $All) { $request.First = $Limit }
    $fields = @(Invoke-SnowBackendRequest @request)
    $script:SnowSchemaCache.Fields[$Table] = $fields
    $fields
}

function Get-SnowCI {
    <#
    .SYNOPSIS
        Gets configuration items from the CMDB.
    .EXAMPLE
        Get-SnowCI -Query 'install_status=1' -Limit 50
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Query,
        [string[]]$Fields,
        [ValidateRange(1, 10000)][int]$Limit = 100,
        [switch]$All,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )
    $request = @{ Table = 'cmdb_ci'; Query = $Query; Fields = $Fields; Limit = $Limit; All = $All }
    if ($Backend) { $request.Backend = $Backend }
    Get-SnowRecord @request
}

function Get-SnowCIRelationship {
    <#
    .SYNOPSIS
        Gets CMDB configuration item relationships.
    .EXAMPLE
        Get-SnowCIRelationship -Query 'parent=<sys_id>' -Limit 50
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Query,
        [string[]]$Fields,
        [ValidateRange(1, 10000)][int]$Limit = 100,
        [switch]$All,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )
    $request = @{ Table = 'cmdb_rel_ci'; Query = $Query; Fields = $Fields; Limit = $Limit; All = $All }
    if ($Backend) { $request.Backend = $Backend }
    Get-SnowRecord @request
}

function Export-SnowRecord {
    <#
    .SYNOPSIS
        Exports records as CSV or JSON.
    .EXAMPLE
        Get-SnowRecord -Table incident -Limit 20 | Export-SnowRecord -Format Csv -Path incidents.csv
    .EXAMPLE
        Get-SnowCI -Limit 10 | Export-SnowRecord -Format Json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][psobject]$InputObject,
        [ValidateSet('Csv', 'Json')][string]$Format = 'Json',
        [string]$Path
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process { $items.Add($InputObject) }
    end {
        $text = if ($Format -eq 'Csv') {
            (@($items) | ConvertTo-Csv -NoTypeInformation) -join [Environment]::NewLine
        }
        else {
            ConvertTo-Json -InputObject @($items) -Depth 100
        }
        if ($Path) {
            Set-Content -LiteralPath $Path -Value $text -Encoding utf8
        }
        else {
            $text
        }
    }
}

function Compare-SnowRecord {
    <#
    .SYNOPSIS
        Compares two record objects and returns the differing properties.
    .DESCRIPTION
        Records can be collected from either the same instance or separate instances.
    .EXAMPLE
        Compare-SnowRecord -Reference $devRecord -Difference $prodRecord
    .EXAMPLE
        $left = Get-SnowRecord -Table incident -Query "number=INC001"
        $right = Get-SnowRecord -Table incident -Backend Rest -Query "number=INC001"
        Compare-SnowRecord -Reference $left -Difference $right
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][psobject]$Reference,
        [Parameter(Mandatory)][psobject]$Difference,
        [string[]]$Property
    )

    $names = if ($Property) { $Property } else {
        @($Reference.PSObject.Properties.Name + $Difference.PSObject.Properties.Name | Sort-Object -Unique)
    }
    foreach ($name in $names) {
        $leftProperty = $Reference.PSObject.Properties[$name]
        $rightProperty = $Difference.PSObject.Properties[$name]
        $left = if ($leftProperty) { $leftProperty.Value } else { $null }
        $right = if ($rightProperty) { $rightProperty.Value } else { $null }
        if (-not $leftProperty -or -not $rightProperty -or (ConvertTo-Json -InputObject $left -Depth 50 -Compress) -cne (ConvertTo-Json -InputObject $right -Depth 50 -Compress)) {
            [pscustomobject]@{ Property = $name; Reference = $left; Difference = $right }
        }
    }
}
