param (
    # The connection parameters for the target organization
    [ValidateSet("MySandbox","MyTest")] # update this list based on files in the CdsConnectionParameters folder
    [string]
    $ConnectionName = "MySandbox",

    # The settings for the actions performed during the export
    [ValidateSet("DefaultSettings")] # update this list based on files in the Settings folder
    [string]
    $ExportSettings = "DefaultSettings",

    # The available actions to perform during the export
    [ValidateSet("All","Solutions","ConfigData","TestData","Export-CrmSolutions","Expand-CrmSolutions","Export-ConfigData","Expand-ConfigData","Export-TestData","Expand-TestData")]
    [string[]]
    $Actions = "Solutions"
)

$global:ErrorActionPreference = "Stop"
$Env:CRM_SDK_PATH = "$PSScriptRoot\Tools"

# Adoxio.Dynamics.DevOps is kept only for Expand-CrmSolution / Expand-CrmData (local, no connection).
Import-Module "$env:CRM_SDK_PATH\Adoxio.Dynamics.DevOps\Adoxio.Dynamics.DevOps.psd1" -Force

$ConnectionParameters = switch ($ConnectionName) {
    "MySandbox" {& "C:\\CrmConnection\MyCdsSandboxConnection.ps1"}
    default     {& "$PSScriptRoot\CdsConnectionParameters\$ConnectionName.ps1"}
}

$settings = & "$PSScriptRoot\Settings\$ExportSettings.ps1" -ConnectionParameters $ConnectionParameters
$cdsSolutionFolder = "$($PSScriptRoot | Split-Path)\CdsSolution"

. "$PSScriptRoot\Doctoring\UpdateSolutionVersion.ps1"


# pac auth -- only set up when a requested action actually needs a live connection.
$needsPacAuth = 'All' -in $Actions -or 'Solutions' -in $Actions -or 'ConfigData' -in $Actions -or 'TestData' -in $Actions `
    -or 'Export-CrmSolutions' -in $Actions -or 'Export-ConfigData' -in $Actions -or 'Export-TestData' -in $Actions

if ($needsPacAuth) {
    $pacParams = $ConnectionParameters.PacConnectionParameter
    if (-not $pacParams -or -not $pacParams.EnvironmentUrl) {
        throw "Connection file '$ConnectionName' has no PacConnectionParameter.EnvironmentUrl. Add one (e.g. https://<org>.crm9.dynamics.com) before running Export.ps1."
    }

    $pacProfileName = $settings.SolutionName
    Write-Host "pac auth: $($pacParams.EnvironmentUrl) (profile: $pacProfileName)"
    pac auth create --url $pacParams.EnvironmentUrl --name $pacProfileName | Out-Null
    pac auth select --name $pacProfileName | Out-Null
}


# ---------------------------------------------------------------------------
# CDS Solutions — export and extract
# ---------------------------------------------------------------------------

if ($settings.ExportSolutions -and ('All' -in $Actions -or 'Solutions' -in $Actions -or 'Export-CrmSolutions' -in $Actions)) {
    foreach ($solution in $settings.ExportSolutions.Solutions) {
        $managedFlag = if ($solution.Managed) { "true" } else { "false" }
        Write-Host "pac solution export: $($solution.SolutionName) (managed=$managedFlag) -> $($solution.ZipFile)"
        if (Test-Path -Path $solution.ZipFile) { Remove-Item -Path $solution.ZipFile -Force }
        pac solution export --name $solution.SolutionName --path $solution.ZipFile --managed $managedFlag --async --max-async-wait-time 90 --overwrite
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $solution.ZipFile)) { throw "pac solution export failed for '$($solution.SolutionName)' (exit $LASTEXITCODE) -- zip file was not produced" }
    }
}

if ($settings.ExtractSolutions -and ('All' -in $Actions -or 'Solutions' -in $Actions -or 'Expand-CrmSolutions' -in $Actions)) {
    $settings.ExtractSolutions | Expand-CrmSolution
    if ($LASTEXITCODE -ne 0) { throw "Expand-CrmSolution (SolutionPackager.exe) failed (exit $LASTEXITCODE)" }
    Set-SolutionVersionNumber -CdsSolutionFolder $cdsSolutionFolder
    & "$PSScriptRoot\Doctoring\Remove-KeysFromMissingDependencies.ps1" -SolutionFolderPath "$(Split-Path $PSScriptRoot)\CdsSolution"
    & "$PSScriptRoot\Doctoring\Sort-SolutionXmlFolder.ps1" -Path "$(Split-Path $PSScriptRoot)\CdsSolution\other"
}


# ---------------------------------------------------------------------------
# Config Data — export and extract
# ---------------------------------------------------------------------------

if ($settings.ExportConfigData -and ('All' -in $Actions -or 'ConfigData' -in $Actions -or 'Export-ConfigData' -in $Actions) -and (Test-Path -Path $settings.ExportConfigData.SchemaFile)) {
    Write-Host "pac data export (config): $($settings.ExportConfigData.SchemaFile) -> $($settings.ExportConfigData.ZipFile)"
    pac data export --schemaFile $settings.ExportConfigData.SchemaFile --dataFile $settings.ExportConfigData.ZipFile --overwrite
    if ($LASTEXITCODE -ne 0) { throw "pac data export failed for config data (exit $LASTEXITCODE)" }
}

if ($settings.ExtractConfigData -and ('All' -in $Actions -or 'ConfigData' -in $Actions -or 'Expand-ConfigData' -in $Actions) -and (Test-Path -Path $settings.ExtractConfigData.ZipFile)) {
    $settings.ExtractConfigData | Expand-CrmData
}


# ---------------------------------------------------------------------------
# Test Data — export and extract
# ---------------------------------------------------------------------------

if ($settings.ExportTestData -and ('TestData' -in $Actions -or 'Export-TestData' -in $Actions) -and (Test-Path -Path $settings.ExportTestData.SchemaFile)) {
    Write-Host "pac data export (test): $($settings.ExportTestData.SchemaFile) -> $($settings.ExportTestData.ZipFile)"
    pac data export --schemaFile $settings.ExportTestData.SchemaFile --dataFile $settings.ExportTestData.ZipFile --overwrite
    if ($LASTEXITCODE -ne 0) { throw "pac data export failed for test data (exit $LASTEXITCODE)" }
}

if ($settings.ExtractTestData -and ('TestData' -in $Actions -or 'Expand-TestData' -in $Actions) -and (Test-Path -Path $settings.ExtractTestData.ZipFile)) {
    $settings.ExtractTestData | Expand-CrmData
}
