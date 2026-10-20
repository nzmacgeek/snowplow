---
external help file: Snowplow-help.xml
Module Name: Snowplow
online version:
schema: 2.0.0
---

# Connect-Snowplow

## SYNOPSIS
Connects to a ServiceNow instance and stores the session in module scope.

## SYNTAX

```
Connect-Snowplow [[-Instance] <String>] [-Profile <String>] [-AuthMethod <String>] [-ClientId <String>]
 [-AuthorizationCode] [-ClientCredentials] [-RedirectPort <Int32>] [-NoBrowser]
 [-ClientCredential <PSCredential>] [-Credential <PSCredential>] [-AccessToken <String>]
 [-ClientCredentialSecretName <String>] [-CredentialSecretName <String>] [-Vault <String>] [-AllowWrite]
 [-SkipValidation] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Authorization code with PKCE is the default interactive grant and opens a browser.
Use -ClientCredentials for unattended automation with a dedicated service account.
Basic authentication is retained for compatibility and emits a deprecation warning.
Sessions require HTTPS.
Prod-tagged profiles warn on connect and are read-only unless -AllowWrite
is supplied.

## EXAMPLES

### EXAMPLE 1
```
'
```

Interactive sign-in.
Your browser opens, you sign in (including SSO and MFA), and the module keeps the token.

### EXAMPLE 2
```
' -NoBrowser
```

Sign in from a headless machine; open the printed URL on any device.

### EXAMPLE 3
```
Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential) -ClientCredentials
```

Unattended sign-in with a service account's client ID and secret.

### EXAMPLE 4
```
Connect-Snowplow -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -ClientCredentials
```

Reads the client credential from SecretManagement so no secret appears in your script.

### EXAMPLE 5
```
Connect-Snowplow -Profile prod -ClientCredentials -AllowWrite
```

Connects to a Prod profile with writes explicitly enabled.

## PARAMETERS

### -Instance
The instance name (dev12345) or a full https URL.

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

### -Profile
The name of a saved profile created by Add-SnowplowProfile.

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

### -ClientId
The OAuth application client ID for the authorization code grant.

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

### -AuthorizationCode
Explicitly selects the authorization code with PKCE grant.

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

### -ClientCredentials
Selects the client credentials grant for unattended use.

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

### -RedirectPort
The local loopback port (1024-65535) used to receive the authorization code.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 8765
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoBrowser
Prints the sign-in URL instead of opening a browser, for SSH sessions and containers.

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

### -ClientCredential
A PSCredential whose username is the OAuth client ID and password is the client secret.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
A PSCredential for Basic authentication.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AccessToken
An existing bearer token to use as-is.

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

### -ClientCredentialSecretName
The name of a SecretManagement secret holding the client credential.

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
The name of a SecretManagement secret holding the Basic credential.

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
The SecretManagement vault to read secrets from.

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

### -AllowWrite
Allows writes on a Prod-tagged profile.

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

### -SkipValidation
Skips the connectivity check made after authenticating.

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

### System.Management.Automation.PSObject
## NOTES

## RELATED LINKS
