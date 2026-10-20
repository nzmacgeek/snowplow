function Get-SnowRecord {
    <#
        .SYNOPSIS
        Gets records from any ServiceNow table.
        .DESCRIPTION
        Reads records through the Table API. Each result is a PSCustomObject whose type name is
        Snowplow.Record.<table>. By default at most 100 records are returned; use -Limit to change the
        cap or -All to page through every matching record.

        Reference fields are returned the way the Table API returns them. Use -Fields to keep payloads
        small on wide tables such as incident or cmdb_ci.
        .PARAMETER Table
        The internal table name, such as incident, change_request or sys_user. Tab completion uses the
        cache filled by Get-SnowTable.
        .PARAMETER Query
        A ServiceNow encoded query. Build one with New-SnowQuery or pass a raw string such as 'active=true^priority=1'.
        .PARAMETER Fields
        The fields to return. Tab completion uses the cache filled by Get-SnowDictionary.
        .PARAMETER Limit
        The maximum number of records to return (1-10000, default 100). Ignored when -All is used.
        .PARAMETER All
        Pages through every matching record instead of stopping at -Limit.
        .PARAMETER Backend
        Rest, Sdk or Auto. Auto currently selects Rest.
        .EXAMPLE
        Get-SnowRecord -Table incident -Query 'active=true^priority=1' -Fields number,short_description,assigned_to -Limit 25

        Lists the 25 most recent active P1 incidents with only the columns you care about.
        .EXAMPLE
        Get-SnowRecord -Table incident -Query 'number=INC0010001'

        Looks up a single incident by number.
        .EXAMPLE
        $query = New-SnowQuery | Where-SnowField sys_created_on -Operator '>' -Value (New-SnowRelativeDate -Last 7 -Unit Days)
        Get-SnowRecord -Table change_request -Query $query -All | Group-Object state | Select-Object Name, Count

        Counts every change request raised in the last week by state.
        .EXAMPLE
        Get-SnowRecord -Table sys_user -Query 'active=true^last_login<javascript:gs.daysAgoStart(90)' -All |
            Select-Object user_name, name, last_login

        Finds active users who have not logged in for 90 days, ready for a licence clean-up review.
        .EXAMPLE
        Get-SnowRecord -Table incident -Limit 1 | Get-SnowLink -Format Markdown

        Pipes a record into Get-SnowLink to produce a link you can paste into a chat or ticket.
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
        .DESCRIPTION
        Sends a POST to the Table API and returns the created record. Supports -WhatIf and -Confirm.
        Prod-tagged profiles are read-only unless you connected with -AllowWrite, and always prompt for
        confirmation.
        .PARAMETER Table
        The internal table name to create the record in.
        .PARAMETER Values
        A hashtable of field names and values. Use the same internal field names you would see in the form.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline on level 3'; urgency = '2'; impact = '2' }

        Logs a new incident.
        .EXAMPLE
        New-SnowRecord -Table incident -Values @{ short_description = 'Test' } -WhatIf

        Shows what would be created without sending the request. Use this before running a new script against a shared instance.
        .EXAMPLE
        Import-Csv .\new-users.csv | ForEach-Object {
            New-SnowRecord -Table sys_user -Values @{ user_name = $_.UserName; first_name = $_.First; last_name = $_.Last; email = $_.Email }
        }

        Bulk-creates users from a CSV file with columns UserName, First, Last and Email.
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

    $previousConfirmPreference = $ConfirmPreference
    try {
        $session = Get-SnowSession
        if ($session.Environment -eq 'Prod') {
            if ($session.ReadOnly) {
                throw [System.InvalidOperationException]::new("Writes are disabled for Prod profile '$($session.Profile)'. Reconnect with -AllowWrite to enable writes.")
            }
            $ConfirmPreference = 'Low'
        }

        if ($PSCmdlet.ShouldProcess($Table, 'Create record')) {
            $record = Invoke-SnowBackendRequest -Table $Table -Method POST -Body $Values -Backend $Backend
            if ($record -is [pscustomobject]) { $record.PSTypeNames.Insert(0, "Snowplow.Record.$Table") }
            $record
        }
    }
    finally {
        $ConfirmPreference = $previousConfirmPreference
    }
}

