# Real-world workflows

Each workflow is a runnable scenario. They assume you have already connected with
[`Connect-Snowplow`](../cmdlets/Connect-Snowplow.md).

| Workflow | For |
|----------|-----|
| [Incident triage](incident-triage.md) | Service desk leads working the morning queue |
| [Querying and reporting](querying-and-reporting.md) | Building queries and exporting weekly reports |
| [Bulk updates safely](bulk-updates.md) | Fixing data in many records with `-WhatIf` and Prod guard rails |
| [CMDB investigation](cmdb.md) | Impact analysis before a change window |
| [Comparing instances](compare-instances.md) | Spotting configuration drift between Dev, Test and Prod |
| [Troubleshooting with the system log](syslog.md) | Tailing errors while reproducing a problem |
| [Unattended automation](automation.md) | Scheduled jobs and CI/CD pipelines |
