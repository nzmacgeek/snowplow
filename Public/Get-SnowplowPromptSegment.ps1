function Get-SnowplowPromptSegment {
    <#
        .SYNOPSIS
        Returns a colored prompt segment for the active Snowplow connection.
        .DESCRIPTION
        Returns the profile (or instance) name; Prod is red and Test is yellow. Returns nothing when
        disconnected. The module never changes your prompt automatically.
        .EXAMPLE
        function prompt { "$(Get-SnowplowPromptSegment) PS $($executionContext.SessionState.Path.CurrentLocation)> " }

        Adds a safety indicator to your prompt so you always know which instance you are talking to.
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
    if ($env:NO_COLOR -or -not $Host.UI.SupportsVirtualTerminal) {
        return "[snow:$label]"
    }
    "$color[snow:$label]$($PSStyle.Reset)"
}