function Set-SnowRecord {
    <#
        .SYNOPSIS
        Updates a ServiceNow record.
        .DESCRIPTION
        Updates by sys_id. Uses PATCH so only the supplied fields change, unless -Replace selects PUT.
        Supports -WhatIf and -Confirm. Prod-tagged profiles require -AllowWrite at connect time and
        always prompt for confirmation.
        .PARAMETER Table
        The internal table name.
        .PARAMETER SysId
        The 32-character sys_id of the record.
        .PARAMETER Values
        A hashtable of fields to change.
        .PARAMETER Replace
        Uses PUT instead of PATCH.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        Set-SnowRecord -Table incident -SysId 9d385017c611228701d22104cc95c371 -Values @{ priority = '2' }

        Raises or lowers the priority of one incident.
        .EXAMPLE
        $incident = Get-SnowRecord -Table incident -Query 'number=INC0010001' -Fields sys_id
        Set-SnowRecord -Table incident -SysId $incident.sys_id -Values @{ state = '6'; close_code = 'Solved (Permanently)'; close_notes = 'Replaced toner.' }

        Resolves an incident by looking up its sys_id from the number first.
        .EXAMPLE
        Get-SnowRecord -Table incident -Query 'active=true^assigned_to=' -Fields sys_id |
            ForEach-Object { Set-SnowRecord -Table incident -SysId $_.sys_id -Values @{ assignment_group = 'Service Desk' } -WhatIf }

        Previews reassigning every unassigned incident to the Service Desk group. Remove -WhatIf to apply.
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
    $previousConfirmPreference = $ConfirmPreference
    try {
        $session = Get-SnowSession
        if ($session.Environment -eq 'Prod') {
            if ($session.ReadOnly) {
                throw [System.InvalidOperationException]::new("Writes are disabled for Prod profile '$($session.Profile)'. Reconnect with -AllowWrite to enable writes.")
            }
            $ConfirmPreference = 'Low'
        }

        if ($PSCmdlet.ShouldProcess("$Table/$SysId", 'Update record')) {
            $record = Invoke-SnowBackendRequest -Table $Table -SysId $SysId -Method $method -Body $Values -Backend $Backend
            if ($record -is [pscustomobject]) { $record.PSTypeNames.Insert(0, "Snowplow.Record.$Table") }
            $record
        }
    }
    finally {
        $ConfirmPreference = $previousConfirmPreference
    }
}

function Remove-SnowRecord {
    <#
        .SYNOPSIS
        Deletes a ServiceNow record.
        .DESCRIPTION
        Deletes by sys_id. This is destructive and high impact, so it prompts for confirmation. Always
        try -WhatIf first. Prod-tagged profiles require -AllowWrite at connect time.
        .PARAMETER Table
        The internal table name.
        .PARAMETER SysId
        The 32-character sys_id of the record to delete.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        Remove-SnowRecord -Table incident -SysId 9d385017c611228701d22104cc95c371 -WhatIf

        Shows what would be deleted.
        .EXAMPLE
        Get-SnowRecord -Table sys_user -Query 'user_name STARTSWITH test.' -Fields sys_id |
            ForEach-Object { Remove-SnowRecord -Table sys_user -SysId $_.sys_id -Confirm:$false }

        Cleans up test accounts left behind by an automation run on a sub-production instance.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Table -Word $word } $wordToComplete })]
        [ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [Parameter(Mandatory, Position = 1)][ValidatePattern('^[0-9a-fA-F]{32}$')][string]$SysId,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    $previousConfirmPreference = $ConfirmPreference
    try {
        $session = Get-SnowSession
        if ($session.Environment -eq 'Prod') {
            if ($session.ReadOnly) {
                throw [System.InvalidOperationException]::new("Writes are disabled for Prod profile '$($session.Profile)'. Reconnect with -AllowWrite to enable writes.")
            }
            $ConfirmPreference = 'Low'
        }

        if ($PSCmdlet.ShouldProcess("$Table/$SysId", 'Delete record')) {
            $null = Invoke-SnowBackendRequest -Table $Table -SysId $SysId -Method DELETE -Backend $Backend
        }
    }
    finally {
        $ConfirmPreference = $previousConfirmPreference
    }
}

function Get-SnowTable {
    <#
        .SYNOPSIS
        Lists ServiceNow tables and their labels.
        .DESCRIPTION
        Queries sys_db_object. Results also populate the cache used for -Table tab completion.
        .PARAMETER Query
        An encoded query against sys_db_object, for example 'nameSTARTSWITHcmdb'.
        .PARAMETER Limit
        The maximum number of tables to return (default 100).
        .PARAMETER All
        Returns every matching table.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        Get-SnowTable -Query 'nameSTARTSWITHcmdb_ci' -All

        Discovers the CMDB class tables available on your instance.
        .EXAMPLE
        Get-SnowTable -All | Out-Null

        Fills the tab-completion cache so Get-SnowRecord -Table <Tab> completes your tables.
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
    if (-not $Query -and $All) { $script:SnowSchemaCache.Tables = $tables }
    $tables
}

