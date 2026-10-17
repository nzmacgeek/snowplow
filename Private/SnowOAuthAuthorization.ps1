function Get-SnowOAuthProofKey {
    [CmdletBinding()]
    param()

    $verifierBytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($verifierBytes)
    $verifier = [Convert]::ToBase64String($verifierBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $challengeBytes = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::ASCII.GetBytes($verifier))
    $stateBytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($stateBytes)

    [pscustomobject]@{
        Verifier  = $verifier
        Challenge = [Convert]::ToBase64String($challengeBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        State     = [Convert]::ToBase64String($stateBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
}

function Get-SnowOAuthAuthorizationUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][uri]$RedirectUri,
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][string]$Challenge
    )

    $query = @(
        'response_type=code'
        'client_id=' + [uri]::EscapeDataString($ClientId)
        'redirect_uri=' + [uri]::EscapeDataString($RedirectUri.AbsoluteUri)
        'state=' + [uri]::EscapeDataString($State)
        'code_challenge=' + [uri]::EscapeDataString($Challenge)
        'code_challenge_method=S256'
    ) -join '&'
    [uri]::new($BaseUri, "/oauth_auth.do?$query")
}

function ConvertFrom-SnowOAuthCallback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CallbackUrl,
        [Parameter(Mandatory)][uri]$RedirectUri,
        [Parameter(Mandatory)][string]$ExpectedState
    )

    $callback = $null
    if (-not [uri]::TryCreate($CallbackUrl, [UriKind]::Absolute, [ref]$callback) -or
        $callback.GetLeftPart([UriPartial]::Path) -ne $RedirectUri.GetLeftPart([UriPartial]::Path)) {
        throw [System.ArgumentException]::new('The authorization callback URL does not match the registered redirect URI.')
    }

    $query = [System.Web.HttpUtility]::ParseQueryString($callback.Query)
    $state = $query['state']
    if ([string]::IsNullOrEmpty($state)) {
        throw [System.InvalidOperationException]::new('The authorization callback did not include state.')
    }
    $expectedBytes = [Text.Encoding]::UTF8.GetBytes($ExpectedState)
    $actualBytes = [Text.Encoding]::UTF8.GetBytes($state)
    if ($expectedBytes.Length -ne $actualBytes.Length -or
        -not [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($expectedBytes, $actualBytes)) {
        throw [System.InvalidOperationException]::new('The authorization callback state did not match. Sign-in was cancelled.')
    }

    if ($query['error']) {
        throw [System.InvalidOperationException]::new('ServiceNow authorization was not granted. Try connecting again.')
    }
    if ([string]::IsNullOrEmpty($query['code'])) {
        throw [System.InvalidOperationException]::new('The authorization callback did not include a code.')
    }
    [pscustomobject]@{ Code = $query['code'] }
}

function Open-SnowOAuthBrowser {
    [CmdletBinding()]
    param([Parameter(Mandatory)][uri]$Uri)

    try {
        switch (Get-SnowplowPlatform) {
            Windows { Start-Process -FilePath $Uri.AbsoluteUri -ErrorAction Stop | Out-Null }
            MacOS { Start-Process -FilePath 'open' -ArgumentList $Uri.AbsoluteUri -ErrorAction Stop | Out-Null }
            Linux {
                if (-not ($env:DISPLAY -or $env:WAYLAND_DISPLAY) -or -not (Get-Command xdg-open -ErrorAction SilentlyContinue)) {
                    return $false
                }
                Start-Process -FilePath 'xdg-open' -ArgumentList $Uri.AbsoluteUri -ErrorAction Stop | Out-Null
            }
            default { return $false }
        }
        $true
    }
    catch {
        $false
    }
}

function Read-SnowOAuthCallbackUrl {
    [CmdletBinding()]
    param()

    try {
        $callbackUrl = Read-Host 'Paste the complete redirect URL shown after sign-in'
    }
    catch {
        throw [System.InvalidOperationException]::new('Interactive sign-in is unavailable. Use -ClientCredentials with a dedicated service account for unattended sessions.')
    }
    if ([string]::IsNullOrWhiteSpace($callbackUrl)) {
        throw [System.InvalidOperationException]::new('No authorization callback URL was provided. For unattended sessions, use -ClientCredentials with a dedicated service account.')
    }
    $callbackUrl
}

