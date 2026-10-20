---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Compare-SnowRecord

## SYNOPSIS
Compares two record objects and returns the differing properties.

## SYNTAX

```
Compare-SnowRecord [-Reference] <PSObject> [-Difference] <PSObject> [[-Property] <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns changed, added and missing properties.
Records can be collected from the same instance
or from separate instances; connect to each in turn and keep the results in variables.

## EXAMPLES

### EXAMPLE 1
```
Connect-Snowplow -Profile dev -ClientCredentials
$dev = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'
Connect-Snowplow -Profile prod -ClientCredentials
$prod = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'
Compare-SnowRecord -Reference $dev -Difference $prod -Property value
```

Checks a system property for drift between Dev and Prod.

### EXAMPLE 2
```
Compare-SnowRecord -Reference $before -Difference $after
```

Shows exactly what a script changed on a record.

## PARAMETERS

### -Reference
The baseline record.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Difference
The record to compare against the baseline.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Property
Limits the comparison to these properties.

```yaml
Type: String[]
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
