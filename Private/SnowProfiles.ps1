function Get-SnowProfileStorePath {
    [CmdletBinding()]
    param()

    $root = if ($IsWindows) {
        Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Snowplow'
    }
    elseif ($env:XDG_CONFIG_HOME) {
        Join-Path $env:XDG_CONFIG_HOME 'snowplow'
    }
    else {
        Join-Path ([Environment]::GetFolderPath('UserProfile')) '.snowplow'
    }

    Join-Path $root 'profiles.json'
}

function Read-SnowProfileStore {
    [CmdletBinding()]
    param()

    $path = Get-SnowProfileStorePath
    if (-not (Test-Path -LiteralPath $path)) { return @() }

    $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

    try {
        $profiles = @(ConvertFrom-Json -InputObject $raw -ErrorAction Stop)
    }
    catch {
        throw [System.IO.InvalidDataException]::new("The Snowplow profile store '$path' is corrupted.")
    }

    foreach ($profile in $profiles) {
        $propertyNames = @($profile.PSObject.Properties.Name)
        if ($propertyNames -notcontains 'Name' -or $propertyNames -notcontains 'Instance') {
            throw [System.IO.InvalidDataException]::new("The Snowplow profile store '$path' is corrupted.")
        }
        if ($propertyNames -notcontains 'Environment' -or
            [string]::IsNullOrWhiteSpace([string]$profile.Environment) -or
            [string]$profile.Environment -notin @('Dev', 'Test', 'Prod')) {
            throw [System.IO.InvalidDataException]::new("The Snowplow profile store '$path' is corrupted.")
        }

        [pscustomobject]@{
            PSTypeName                 = 'Snowplow.Profile'
            Name                       = [string]$profile.Name
            Instance                   = [string]$profile.Instance
            AuthMethod                 = if (($propertyNames -contains 'AuthMethod') -and $profile.AuthMethod) { [string]$profile.AuthMethod } else { 'OAuth' }
            DefaultBackend             = if (($propertyNames -contains 'DefaultBackend') -and $profile.DefaultBackend) { [string]$profile.DefaultBackend } else { 'Rest' }
            Environment                = [string]$profile.Environment
            ClientCredentialSecretName = if ($propertyNames -contains 'ClientCredentialSecretName') { [string]$profile.ClientCredentialSecretName } else { $null }
            CredentialSecretName       = if ($propertyNames -contains 'CredentialSecretName') { [string]$profile.CredentialSecretName } else { $null }
            Vault                      = if ($propertyNames -contains 'Vault') { [string]$profile.Vault } else { $null }
        }
    }
}

function Resolve-SnowProfileInstance {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Instance)

    try {
        (Resolve-SnowInstanceUri -Instance $Instance).AbsoluteUri
    }
    catch {
        throw [System.ArgumentException]::new('The profile instance must be a valid HTTPS ServiceNow instance name or URL.')
    }
}

function Write-SnowProfileStore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Profiles)

    $path = Get-SnowProfileStorePath
    $directory = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -Path $directory -ItemType Directory -Force
    }

    $json = if ($Profiles.Count -eq 0) {
        '[]'
    }
    else {
        $Profiles | Sort-Object Name | ConvertTo-Json -Depth 4
    }
    Set-Content -LiteralPath $path -Value $json -Encoding utf8
}

function Get-SnowStoredProfile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $profile = @(Read-SnowProfileStore | Where-Object Name -eq $Name)
    if (-not $profile) {
        throw [System.Management.Automation.ItemNotFoundException]::new("Snowplow profile '$Name' was not found.")
    }

    $profile[0]
}
