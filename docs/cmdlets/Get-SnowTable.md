---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowTable

## SYNOPSIS
Lists ServiceNow tables and their labels.

## SYNTAX

```
Get-SnowTable [[-Query] <String>] [[-Limit] <Int32>] [-All] [[-Backend] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries sys_db_object.
Results also populate the cache used for -Table tab completion.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowTable -Query 'nameSTARTSWITHcmdb_ci' -All
```

Discovers the CMDB class tables available on your instance.

### EXAMPLE 2
```
Get-SnowTable -All | Out-Null
```

Fills the tab-completion cache so Get-SnowRecord -Table \<Tab\> completes your tables.

## PARAMETERS

### -Query
An encoded query against sys_db_object, for example 'nameSTARTSWITHcmdb'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
The maximum number of tables to return (default 100).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 1000
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Returns every matching table.

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
Position: 3
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
