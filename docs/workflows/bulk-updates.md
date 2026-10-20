# Bulk updates safely

**Scenario:** a team was renamed and you need to reassign its open incidents, and you want to be
certain nothing unexpected changes.

## The safe pattern

1. Query exactly the records you intend to change.
2. Back them up.
3. Preview with `-WhatIf`.
4. Apply.
5. Verify.

```powershell
Connect-Snowplow -Profile test -ClientCredentials

# 1. Select
$targets = Get-SnowRecord -Table incident `
    -Query 'active=true^assignment_group.name=Helpdesk' `
    -Fields sys_id,number,assignment_group -All
"$($targets.Count) incidents selected"

# 2. Back up
$targets | Export-SnowRecord -Format Json -Path ".\backup-$(Get-Date -Format yyyyMMdd-HHmm).json"

# 3. Preview
$targets | ForEach-Object {
    Set-SnowRecord -Table incident -SysId $_.sys_id -Values @{ assignment_group = 'Service Desk' } -WhatIf
}

# 4. Apply
$targets | ForEach-Object {
    Set-SnowRecord -Table incident -SysId $_.sys_id -Values @{ assignment_group = 'Service Desk' }
}

# 5. Verify
Get-SnowRecord -Table incident -Query 'active=true^assignment_group.name=Helpdesk' -Limit 1
```

## Production guard rails

A profile with `-Environment Prod` refuses writes until you reconnect with `-AllowWrite`, and then
prompts for each one. Rehearse the same script against a Test profile first.

```powershell
Add-SnowplowProfile -Name prod -Instance acme -ClientCredentialSecretName SnowplowProdOAuth -Environment Prod
Connect-Snowplow -Profile prod -ClientCredentials -AllowWrite
```

## Clean up test data

```powershell
Get-SnowRecord -Table sys_user -Query 'user_nameSTARTSWITHtest.' -Fields sys_id,user_name |
    ForEach-Object { Remove-SnowRecord -Table sys_user -SysId $_.sys_id -WhatIf }
```

Related: [Set-SnowRecord](../cmdlets/Set-SnowRecord.md), [New-SnowRecord](../cmdlets/New-SnowRecord.md),
[Remove-SnowRecord](../cmdlets/Remove-SnowRecord.md).
