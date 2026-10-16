# snowplow
snowplow is a Powershell module to assist ServiceNow administrators to read and manipulate their ServiceNow instances 

## Quick start
```powershell
Import-Module ./Snowplow.psd1
Connect-Snowplow -Instance dev12345 -ClientCredential (Get-Credential)   # OAuth (preferred)
Invoke-Pester ./Tests
```
Design notes: sessions live in module scope; HTTPS only; OAuth preferred, Basic warns; secrets only as PSCredential / SecretManagement;
retries on 429/5xx with backoff (POST retried on 429 only); writes honour -WhatIf/-Confirm; `-Backend Rest|Sdk|Auto` (Sdk is not yet implemented).
