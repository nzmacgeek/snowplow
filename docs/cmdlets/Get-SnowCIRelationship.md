---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowCIRelationship

## SYNOPSIS
Gets CMDB configuration item relationships.

## SYNTAX

```
Get-SnowCIRelationship [[-Query] <String>] [[-Fields] <String[]>] [[-Limit] <Int32>] [-All]
 [[-Backend] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
A convenience wrapper over Get-SnowRecord for the cmdb_rel_ci table.
Parent and child values are
sys_ids of CIs.

## EXAMPLES

### EXAMPLE 1
```
$ci = Get-SnowCI -Query 'name=prod-web-01' -Fields sys_id | Select-Object -First 1
Get-SnowCIRelationship -Query "child=$($ci.sys_id)" -All
```

Finds what depends on a server before a maintenance window.

### EXAMPLE 2
```
Get-SnowCIRelationship -Query "parent=$($ci.sys_id)" -Fields type,child | Format-Table
```

Lists the downstream items of a CI.

## PARAMETERS

### -Query
An encoded query such as 'parent=\<sys_id\>' or 'child=\<sys_id\>'.

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

### -Fields
The fields to return.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
The maximum number of relationships to return (default 100).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 100
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Returns every matching relationship.

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
