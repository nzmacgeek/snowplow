BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    $script:PreexistingConvenienceAliases = @('snow', 'snowc', 'snowl', 'snowo') |
        Where-Object { Get-Alias -Name $_ -ErrorAction SilentlyContinue }
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

Describe 'Snow query builder' {
    It 'builds known encoded queries from condition hashtables' {
        $conditions = [ordered]@{
            name = @{ Operator = 'STARTSWITH'; Value = 'INC' }
            priority = @{ Operator = 'IN'; Value = @('1', '2'); Joiner = 'or' }
            active = @{ Operator = '='; Value = $false; Joiner = 'nq' }
        }
        New-SnowQuery -Conditions $conditions | Should -Be 'nameSTARTSWITHINC^ORpriorityIN1,2^NQactive=false'
    }

    It 'normalizes lowercase joiners supplied to the query builder' {
        New-SnowQuery -Conditions ([ordered]@{ active = 'true'; priority = '1' }) -Joiner or |
            Should -Be 'active=true^ORpriority=1'
    }

    It 'supports operators without values and validates list operands' {
        New-SnowQuery -Conditions @{ short_description = @{ Operator = 'ISEMPTY' } } |
            Should -Be 'short_descriptionISEMPTY'
        { New-SnowQuery -Conditions @{ priority = @{ Operator = '=' } } } |
            Should -Throw '*A value is required*'
        New-SnowQuery -Conditions @{ priority = @{ Operator = 'BETWEEN'; Value = @(1, 3) } } |
            Should -Be 'priorityBETWEEN1@3'
        { New-SnowQuery -Conditions @{ priority = @{ Operator = 'BETWEEN'; Value = @(1) } } } |
            Should -Throw '*BETWEEN requires exactly two values*'
    }

    It 'encodes the remaining comparison and text operators' {
        $conditions = [ordered]@{
            active = @{ Operator = '!='; Value = 'false' }
            short_description = @{ Operator = 'LIKE'; Value = 'printer' }
            priority = @{ Operator = '<'; Value = 3 }
            assigned_to = @{ Operator = 'ISNOTEMPTY' }
        }
        New-SnowQuery -Conditions $conditions |
            Should -Be 'active!=false^short_descriptionLIKEprinter^priority<3^assigned_toISNOTEMPTY'
    }

    It 'escapes query delimiters in values without altering other characters' {
        $query = New-SnowQuery -Conditions @{ short_description = 'a^b\c &+?' }
        $query | Should -Be 'short_description=a^^b\c &+?'
        New-SnowQuery -Conditions @{ short_description = 'x^NQactive=true' } |
            Should -Be 'short_description=x^^NQactive=true'
    }

    It 'builds and extends fluent queries with sorting and relative dates' {
        $query = New-SnowQuery |
            Where-SnowField active -Value $true |
            Where-SnowField sys_created_on -Operator '>' -Value (New-SnowRelativeDate -Last 7 -Unit Days) |
            Add-SnowOrderBy sys_created_on -Descending
        $query | Should -Be 'active=true^sys_created_on>javascript:gs.daysAgoStart(7)^ORDERBYDESCsys_created_on'
        (New-SnowRelativeDate -Last 2 -Unit Weeks -Boundary end) | Should -Be 'javascript:gs.weeksAgoEnd(2)'
    }

    It 'normalizes lowercase fluent joiners' {
        'active=true' | Where-SnowField priority -Value 1 -Joiner or |
            Should -Be 'active=true^ORpriority=1'
    }

    It 'completes fields in query-builder commands from the schema cache' {
        InModuleScope Snowplow {
            $script:SnowSchemaCache.Fields.incident = @(
                [pscustomobject]@{ element = 'number' },
                [pscustomobject]@{ element = 'short_description' }
            )
        }
        $scriptText = 'Where-SnowField -Table incident -Field short'
        (TabExpansion2 $scriptText $scriptText.Length).CompletionMatches.CompletionText |
            Should -Contain short_description
        $scriptText = 'Add-SnowOrderBy -Table incident -Field short'
        (TabExpansion2 $scriptText $scriptText.Length).CompletionMatches.CompletionText |
            Should -Contain short_description
    }
}

