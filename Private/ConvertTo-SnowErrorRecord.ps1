function ConvertTo-SnowErrorRecord {
    <#
    .SYNOPSIS
        Builds an ErrorRecord from a failed HTTP call, parsing the ServiceNow
        {"error":{"message":..,"detail":..},"status":"failure"} body when present.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Target
    )

    $status = $null
    $ex = $ErrorRecord.Exception
    if ($ex.PSObject.Properties['Response'] -and $ex.Response) { $status = [int]$ex.Response.StatusCode }

    $message = $null; $detail = $null
    $body = $ErrorRecord.ErrorDetails.Message
    if ($body) {
        try {
            $parsed = $body | ConvertFrom-Json -ErrorAction Stop
            $err = $parsed.PSObject.Properties['error']
            if ($err -and $err.Value) {
                $message = $err.Value.PSObject.Properties['message']?.Value
                $detail = $err.Value.PSObject.Properties['detail']?.Value
            }
        }
        catch { $message = $null }
    }
    if (-not $message) { $message = $ex.Message }

    $text = if ($status) { "ServiceNow request failed (HTTP $status): $message" } else { "ServiceNow request failed: $message" }
    if ($detail) { $text += " Detail: $detail" }

    $category = switch ($status) {
        401 { 'AuthenticationError' }
        403 { 'PermissionDenied' }
        404 { 'ObjectNotFound' }
        400 { 'InvalidArgument' }
        409 { 'ResourceExists' }
        429 { 'LimitsExceeded' }
        { $_ -ge 500 } { 'ResourceUnavailable' }
        default { 'NotSpecified' }
    }
    $id = if ($status) { "Snowplow.Http$status" } else { 'Snowplow.RequestFailed' }
    $newEx = [System.InvalidOperationException]::new($text, $ex)
    [System.Management.Automation.ErrorRecord]::new($newEx, $id, $category, $Target)
}
