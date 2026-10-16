# Contributing

## Local validation

Run the same checks used by CI from the repository root:

```powershell
# install the exact versions used in automation
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -RequiredVersion 1.22.0 -Scope CurrentUser -Force -SkipPublisherCheck

# lint the repository
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./.psscriptanalyzer.settings.psd1

# validate the module manifest and explicit exports
Test-ModuleManifest -Path ./Snowplow.psd1 | Out-Null

# execute the unit test set
Invoke-Pester ./Tests -Tag Unit -CI
```

The CI workflow also stores JUnit XML and coverage output in `TestResults/` for review.

## Pull requests

- Keep changes focused and scoped to the issue or feature being fixed.
- Ensure module exports remain explicit in `Snowplow.psd1` when adding public functions.
- Verify that any new Public/ script is also exported from the module manifest.
