function Add-SnowplowProfile {
    <#
        .SYNOPSIS
        Adds a named Snowplow connection profile.
        .DESCRIPTION
        Profiles are stored per-user ($HOME/.snowplow/profiles.json on Unix-like systems). They hold only
        the instance, auth settings, backend, environment tag and optional SecretManagement secret names,
        never secrets. Fails if the name already exists; use Set-SnowplowProfile to change one.
        .PARAMETER Name
        The profile name.
        .PARAMETER Instance
        The instance name or https URL.
        .PARAMETER AuthMethod
        OAuth (default) or Basic.
        .PARAMETER DefaultBackend
        Rest, Sdk or Auto.
        .PARAMETER Environment
        Dev, Test or Prod. Prod profiles warn on connect and are read-only unless -AllowWrite is used.
        .PARAMETER ClientCredentialSecretName
        The SecretManagement secret holding the OAuth client credential.
        .PARAMETER CredentialSecretName
        The SecretManagement secret holding a Basic credential.
        .PARAMETER Vault
        The SecretManagement vault.
        .PARAMETER PassThru
        Returns the profile.
        .EXAMPLE
        Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowplowOAuth -Vault SnowplowVault -Environment Dev

        Saves a dev profile.
        .EXAMPLE
        Add-SnowplowProfile -Name prod -Instance acme -ClientCredentialSecretName SnowplowProdOAuth -Environment Prod -PassThru

        Saves a Prod profile with the safety defaults.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name,
        [Parameter(Mandatory)][string]$Instance,
        [ValidateSet('OAuth', 'Basic')][string]$AuthMethod = 'OAuth',
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$DefaultBackend = 'Rest',
        [ValidateSet('Dev', 'Test', 'Prod')][string]$Environment = 'Dev',
        [string]$ClientCredentialSecretName,
        [string]$CredentialSecretName,
        [string]$Vault,
        [switch]$PassThru
    )

    $profiles = @(Read-SnowProfileStore)
    if (@($profiles | Where-Object Name -eq $Name).Count -gt 0) {
        throw [System.ArgumentException]::new("Snowplow profile '$Name' already exists.")
    }

    $Instance = Resolve-SnowProfileInstance -Instance $Instance
    $profile = [pscustomobject]@{
        PSTypeName                 = 'Snowplow.Profile'
        Name                       = $Name
        Instance                   = $Instance
        AuthMethod                 = $AuthMethod
        DefaultBackend             = $DefaultBackend
        Environment                = $Environment
        ClientCredentialSecretName = $ClientCredentialSecretName
        CredentialSecretName       = $CredentialSecretName
        Vault                      = $Vault
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Add Snowplow profile')) {
        Write-SnowProfileStore -Profiles @($profiles + $profile)
        if ($PassThru) { $profile }
    }
}

function Get-SnowplowProfile {
    <#
        .SYNOPSIS
        Gets Snowplow connection profiles.
        .PARAMETER Name
        The profile to get. Omit to list all.
        .EXAMPLE
        Get-SnowplowProfile

        Lists every saved profile.
        .EXAMPLE
        Get-SnowplowProfile -Name prod | Format-List

        Inspects one profile.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Profile -Word $word } $wordToComplete })]
        [string]$Name
    )

    $profiles = @(Read-SnowProfileStore)
    if ($Name) {
        $profiles = @($profiles | Where-Object Name -eq $Name)
    }
    $profiles | Sort-Object Name
}

function Remove-SnowplowProfile {
    <#
        .SYNOPSIS
        Removes a named Snowplow connection profile.
        .DESCRIPTION
        Removes the profile entry only; secrets stored in your vault are left untouched.
        .PARAMETER Name
        The profile to remove.
        .EXAMPLE
        Remove-SnowplowProfile -Name old-pdi

        Deletes a profile for a personal developer instance you have released.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Profile -Word $word } $wordToComplete })]
        [ValidateNotNullOrEmpty()][string]$Name
    )

    $profiles = @(Read-SnowProfileStore)
    if (@($profiles | Where-Object Name -eq $Name).Count -eq 0) {
        throw [System.Management.Automation.ItemNotFoundException]::new("Snowplow profile '$Name' was not found.")
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Remove Snowplow profile')) {
        Write-SnowProfileStore -Profiles @($profiles | Where-Object Name -ne $Name)
    }
}

