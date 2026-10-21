---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Disconnect-Snowplow

## SYNOPSIS
Discards the stored session and any cached token.

## SYNTAX

```
Disconnect-Snowplow [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Run this when you finish, particularly on shared machines or at the end of a pipeline job.

## EXAMPLES

### EXAMPLE 1
```
Disconnect-Snowplow
```

Ends the session.

### EXAMPLE 2
```
try { Connect-Snowplow -Profile dev -ClientCredentials; Get-SnowRecord -Table incident -Limit 1 } finally { Disconnect-Snowplow }
```

Guarantees the token is discarded even if a command fails.

## PARAMETERS

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
