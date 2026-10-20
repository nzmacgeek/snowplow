---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Find-SnowField

## SYNOPSIS
Adds a field condition to a ServiceNow encoded query.
Also available as Where-SnowField.

## SYNTAX

```
Find-SnowField [-Field] <String> [-Operator <String>] [-Value <Object>] [-Joiner <String>] [-Table <String>]
 [-Query <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Appends a condition to the query received from the pipeline.
Operators are =, !=, LIKE,
STARTSWITH, IN, \>, \<, BETWEEN, ISEMPTY and ISNOTEMPTY.

## EXAMPLES

### EXAMPLE 1
```
New-SnowQuery | Where-SnowField active -Operator '=' -Value $true
```

Starts a query with one condition.

### EXAMPLE 2
```
'active=true' | Where-SnowField priority -Operator IN -Value @('1', '2') -Joiner OR
```

Extends an existing raw query.

### EXAMPLE 3
```
New-SnowQuery | Where-SnowField assigned_to -Operator ISEMPTY | Where-SnowField sys_created_on -Operator BETWEEN -Value @('2026-01-01', '2026-01-31')
```

Finds unassigned records created in January.

## PARAMETERS

### -Field
The field name.
Completes from the schema cache when -Table is given.

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

### -Operator
The comparison operator (default =).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: =
Accept pipeline input: False
Accept wildcard characters: False
```

### -Value
The value to compare against.
Arrays are used for IN and BETWEEN.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Joiner
AND (default), OR or NQ.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: AND
Accept pipeline input: False
Accept wildcard characters: False
```

### -Table
The table used for field tab completion.

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

### -Query
The existing query, normally from the pipeline.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
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
