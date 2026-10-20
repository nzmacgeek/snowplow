---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowRecord

## SYNOPSIS
Gets records from any ServiceNow table.

## SYNTAX

```
Get-SnowRecord [-Table] <String> [-Query <String>] [-Fields <String[]>] [-Limit <Int32>] [-All]
 [-Backend <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Reads records through the Table API.
Each result is a PSCustomObject whose type name is
Snowplow.Record.\<table\>.
By default at most 100 records are returned; use -Limit to change the
cap or -All to page through every matching record.

Reference fields are returned the way the Table API returns them.
Use -Fields to keep payloads
small on wide tables such as incident or cmdb_ci.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowRecord -Table incident -Query 'active=true^priority=1' -Fields number,short_description,assigned_to -Limit 25
```

Lists the 25 most recent active P1 incidents with only the columns you care about.

### EXAMPLE 2
```
Get-SnowRecord -Table incident -Query 'number=INC0010001'
```

Looks up a single incident by number.

### EXAMPLE 3
```
' -Value (New-SnowRelativeDate -Last 7 -Unit Days)
Get-SnowRecord -Table change_request -Query $query -All | Group-Object state | Select-Object Name, Count
```

Counts every change request raised in the last week by state.

### EXAMPLE 4
```
Get-SnowRecord -Table sys_user -Query 'active=true^last_login<javascript:gs.daysAgoStart(90)' -All |
    Select-Object user_name, name, last_login
```

Finds active users who have not logged in for 90 days, ready for a licence clean-up review.

### EXAMPLE 5
```
Get-SnowRecord -Table incident -Limit 1 | Get-SnowLink -Format Markdown
```

Pipes a record into Get-SnowLink to produce a link you can paste into a chat or ticket.

## PARAMETERS

### -Table
The internal table name, such as incident, change_request or sys_user.
Tab completion uses the
cache filled by Get-SnowTable.

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

### -Query
A ServiceNow encoded query.
Build one with New-SnowQuery or pass a raw string such as 'active=true^priority=1'.

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

### -Fields
The fields to return.
Tab completion uses the cache filled by Get-SnowDictionary.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
The maximum number of records to return (1-10000, default 100).
Ignored when -All is used.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 100
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Pages through every matching record instead of stopping at -Limit.

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
Auto currently selects Rest.

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
