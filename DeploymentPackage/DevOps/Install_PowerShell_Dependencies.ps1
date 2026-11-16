# Developer machine setup for the DevOps scripts. Everything installs for the current user only,
# so no elevated (administrator) PowerShell is needed.
#
# Everything that connects to an environment signs in with MSAL:
#   - Power Platform CLI (pac): solution export/import/pack, data export/import, Import.ps1 -ResetEnvironment
#   - MSAL.PS: Import-DocumentTemplates.ps1 and Upload-StagedPortalChanges.ps1
#
# The ADAL-based modules this script used to install (Microsoft.Xrm.Data.PowerShell,
# Microsoft.Xrm.Tooling.ConfigurationMigration, Microsoft.Xrm.Tooling.PackageDeployment.PowerShell,
# Microsoft.Xrm.DevOps.Data.PowerShell, Microsoft.PowerApps(.Administration).PowerShell and the
# PowerShell Gallery copy of Adoxio.Dynamics.DevOps) are no longer used. The Adoxio functions the
# scripts need are vendored under DevOps\Tools.

$ErrorActionPreference = "Stop"

if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
}

Install-Module MSAL.PS -Scope CurrentUser -Force -AllowClobber

if (Get-Command pac -ErrorAction SilentlyContinue) {
    dotnet tool update --global Microsoft.PowerApps.CLI.Tool
}
else {
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool
    Write-Host "Installed pac. Open a new terminal (or restart Visual Studio) so it is on PATH."
}

# Provision the developer sandbox connection file at the location the DevOps scripts read. It lives
# outside the repo so it is never committed and is shared by every solution repo on this machine. An
# existing file is left alone, so re-running this script does not wipe values a developer already filled in.
$connectionFolder = "C:\CrmConnection"
$connectionFile   = Join-Path $connectionFolder "MyCdsSandboxConnection.ps1"

if (-not (Test-Path $connectionFolder)) {
    New-Item -ItemType Directory -Path $connectionFolder | Out-Null
}

if (Test-Path $connectionFile) {
    Write-Host "Existing connection file left in place: $connectionFile"
} else {
    Copy-Item "$PSScriptRoot\CdsConnectionParameters\MyCdsSandboxConnection-Template.ps1" -Destination $connectionFile
    Write-Host "Created $connectionFile"
    Write-Host "Edit it with your sandbox details before running Export.ps1 or Import.ps1."
}