Describe 'Module' {
    It 'exports only public functions' {
        (Get-Command -Module Snowplow -CommandType Function).Name | Sort-Object |
            Should -Be (@(
                'Compare-SnowRecord', 'Connect-Snowplow', 'Disconnect-Snowplow', 'Export-SnowRecord',
                'Get-SnowCI', 'Get-SnowCIRelationship', 'Get-SnowDictionary', 'Get-SnowRecord',
                'Get-SnowTable', 'Get-SnowplowConfiguration', 'Get-SnowplowProfile', 'Get-SnowLink',
                'Get-SnowplowPromptSegment', 'Open-SnowRecord', 'New-SnowRecord',
                'New-SnowQuery', 'Where-SnowField', 'Add-SnowOrderBy', 'New-SnowRelativeDate',
                'Remove-SnowRecord', 'Remove-SnowplowProfile', 'Set-SnowRecord', 'Set-SnowplowConfiguration',
                'Add-SnowplowProfile', 'Set-SnowplowProfile'
            ) | Sort-Object)
    }
    It 'creates no global session variables' {
        Get-Variable -Scope Global -Name 'Snowplow*' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
    It 'exports convenience aliases that do not replace built-in aliases' {
        $script:PreexistingConvenienceAliases | Should -BeNullOrEmpty
        (Get-Alias snow).Definition | Should -Be 'Get-SnowRecord'
        (Get-Alias snowc).Definition | Should -Be 'Connect-Snowplow'
        (Get-Alias snowl).Definition | Should -Be 'Get-SnowLink'
        (Get-Alias snowo).Definition | Should -Be 'Open-SnowRecord'
    }
}

Describe 'CLI conveniences' {
    BeforeEach {
        $null = Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -SkipValidation -WarningAction SilentlyContinue
    }
    AfterEach { Disconnect-Snowplow }

    It 'builds URLs for forms, lists, special query values, and nav_to links' {
        Get-SnowLink -Table incident -SysId $Sid |
            Should -Be "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        Get-SnowLink -Table incident -Query 'short_description=a^b&c+?' |
            Should -Be 'https://dev1.service-now.com/incident_list.do?sysparm_query=short_description%3Da%5Eb%26c%2B%3F'
        Get-SnowLink -Table incident -SysId $Sid -UseNavTo |
            Should -Be "https://dev1.service-now.com/nav_to.do?uri=incident.do%3Fsys_id%3D$Sid"
    }

    It 'formats links as URL, Markdown, or HTML' {
        Mock -ModuleName Snowplow Get-SnowRecord { [pscustomobject]@{ sys_id = $Sid; number = 'INC001' } }
        $url = "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        Get-SnowLink -Table incident -Number INC001 -Format Url | Should -Be $url
        Get-SnowLink -Table incident -Number INC001 -Format Markdown |
            Should -Be "[INC001]($url)"
        Get-SnowLink -Table incident -Number INC001 -Format Html |
            Should -Be "<a href=`"$url`">INC001</a>"
    }

    It 'uses the generated URL as the label when a pipeline record has no number' {
        $record = [pscustomobject]@{ sys_id = $Sid }
        $record.PSTypeNames.Insert(0, 'Snowplow.Record.incident')
        $url = "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        $record | Get-SnowLink -Format Markdown | Should -Be "[$url]($url)"
        $record | Get-SnowLink -Format Html |
            Should -Be "<a href=`"$url`">$url</a>"
    }

    It 'resolves a record number and a table schema before building links' {
        Mock -ModuleName Snowplow Get-SnowRecord { [pscustomobject]@{ sys_id = $Sid; number = 'INC001' } }
        Get-SnowLink -Table incident -Number INC001 | Should -Be "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        Get-SnowLink -Table incident -Schema | Should -Be "https://dev1.service-now.com/sys_db_object.do?sys_id=$Sid"
    }

    It 'throws InvalidDataException when a lookup returns a malformed sys_id' {
        Mock -ModuleName Snowplow Get-SnowRecord { [pscustomobject]@{ sys_id = 'invalid' } }
        { Get-SnowLink -Table incident -Number INC001 } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException])
        { Get-SnowLink -Table incident -Schema } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException])
    }

    It 'accepts pipeline records and returns URLs without opening a browser' {
        $record = [pscustomobject]@{ sys_id = $Sid; number = 'INC001' }
        $record.PSTypeNames.Insert(0, 'Snowplow.Record.incident')
        $record | Get-SnowLink | Should -Be "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        $record | Open-SnowRecord -PassThru | Should -Be "https://dev1.service-now.com/incident.do?sys_id=$Sid"
    }

    It 'does not request bulk confirmation for a WhatIf batch' {
        $records = foreach ($i in 1..6) {
            $record = [pscustomobject]@{ sys_id = [string]([char](96 + $i)) * 32 }
            $record.PSTypeNames.Insert(0, 'Snowplow.Record.incident')
            $record
        }
        { $records | Open-SnowRecord -WhatIf } | Should -Not -Throw
    }

    It 'returns a link when clipboard support is unavailable or fails' {
        Mock -ModuleName Snowplow Set-Clipboard { throw 'Clipboard is unavailable.' }
        $warnings = @()
        $url = Get-SnowLink -Table incident -SysId $Sid -Clipboard -WarningVariable warnings
        $url | Should -Be "https://dev1.service-now.com/incident.do?sys_id=$Sid"
        $warnings | Should -Match 'still returned'
    }

    It 'reports clearly when asked to open a browser in a headless Linux session' {
        if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
            $display = $env:DISPLAY
            $waylandDisplay = $env:WAYLAND_DISPLAY
            $ci = $env:CI
            try {
                Remove-Item Env:DISPLAY, Env:WAYLAND_DISPLAY -ErrorAction SilentlyContinue
                Remove-Item Env:CI -ErrorAction SilentlyContinue
                { Open-SnowRecord -Table incident } | Should -Throw '*No graphical browser session*'
            }
            finally {
                if ($null -ne $display) { $env:DISPLAY = $display }
                if ($null -ne $waylandDisplay) { $env:WAYLAND_DISPLAY = $waylandDisplay }
                if ($null -ne $ci) { $env:CI = $ci }
            }
        }
    }

    It 'returns no prompt segment when disconnected and colors the active environment' {
        Disconnect-Snowplow
        Get-SnowplowPromptSegment | Should -BeNullOrEmpty
        InModuleScope Snowplow {
            $script:SnowplowSession = [pscustomobject]@{
                BaseUri = [uri]'https://prod.service-now.com/'
                Profile = 'prod'
                Environment = 'Prod'
            }
        }
        $segment = Get-SnowplowPromptSegment
        $segment | Should -Match '\[snow:prod\]'
        $segment | Should -Match ([regex]::Escape([string][char]27))
        $segment | Should -Match ([regex]::Escape([string]$PSStyle.Foreground.Red))
    }

    It 'fails clearly when generating a URL without an active connection' {
        Disconnect-Snowplow
        { Get-SnowLink -Table incident } | Should -Throw '*Not connected*'
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
    AfterEach {
        Disconnect-Snowplow
        Set-SnowplowConfiguration -DefaultBackend Rest
    }

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
    It 'clears schema caches when connecting or disconnecting' {
        InModuleScope Snowplow {
            $script:SnowSchemaCache.Tables = @([pscustomobject]@{ name = 'old_table' })
            $script:SnowSchemaCache.Fields.old_table = @([pscustomobject]@{ element = 'old_field' })
        }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } }
        $null = Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -SkipValidation -WarningAction SilentlyContinue
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables } | Should -BeNullOrEmpty
        InModuleScope Snowplow { $script:SnowSchemaCache.Fields.Count } | Should -Be 0

        InModuleScope Snowplow {
            $script:SnowSchemaCache.Tables = @([pscustomobject]@{ name = 'old_table' })
            $script:SnowSchemaCache.Fields.old_table = @([pscustomobject]@{ element = 'old_field' })
        }
        Disconnect-Snowplow
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables } | Should -BeNullOrEmpty
        InModuleScope Snowplow { $script:SnowSchemaCache.Fields.Count } | Should -Be 0
    }

    It 'connects to a Prod profile with a warning and read-only mode by default' {
        Mock -ModuleName Snowplow Get-SnowProfileStorePath { Join-Path $TestDrive 'profiles.json' }
        Remove-Item (Join-Path $TestDrive 'profiles.json') -ErrorAction SilentlyContinue
        function global:Get-Secret { param($Name, $Vault) }
        Add-SnowplowProfile -Name prod -Instance prod1 -DefaultBackend Sdk -Environment Prod -ClientCredentialSecretName SnowClient -Vault Corp
        Mock -ModuleName Snowplow Get-Secret { $Client }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ access_token = 'tok'; expires_in = 1800 } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } } -ParameterFilter { $Uri.AbsolutePath -like '/api/*' }

        $session = Connect-Snowplow -Profile prod -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -Match 'read-only'
        $session.Environment | Should -Be 'Prod'
        $session.ReadOnly | Should -BeTrue
        (Get-SnowplowConfiguration).DefaultBackend | Should -Be 'Sdk'
        { New-SnowRecord -Table incident -Values @{ short_description = 'Blocked' } -Confirm:$false } | Should -Throw '*Writes are disabled*'
        (Get-Content (Join-Path $TestDrive 'profiles.json') -Raw) | Should -Not -Match 'tok|csecret|pw'
        Remove-Item function:global:Get-Secret
    }

    It 'allows Prod profile writes when -AllowWrite is passed' {
        Mock -ModuleName Snowplow Get-SnowProfileStorePath { Join-Path $TestDrive 'profiles.json' }
        Remove-Item (Join-Path $TestDrive 'profiles.json') -ErrorAction SilentlyContinue
        function global:Get-Secret { param($Name, $Vault) }
        Add-SnowplowProfile -Name prod -Instance prod1 -Environment Prod -ClientCredentialSecretName SnowClient
        Mock -ModuleName Snowplow Get-Secret { $Client }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ access_token = 'tok'; expires_in = 1800 } } -ParameterFilter { $Uri.AbsolutePath -eq '/oauth_token.do' }
        Mock -ModuleName Snowplow Invoke-SnowRequest { [pscustomobject]@{ result = @([pscustomobject]@{ sys_id = $Sid; number = 'INC1' }) } }
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } } -ParameterFilter { $Uri.AbsolutePath -like '/api/*' }

        $null = Connect-Snowplow -Profile prod -AllowWrite -WarningAction SilentlyContinue
        New-SnowRecord -Table incident -Values @{ short_description = 'Allowed' } -Confirm:$false | Out-Null

        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Method -eq 'POST' -and $Body.short_description -eq 'Allowed' }
        Remove-Item function:global:Get-Secret
    }

    It 'uses explicit profile credentials instead of inherited secret references' {
        Mock -ModuleName Snowplow Get-SnowProfileStorePath { Join-Path $TestDrive 'profiles.json' }
        Remove-Item (Join-Path $TestDrive 'profiles.json') -ErrorAction SilentlyContinue
        Add-SnowplowProfile -Name dev -Instance dev1 -ClientCredentialSecretName ClientSecret -CredentialSecretName UserSecret
        Remove-Item function:global:Get-Secret -ErrorAction SilentlyContinue

        $null = Connect-Snowplow -Profile dev -ClientCredential $Client -Credential $Cred -SkipValidation -WarningAction SilentlyContinue

        InModuleScope Snowplow -Parameters @{ Client = $Client; Cred = $Cred } {
            $script:SnowplowSession.ClientCredential.UserName | Should -Be 'cid'
            $script:SnowplowSession.Credential.UserName | Should -Be 'user'
        }
    }
}

