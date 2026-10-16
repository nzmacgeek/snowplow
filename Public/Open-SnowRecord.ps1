function Open-SnowRecord {
    <#
    .SYNOPSIS
        Opens a ServiceNow record, list, or table in the default browser.
    .EXAMPLE
        Open-SnowRecord -Table incident -SysId $id
    .EXAMPLE
        Get-SnowRecord -Table incident -Limit 5 | Open-SnowRecord
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
        if ($urls.Count -gt 5 -and -not $Force -and -not $PSCmdlet.ShouldContinue("Open $($urls.Count) ServiceNow pages?", 'Confirm bulk browser open')) {
            return
        }

        foreach ($url in $urls) {
            if (-not $PSCmdlet.ShouldProcess($url, 'Open in browser')) { continue }

            try {
                if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
                    Start-Process -FilePath $url -ErrorAction Stop
                }
                elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
                    $null = & open $url
                    if ($LASTEXITCODE -ne 0) { throw 'The macOS open command failed.' }
                }
                else {
                    if ($env:CI -or (-not $env:DISPLAY -and -not $env:WAYLAND_DISPLAY)) {
                        throw 'No graphical browser session is available. Use Get-SnowLink to retrieve the URL instead.'
                    }
                    if (-not (Get-Command xdg-open -ErrorAction SilentlyContinue)) {
                        throw 'The xdg-open command is unavailable. Use Get-SnowLink to retrieve the URL instead.'
                    }
                    $null = & xdg-open $url
                    if ($LASTEXITCODE -ne 0) { throw 'The xdg-open command failed.' }
                }
            }
            catch {
                if ($_.Exception.Message -like 'No graphical browser session*' -or $_.Exception.Message -like 'The xdg-open command is unavailable*') {
                    throw [System.InvalidOperationException]::new($_.Exception.Message)
                }
                throw [System.InvalidOperationException]::new("Could not open the ServiceNow URL in a browser. Use Get-SnowLink to retrieve it. $($_.Exception.Message)")
            }
        }
    }
}
