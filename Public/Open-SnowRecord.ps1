function Open-SnowRecord {
    <#
        .SYNOPSIS
        Opens a ServiceNow record, list, or table in the default browser.
        .DESCRIPTION
        Accepts the same targets as Get-SnowLink. Pipeline batches over five records ask for
        confirmation unless -Force is supplied. On Linux a graphical session and xdg-open are needed.
        .PARAMETER Table
        The table name.
        .PARAMETER InputObject
        A record from Get-SnowRecord.
        .PARAMETER SysId
        The sys_id of the record.
        .PARAMETER Number
        A record number such as INC0010001.
        .PARAMETER Query
        Opens a list view filtered by this encoded query.
        .PARAMETER Schema
        Opens the table definition.
        .PARAMETER PassThru
        Returns the URLs without opening the browser.
        .PARAMETER Force
        Skips the confirmation for batches over five records.
        .PARAMETER UseNavTo
        Uses the classic frame-wrapped URL.
        .EXAMPLE
        Open-SnowRecord -Table incident -Number INC0010001

        Jumps straight to an incident from the console.
        .EXAMPLE
        Get-SnowRecord -Table incident -Query 'active=true^priority=1' | Open-SnowRecord

        Opens every active P1 (asks first if more than five).
        .EXAMPLE
        Open-SnowRecord -Table incident -Query 'active=true^assignment_group.name=Service Desk'

        Opens the Service Desk queue as a list.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)][string]$Table,
        [Parameter(ValueFromPipeline)][psobject]$InputObject,
        [string]$SysId,
        [string]$Number,
        [string]$Query,
        [switch]$Schema,
        [switch]$PassThru,
        [switch]$Force,
        [switch]$UseNavTo
    )
    begin { $urls = [System.Collections.Generic.List[string]]::new() }
    process {
        $urls.Add((New-SnowRecordUri -Table $Table -SysId $SysId -Number $Number -Query $Query -Schema:$Schema -UseNavTo:$UseNavTo -InputObject $InputObject))
    }
    end {
        if ($PassThru) {
            $urls.ToArray()
            return
        }
        if ($urls.Count -gt 5 -and -not $Force -and -not $WhatIfPreference -and -not $PSCmdlet.ShouldContinue("Open $($urls.Count) ServiceNow pages?", 'Confirm bulk browser open')) {
            return
        }

        foreach ($url in $urls) {
            if (-not $PSCmdlet.ShouldProcess($url, 'Open in browser')) { continue }

            try {
                $platform = Get-SnowplowPlatform
                if ($platform -eq 'Windows') {
                    Start-Process -FilePath $url -ErrorAction Stop
                }
                elseif ($platform -eq 'MacOS') {
                    $null = & open $url
                    if ($LASTEXITCODE -ne 0) { throw 'The macOS open command failed.' }
                }
                elseif ($platform -eq 'Linux') {
                    if ($env:CI -or (-not $env:DISPLAY -and -not $env:WAYLAND_DISPLAY)) {
                        throw 'No graphical browser session is available. Use Get-SnowLink to retrieve the URL instead.'
                    }
                    if (-not (Get-Command xdg-open -ErrorAction SilentlyContinue)) {
                        throw 'The xdg-open command is unavailable. Use Get-SnowLink to retrieve the URL instead.'
                    }
                    $null = & xdg-open $url
                    if ($LASTEXITCODE -ne 0) { throw 'The xdg-open command failed.' }
                }
                else {
                    throw 'Browser integration is not supported on this platform. Use Get-SnowLink to retrieve the URL instead.'
                }
            }
            catch {
                if ($_.Exception.Message -like 'No graphical browser session*' -or
                    $_.Exception.Message -like 'The xdg-open command is unavailable*' -or
                    $_.Exception.Message -like 'Browser integration is not supported*') {
                    throw [System.InvalidOperationException]::new($_.Exception.Message)
                }
                throw [System.InvalidOperationException]::new("Could not open the ServiceNow URL in a browser. Use Get-SnowLink to retrieve it. $($_.Exception.Message)")
            }
        }
    }
}
