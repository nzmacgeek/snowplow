# Comparing instances

**Scenario:** an integration works in Dev but fails in Prod. Is a system property different?

Snowplow keeps one active session at a time. Fetch from each instance in turn, keep the results in
variables, then compare.

```powershell
Connect-Snowplow -Profile dev -ClientCredentials
$dev = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'

Connect-Snowplow -Profile prod -ClientCredentials
$prod = Get-SnowRecord -Table sys_properties -Query 'name=glide.smtp.host'

Compare-SnowRecord -Reference $dev -Difference $prod -Property value
Disconnect-Snowplow
```

## Compare many properties

```powershell
$names = 'glide.smtp.host', 'glide.smtp.port', 'glide.ui.session_timeout'
foreach ($name in $names) {
    Connect-Snowplow -Profile dev -ClientCredentials
    $a = Get-SnowRecord -Table sys_properties -Query "name=$name"
    Connect-Snowplow -Profile prod -ClientCredentials
    $b = Get-SnowRecord -Table sys_properties -Query "name=$name"
    [pscustomobject]@{ Name = $name; Dev = $a.value; Prod = $b.value }
}
```

## Before/after a change

```powershell
$before = Get-SnowRecord -Table incident -Query 'number=INC0010001'
Set-SnowRecord -Table incident -SysId $before.sys_id -Values @{ priority = '2' }
$after = Get-SnowRecord -Table incident -Query 'number=INC0010001'
Compare-SnowRecord -Reference $before -Difference $after
```

Related: [Compare-SnowRecord](../cmdlets/Compare-SnowRecord.md).
