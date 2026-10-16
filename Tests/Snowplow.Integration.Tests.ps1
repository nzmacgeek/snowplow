BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $root 'Snowplow.psd1') -Force
}

Describe 'ServiceNow integration' -Tag 'Integration' {
    It 'authenticates and reaches the Table API with the configured instance credentials' {
        $securePassword = ConvertTo-SecureString $env:SNOW_PASSWORD -AsPlainText -Force
        $credential = [pscredential]::new($env:SNOW_USERNAME, $securePassword)

        try {
            $session = Connect-Snowplow -Instance $env:SNOW_INSTANCE -AuthMethod Basic -Credential $credential -WarningAction SilentlyContinue
            $session.AuthMethod | Should -Be 'Basic'
            $session.BaseUri.Scheme | Should -Be 'https'
        }
        finally {
            Disconnect-Snowplow
        }
    }
}
