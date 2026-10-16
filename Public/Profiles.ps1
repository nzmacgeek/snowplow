function Add-SnowplowProfile {
    <#
    .SYNOPSIS
        Adds a named Snowplow connection profile.
    .EXAMPLE
        Add-SnowplowProfile -Name dev -Instance dev12345 -ClientCredentialSecretName SnowClient
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
    .EXAMPLE
        Get-SnowplowProfile
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
    .EXAMPLE
        Remove-SnowplowProfile -Name prod
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
    .EXAMPLE
        Set-SnowplowProfile -Name prod -Instance prod12345 -Environment Prod
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
