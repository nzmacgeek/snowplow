function Invoke-SnowRequest {
    <#
    .SYNOPSIS
        REST backend: calls the ServiceNow Table API with pagination, retry/backoff and error parsing.
    .DESCRIPTION
        GET without -SysId pages with sysparm_limit/sysparm_offset until a short page is returned
        or -First records have been emitted. Retries on 429 and 5xx with exponential backoff and
        jitter (honouring Retry-After); non-idempotent POST is only retried on 429, since a 5xx
        may mean the write succeeded. Anything other than GET goes through ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[a-z0-9_]+$')][string]$Table,
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method = 'GET',
        [ValidatePattern('^[0-9a-fA-F]{32}$')][string]$SysId,
        [string]$Query,
        [string[]]$Fields,
        [ValidateSet('true', 'false', 'all')][string]$DisplayValue,
        [ValidateRange(1, 10000)][int]$PageSize = 1000,
        [ValidateRange(1, [int]::MaxValue)][int]$First,
        [object]$Body,
        [ValidateRange(0, 10)][int]$MaxRetries = 4,
        [ValidateRange(0.0, 60.0)][double]$BaseDelaySeconds = 1.0
    )

    $session = Get-SnowSession
    $path = "/api/now/table/$Table" + $(if ($SysId) { "/$SysId" })
    $isRead = $Method -eq 'GET'
    $paged = $isRead -and -not $SysId

    if (-not $isRead -and -not $PSCmdlet.ShouldProcess("$Table$(if ($SysId) { "/$SysId" })", $Method)) { return }

    $offset = 0
    $emitted = 0
    do {
        $limit = $PageSize
        if ($paged -and $First) { $limit = [Math]::Min($PageSize, $First - $emitted) }

        $qs = [System.Collections.Generic.List[string]]::new()
        if ($Query) { $qs.Add('sysparm_query=' + [uri]::EscapeDataString($Query)) }
        if ($Fields) { $qs.Add('sysparm_fields=' + [uri]::EscapeDataString($Fields -join ',')) }
        if ($DisplayValue) { $qs.Add("sysparm_display_value=$DisplayValue") }
        if ($paged) { $qs.Add("sysparm_limit=$limit"); $qs.Add("sysparm_offset=$offset") }
        $uri = [uri]::new($session.BaseUri, $path + $(if ($qs.Count) { '?' + ($qs -join '&') }))

        $params = @{
            Uri         = $uri
            Method      = $Method
            ErrorAction = 'Stop'
        }
        if ($null -ne $Body) {
            $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 -Compress }
            $params.ContentType = 'application/json'
        }

        $attempt = 0
        while ($true) {
            $params.Headers = (Get-SnowAuthHeader -Session $session) + @{ Accept = 'application/json' }
            try {
                $response = Invoke-RestMethod @params
                break
            }
            catch {
                $status = $null
                $retryAfter = $null
                if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) {
                    $status = [int]$_.Exception.Response.StatusCode
                    $values = $null
                    if ($_.Exception.Response.Headers.TryGetValues('Retry-After', [ref]$values)) {
                        $value = @($values)[0].Trim()
                        $parsed = 0.0
                        if ([double]::TryParse(
                                $value,
                                [Globalization.NumberStyles]::AllowDecimalPoint,
                                [Globalization.CultureInfo]::InvariantCulture,
                                [ref]$parsed
                            ) -and $parsed -ge 0) {
                            $retryAfter = $parsed
                        }
                        else {
                            $retryDate = [DateTimeOffset]::MinValue
                            $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
                            if ([DateTimeOffset]::TryParse($value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$retryDate)) {
                                $retryAfter = [Math]::Max(0, ($retryDate - [DateTimeOffset]::UtcNow).TotalSeconds)
                            }
                        }
                    }
                }
                $retryable = $status -eq 429 -or ($status -ge 500 -and $Method -ne 'POST')
                if (-not $retryable -or $attempt -ge $MaxRetries) {
                    $PSCmdlet.ThrowTerminatingError((ConvertTo-SnowErrorRecord -ErrorRecord $_ -Target $uri.AbsolutePath))
                }
                if ($null -ne $retryAfter -and $retryAfter -gt 120) {
                    throw [System.InvalidOperationException]::new("Retry-After requests a $([Math]::Ceiling($retryAfter))-second wait, exceeding the 120-second maximum supported wait.")
                }
                $delay = if ($null -ne $retryAfter) { $retryAfter }
                else { $BaseDelaySeconds * [Math]::Pow(2, $attempt) * (0.5 + [Random]::Shared.NextDouble() / 2) }
                Write-Verbose "HTTP $status from $($uri.AbsolutePath); retry $($attempt + 1)/$MaxRetries in $([Math]::Round($delay, 2))s."
                Start-SnowSleep -Seconds $delay
                $attempt++
            }
        }

        $records = @(if ($null -ne $response -and $response.PSObject.Properties['result']) { $response.result })
        $records
        $emitted += $records.Count
        $offset += $records.Count
        $more = $paged -and $records.Count -ge $limit -and $records.Count -gt 0 -and (-not $First -or $emitted -lt $First)
    } while ($more)
}
