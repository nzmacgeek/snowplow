# CMDB investigation

**Scenario:** `prod-web-01` is going down for patching. Which other services depend on it?

```powershell
# Find the CI
$ci = Get-SnowCI -Query 'name=prod-web-01' -Fields sys_id,name,sys_class_name,ip_address | Select-Object -First 1

# What depends on it? (it is the child, others are its parents)
$deps = Get-SnowCIRelationship -Query "child=$($ci.sys_id)" -Fields parent,type -All
$deps | Format-Table

# What does it depend on? (it is the parent)
Get-SnowCIRelationship -Query "parent=$($ci.sys_id)" -Fields child,type -All | Format-Table
```

## Inventory report

```powershell
Get-SnowCI -Query 'install_status=1^sys_class_name=cmdb_ci_linux_server' `
    -Fields name,ip_address,os_version,assigned_to -All |
    Export-SnowRecord -Format Csv -Path .\linux-servers.csv
```

## Discover CMDB classes

```powershell
Get-SnowTable -Query 'nameSTARTSWITHcmdb_ci_' -All | Select-Object name, label
Get-SnowDictionary -Table cmdb_ci_linux_server -All | Select-Object element, column_label
```

## Share the result

```powershell
Get-SnowLink -Table cmdb_ci -SysId $ci.sys_id -Format Markdown
```

Related: [Get-SnowCI](../cmdlets/Get-SnowCI.md),
[Get-SnowCIRelationship](../cmdlets/Get-SnowCIRelationship.md).
