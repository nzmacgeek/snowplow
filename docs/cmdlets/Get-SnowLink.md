---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowLink

## SYNOPSIS
Builds a ServiceNow URL for a record, list, or table.

## SYNTAX

```
Get-SnowLink [[-Table] <String>] [-InputObject <PSObject>] [-SysId <String>] [-Number <String>]
 [-Query <String>] [-Schema] [-Format <String>] [-Clipboard] [-UseNavTo] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Builds a record URL from -Table with -SysId or -Number, a list URL from -Table with -Query, or
a table-definition URL with -Schema.
Pipeline objects from Get-SnowRecord are accepted.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowLink -Table incident -Number INC0010001 -Format Markdown
```

Creates a link you can paste in Teams, Slack or a pull request.

### EXAMPLE 2
```
Get-SnowLink -Table incident -Query 'active=true^priority=1'
```

Creates a link to a filtered list view.

### EXAMPLE 3
```
Get-SnowRecord -Table change_request -Query 'state=-1' -Limit 5 | Get-SnowLink -Format Html
```

Produces HTML links for an email summary.

## PARAMETERS

### -Table
The table name.
Taken from the pipeline object when omitted.

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

### -InputObject
A record from Get-SnowRecord.

```yaml
Type: PSObject
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -SysId
The sys_id of the record.

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

### -Number
A record number such as INC0010001.
The record is resolved for you.

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
An encoded query to build a list URL.

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

### -Schema
Builds a link to the table definition.

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

### -Format
Url (default), Markdown or Html.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Url
Accept pipeline input: False
Accept wildcard characters: False
```

### -Clipboard
Copies the result to the clipboard when supported.

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

### -UseNavTo
Builds a classic frame-wrapped URL.

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
