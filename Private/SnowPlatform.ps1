function Get-SnowplowPlatform {
    [CmdletBinding()]
    param()

    if ($IsWindows) { return 'Windows' }
    if ($IsLinux) { return 'Linux' }
    if ($IsMacOS) { return 'MacOS' }
    'Unknown'
}

function Get-SnowplowDirectories {
    [CmdletBinding()]
    param()

    $homeDirectory = [Environment]::GetFolderPath('UserProfile')
    switch (Get-SnowplowPlatform) {
        Windows {
            $config = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Snowplow'
            $local = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Snowplow'
            $cache = Join-Path $local 'Cache'
            $data = Join-Path $local 'Data'
        }
        MacOS {
            $support = Join-Path (Join-Path (Join-Path $homeDirectory 'Library') 'Application Support') 'Snowplow'
            $config = $support
            $cache = Join-Path (Join-Path (Join-Path $homeDirectory 'Library') 'Caches') 'Snowplow'
            $data = Join-Path $support 'Data'
        }
        Linux {
            $configRoot = if ($env:XDG_CONFIG_HOME -and [IO.Path]::IsPathRooted($env:XDG_CONFIG_HOME)) {
                $env:XDG_CONFIG_HOME
            }
            else {
                Join-Path $homeDirectory '.config'
            }
            $cacheRoot = if ($env:XDG_CACHE_HOME -and [IO.Path]::IsPathRooted($env:XDG_CACHE_HOME)) {
                $env:XDG_CACHE_HOME
            }
            else {
                Join-Path $homeDirectory '.cache'
            }
            $dataRoot = if ($env:XDG_DATA_HOME -and [IO.Path]::IsPathRooted($env:XDG_DATA_HOME)) {
                $env:XDG_DATA_HOME
            }
            else {
                Join-Path (Join-Path $homeDirectory '.local') 'share'
            }
            $config = Join-Path $configRoot 'snowplow'
            $cache = Join-Path $cacheRoot 'snowplow'
            $data = Join-Path $dataRoot 'snowplow'
        }
        default {
            throw [System.PlatformNotSupportedException]::new('Snowplow supports PowerShell on Windows, Linux, and macOS.')
        }
    }

    [pscustomobject]@{ Config = $config; Cache = $cache; Data = $data }
}

function Protect-SnowplowPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('Directory', 'File')][string]$Type
    )

    if ((Get-SnowplowPlatform) -ne 'Linux') { return }
    $mode = if ($Type -eq 'Directory') {
        '700'
    }
    else {
        '600'
    }
    & chmod $mode -- $Path
    if ($LASTEXITCODE -ne 0) {
        throw [System.IO.IOException]::new("Could not restrict permissions on '$Path'.")
    }
}
