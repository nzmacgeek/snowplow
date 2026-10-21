# Querying and reporting

**Scenario:** management wants a weekly report of incidents opened in the last seven days, and you
need an audit of dormant user accounts.

## Build readable queries

```powershell
# Simple equality conditions
New-SnowQuery -Conditions ([ordered]@{ active = 'true'; category = 'network' })

# IN, LIKE and friends use a descriptor
New-SnowQuery -Conditions @{ priority = @{ Operator = 'IN'; Value = @('1', '2') } }

# Fluent style with relative dates and sorting
$query = New-SnowQuery |
    Where-SnowField sys_created_on -Operator '>' -Value (New-SnowRelativeDate -Last 7 -Unit Days) |
    Add-SnowOrderBy sys_created_on -Descending
```

## Weekly incident report

```powershell
Get-SnowRecord -Table incident -Query $query -Fields number,short_description,priority,state,assignment_group -All |
    Export-SnowRecord -Format Csv -Path .\incidents-last-7-days.csv
```

## Summarise by group

```powershell
Get-SnowRecord -Table incident -Query $query -Fields assignment_group -All |
    Group-Object { $_.assignment_group.display_value ?? $_.assignment_group } |
    Sort-Object Count -Descending |
    Select-Object Count, Name
```

## Audit dormant accounts

```powershell
Get-SnowRecord -Table sys_user `
    -Query 'active=true^last_login<javascript:gs.daysAgoStart(90)' `
    -Fields user_name,name,last_login -All |
    Export-SnowRecord -Format Csv -Path .\dormant-users.csv
```

## Discover tables and fields

Not sure of an internal name? Ask the instance.

```powershell
Get-SnowTable -Query 'labelLIKEchange' | Select-Object name, label
Get-SnowDictionary -Table change_request -All | Select-Object element, column_label, internal_type
```

Related: [New-SnowQuery](../cmdlets/New-SnowQuery.md), [Find-SnowField](../cmdlets/Find-SnowField.md),
[Export-SnowRecord](../cmdlets/Export-SnowRecord.md).
