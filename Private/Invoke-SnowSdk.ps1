function Invoke-SnowSdk {
    <#
    .SYNOPSIS
        Executes one ServiceNow table operation through the optional Node.js SDK.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Table,
        [string]$Method = 'GET',
        [string]$SysId,
        [string]$Query,
        [string[]]$Fields,
        [int]$PageSize = 1000,
        [int]$First,
        [object]$Body
    )

    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        throw [System.InvalidOperationException]::new('The Sdk backend requires Node.js and the now-sdk package. Install Node.js and make now-sdk available to Node.js, or select the Rest backend.')
    }

    $sdkCheck = & $node.Source -e "try { require.resolve('now-sdk', { paths: require('module').globalPaths }); process.exit(0) } catch { process.exit(1) }" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw [System.InvalidOperationException]::new('The Sdk backend requires the Node.js package now-sdk. Make now-sdk available in Node.js module resolution, or select the Rest backend.')
    }

    throw [System.NotSupportedException]::new('The installed now-sdk package does not expose the supported Snowplow table-operation adapter. Use the Rest backend.')
}
