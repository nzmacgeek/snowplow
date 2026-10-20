function ConvertTo-SnowQueryValue {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [bool]) { $text = $Value.ToString().ToLowerInvariant() }
    elseif ($Value -is [IFormattable]) { $text = $Value.ToString($null, [Globalization.CultureInfo]::InvariantCulture) }
    else { $text = [string]$Value }
    $text.Replace('^', '^^')
}

function ConvertTo-SnowQueryCondition {
    param(
        [Parameter(Mandatory)][string]$Field,
        [Parameter(Mandatory)][string]$Operator,
        [AllowNull()][object]$Value
    )

    if ($Field -notmatch '^[a-zA-Z_][a-zA-Z0-9_.]*$') {
        throw [System.ArgumentException]::new("Invalid ServiceNow field name '$Field'.")
    }
    $Operator = $Operator.ToUpperInvariant()
    if ($Operator -notin @('=', '!=', 'LIKE', 'STARTSWITH', 'IN', '>', '<', 'BETWEEN', 'ISEMPTY', 'ISNOTEMPTY')) {
        throw [System.ArgumentException]::new("Unsupported ServiceNow query operator '$Operator'.")
    }
    if ($Operator -in @('ISEMPTY', 'ISNOTEMPTY')) {
        return "$Field$Operator"
    }
    if ($null -eq $Value) {
        throw [System.ArgumentException]::new("A value is required for the '$Operator' operator.")
    }

    if ($Operator -eq 'IN') {
        $values = @($Value)
        if ($values.Count -eq 0) { throw [System.ArgumentException]::new('IN requires at least one value.') }
        $encoded = @($values | ForEach-Object { ConvertTo-SnowQueryValue $_ }) -join ','
    }
    elseif ($Operator -eq 'BETWEEN') {
        $values = @($Value)
        if ($values.Count -ne 2) { throw [System.ArgumentException]::new('BETWEEN requires exactly two values.') }
        $encoded = (@($values | ForEach-Object { ConvertTo-SnowQueryValue $_ }) -join '@')
    }
    else {
        if ($Value -is [array]) { throw [System.ArgumentException]::new("'$Operator' requires a single value.") }
        $encoded = ConvertTo-SnowQueryValue $Value
    }
    "$Field$Operator$encoded"
}

function New-SnowQuery {
    <#
        .SYNOPSIS
        Builds a ServiceNow encoded query.
        .DESCRIPTION
        Hashtable values are equality conditions. Use a descriptor with Operator,
        Value, and optional Joiner keys for other operators and OR/NQ conditions.
        Use an [ordered] hashtable when condition order matters. Calling it with no arguments returns an
        empty query for use with Where-SnowField and Add-SnowOrderBy.
        .PARAMETER Conditions
        A hashtable of field names to values or descriptors.
        .PARAMETER Joiner
        AND (default), OR or NQ, used between conditions.
        .EXAMPLE
        New-SnowQuery -Conditions ([ordered]@{ active = 'true'; priority = '1' })

        Builds 'active=true^priority=1'.
        .EXAMPLE
        New-SnowQuery -Conditions @{ priority = @{ Operator = 'IN'; Value = @('1', '2') } }

        Matches P1 and P2.
        .EXAMPLE
        $q = New-SnowQuery -Conditions @{ active = 'true' } | Where-SnowField short_description -Operator LIKE -Value 'VPN' | Add-SnowOrderBy sys_created_on -Descending
        Get-SnowRecord -Table incident -Query $q -Limit 10

        Finds the ten newest active incidents mentioning VPN.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [Alias('Filter', 'Where')]
        [System.Collections.IDictionary]$Conditions,
        [ValidateSet('AND', 'OR', 'NQ')][string]$Joiner = 'AND'
    )

    $terms = [System.Collections.Generic.List[string]]::new()
    if ($Conditions) {
        foreach ($field in $Conditions.Keys) {
            $condition = $Conditions[$field]
            $operator = '='
            $value = $condition
            $join = $Joiner
            if ($condition -is [System.Collections.IDictionary] -and $condition.Contains('Operator')) {
                $operator = [string]$condition.Operator
                $value = $null
                if ($condition.Contains('Value')) { $value = $condition.Value }
                if ($condition.Contains('Joiner')) { $join = [string]$condition.Joiner }
            }
            if ($join -notin @('AND', 'OR', 'NQ')) {
                throw [System.ArgumentException]::new("Unsupported query joiner '$join'.")
            }
            $encoded = ConvertTo-SnowQueryCondition -Field ([string]$field) -Operator $operator -Value $value
            if ($terms.Count -gt 0) {
                $prefix = if ($join -eq 'AND') { '^' } else { "^$($join.ToUpperInvariant())" }
                $terms.Add($prefix)
            }
            $terms.Add($encoded)
        }
    }
    $terms -join ''
}

