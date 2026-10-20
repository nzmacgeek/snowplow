---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Add-SnowplowProfile

## SYNOPSIS
Adds a named Snowplow connection profile.

## SYNTAX

```
Add-SnowplowProfile [-Name] <String> -Instance <String> [-AuthMethod <String>] [-DefaultBackend <String>]
 [-Environment <String>] [-ClientCredentialSecretName <String>] [-CredentialSecretName <String>]
 [-Vault <String>] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Profiles are stored per-user ($HOME/.snowplow/profiles.json on Unix-like systems).
They hold only
the instance, auth settings, backend, environment tag and optional SecretManagement secret names,
never secrets.
Fails if the name already exists; use Set-SnowplowProfile to change one.

## EXAMPLES

### EXAMPLE 1
```
Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -Environment Dev
```

Saves a dev profile.

### EXAMPLE 2
```
Add-SnowplowProfile -Name prod -Instance acme -ClientCredentialSecretName SnowplowProdOAuth -Environment Prod -PassThru
```

Saves a Prod profile with the safety defaults.

## PARAMETERS

### -Name
The profile name.

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

### -Instance
The instance name or https URL.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AuthMethod
OAuth (default) or Basic.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: OAuth
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultBackend
Rest, Sdk or Auto.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Rest
Accept pipeline input: False
Accept wildcard characters: False
```

### -Environment
Dev, Test or Prod.
Prod profiles warn on connect and are read-only unless -AllowWrite is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Dev
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientCredentialSecretName
The SecretManagement secret holding the OAuth client credential.

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

### -CredentialSecretName
The SecretManagement secret holding a Basic credential.

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

### -Vault
The SecretManagement vault.

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

### -PassThru
Returns the profile.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

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