Describe 'Snowplow profiles' {
    BeforeEach {
        Mock -ModuleName Snowplow Get-SnowProfileStorePath { Join-Path $TestDrive 'profiles.json' }
    }

    It 'adds, updates, lists, removes, and completes profiles' {
        Add-SnowplowProfile -Name dev -Instance dev1 -ClientCredentialSecretName SnowClient -Vault Local -PassThru | Out-Null
        Set-SnowplowProfile -Name dev -DefaultBackend Sdk -Environment Test
        Add-SnowplowProfile -Name prod -Instance prod1 -Environment Prod

        $profile = Get-SnowplowProfile -Name dev
        $profile.Instance | Should -Be 'https://dev1.service-now.com/'
        $profile.DefaultBackend | Should -Be 'Sdk'
        $profile.Environment | Should -Be 'Test'
        (Get-SnowplowProfile).Name | Should -Be @('dev', 'prod')
        InModuleScope Snowplow { (Get-SnowCompletionValue -Kind Profile -Word 'pr').CompletionText | Should -Contain 'prod' }
        $scriptText = 'Connect-Snowplow -Profile pr'
        (TabExpansion2 $scriptText $scriptText.Length).CompletionMatches.CompletionText | Should -Contain 'prod'

        Remove-SnowplowProfile -Name prod -Confirm:$false
        (Get-SnowplowProfile).Name | Should -Be @('dev')
        Remove-SnowplowProfile -Name dev -Confirm:$false
        (Get-SnowplowProfile) | Should -BeNullOrEmpty
        (Get-Content (Join-Path $TestDrive 'profiles.json') -Raw).Trim() | Should -Be '[]'
    }

    It 'fails clearly when the profile store is corrupted' {
        Set-Content -Path (Join-Path $TestDrive 'profiles.json') -Value '{bad json' -Encoding utf8
        { Get-SnowplowProfile } | Should -Throw '*corrupted*'
    }

    It 'rejects missing or invalid environment metadata in the profile store' {
        foreach ($profile in @(
            [pscustomobject]@{ Name = 'prod'; Instance = 'prod1' },
            [pscustomobject]@{ Name = 'prod'; Instance = 'prod1'; Environment = 'Prdo' },
            [pscustomobject]@{ Name = 'prod'; Instance = 'prod1'; Environment = '' }
        )) {
            $profile | ConvertTo-Json | Set-Content -Path (Join-Path $TestDrive 'profiles.json') -Encoding utf8
            { Get-SnowplowProfile } | Should -Throw '*corrupted*'
        }
    }

    It 'normalizes instance URLs before persisting profile data' {
        Remove-Item (Join-Path $TestDrive 'profiles.json') -ErrorAction SilentlyContinue
        $credentialedInstance = 'https://' + 'sample-user' + ':' + 'sample-password@dev1.service-now.com/path?token=sample-token'
        $profile = Add-SnowplowProfile -Name dev -Instance $credentialedInstance -PassThru

        $profile.Instance | Should -Be 'https://dev1.service-now.com/'
        (Get-Content (Join-Path $TestDrive 'profiles.json') -Raw) | Should -Not -Match 'sample-user|sample-password|sample-token'

        $updatedInstance = 'https://' + 'other-user' + ':' + 'other-password@dev2.service-now.com/path?access_token=other-token'
        Set-SnowplowProfile -Name dev -Instance $updatedInstance
        $stored = Get-Content (Join-Path $TestDrive 'profiles.json') -Raw
        $stored | Should -Match 'https://dev2.service-now.com/'
        $stored | Should -Not -Match 'other-user|other-password|other-token'

        $errorMessage = try {
            Add-SnowplowProfile -Name invalid -Instance ('http://' + 'sample-user' + ':' + 'sample-password@dev3.service-now.com') -ErrorAction Stop
        }
        catch {
            $_.Exception.Message
        }
        $errorMessage | Should -Not -Match 'sample-user|sample-password|dev3'
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
        Mock -ModuleName Snowplow Invoke-RestMethod { [pscustomobject]@{ result = @() } }
        Mock -ModuleName Snowplow Invoke-SnowRequest { [pscustomobject]@{ result = @([pscustomobject]@{ sys_id = $Sid; number = 'INC1'; short_description = 'Test' }) } }
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables = $null; $script:SnowSchemaCache.Fields = @{} }
        $null = Connect-Snowplow -Instance dev1 -AuthMethod Basic -Credential $Cred -SkipValidation -WarningAction SilentlyContinue
    }
    AfterEach { Disconnect-Snowplow }

    It 'gets typed records with query, fields and limit' {
        $record = Get-SnowRecord -Table incident -Query 'active=true' -Fields number,short_description -Limit 10
        $record | Should -BeOfType [pscustomobject]
        $record.PSTypeNames | Should -Contain 'Snowplow.Record.incident'
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter {
            $Table -eq 'incident' -and $Query -eq 'active=true' -and $First -eq 10 -and $Fields -contains 'number'
        }
    }

    It 'passes a built query to Get-SnowRecord unchanged' {
        $query = New-SnowQuery -Conditions ([ordered]@{ active = 'true'; priority = '1' })
        Get-SnowRecord -Table incident -Query $query | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter {
            $Table -eq 'incident' -and $Query -eq 'active=true^priority=1'
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
        Get-SnowTable -All -Limit 25 | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Table -eq 'sys_db_object' -and -not $PSBoundParameters.ContainsKey('First') }
        InModuleScope Snowplow { $script:SnowSchemaCache.Tables } | Should -Not -BeNullOrEmpty
    }

    It 'gets dictionary fields without caching filtered results' {
        Get-SnowDictionary -Table incident -Element priority -All | Out-Null
        Should -Invoke -ModuleName Snowplow Invoke-SnowRequest -ParameterFilter { $Table -eq 'sys_dictionary' -and $Query -eq 'name=incident^element=priority' }
        InModuleScope Snowplow { $script:SnowSchemaCache.Fields.ContainsKey('incident') } | Should -BeFalse
    }

    It 'does not cache filtered or limited schema lookups' {
        Get-SnowTable -Query 'nameSTARTSWITHcmdb' -All | Out-Null
        Get-SnowTable -Limit 25 | Out-Null
        Get-SnowDictionary -Table incident -Element priority -All | Out-Null
        Get-SnowDictionary -Table incident -Limit 25 | Out-Null
        InModuleScope Snowplow {
            $script:SnowSchemaCache.Tables | Should -BeNullOrEmpty
            $script:SnowSchemaCache.Fields.Count | Should -Be 0
        }
    }

    It 'caches complete unfiltered dictionary fields' {
        Get-SnowDictionary -Table incident -All | Out-Null
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

    It 'compares single-property records correctly' {
        $diff = Compare-SnowRecord -Reference ([pscustomobject]@{ state = '1' }) -Difference ([pscustomobject]@{ state = '2' })
        @($diff).Count | Should -Be 1
        $diff.Property | Should -Be state
        $diff.Reference | Should -Be '1'
        $diff.Difference | Should -Be '2'
        Compare-SnowRecord -Reference ([pscustomobject]@{ state = '1' }) -Difference ([pscustomobject]@{ state = '1' }) |
            Should -BeNullOrEmpty
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
