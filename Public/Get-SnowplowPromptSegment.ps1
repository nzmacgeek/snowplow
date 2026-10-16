function Get-SnowplowPromptSegment {
    <#
    .SYNOPSIS
        Returns a colored prompt segment for the active Snowplow connection.
    .EXAMPLE
        "$(Get-SnowplowPromptSegment) PS $($executionContext.SessionState.Path.CurrentLocation)> "
    #>
    [CmdletBinding()]
    param()

    if (-not $script:SnowplowSession) { return }

    $session = $script:SnowplowSession
    $label = if ($session.Profile) { [string]$session.Profile } else { ([uri]$session.BaseUri).Host -replace '\.service-now\.com$', '' }
    $label = $label -replace '[\x00-\x1F\x7F]', ''
    $color = switch ($session.Environment) {
        'Prod' { $PSStyle.Foreground.Red }
        'Test' { $PSStyle.Foreground.Yellow }
        default { $PSStyle.Foreground.Green }
    }
    "$color[snow:$label]$($PSStyle.Reset)"
}
