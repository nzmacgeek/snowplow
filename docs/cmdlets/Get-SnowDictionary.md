---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowDictionary

## SYNOPSIS
Gets field definitions from the ServiceNow dictionary.

## SYNTAX

```
Get-SnowDictionary [-Table] <String> [[-Element] <String>] [[-Limit] <Int32>] [-All] [[-Backend] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries sys_dictionary for a table.
Results populate the cache used by -Fields tab completion
and by the query builder.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowDictionary -Table incident -All | Select-Object element, column_label, internal_type, max_length
```

Lists every column on the incident table so you know the names to use in queries.

### EXAMPLE 2
```
Get-SnowDictionary -Table incident -Element priority
```

Inspects one field.

### EXAMPLE 3
```
Get-SnowDictionary -Table x_acme_asset -All | Where-Object mandatory -eq 'true' | Select-Object element, column_label
```

Finds the mandatory fields on a custom table before scripting inserts.

## PARAMETERS

### -Table
The table whose fields you want.

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

### -Element
Limits the result to a single field (column) name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
The maximum number of rows to return.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 1000
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Returns every field.

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
Position: 4
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
