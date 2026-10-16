function Start-SnowSleep {
    # Thin wrapper so tests can mock backoff delays.
    [CmdletBinding()]
    param([Parameter(Mandatory)][double]$Seconds)
    Start-Sleep -Milliseconds ([int]($Seconds * 1000))
}
