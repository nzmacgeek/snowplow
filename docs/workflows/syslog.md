# Troubleshooting with the system log

**Scenario:** users report that a flow times out. Reproduce the issue while watching the log.

## Recent errors

```powershell
Get-SnowSyslog -Level error -Last 50
```

By default Snowplow returns rows from the last 15 minutes, capped at 100.

## Follow the log like `tail -f`

```powershell
Get-SnowSyslog -Wait -Pretty -Source 'Flow Engine' -Message timeout -PollSeconds 10
```

Trigger the flow in another window; matching rows print as they arrive. Press **Ctrl+C** to stop.

## Rank the noisiest sources

```powershell
Get-SnowSyslog -Level error -Since (Get-Date).AddHours(-2) -Last 500 |
    Group-Object source | Sort-Object Count -Descending |
    Select-Object -First 5 Name, Count
```

## Check slow transactions or a scoped app

```powershell
Get-SnowSyslog -Table syslog_transaction -Since (Get-Date).AddMinutes(-30) -Last 200
Get-SnowSyslog -Table syslog_app_scope -Level error -Last 100
```

## Capture evidence for a ticket

```powershell
Get-SnowSyslog -Level error -User integration.user -Last 200 |
    Export-SnowRecord -Format Json -Path .\integration-errors.json
```

Related: [Get-SnowSyslog](../cmdlets/Get-SnowSyslog.md).
