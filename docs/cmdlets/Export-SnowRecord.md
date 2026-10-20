---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Export-SnowRecord

## SYNOPSIS
Exports records as CSV or JSON.

## SYNTAX

```
Export-SnowRecord [-InputObject] <PSObject> [[-Format] <String>] [[-Path] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Accepts pipeline objects from the Snowplow cmdlets.
With -Path the output is written to a file;
without it the text is returned on the pipeline.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description,priority -All |
    Export-SnowRecord -Format Csv -Path .\open-incidents.csv
```

Produces a spreadsheet-friendly report of open incidents.

### EXAMPLE 2
```
Get-SnowCI -Limit 10 | Export-SnowRecord -Format Json
```

Writes JSON to the pipeline, for example to feed another tool.

### EXAMPLE 3
```
Get-SnowRecord -Table sys_properties -Query 'nameSTARTSWITHglide.ui' -All | Export-SnowRecord -Format Json -Path .\ui-properties-backup.json
```

Takes a backup of system properties before changing them.

## PARAMETERS

### -InputObject
The records to export.
Normally supplied from the pipeline.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Format
Csv (default) or Json.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Json
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
The file to write.
Omit to return text.

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

## NOTES

## RELATED LINKS