function Invoke-SnowOAuthAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][ValidateRange(1024, 65535)][int]$RedirectPort,
        [switch]$NoBrowser,
        [ValidateRange(1, 600)][int]$TimeoutSeconds = 120
    )

    $redirectUri = [uri]::new("http://127.0.0.1:$RedirectPort/callback")
    $proofKey = Get-SnowOAuthProofKey
    $authorizationUri = Get-SnowOAuthAuthorizationUri -BaseUri $BaseUri -ClientId $ClientId `
        -RedirectUri $redirectUri -State $proofKey.State -Challenge $proofKey.Challenge

    if ($NoBrowser) {
        Write-Host "Open this URL in a browser to sign in:`n$authorizationUri"
        $callbackUrl = Read-SnowOAuthCallbackUrl
    }
    else {
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add("http://127.0.0.1:$RedirectPort/")
        try {
            $listener.Start()
        }
        catch {
            $listener.Close()
            throw [System.InvalidOperationException]::new("Could not listen on redirect port $RedirectPort. Choose another port with -RedirectPort.")
        }

        try {
            if (Open-SnowOAuthBrowser -Uri $authorizationUri) {
                $callbackTask = $listener.GetContextAsync()
                if (-not $callbackTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
                    throw [System.TimeoutException]::new('Timed out waiting for the ServiceNow sign-in callback. Run Connect-Snowplow again.')
                }
                $context = $callbackTask.GetAwaiter().GetResult()
                try {
                    $callbackUrl = $context.Request.Url.AbsoluteUri
                    $responseText = '<!doctype html><html><head><title>Snowplow</title></head><body>You can close this window and return to PowerShell.</body></html>'
                    $responseBytes = [Text.Encoding]::UTF8.GetBytes($responseText)
                    $context.Response.ContentType = 'text/html; charset=utf-8'
                    $context.Response.ContentLength64 = $responseBytes.Length
                    $context.Response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
                }
                finally {
                    $context.Response.Close()
                }
            }
            else {
                Write-Host "Could not open a browser. Open this URL to sign in:`n$authorizationUri"
                $callbackUrl = Read-SnowOAuthCallbackUrl
            }
        }
        finally {
            $listener.Stop()
            $listener.Close()
        }
    }

    $callback = ConvertFrom-SnowOAuthCallback -CallbackUrl $callbackUrl -RedirectUri $redirectUri -ExpectedState $proofKey.State
    [pscustomobject]@{
        Code        = $callback.Code
        Verifier    = $proofKey.Verifier
        RedirectUri = $redirectUri
    }
}

function Get-SnowOAuthTokenKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId
    )

    $bytes = [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$($BaseUri.AbsoluteUri)|$ClientId"))
    [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function Get-SnowOAuthTokenStorePath {
    [CmdletBinding()]
    param()

    Join-Path (Get-SnowplowDirectories).Data 'oauth-tokens.json'
}

function Read-SnowOAuthRefreshToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId
    )

    $path = Get-SnowOAuthTokenStorePath
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        $entries = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop)
        $entry = $entries | Where-Object Key -eq (Get-SnowOAuthTokenKey -BaseUri $BaseUri -ClientId $ClientId) | Select-Object -First 1
        if ($entry -and $entry.RefreshToken) {
            ConvertTo-SecureString -String ([string]$entry.RefreshToken) -AsPlainText -Force
        }
    }
    catch {
        throw [System.IO.InvalidDataException]::new('The saved OAuth token store could not be read. Remove it and sign in again.')
    }
}

function Write-SnowOAuthRefreshToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][securestring]$RefreshToken
    )

    $path = Get-SnowOAuthTokenStorePath
    $directory = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = [System.IO.Directory]::CreateDirectory($directory)
    }
    Protect-SnowplowPath -Path $directory -Type Directory

    $entries = if (Test-Path -LiteralPath $path) {
        try { @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop) }
        catch { throw [System.IO.InvalidDataException]::new('The saved OAuth token store could not be read. Remove it and sign in again.') }
    }
    else { @() }
    $key = Get-SnowOAuthTokenKey -BaseUri $BaseUri -ClientId $ClientId
    $entries = @($entries | Where-Object Key -ne $key)
    $plainToken = [System.Net.NetworkCredential]::new('', $RefreshToken).Password
    $entries += [pscustomobject]@{ Key = $key; RefreshToken = $plainToken }
    $entries | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    Protect-SnowplowPath -Path $path -Type File
}

function Clear-SnowOAuthRefreshToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$BaseUri,
        [Parameter(Mandatory)][string]$ClientId
    )

    $path = Get-SnowOAuthTokenStorePath
    if (-not (Test-Path -LiteralPath $path)) { return }
    try {
        $key = Get-SnowOAuthTokenKey -BaseUri $BaseUri -ClientId $ClientId
        $entries = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop | Where-Object Key -ne $key)
        if ($entries.Count) {
            $entries | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
            Protect-SnowplowPath -Path $path -Type File
        }
        else {
            Remove-Item -LiteralPath $path -Force
        }
    }
    catch {
        throw [System.IO.InvalidDataException]::new('The saved OAuth token store could not be updated.')
    }
}
