---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Set-SnowRecord

## SYNOPSIS
Updates a ServiceNow record.

## SYNTAX

```
Set-SnowRecord [-Table] <String> [-SysId] <String> [-Values] <IDictionary> [-Replace] [-Backend <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Updates by sys_id.
Uses PATCH so only the supplied fields change, unless -Replace selects PUT.
Supports -WhatIf and -Confirm.
Prod-tagged profiles require -AllowWrite at connect time and
always prompt for confirmation.

## EXAMPLES

### EXAMPLE 1
```
Set-SnowRecord -Table incident -SysId 9d385017c611228701d22104cc95c371 -Values @{ priority = '2' }
```

Raises or lowers the priority of one incident.

### EXAMPLE 2
```
$incident = Get-SnowRecord -Table incident -Query 'number=INC0010001' -Fields sys_id
Set-SnowRecord -Table incident -SysId $incident.sys_id -Values @{ state = '6'; close_code = 'Solved (Permanently)'; close_notes = 'Replaced toner.' }
```

Resolves an incident by looking up its sys_id from the number first.

### EXAMPLE 3
```
$serviceDeskGroups = @(Get-SnowRecord -Table sys_user_group -Query 'name=Service Desk' -Fields sys_id -Limit 2)
if ($serviceDeskGroups.Count -ne 1) { throw "Expected exactly one Service Desk group, found $($serviceDeskGroups.Count)." }
$assignmentGroupId = $serviceDeskGroups[0].sys_id
Get-SnowRecord -Table incident -Query 'active=true^assigned_to=' -Fields sys_id |
    ForEach-Object { Set-SnowRecord -Table incident -SysId $_.sys_id -Values @{ assignment_group = $assignmentGroupId } -WhatIf }
```

Previews reassigning every unassigned incident to the Service Desk group.
Remove -WhatIf to apply.

## PARAMETERS

### -Table
The internal table name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SysId
The 32-character sys_id of the record.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Values
A hashtable of fields to change.

```yaml
Type: IDictionary
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Replace
Uses PUT instead of PATCH.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Backend
Rest, Sdk or Auto.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject
## NOTES

## RELATED LINKS
