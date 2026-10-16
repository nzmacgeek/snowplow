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
            Should -Be (@(
                'Compare-SnowRecord', 'Connect-Snowplow', 'Disconnect-Snowplow', 'Export-SnowRecord',
                'Get-SnowCI', 'Get-SnowCIRelationship', 'Get-SnowDictionary', 'Get-SnowRecord',
                'Get-SnowTable', 'Get-SnowplowConfiguration', 'New-SnowRecord', 'Remove-SnowRecord',
                'Set-SnowRecord', 'Set-SnowplowConfiguration'
            ) | Sort-Object)
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
        @{ In = ('https://' + 'user' + ':' + 'pass@dev123.service-now.com/some/path'); Out = 'https://dev123.service-now.com/' }
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

    It 'retries 429 honouring an HTTP-date Retry-After' {
        $script:calls = 0
        $retryAt = [DateTimeOffset]::UtcNow.AddSeconds(30).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
        Mock -ModuleName Snowplow Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) { throw (New-HttpError 429 '' @{ 'Retry-After' = $retryAt }) }
            [pscustomobject]@{ result = @([pscustomobject]@{ ok = 1 }) }
        }
        $null = InModuleScope Snowplow { Invoke-SnowRequest -Table incident }
        Should -Invoke -ModuleName Snowplow Start-SnowSleep -Times 1 -ParameterFilter { $Seconds -gt 0 -and $Seconds -le 30 }
    }

    It 'fails explicitly when Retry-After exceeds the supported wait' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 429 '' @{ 'Retry-After' = '121' }) }
        $err = InModuleScope Snowplow { try { Invoke-SnowRequest -Table incident } catch { $_ } }
        $err.Exception.Message | Should -BeLike '*exceeding the 120-second maximum supported wait*'
        Should -Invoke -ModuleName Snowplow Start-SnowSleep -Times 0 -Exactly
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

    It 'maps an HTTP error without ErrorDetails under strict mode' {
        Mock -ModuleName Snowplow Invoke-RestMethod { throw (New-HttpError 404 '') }
        $err = InModuleScope Snowplow { try { Invoke-SnowRequest -Table incident -SysId ('b' * 32) } catch { $_ } }
        $err.FullyQualifiedErrorId | Should -BeLike 'Snowplow.Http404*'
        $err.Exception.Message | Should -BeLike '*HTTP 404*'
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

    It 'uses the default OAuth token lifetime when expires_in is missing' {
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ access_token = 'tok' } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        $token = InModuleScope Snowplow -Parameters @{ Client = $Client } {
            Request-SnowOAuthToken -Session ([pscustomobject]@{
                ClientCredential = $Client
                Credential = $null
                BaseUri = [uri]'https://dev1.service-now.com/'
            })
        }
        [Math]::Abs(($token.ExpiresAt - [DateTime]::UtcNow.AddSeconds(1800)).TotalSeconds) | Should -BeLessThan 2
    }
}

Describe 'Resolve-SnowBackend / configuration' {
    AfterAll { Set-SnowplowConfiguration -DefaultBackend Rest }
    It 'defaults to Rest and Auto resolves to Rest' {
        InModuleScope Snowplow { Resolve-SnowBackend | Should -Be 'Rest'; Resolve-SnowBackend -Backend Auto | Should -Be 'Rest' }
    }
    It 'resolves the Sdk backend and reports missing dependencies clearly' {
        InModuleScope Snowplow {
            Resolve-SnowBackend -Backend Sdk | Should -Be Sdk
            { Invoke-SnowSdk -Table incident } | Should -Throw '*now-sdk*'
        }
    }
    It 'uses the module default when set' {
        Set-SnowplowConfiguration -DefaultBackend Sdk
        (Get-SnowplowConfiguration).DefaultBackend | Should -Be 'Sdk'
        InModuleScope Snowplow { Resolve-SnowBackend | Should -Be Sdk }
    }
}

