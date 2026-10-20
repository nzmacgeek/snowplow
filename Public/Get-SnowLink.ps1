function Get-SnowLink {
    <#
        .SYNOPSIS
        Builds a ServiceNow URL for a record, list, or table.
        .DESCRIPTION
        Builds a record URL from -Table with -SysId or -Number, a list URL from -Table with -Query, or
        a table-definition URL with -Schema. Pipeline objects from Get-SnowRecord are accepted.
        .PARAMETER Table
        The table name. Taken from the pipeline object when omitted.
        .PARAMETER InputObject
        A record from Get-SnowRecord.
        .PARAMETER SysId
        The sys_id of the record.
        .PARAMETER Number
        A record number such as INC0010001. The record is resolved for you.
        .PARAMETER Query
        An encoded query to build a list URL.
        .PARAMETER Schema
        Builds a link to the table definition.
        .PARAMETER Format
        Url (default), Markdown or Html.
        .PARAMETER Clipboard
        Copies the result to the clipboard when supported.
        .PARAMETER UseNavTo
        Builds a classic frame-wrapped URL.
        .EXAMPLE
        Get-SnowLink -Table incident -Number INC0010001 -Format Markdown

        Creates a link you can paste in Teams, Slack or a pull request.
        .EXAMPLE
        Get-SnowLink -Table incident -Query 'active=true^priority=1'

        Creates a link to a filtered list view.
        .EXAMPLE
        Get-SnowRecord -Table change_request -Query 'state=-1' -Limit 5 | Get-SnowLink -Format Html

        Produces HTML links for an email summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Table,
        [Parameter(ValueFromPipeline)][psobject]$InputObject,
        [string]$SysId,
        [string]$Number,
        [string]$Query,
        [switch]$Schema,
        [ValidateSet('Url', 'Markdown', 'Html')][string]$Format = 'Url',
        [switch]$Clipboard,
        [switch]$UseNavTo
    )
    begin { $links = [System.Collections.Generic.List[string]]::new() }
    process {
        $url = New-SnowRecordUri -Table $Table -SysId $SysId -Number $Number -Query $Query -Schema:$Schema -UseNavTo:$UseNavTo -InputObject $InputObject
        $label = if ($Number) { $Number } elseif ($InputObject -and $InputObject.PSObject.Properties['number']) { [string]$InputObject.number } elseif ($SysId) { "$Table/$SysId" } else { $Table }
        if ([string]::IsNullOrWhiteSpace($label)) { $label = $url }
        $link = switch ($Format) {
            Markdown {
                $markdownLabel = $label.Replace('\', '\\').Replace('[', '\[').Replace(']', '\]')
                "[$markdownLabel]($url)"
            }
            Html {
                $encodedUrl = [System.Net.WebUtility]::HtmlEncode($url)
                $encodedLabel = [System.Net.WebUtility]::HtmlEncode($label)
                "<a href=`"$encodedUrl`">$encodedLabel</a>"
            }
            default { $url }
        }
        $links.Add($link)
    }
    end {
        if ($Clipboard) {
            $copied = $false
            if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                try {
                    $null = Set-Clipboard -Value ($links -join [Environment]::NewLine) -ErrorAction Stop
                    $copied = $true
                }
                catch {
                    $copied = $false
                }
            }
            if (-not $copied -and (Get-SnowplowPlatform) -eq 'Linux') {
                $text = $links -join [Environment]::NewLine
                foreach ($clipboardUtility in @(
                    @{ Name = 'wl-copy'; Arguments = @() },
                    @{ Name = 'xclip'; Arguments = @('-selection', 'clipboard') },
                    @{ Name = 'xsel'; Arguments = @('--clipboard', '--input') }
                )) {
                    $command = Get-Command $clipboardUtility.Name -CommandType Application -ErrorAction SilentlyContinue
                    if (-not $command) { continue }
                    try {
                        $arguments = $clipboardUtility.Arguments
                        $text | & $command.Source @arguments
                        if ($LASTEXITCODE -eq 0) {
                            $copied = $true
                            break
                        }
                    }
                    catch {
                        continue
                    }
                }
            }
            if (-not $copied) {
                Write-Warning 'Clipboard support is unavailable; the link is still returned.'
            }
        }
        $links.ToArray()
    }
}
