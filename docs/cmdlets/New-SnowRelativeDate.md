---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# New-SnowRelativeDate

## SYNOPSIS
Creates a javascript:gs relative-date value for an encoded query.

## SYNTAX

```
New-SnowRelativeDate [-Last] <Int32> [[-Unit] <String>] [[-Boundary] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Produces expressions such as javascript:gs.daysAgoStart(7) so queries stay relative to when they run.

## EXAMPLES

### EXAMPLE 1
```
New-SnowRelativeDate -Last 7 -Unit Days
```

Returns the value for seven days ago.

### EXAMPLE 2
```
New-SnowQuery | Where-SnowField sys_updated_on -Operator '<' -Value (New-SnowRelativeDate -Last 90 -Unit Days) | Where-SnowField state -Operator = -Value 1
```

Finds new records not touched in 90 days.

## PARAMETERS

### -Last
How many units back.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Unit
Day(s), Week(s), Month(s) or Year(s) (default Days).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Days
Accept pipeline input: False
Accept wildcard characters: False
```

### -Boundary
Start (default) or End of the period.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Start
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

### System.String
## NOTES

## RELATED LINKS