function Set-SnowplowProfile {
    <#
        .SYNOPSIS
        Creates or updates a named Snowplow connection profile.
        .DESCRIPTION
        Only the parameters you supply are changed on an existing profile.
        .PARAMETER Name
        The profile name.
        .PARAMETER Instance
        The instance name or https URL.
        .PARAMETER AuthMethod
        OAuth or Basic.
        .PARAMETER DefaultBackend
        Rest, Sdk or Auto.
        .PARAMETER Environment
        Dev, Test or Prod.
        .PARAMETER ClientCredentialSecretName
        The SecretManagement secret holding the OAuth client credential.
        .PARAMETER CredentialSecretName
        The SecretManagement secret holding a Basic credential.
        .PARAMETER Vault
        The SecretManagement vault.
        .PARAMETER PassThru
        Returns the profile.
        .EXAMPLE
        Set-SnowplowProfile -Name test -Environment Test

        Tags an existing profile as Test so the prompt shows it in yellow.
        .EXAMPLE
        Set-SnowplowProfile -Name prod -Instance prod12345 -Environment Prod

        Creates or updates the Prod profile.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ArgumentCompleter({ param($commandName, $parameterName, $wordToComplete) & (Get-Module Snowplow) { param($word) Get-SnowCompletionValue -Kind Profile -Word $word } $wordToComplete })]
        [ValidateNotNullOrEmpty()][string]$Name,
        [string]$Instance,
        [ValidateSet('OAuth', 'Basic')][string]$AuthMethod,
        [ValidateSet('Rest', 'Sdk', 'Auto')][string]$DefaultBackend,
        [ValidateSet('Dev', 'Test', 'Prod')][string]$Environment,
        [string]$ClientCredentialSecretName,
        [string]$CredentialSecretName,
        [string]$Vault,
        [switch]$PassThru
    )

    $profiles = [System.Collections.Generic.List[object]]::new()
    foreach ($profile in @(Read-SnowProfileStore)) {
        $profiles.Add($profile)
    }

    $existing = @($profiles | Where-Object Name -eq $Name)
    $current = if ($existing) { $existing[0] } else { $null }

    $profile = [pscustomobject]@{
        PSTypeName                 = 'Snowplow.Profile'
        Name                       = $Name
        Instance                   = if ($PSBoundParameters.ContainsKey('Instance')) { $Instance } elseif ($current) { $current.Instance } else { $null }
        AuthMethod                 = if ($PSBoundParameters.ContainsKey('AuthMethod')) { $AuthMethod } elseif ($current) { $current.AuthMethod } else { 'OAuth' }
        DefaultBackend             = if ($PSBoundParameters.ContainsKey('DefaultBackend')) { $DefaultBackend } elseif ($current) { $current.DefaultBackend } else { 'Rest' }
        Environment                = if ($PSBoundParameters.ContainsKey('Environment')) { $Environment } elseif ($current) { $current.Environment } else { 'Dev' }
        ClientCredentialSecretName = if ($PSBoundParameters.ContainsKey('ClientCredentialSecretName')) { $ClientCredentialSecretName } elseif ($current) { $current.ClientCredentialSecretName } else { $null }
        CredentialSecretName       = if ($PSBoundParameters.ContainsKey('CredentialSecretName')) { $CredentialSecretName } elseif ($current) { $current.CredentialSecretName } else { $null }
        Vault                      = if ($PSBoundParameters.ContainsKey('Vault')) { $Vault } elseif ($current) { $current.Vault } else { $null }
    }

    if (-not $profile.Instance) {
        throw [System.ArgumentException]::new('An instance is required when creating a new Snowplow profile.')
    }
    $profile.Instance = Resolve-SnowProfileInstance -Instance $profile.Instance

    if ($PSCmdlet.ShouldProcess($Name, 'Set Snowplow profile')) {
        if ($current) {
            $index = $profiles.IndexOf($current)
            $profiles[$index] = $profile
        }
        else {
            $profiles.Add($profile)
        }

        Write-SnowProfileStore -Profiles @($profiles)
        if ($PassThru) { $profile }
    }
}
