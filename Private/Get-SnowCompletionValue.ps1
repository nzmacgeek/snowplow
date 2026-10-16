function Get-SnowCompletionValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Table', 'Field')][string]$Kind,
        [string]$Table,
        [string]$Word = ''
    )

    try {
        if ($Kind -eq 'Table') {
            $items = $script:SnowSchemaCache.Tables
            if (-not $items) {
                $items = @(Invoke-SnowRequest -Table sys_db_object -Fields name,label -PageSize 1000)
                $script:SnowSchemaCache.Tables = $items
            }
            $values = @($items | ForEach-Object { $_.name } | Where-Object { $_ -like "$Word*" } | Sort-Object -Unique)
        }
        else {
            $items = $script:SnowSchemaCache.Fields[$Table]
            if (-not $items -and $Table) {
                $items = @(Invoke-SnowRequest -Table sys_dictionary -Query "name=$Table" -Fields element -PageSize 1000)
                $script:SnowSchemaCache.Fields[$Table] = $items
            }
            $values = @($items | ForEach-Object { $_.element } | Where-Object { $_ -and $_ -like "$Word*" } | Sort-Object -Unique)
        }
        foreach ($value in $values) {
            [System.Management.Automation.CompletionResult]::new($value, $value, 'ParameterValue', $value)
        }
    }
    catch { }
}
