BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $Root 'Snowplow.psd1') -Force

    function script:New-HttpError {
        param([int]$Status, [string]$Body, [hashtable]$Headers = @{})
        $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status)
        foreach ($k in $Headers.Keys) { $resp.Headers.Add($k, [string]$Headers[$k]) }
        $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $Status.", $resp)
        $er = [System.Management.Automation.ErrorRecord]::new($ex, 'WebCmdletWebResponseException', 'InvalidOperation', $null)
        if ($Body) { $er.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body) }
        $er
    }
    $script:Cred = [pscredential]::new('user', (ConvertTo-SecureString 'pw' -AsPlainText -Force))
    $script:Client = [pscredential]::new('cid', (ConvertTo-SecureString 'csecret' -AsPlainText -Force))
    $script:Sid = 'a' * 32
}

Describe 'Module' {
    It 'exports only public functions' {
        (Get-Command -Module Snowplow).Name | Sort-Object |
            Should -Be @('Connect-Snowplow', 'Disconnect-Snowplow', 'Get-SnowplowConfiguration', 'Set-SnowplowConfiguration')
    }
    It 'creates no global session variables' {
        Get-Variable -Scope Global -Name 'Snowplow*' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-SnowInstanceUri' {
    It 'expands <In> to <Out>' -ForEach @(
        @{ In = 'dev123'; Out = 'https://dev123.service-now.com/' }
        @{ In = 'dev123.service-now.com'; Out = 'https://dev123.service-now.com/' }
        @{ In = 'https://dev123.service-now.com/some/path?x=1'; Out = 'https://dev123.service-now.com/' }
    ) {
        InModuleScope Snowplow -Parameters $_ { (Resolve-SnowInstanceUri $In).AbsoluteUri | Should -Be $Out }
    }
    It 'rejects http' { InModuleScope Snowplow { { Resolve-SnowInstanceUri 'http://dev1.service-now.com' } | Should -Throw '*insecure*' } }
    It 'rejects junk' { InModuleScope Snowplow { { Resolve-SnowInstanceUri 'bad host!' } | Should -Throw } }
}

Describe 'Connect-Snowplow' {
    AfterEach { Disconnect-Snowplow }

    It 'requires a client credential for OAuth' {
        { Connect-Snowplow -Instance dev1 } | Should -Throw '*OAuth requires*'
    }
    It 'requires -Credential for Basic and warns' {
        { Connect-Snowplow -Instance dev1 -AuthMethod Basic -WarningAction SilentlyContinue } | Should -Throw '*Basic auth requires*'
    }
    It 'warns on Basic and sends a Basic header' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } }
        $s = Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -WarningVariable w -WarningAction SilentlyContinue
        $w | Should -Match 'deprecated'
        $s.AuthMethod | Should -Be 'Basic'
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Headers.Authorization -like 'Basic *' }
    }
    It 'fetches an OAuth client_credentials token and uses it as Bearer' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ access_token = 'tok'; expires_in = 1800 } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } } -ParameterFilter { $Uri.AbsolutePath -like '/api/*' }
        $s = Connect-Snowplow -Instance dev1 -ClientCredential $Client
        $s.Instance | Should -Be 'dev1.service-now.com'
        $s.PSObject.Properties.Name | Should -Not -Contain 'AccessToken'
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' -and $Body.grant_type -eq 'client_credentials' -and $Body.client_id -eq 'cid' }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Headers.Authorization -eq 'Bearer tok' }
    }
    It 'uses the password grant when a user credential is also supplied' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ access_token = 'tok'; expires_in = 60 } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } } -ParameterFilter { $Uri.AbsolutePath -like '/api/*' }
        $null = Connect-Snowplow -Instance dev1 -ClientCredential $Client -Credential $Cred -WarningAction SilentlyContinue
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Body.grant_type -eq 'password' -and $Body.username -eq 'user' }
    }
    It 'resolves credentials from SecretManagement' {
        function global:Get-Secret { param($Name, $Vault) }
        Mock -ModuleName Snowplow Get-Secret { $Cred }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } }
        $null = Connect-Snowplow -Instance dev1 -AuthMethod Basic -CredentialSecretName S -Vault V -WarningAction SilentlyContinue
        Should -Invoke -ModuleName Snowplow Get-Secret -ParameterFilter { $Name -eq 'S' -and $Vault -eq 'V' }
        Remove-Item function:global:Get-Secret
    }
    It 'does not keep a session when validation fails' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 401 '{"error":{"message":"User Not Authenticated"},"status":"failure"}') }
        { Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -WarningAction SilentlyContinue } | Should -Throw '*HTTP 401*'
        InModuleScope Snowplow { $script:SnowplowSession } | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-SnowRequest' {
    BeforeEach {
        Mock -ModuleName Snowplow Start-SnowSleep {}
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } }
        $null = Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -SkipValidation -WarningAction SilentlyContinue
    }
    AfterEach { Disconnect-Snowplow }

    It 'throws when not connected' {
        Disconnect-Snowplow
        InModuleScope Snowplow { { Invoke-SnowRequest -Table incident } | Should -Throw '*Connect-Snowplow*' }
    }

    It 'builds query, fields, display value, limit and offset' {
        InModuleScope Snowplow {
            Invoke-SnowRequest -Table incident -Query 'active=true^priority=1' -Fields number, short_description -DisplayValue all -PageSize 50 | Out-Null
        }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter {
            $u = $Uri.AbsoluteUri
            $u -like 'https://dev1.service-now.com/api/now/table/incident?*' -and
            $u -like '*sysparm_query=active%3Dtrue%5Epriority%3D1*' -and
            $u -like '*sysparm_fields=number%2Cshort_description*' -and
            $u -like '*sysparm_display_value=all*' -and $u -like '*sysparm_limit=50*' -and $u -like '*sysparm_offset=0*'
        }
    }

    It 'pages until a short page is returned' {
        $script:calls = 0
        Mock -ModuleName Snowplow Invoke-RestMethod {
            $script:calls++
            $n = if ($script:calls -lt 3) { 2 } else { 1 }
            [pscustomobject]@{ result = 1..$n | ForEach-Object { [pscustomobject]@{ n = $_ } } }
        }
        $r = InModuleScope Snowplow { Invoke-SnowRequest -Table incident -PageSize 2 }
        $r.Count | Should -Be 5
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 1 -ParameterFilter { $Uri.Query -like '*sysparm_offset=4*' }
    }

    It 'honours -First' {
        Mock -ModuleName Snowplow Invoke-RestMethod {
            [pscustomobject]@{ result = 1..3 | ForEach-Object { [pscustomobject]@{ n = $_ } } }
        }
        $r = InModuleScope Snowplow { Invoke-SnowRequest -Table incident -PageSize 3 -First 3 }
        $r.Count | Should -Be 3
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 1
    }

    It 'gets a single record by sys_id without paging' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = [pscustomobject]@{ number = 'INC1' } } }
        $r = InModuleScope Snowplow -Parameters @{ Sid = $Sid } { Invoke-SnowRequest -Table incident -SysId $Sid }
        $r.number | Should -Be 'INC1'
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Uri.AbsolutePath -like "*/incident/$Sid" -and $Uri.Query -notlike '*sysparm_limit*' }
    }

    It 'retries 429 honouring Retry-After, then succeeds' {
        $script:calls = 0
        Mock -ModuleName Snowplow Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { throw (New-HttpError 429 '' @{ 'Retry-After' = '7' }) }
            [pscustomobject]@{ result = @([pscustomobject]@{ ok = 1 }) }
        }
        $r = InModuleScope Snowplow { Invoke-SnowRequest -Table incident }
        @($r).Count | Should -Be 1
        Should -Invoke -ModuleName Snowplow Start-SnowSleep -Times 1 -ParameterFilter { $Seconds -eq 7 }
    }

    It 'retries 503 with exponential backoff and gives up with a parsed error' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 503 '{"error":{"message":"Down","detail":"maintenance"},"status":"failure"}') }
        $err = InModuleScope Snowplow {
            try { Invoke-SnowRequest -Table incident -MaxRetries 2 } catch { $_ }
        }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 3 -Exactly
        Should -Invoke -ModuleName Snowplow Start-SnowSleep -Times 2 -Exactly
        $err | Should -BeOfType [System.Management.Automation.ErrorRecord]
        $err.FullyQualifiedErrorId | Should -BeLike 'Snowplow.Http503*'
        $err.Exception.Message | Should -BeLike '*Down*maintenance*'
        $err.CategoryInfo.Category | Should -Be 'ResourceUnavailable'
    }

    It 'does not retry 4xx and maps the error' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 404 '{"error":{"message":"No Record found"},"status":"failure"}') }
        $err = InModuleScope Snowplow { try { Invoke-SnowRequest -Table incident -SysId ('b' * 32) } catch { $_ } }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 1 -Exactly
        $err.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $err.Exception.Message | Should -BeLike '*No Record found*'
    }

    It 'does not retry POST on 5xx (non-idempotent)' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 500 '') }
        InModuleScope Snowplow { { Invoke-SnowRequest -Table incident -Method POST -Body @{ a = 1 } -Confirm:$false } | Should -Throw }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 1 -Exactly
    }

    It 'sends a JSON body for writes' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = [pscustomobject]@{ sys_id = 'x' } } }
        InModuleScope Snowplow { Invoke-SnowRequest -Table incident -Method POST -Body @{ short_description = 'hi' } -Confirm:$false | Out-Null }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -ParameterFilter { $Method -eq 'POST' -and $Body -eq '{"short_description":"hi"}' -and $ContentType -eq 'application/json' }
    }

    It 'honours -WhatIf for writes' {
        InModuleScope Snowplow { Invoke-SnowRequest -Table incident -Method DELETE -SysId ('c' * 32) -WhatIf }
        Should -Invoke -ModuleName Snowplow Invoke-RestMethod -Times 0 -Exactly
    }

    It 'refreshes an expiring OAuth token' {
        Disconnect-Snowplow
        $script:tokens = 0
        Mock -ModuleName Snowplow Invoke-RestMethod { $script:tokens++; [pscustomobject]@{ access_token = "t$($script:tokens)"; expires_in = 30 } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } } -ParameterFilter { $Uri.AbsolutePath -like '/api/*' }
        $null = Connect-Snowplow -Instance dev1 -ClientCredential $Client -SkipValidation
        InModuleScope Snowplow { Invoke-SnowRequest -Table incident | Out-Null; Invoke-SnowRequest -Table incident | Out-Null }
        $script:tokens | Should -Be 2   # 30s lifetime is inside the 60s refresh window
    }
}

Describe 'Resolve-SnowBackend / configuration' {
    AfterAll { Set-SnowplowConfiguration -DefaultBackend Rest }
    It 'defaults to Rest and Auto resolves to Rest' {
        InModuleScope Snowplow { Resolve-SnowBackend | Should -Be 'Rest'; Resolve-SnowBackend -Backend Auto | Should -Be 'Rest' }
    }
    It 'Sdk is not implemented yet' {
        InModuleScope Snowplow { { Resolve-SnowBackend -Backend Sdk } | Should -Throw '*not implemented*' }
    }
    It 'uses the module default when set' {
        Set-SnowplowConfiguration -DefaultBackend Sdk
        (Get-SnowplowConfiguration).DefaultBackend | Should -Be 'Sdk'
        InModuleScope Snowplow { { Resolve-SnowBackend } | Should -Throw }
    }
}
