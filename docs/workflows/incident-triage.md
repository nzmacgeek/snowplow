# Incident triage

**Scenario:** you lead a service desk and start the day by reviewing high-priority incidents,
finding what has no owner, and closing out work that is done.

## 1. See what is on fire

```powershell
Connect-Snowplow -Profile prod -ClientCredentials

Get-SnowRecord -Table incident -Query 'active=true^priority=1' `
    -Fields number,short_description,assigned_to,assignment_group,opened_at |
    Format-Table
```

## 2. Find incidents nobody owns

```powershell
$query = New-SnowQuery -Conditions @{ active = 'true' } |
    Where-SnowField assigned_to -Operator ISEMPTY |
    Add-SnowOrderBy priority, sys_created_on

$unassigned = Get-SnowRecord -Table incident -Query $query -Fields number,short_description,priority
$unassigned | Format-Table
```

## 3. Jump to one in the browser or share it

```powershell
Open-SnowRecord -Table incident -Number INC0010001

# A link to paste into Teams or Slack
Get-SnowLink -Table incident -Number INC0010001 -Format Markdown
```

## 4. Assign and resolve

Prod profiles are read-only by default, so reconnect with writes enabled for this step.

```powershell
Connect-Snowplow -Profile prod -ClientCredentials -AllowWrite

$inc = Get-SnowRecord -Table incident -Query 'number=INC0010001' -Fields sys_id
Set-SnowRecord -Table incident -SysId $inc.sys_id -Values @{ assignment_group = 'Service Desk' } -WhatIf
Set-SnowRecord -Table incident -SysId $inc.sys_id -Values @{
    state       = '6'
    close_code  = 'Solved (Permanently)'
    close_notes = 'Replaced toner cartridge.'
}
```

Snowplow asks for confirmation on every Prod write. Finish with `Disconnect-Snowplow`.

Related: [Get-SnowRecord](../cmdlets/Get-SnowRecord.md), [Set-SnowRecord](../cmdlets/Set-SnowRecord.md),
[Open-SnowRecord](../cmdlets/Open-SnowRecord.md).