Describe 'Admin cmdlets' {
    BeforeEach {
        Mock -ModuleName Snowplow Invoke-SnowRequest { [pscustomobject]@{ result = @([pscustomobject]@{ sys_id = $Sid; number = 'INC1'; short_description = 'Test' }) } }
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables = $null; $script:SnowSchemaCache.Fields = @{} }
    }

    It 'gets typed records with query, fields and limit' {
        $record = Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description -Limit 10
        $record | Should -BeOfType [pscustomobject]
        $record.PSTypeNames | Should -Contain 'Snowplow.Record.incident'
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter {
            $Table -eq 'incident' -and $Query -eq 'active=true' -and $First -eq 10 -and $Fields -contains 'number'
        }
    }

    It 'pages all records when -All is supplied' {
        Get-SnowRecord -Table incident -Limit 15 -All | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Table -eq 'incident' -and -not $PSBoundParameters.ContainsKey('First') }
    }

    It 'creates records and honors WhatIf' {
        New-SnowRecord -Table incident -Values @{ short_description = 'Test' } -Confirm:$false | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Method -eq 'POST' -and $Body.short_description -eq 'Test' }
        New-SnowRecord -Table incident -Values @{ short_description = 'No-op' } -WhatIf
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -Exactly
    }

    It 'updates records using PATCH by default and PUT when requested' {
        Set-SnowRecord -Table incident -SysId $Sid -Values @{ priority = '2' } -Confirm:$false | Out-Null
        Set-SnowRecord -Table incident -SysId $Sid -Values @{ priority = '2' } -Replace -Confirm:$false | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -ParameterFilter { $Method -eq 'PATCH' }
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -ParameterFilter { $Method -eq 'PUT' }
    }

    It 'deletes records and honors WhatIf' {
        Remove-SnowRecord -Table incident -SysId $Sid -Confirm:$false
        Remove-SnowRecord -Table incident -SysId $Sid -WhatIf
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -ParameterFilter { $Method -eq 'DELETE' }
    }

    It 'lists tables and caches their schema' {
        Get-SnowTable -Limit 25 | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Table -eq 'sys_db_object' -and $First -eq 25 }
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables } | Should -Not -BeNullOrEmpty
    }

    It 'gets and caches dictionary fields' {
        Get-SnowDictionary -Table incident -Element priority | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Table -eq 'sys_dictionary' -and $Query -eq 'name=incident^element=priority' }
        InModuleScope Snowplow { $script:SnowSchemaCache.Fields.ContainsKey('incident') } | Should -BeTrue
    }

    It 'gets CI and relationship records from their respective tables' {
        Get-SnowCI -Limit 5 | Out-Null
        Get-SnowCIRelationship -Limit 6 | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -ParameterFilter { $Table -eq 'cmdb_ci' }
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -Times 1 -ParameterFilter { $Table -eq 'cmdb_rel_ci' }
    }

    It 'exports pipeline records to CSV and JSON' {
        $csv = [pscustomobject]@{ number = 'INC1' } | Export-SnowRecord -Format Csv
        $csv | Should -Match 'number'
        $csv | Should -Match 'INC1'
        $json = [pscustomobject]@{ number = 'INC1' } | Export-SnowRecord -Format Json
        $json | Should -Match '"number": "INC1"'
    }

    It 'compares records and returns differences only' {
        $diff = Compare-SnowRecord -Reference ([pscustomobject]@{ number = 'INC1'; state = '1' }) -Difference ([pscustomobject]@{ number = 'INC1'; state = '2' })
        @($diff).Count | Should -Be 1
        $diff.Property | Should -Be state
        $diff.Reference | Should -Be '1'
        $diff.Difference | Should -Be '2'
    }

    It 'completes tables and fields from cached schema' {
        InModuleScope Snowplow {
            $script:SnowSchemaCache.Tables = @([pscustomobject]@{ name = 'incident' }, [pscustomobject]@{ name = 'cmdb_ci' })
            $script:SnowSchemaCache.Fields.incident = @([pscustomobject]@{ element = 'number' }, [pscustomobject]@{ element = 'short_description' })
            (Get-SnowCompletionValue -Kind Table -Word 'inc').CompletionText | Should -Be incident
            (Get-SnowCompletionValue -Kind Field -Table incident -Word 'short').CompletionText | Should -Be short_description
        }
        $scriptText = 'Get-SnowRecord -Table inc'
        (TabExpansion2 $scriptText $scriptText.Length).CompletionMatches.CompletionText | Should -Contain incident
        $scriptText = 'Get-SnowRecord -Table incident -Fields short'
        (TabExpansion2 $scriptText $scriptText.Length).CompletionMatches.CompletionText | Should -Contain short_description
    }
}
