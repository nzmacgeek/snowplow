---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# New-SnowRecord

## SYNOPSIS
Creates a record in a ServiceNow table.

## SYNTAX

```
New-SnowRecord [-Table] <String> [-Values] <IDictionary> [-Backend <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Sends a POST to the Table API and returns the created record.
Supports -WhatIf and -Confirm.
Prod-tagged profiles are read-only unless you connected with -AllowWrite, and always prompt for
confirmation.

## EXAMPLES

### EXAMPLE 1
```
New-SnowRecord -Table incident -Values @{ short_description = 'Printer offline on level 3'; urgency = '2'; impact = '2' }
```

Logs a new incident.

### EXAMPLE 2
```
New-SnowRecord -Table incident -Values @{ short_description = 'Test' } -WhatIf
```

Shows what would be created without sending the request.
Use this before running a new script against a shared instance.

### EXAMPLE 3
```
Import-Csv .\new-users.csv | ForEach-Object {
    New-SnowRecord -Table sys_user -Values @{ user_name = $_.UserName; first_name = $_.First; last_name = $_.Last; email = $_.Email }
}
```

Bulk-creates users from a CSV file with columns UserName, First, Last and Email.

## PARAMETERS

### -Table
The internal table name to create the record in.

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

### -Values
A hashtable of field names and values.
Use the same internal field names you would see in the form.

```yaml
Type: IDictionary
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

### System.Management.Automation.PSObject
## NOTES

## RELATED LINKS
