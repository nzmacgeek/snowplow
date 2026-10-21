---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# New-SnowQuery

## SYNOPSIS
Builds a ServiceNow encoded query.

## SYNTAX

```
New-SnowQuery [[-Conditions] <IDictionary>] [-Joiner <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Hashtable values are equality conditions.
Use a descriptor with Operator,
Value, and optional Joiner keys for other operators and OR/NQ conditions.
Use an \[ordered\] hashtable when condition order matters.
Calling it with no arguments returns an
empty query for use with Where-SnowField and Add-SnowOrderBy.

## EXAMPLES

### EXAMPLE 1
```
New-SnowQuery -Conditions ([ordered]@{ active = 'true'; priority = '1' })
```

Builds 'active=true^priority=1'.

### EXAMPLE 2
```
New-SnowQuery -Conditions @{ priority = @{ Operator = 'IN'; Value = @('1', '2') } }
```

Matches P1 and P2.

### EXAMPLE 3
```
$q = New-SnowQuery -Conditions @{ active = 'true' } | Where-SnowField short_description -Operator LIKE -Value 'VPN' | Add-SnowOrderBy sys_created_on -Descending
Get-SnowRecord -Table incident -Query $q -Limit 10
```

Finds the ten newest active incidents mentioning VPN.

## PARAMETERS

### -Conditions
A hashtable of field names to values or descriptors.

```yaml
Type: IDictionary
Parameter Sets: (All)
Aliases: Filter, Where

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Joiner
AND (default), OR or NQ, used between conditions.

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
