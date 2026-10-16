function Invoke-SnowBackendRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Table,
        [string]$Method = 'GET',
        [string]$SysId,
        [string]$Query,
        [string[]]$Fields,
        [int]$PageSize = 1000,
        [int]$First,
        [object]$Body,
        [string]$Backend
    )

    $resolvedBackend = if ($Backend) { Resolve-SnowBackend -Backend $Backend } else { Resolve-SnowBackend }
    if ($resolvedBackend -eq 'Sdk') {
        return Invoke-SnowSdk -Table $Table -Method $Method -SysId $SysId -Query $Query -Fields $Fields -PageSize $PageSize -First $First -Body $Body
    }
    $request = @{
        Table = $Table
        Method = $Method
        PageSize = $PageSize
    }
    if ($SysId) { $request.SysId = $SysId }
    if ($Query) { $request.Query = $Query }
    if ($Fields) { $request.Fields = $Fields }
    if ($null -ne $Body) { $request.Body = $Body }
    if ($PSBoundParameters.ContainsKey('First')) { $request.First = $First }
    if ($Method -ne 'GET') { $request.Confirm = $false }
    Invoke-SnowRequest @request
}
