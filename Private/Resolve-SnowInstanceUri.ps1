function Resolve-SnowInstanceUri {
    <#
    .SYNOPSIS
        Normalises an instance name or URL to https://<host>. HTTPS only.
    #>
    [CmdletBinding()]
    [OutputType([uri])]
    param([Parameter(Mandatory)][string]$Instance)

    $text = $Instance.Trim()
    if ($text -match '^http://') {
        throw [System.ArgumentException]::new("Refusing insecure instance URL '$text'. Use https.")
    }
    if ($text -notmatch '^https://') {
        if ($text -notmatch '\.') { $text = "$text.service-now.com" }
        $text = "https://$text"
    }
    $uri = $null
    if (-not [uri]::TryCreate($text, [System.UriKind]::Absolute, [ref]$uri) -or
        $uri.Host -notmatch '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$') {
        throw [System.ArgumentException]::new("'$Instance' is not a valid ServiceNow instance name or URL.")
    }
    # Rebuild authority to omit any embedded userinfo.
    [System.UriBuilder]::new($uri.Scheme, $uri.Host, $uri.Port).Uri
}
