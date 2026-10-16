function New-SnowRecordUri {
    [CmdletBinding()]
    param(
        [string]$Table,
        [string]$SysId,
        [string]$Number,
        [string]$Query,
        [switch]$Schema,
        [switch]$UseNavTo,
        [psobject]$InputObject
    )

    $session = Get-SnowSession
    if ($InputObject) {
        if (-not $Table) {
            foreach ($typeName in $InputObject.PSTypeNames) {
                if ($typeName -match '^Snowplow\.Record\.(.+)$') {
                    $Table = $Matches[1]
                    break
                }
            }
        }
        if (-not $SysId -and $InputObject.PSObject.Properties['sys_id']) {
            $SysId = [string]$InputObject.sys_id
        }
        if (-not $SysId -and -not $Number -and $InputObject.PSObject.Properties['number']) {
            $Number = [string]$InputObject.number
        }
    }

    if (-not $Table -or $Table -notmatch '^[a-z0-9_]+$') {
        throw [System.ArgumentException]::new('Specify a valid -Table or pipe a Snowplow record.')
    }
    if ($Schema -and ($SysId -or $Number -or $Query)) {
        throw [System.ArgumentException]::new('-Schema cannot be combined with -SysId, -Number, or -Query.')
    }
    if ($SysId -and ($Number -or $Query)) {
        throw [System.ArgumentException]::new('-SysId cannot be combined with -Number or -Query.')
    }
    if ($Number -and $Query) {
        throw [System.ArgumentException]::new('-Number cannot be combined with -Query.')
    }

    if ($Schema) {
        $definition = @(Get-SnowRecord -Table sys_db_object -Query (New-SnowQuery -Conditions @{ name = $Table }) -Fields sys_id -Limit 1)
        if (-not $definition -or -not $definition[0].sys_id) {
            throw [System.Management.Automation.ItemNotFoundException]::new("ServiceNow table '$Table' was not found.")
        }
        if ([string]$definition[0].sys_id -notmatch '^[0-9a-fA-F]{32}$') {
            throw [System.IO.InvalidDataException]::new("ServiceNow returned an invalid sys_id for table '$Table'.")
        }
        $path = "sys_db_object.do?sys_id=$($definition[0].sys_id)"
    }
    elseif ($Number) {
        $numberQuery = New-SnowQuery -Conditions @{ number = $Number }
        $record = @(Get-SnowRecord -Table $Table -Query $numberQuery -Fields sys_id, number -Limit 1)
        if (-not $record -or -not $record[0].sys_id) {
            throw [System.Management.Automation.ItemNotFoundException]::new("No $Table record with number '$Number' was found.")
        }
        if ([string]$record[0].sys_id -notmatch '^[0-9a-fA-F]{32}$') {
            throw [System.IO.InvalidDataException]::new("ServiceNow returned an invalid sys_id for $Table record '$Number'.")
        }
        $path = "$Table.do?sys_id=$($record[0].sys_id)"
    }
    elseif ($SysId) {
        if ($SysId -notmatch '^[0-9a-fA-F]{32}$') {
            throw [System.ArgumentException]::new('-SysId must be a 32-character ServiceNow sys_id.')
        }
        $path = "$Table.do?sys_id=$SysId"
    }
    else {
        $path = "${Table}_list.do"
        if ($Query) {
            $path += "?sysparm_query=$([uri]::EscapeDataString($Query))"
        }
    }

    if ($UseNavTo) {
        $path = "nav_to.do?uri=$([uri]::EscapeDataString($path))"
    }
    [uri]::new([uri]$session.BaseUri, $path).AbsoluteUri
}
