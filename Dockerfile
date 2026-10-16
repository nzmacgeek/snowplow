FROM mcr.microsoft.com/powershell:latest

WORKDIR /workspace
COPY . .

RUN pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = "Stop"; Register-PSRepository -Default; if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) { throw "PSGallery could not be registered" }; Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module Pester -MinimumVersion 5.0 -Scope AllUsers -Force -SkipPublisherCheck -ErrorAction Stop'

CMD ["pwsh", "-NoLogo", "-NoProfile", "-Command", "Invoke-Pester ./Tests -CI"]
