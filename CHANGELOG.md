# Changelog

## 0.1.0-beta1

- Added cross-platform PowerShell 7.2 support for ServiceNow administration through the Table API, with an optional now-sdk backend.
- Added interactive OAuth authorization code with PKCE and unattended client-credentials authentication, including token refresh and named profiles.
- Added cmdlets for querying, creating, updating, deleting, exporting, and comparing records, plus schema and CMDB helpers.
- Added query-building, record-link, browser, prompt, and PowerShell convenience features.
- Added production safeguards including confirmation for writes, read-only production profiles by default, and retry handling for rate limits and transient server errors.

## Unreleased

- Added CI, integration, and publication workflows for PowerShell Gallery releases.
