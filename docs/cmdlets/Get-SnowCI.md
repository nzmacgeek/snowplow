---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowCI

## SYNOPSIS
Gets configuration items from the CMDB.

## SYNTAX

```
Get-SnowCI [[-Query] <String>] [[-Fields] <String[]>] [[-Limit] <Int32>] [-All] [[-Backend] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
A convenience wrapper over Get-SnowRecord for the cmdb_ci table.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowCI -Query 'install_status=1^sys_class_name=cmdb_ci_linux_server' -Fields name,ip_address,os_version -All
```

Lists all installed Linux servers with their IP address and OS version.

### EXAMPLE 2
```
Get-SnowCI -Query 'operational_status=2' -Fields name,sys_class_name | Export-SnowRecord -Format Csv -Path .\non-operational-cis.csv
```

Exports non-operational CIs for an audit.

## PARAMETERS

### -Query
An encoded query, for example 'sys_class_name=cmdb_ci_linux_server'.

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
The maximum number of CIs to return (default 100).

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
Returns every matching CI.

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
