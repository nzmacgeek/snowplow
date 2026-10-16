function Get-SnowLink {
    <#
    .SYNOPSIS
        Builds a ServiceNow URL for a record, list, or table.
    .EXAMPLE
        Get-SnowLink -Table incident -SysId $id
    .EXAMPLE
        Get-SnowRecord -Table incident -Limit 5 | Get-SnowLink -Format Markdown
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
            if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                try {
                    $null = Set-Clipboard -Value ($links -join [Environment]::NewLine) -ErrorAction Stop
                }
                catch {
                    Write-Warning 'Could not copy the link to the clipboard; the link is still returned.'
                }
            }
            else {
                Write-Warning 'Clipboard support is unavailable; the link is still returned.'
            }
        }
        $links.ToArray()
    }
}