function Find-SnowField {
    <#
        .SYNOPSIS
        Adds a field condition to a ServiceNow encoded query. Also available as Where-SnowField.
        .DESCRIPTION
        Appends a condition to the query received from the pipeline. Operators are =, !=, LIKE,
        STARTSWITH, IN, >, <, BETWEEN, ISEMPTY and ISNOTEMPTY.
        .PARAMETER Field
        The field name. Completes from the schema cache when -Table is given.
        .PARAMETER Operator
        The comparison operator (default =).
        .PARAMETER Value
        The value to compare against. Arrays are used for IN and BETWEEN.
        .PARAMETER Joiner
        AND (default), OR or NQ.
        .PARAMETER Table
        The table used for field tab completion.
        .PARAMETER Query
        The existing query, normally from the pipeline.
        .EXAMPLE
        New-SnowQuery | Where-SnowField active -Operator '=' -Value $true

        Starts a query with one condition.
        .EXAMPLE
        'active=true' | Where-SnowField priority -Operator IN -Value @('1', '2') -Joiner OR

        Extends an existing raw query.
        .EXAMPLE
        New-SnowQuery | Where-SnowField assigned_to -Operator ISEMPTY | Where-SnowField sys_created_on -Operator BETWEEN -Value @('2026-01-01', '2026-01-31')

        Finds unassigned records created in January.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            & (Get-Module Snowplow) {
                param($table, $word)
                Get-SnowCompletionValue -Kind Field -Table $table -Word $word
            } $fakeBoundParameters.Table $wordToComplete
        })]
        [Parameter(Position = 0, Mandatory)][string]$Field,
        [ValidateSet('=', '!=', 'LIKE', 'STARTSWITH', 'IN', '>', '<', 'BETWEEN', 'ISEMPTY', 'ISNOTEMPTY')]
        [string]$Operator = '=',
        [AllowNull()][object]$Value,
        [ValidateSet('AND', 'OR', 'NQ')][string]$Joiner = 'AND',
        [string]$Table,
        [Parameter(ValueFromPipeline)][AllowEmptyString()][string]$Query = ''
    )
    process {
        $condition = ConvertTo-SnowQueryCondition -Field $Field -Operator $Operator -Value $Value
        $prefix = if ($Query) {
            if ($Joiner -eq 'AND') { '^' } else { "^$($Joiner.ToUpperInvariant())" }
        }
        else { '' }
        "$Query$prefix$condition"
    }
}

function Add-SnowOrderBy {
    <#
        .SYNOPSIS
        Adds a field sort to a ServiceNow encoded query.
        .PARAMETER Field
        One or more fields to sort by.
        .PARAMETER Descending
        Sorts descending instead of ascending.
        .PARAMETER Table
        The table used for field tab completion.
        .PARAMETER Query
        The existing query, normally from the pipeline.
        .EXAMPLE
        New-SnowQuery -Conditions @{ active = 'true' } | Add-SnowOrderBy number

        Sorts by incident number ascending.
        .EXAMPLE
        'active=true' | Add-SnowOrderBy sys_created_on -Descending

        Newest records first.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            & (Get-Module Snowplow) {
                param($table, $word)
                Get-SnowCompletionValue -Kind Field -Table $table -Word $word
            } $fakeBoundParameters.Table $wordToComplete
        })]
        [Parameter(Position = 0, Mandatory)][string[]]$Field,
        [switch]$Descending,
        [string]$Table,
        [Parameter(ValueFromPipeline)][AllowEmptyString()][string]$Query = ''
    )
    process {
        foreach ($fieldName in $Field) {
            if ($fieldName -notmatch '^[a-zA-Z_][a-zA-Z0-9_.]*$') {
                throw [System.ArgumentException]::new("Invalid ServiceNow field name '$fieldName'.")
            }
            $order = if ($Descending) { "^ORDERBYDESC$fieldName" } else { "^ORDERBY$fieldName" }
            $Query += $order
        }
        $Query
    }
}

function New-SnowRelativeDate {
    <#
        .SYNOPSIS
        Creates a javascript:gs relative-date value for an encoded query.
        .DESCRIPTION
        Produces expressions such as javascript:gs.daysAgoStart(7) so queries stay relative to when they run.
        .PARAMETER Last
        How many units back.
        .PARAMETER Unit
        Day(s), Week(s), Month(s) or Year(s) (default Days).
        .PARAMETER Boundary
        Start (default) or End of the period.
        .EXAMPLE
        New-SnowRelativeDate -Last 7 -Unit Days

        Returns the value for seven days ago.
        .EXAMPLE
        New-SnowQuery | Where-SnowField sys_updated_on -Operator '<' -Value (New-SnowRelativeDate -Last 90 -Unit Days) | Where-SnowField state -Operator = -Value 1

        Finds new records not touched in 90 days.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][ValidateRange(0, 9999)][int]$Last,
        [ValidateSet('Day', 'Days', 'Week', 'Weeks', 'Month', 'Months', 'Year', 'Years')]
        [string]$Unit = 'Days',
        [ValidateSet('Start', 'End')][string]$Boundary = 'Start'
    )

    $unitName = switch -Regex ($Unit) {
        '^Days?$' { 'days'; break }
        '^Weeks?$' { 'weeks'; break }
        '^Months?$' { 'months'; break }
        '^Years?$' { 'years'; break }
    }
    $boundaryName = if ($Boundary -ieq 'Start') { 'Start' } else { 'End' }
    "javascript:gs.$($unitName)Ago$boundaryName($Last)"
}
