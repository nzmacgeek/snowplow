#Requires -Version 7.2
<#
.SYNOPSIS
    Regenerates the platyPS markdown in docs/cmdlets from the comment-based help.
.DESCRIPTION
    Run from the repository root before committing help changes. Use -Check in CI to fail
    when the committed markdown is out of date.
#>
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'docs/cmdlets'

if (-not (Get-Module -ListAvailable platyPS)) {
    Install-Module platyPS -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module platyPS
Import-Module (Join-Path $root 'Snowplow.psd1') -Force

New-Item -ItemType Directory -Path $output -Force | Out-Null
$exported = (Get-Module Snowplow).ExportedFunctions.Keys
Get-ChildItem $output -Filter *.md | Where-Object { $_.BaseName -notin $exported -and $_.BaseName -ne 'index' } | Remove-Item
$null = New-MarkdownHelp -Module Snowplow -OutputFolder $output -Force
Get-ChildItem $output -Filter *.md | ForEach-Object {
    $content = [IO.File]::ReadAllText($_.FullName) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($_.FullName, $content.TrimEnd() + "`n")
}

if ($Check) {
    $changes = git -C $root status --porcelain -- docs/cmdlets
    if ($changes) {
        $changes
        throw 'docs/cmdlets is out of date. Run ./tools/Build-Docs.ps1 and commit the result.'
    }
}
