# Snowplow

Snowplow is a PowerShell 7 module for reading and administering ServiceNow instances through the
Table API. It turns everyday admin chores — triaging incidents, auditing the CMDB, bulk-fixing
data, following the system log — into short, scriptable, pipeline-friendly commands.

```powershell
Connect-Snowplow -Instance dev12345 -ClientId '<oauth-client-id>'
Get-SnowRecord -Table incident -Query 'active=true^priority=1' -Fields number,short_description -Limit 10
```

## Where to go next

- **New here?** Start with [Installation and first connection](getting-started.md).
- **Want to see it used?** Browse the [real-world workflows](workflows/index.md).
- **Looking up a command?** See the [cmdlet reference](cmdlets/index.md).
- **Automating?** Read [Authentication](authentication.md) and
  [Unattended automation](workflows/automation.md).

## Safety features

- HTTPS only; secrets are never written to profile files.
- Write cmdlets support `-WhatIf` and `-Confirm`.
- Profiles tagged `Prod` are read-only unless you connect with `-AllowWrite`, and always
  prompt before writing.
- `Get-SnowplowPromptSegment` can show the active instance in your prompt (Prod in red).
