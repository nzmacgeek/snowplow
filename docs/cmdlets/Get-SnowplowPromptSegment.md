---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Get-SnowplowPromptSegment

## SYNOPSIS
Returns a colored prompt segment for the active Snowplow connection.

## SYNTAX

```
Get-SnowplowPromptSegment [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns the profile (or instance) name; Prod is red and Test is yellow.
Returns nothing when
disconnected.
The module never changes your prompt automatically.

## EXAMPLES

### EXAMPLE 1
```
function prompt { "$(Get-SnowplowPromptSegment) PS $($executionContext.SessionState.Path.CurrentLocation)$([char]62) " }
```

Adds a safety indicator to your prompt so you always know which instance you are talking to.

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
