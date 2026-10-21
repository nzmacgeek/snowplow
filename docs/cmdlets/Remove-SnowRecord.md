---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Remove-SnowRecord

## SYNOPSIS
Deletes a ServiceNow record.

## SYNTAX

```
Remove-SnowRecord [-Table] <String> [-SysId] <String> [-Backend <String>] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes by sys_id.
This is destructive and high impact, so it prompts for confirmation.
Always
try -WhatIf first.
Prod-tagged profiles require -AllowWrite at connect time.

## EXAMPLES

### EXAMPLE 1
```
Remove-SnowRecord -Table incident -SysId 9d385017c611228701d22104cc95c371 -WhatIf
```

Shows what would be deleted.

### EXAMPLE 2
```
Get-SnowRecord -Table sys_user -Query 'user_nameSTARTSWITHtest.' -Fields sys_id |
    ForEach-Object { Remove-SnowRecord -Table sys_user -SysId $_.sys_id -Confirm:$false }
```

Cleans up test accounts left behind by an automation run on a sub-production instance.

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
The 32-character sys_id of the record to delete.

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

## NOTES

## RELATED LINKS