function Get-SnowDictionary {
    <#
        .SYNOPSIS
        Gets field definitions from the ServiceNow dictionary.
        .DESCRIPTION
        Queries sys_dictionary for a table. Results populate the cache used by -Fields tab completion
        and by the query builder.
        .PARAMETER Table
        The table whose fields you want.
        .PARAMETER Element
        Limits the result to a single field (column) name.
        .PARAMETER Limit
        The maximum number of rows to return.
        .PARAMETER All
        Returns every field.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        Get-SnowDictionary -Table incident -All | Select-Object element, column_label, internal_type, max_length

        Lists every column on the incident table so you know the names to use in queries.
        .EXAMPLE
        Get-SnowDictionary -Table incident -Element priority

        Inspects one field.
        .EXAMPLE
        Get-SnowDictionary -Table x_acme_asset -All | Where-Object mandatory -eq 'true' | Select-Object element, column_label

        Finds the mandatory fields on a custom table before scripting inserts.
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
    if (-not $Element -and $All) { $script:SnowSchemaCache.Fields[$Table] = $fields }
    $fields
}

function Get-SnowCI {
    <#
        .SYNOPSIS
        Gets configuration items from the CMDB.
        .DESCRIPTION
        A convenience wrapper over Get-SnowRecord for the cmdb_ci table.
        .PARAMETER Query
        An encoded query, for example 'sys_class_name=cmdb_ci_linux_server'.
        .PARAMETER Fields
        The fields to return.
        .PARAMETER Limit
        The maximum number of CIs to return (default 100).
        .PARAMETER All
        Returns every matching CI.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        Get-SnowCI -Query 'install_status=1^sys_class_name=cmdb_ci_linux_server' -Fields name,ip_address,os_version -All

        Lists all installed Linux servers with their IP address and OS version.
        .EXAMPLE
        Get-SnowCI -Query 'operational_status=2' -Fields name,sys_class_name | Export-SnowRecord -Format Csv -Path .\non-operational-cis.csv

        Exports non-operational CIs for an audit.
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
        .DESCRIPTION
        A convenience wrapper over Get-SnowRecord for the cmdb_rel_ci table. Parent and child values are
        sys_ids of CIs.
        .PARAMETER Query
        An encoded query such as 'parent=<sys_id>' or 'child=<sys_id>'.
        .PARAMETER Fields
        The fields to return.
        .PARAMETER Limit
        The maximum number of relationships to return (default 100).
        .PARAMETER All
        Returns every matching relationship.
        .PARAMETER Backend
        Rest, Sdk or Auto.
        .EXAMPLE
        $ci = Get-SnowCI -Query 'name=prod-web-01' -Fields sys_id | Select-Object -First 1
        Get-SnowCIRelationship -Query "child=$($ci.sys_id)" -All

        Finds what depends on a server before a maintenance window.
        .EXAMPLE
        Get-SnowCIRelationship -Query "parent=$($ci.sys_id)" -Fields type,child | Format-Table

        Lists the downstream items of a CI.
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
        .DESCRIPTION
        Accepts pipeline objects from the Snowplow cmdlets. With -Path the output is written to a file;
        without it the text is returned on the pipeline.
        .PARAMETER InputObject
        The records to export. Normally supplied from the pipeline.
        .PARAMETER Format
        Csv (default) or Json.
        .PARAMETER Path
        The file to write. Omit to return text.
        .EXAMPLE
        Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description,priority -All |
            Export-SnowRecord -Format Csv -Path .\open-incidents.csv

        Produces a spreadsheet-friendly report of open incidents.
        .EXAMPLE
        Get-SnowCI -Limit 10 | Export-SnowRecord -Format Json

        Writes JSON to the pipeline, for example to feed another tool.
        .EXAMPLE
        Get-SnowRecord -Table sys_properties -Query 'nameSTARTSWITHglide.ui' -All | Export-SnowRecord -Format Json -Path .\ui-properties-backup.json

        Takes a backup of system properties before changing them.
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
            Set-Content -LiteralPath $Path -Value $text -Encoding utf8NoBOM
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
        Returns changed, added and missing properties. Records can be collected from the same instance
        or from separate instances; connect to each in turn and keep the results in variables.
        .PARAMETER Reference
        The baseline record.
        .PARAMETER Difference
        The record to compare against the baseline.
        .PARAMETER Property
        Limits the comparison to these properties.
        .EXAMPLE
        Connect-Snowplow -Profile dev -ClientCredentials
        $dev = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'
        Connect-Snowplow -Profile prod -ClientCredentials
        $prod = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'
        Compare-SnowRecord -Reference $dev -Difference $prod -Property value

        Checks a system property for drift between Dev and Prod.
        .EXAMPLE
        Compare-SnowRecord -Reference $before -Difference $after

        Shows exactly what a script changed on a record.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][psobject]$Reference,
        [Parameter(Mandatory)][psobject]$Difference,
        [string[]]$Property
    )

    $names = if ($Property) { $Property } else {
        @($Reference.PSObject.Properties.Name) + @($Difference.PSObject.Properties.Name) | Sort-Object -Unique
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
