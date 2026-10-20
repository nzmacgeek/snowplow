---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowSyslog

## SYNOPSIS
Queries the ServiceNow system log, optionally following new entries like tail -f.

## SYNTAX

```
Get-SnowSyslog [[-Table] <String>] [[-Level] <String>] [[-Source] <String>] [[-Message] <String>]
 [[-User] <String>] [[-Since] <DateTime>] [[-Last] <Int32>] [-Wait] [[-PollSeconds] <Int32>]
 [[-MaxPolls] <Int32>] [-Pretty] [[-Fields] <String[]>] [[-Backend] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Rows are returned oldest first.
A time or row limit is always applied: by default the
last 15 minutes, capped at 100 rows.
With -Wait the log is polled every -PollSeconds
(minimum 2) and only new rows are emitted; the last seen sys_created_on plus the sys_ids
seen at that timestamp prevent duplicates and gaps.
Failed polls back off and retry.
Press Ctrl+C to stop.
Use -Pretty for coloured console output instead of objects.

## EXAMPLES

### EXAMPLE 1
```
Get-SnowSyslog -Level error -Last 50
```

Shows the last 50 errors from the past 15 minutes.

### EXAMPLE 2
```
Get-SnowSyslog -Wait -Pretty -Source 'Flow Engine' -Message timeout -PollSeconds 10
```

Watches for flow timeouts while you reproduce a problem.

### EXAMPLE 3
```
Get-SnowSyslog -Level error -Since (Get-Date).AddHours(-2) -Last 500 | Group-Object source | Sort-Object Count -Descending | Select-Object -First 5 Name, Count
```

Finds the noisiest error sources in the last two hours.

## PARAMETERS

### -Table
syslog (default), syslog_transaction or syslog_app_scope.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Syslog
Accept pipeline input: False
Accept wildcard characters: False
```

### -Level
error, warning, info or debug.

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

### -Source
Filters on the log source.

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

### -Message
Filters on text contained in the message.

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

### -User
Filters on the user (sys_created_by).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Since
Returns rows created after this time.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Last
The maximum number of rows to return (default 100).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: 100
Accept pipeline input: False
Accept wildcard characters: False
```

### -Wait
Follows new rows until stopped.

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

### -PollSeconds
Seconds between polls when -Wait is used (2-3600, default 5).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxPolls
Stops after this many polls; 0 means unlimited.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Pretty
Writes coloured lines to the console instead of returning objects.

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

### -Fields
The fields to return.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
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
Position: 11
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
