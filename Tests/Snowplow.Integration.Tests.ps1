BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $root 'Snowplow.psd1') -Force
}

Describe 'ServiceNow integration' -Tag 'Integration' {
    It 'connects with Basic auth and reads a record within 30 seconds' {
        $securePassword = ConvertTo-SecureString $env:SNOW_PASSWORD -AsPlainText -Force
        $credential = [pscredential]::new($env:SNOW_USERNAME, $securePassword)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $session = Connect-Snowplow -Instance $env:SNOW_INSTANCE -AuthMethod Basic -Credential $credential -WarningAction SilentlyContinue
            $records = @(Get-SnowRecord -Table sys_user -Fields sys_id -Limit 1)
        }
        finally {
            $stopwatch.Stop()
            Disconnect-Snowplow
        }

        $session.AuthMethod | Should -Be 'Basic'
        $session.BaseUri.Scheme | Should -Be 'https'
        $records.Count | Should -BeGreaterThan 0
        if ($stopwatch.Elapsed.TotalSeconds -gt 30) {
            throw "Basic connection and record read took $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) seconds; the limit is 30 seconds."
        }
    }

    It 'connects with OAuth client credentials and reads a record within 30 seconds' {
        $secureSecret = ConvertTo-SecureString $env:SNOW_OAUTH_CLIENT_SECRET -AsPlainText -Force
        $credential = [pscredential]::new($env:SNOW_OAUTH_CLIENT_ID, $secureSecret)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $session = Connect-Snowplow -Instance $env:SNOW_INSTANCE -ClientCredential $credential -ClientCredentials
            $records = @(Get-SnowRecord -Table sys_user -Fields sys_id -Limit 1)
        }
        finally {
            $stopwatch.Stop()
            Disconnect-Snowplow
        }

        $session.AuthMethod | Should -Be 'OAuth'
        $session.BaseUri.Scheme | Should -Be 'https'
        $records.Count | Should -BeGreaterThan 0
        if ($stopwatch.Elapsed.TotalSeconds -gt 30) {
            throw "OAuth connection and record read took $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) seconds; the limit is 30 seconds."
        }
    }
}
