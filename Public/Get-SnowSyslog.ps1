function Get-SnowSyslogNewRow {
    # Returns only rows not yet seen, given the newest timestamp and the sys_ids already emitted at that timestamp.
    param(
        [AllowEmptyCollection()][object[]]$Row = @(),
        [string]$LastCreated,
        [System.Collections.Generic.HashSet[string]]$SeenIds
    )

    foreach ($item in $Row) {
        $created = [string]$item.sys_created_on
        if ($LastCreated -and $created -lt $LastCreated) { continue }
        if ($LastCreated -and $created -eq $LastCreated -and $SeenIds.Contains([string]$item.sys_id)) { continue }
        $item
    }
}

function Write-SnowSyslogLine {
    param([Parameter(Mandatory)][object]$Row)

    $level = if ($Row.PSObject.Properties['level']) { [string]$Row.level } else { '' }
    $name = switch ($level) { { $_ -in '2', 'error' } { 'error' } { $_ -in '1', 'warning' } { 'warning' } { $_ -in '3', 'debug' } { 'debug' } default { 'info' } }
    $color = switch ($name) { 'error' { 'Red' } 'warning' { 'Yellow' } 'debug' { 'DarkGray' } default { 'Gray' } }
    $source = if ($Row.PSObject.Properties['source']) { [string]$Row.source } else { '' }
    $message = if ($Row.PSObject.Properties['message']) { [string]$Row.message } elseif ($Row.PSObject.Properties['url']) { [string]$Row.url } else { '' }
    Write-Host ('{0} {1,-7} {2} {3}' -f $Row.sys_created_on, $name.ToUpperInvariant(), $source, $message) -ForegroundColor $color
}

function Get-SnowSyslog {
    <#
    .SYNOPSIS
        Queries the ServiceNow system log, optionally following new entries like tail -f.
    .DESCRIPTION
        Rows are returned oldest first. A time or row limit is always applied: by default the
        last 15 minutes, capped at 100 rows. With -Wait the log is polled every -PollSeconds
        (minimum 2) and only new rows are emitted; the last seen sys_created_on plus the sys_ids
        seen at that timestamp prevent duplicates and gaps. Failed polls back off and retry.
        Press Ctrl+C to stop. Use -Pretty for coloured console output instead of objects.
    .EXAMPLE
        Get-SnowSyslog -Level error -Last 50
    .EXAMPLE
        Get-SnowSyslog -Wait -Source 'Flow Engine' -Message timeout -PollSeconds 10
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateSet('syslog', 'syslog_transaction', 'syslog_app_scope')][string]$Table = 'syslog',
        [ValidateSet('error', 'warning', 'info', 'debug')][string]$Level,
        [string]$Source,
        [string]$Message,
        [string]$User,
        [datetime]$Since,
        [ValidateRange(1, 10000)][int]$Last = 100,
        [switch]$Wait,
        [ValidateRange(2, 3600)][int]$PollSeconds = 5,
        [ValidateRange(0, 1000000)][int]$MaxPolls = 0,
        [switch]$Pretty,
        [string[]]$Fields,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$Backend
    )

    if ($Table -eq 'syslog_transaction' -and ($Level -or $Source)) {
        throw [System.ArgumentException]::new('-Level and -Source are not supported for syslog_transaction.')
    }
    $levelValues = @{ info = '0'; warning = '1'; error = '2'; debug = '3' }
    $terms = [System.Collections.Generic.List[string]]::new()
    if ($Level) { $terms.Add("level=$($levelValues[$Level])") }
    if ($Source) { $terms.Add("source=$(ConvertTo-SnowQueryValue $Source)") }
    if ($Message) {
        $messageField = if ($Table -eq 'syslog_transaction') { 'url' } else { 'message' }
        $terms.Add("${messageField}LIKE$(ConvertTo-SnowQueryValue $Message)")
    }
    if ($User) { $terms.Add("sys_created_by=$(ConvertTo-SnowQueryValue $User)") }
    $sinceTime = if ($PSBoundParameters.ContainsKey('Since')) { $Since.ToUniversalTime() } else { [datetime]::UtcNow.AddMinutes(-15) }
    $format = 'yyyy-MM-dd HH:mm:ss'
    $sinceText = $sinceTime.ToString($format, [Globalization.CultureInfo]::InvariantCulture)
    $terms.Add("sys_created_on>=$sinceText")
    $filter = $terms -join '^'

    $request = @{ Table = $Table; Fields = $Fields; Backend = $Backend }
    if ($Fields) {
        $request.Fields = @($Fields + 'sys_id' + 'sys_created_on' | Select-Object -Unique)
    }
    $emit = {
        param($row)
        if ($Pretty) { Write-SnowSyslogLine -Row $row }
        else {
            if ($row -is [System.Collections.IDictionary]) { $row = [pscustomobject]$row }
            if ($row -is [pscustomobject]) { $row.PSTypeNames.Insert(0, "Snowplow.Record.$Table") }
            $row
        }
    }

    # Initial query: newest -Last rows within the window, then oldest first.
    $initial = @(Invoke-SnowBackendRequest @request -Query "$filter^ORDERBYDESCsys_created_on^ORDERBYDESCsys_id" -PageSize ([Math]::Min($Last, 1000)) -First $Last)
    [array]::Reverse($initial)
    $lastCreated = $sinceText
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($row in $initial) {
        $created = [string]$row.sys_created_on
        if ($created -gt $lastCreated) { $lastCreated = $created; $seen.Clear() }
        if ($created -eq $lastCreated) { [void]$seen.Add([string]$row.sys_id) }
        & $emit $row
    }
    if (-not $Wait) { return }

    Write-Warning "Following $Table every $PollSeconds second(s). Each poll is a request against the instance; press Ctrl+C to stop."
    $failures = 0
    $polls = 0
    try {
        while ($true) {
            $delay = if ($failures) { [Math]::Min($PollSeconds * [Math]::Pow(2, $failures), 300) } else { $PollSeconds }
            Start-SnowSleep -Seconds $delay
            $polls++
            $pollFilter = ($terms | Where-Object { $_ -notlike 'sys_created_on>=*' }) + "sys_created_on>=$lastCreated" -join '^'
            try {
                $rows = @(Invoke-SnowBackendRequest @request -Query "$pollFilter^ORDERBYsys_created_on^ORDERBYsys_id" -PageSize 1000)
                $failures = 0
            }
            catch {
                $failures++
                if ($failures -ge 5) { throw }
                Write-Warning "Syslog poll failed ($($_.Exception.Message)); backing off."
                $rows = @()
            }
            foreach ($row in @(Get-SnowSyslogNewRow -Row $rows -LastCreated $lastCreated -SeenIds $seen)) {
                $created = [string]$row.sys_created_on
                if ($created -gt $lastCreated) { $lastCreated = $created; $seen.Clear() }
                [void]$seen.Add([string]$row.sys_id)
                & $emit $row
            }
            if ($MaxPolls -and $polls -ge $MaxPolls) { break }
        }
    }
    finally {
        Write-Verbose 'Syslog follow stopped.'
    }
}
