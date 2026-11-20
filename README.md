# JMCL Dataverse Deployment Template

Export, import and packaging scripts for a Dataverse solution repository. A solution repo
consumes this template as a NuGet package (`JMCL.Dataverse.DeploymentTemplate.Sources`), which
drops the `DevOps` scripts into the consuming project so updates arrive centrally rather than by
copy-paste.

## Layout

```
DeploymentPackage/
  DevOps/
    Export.ps1                     # environment -> repo (solution, config data, test data, portal)
    Import.ps1                     # repo -> environment (pack, package, import)
    Stage-PortalChange.ps1         # correlate staged Power Pages files with solution components
    Upload-StagedPortalChanges.ps1 # push staged portal changes without clobbering others' work
    post-build.ps1                 # builds the deployment package on Release/Debug build
    Install_PowerShell_Dependencies.ps1 # installs pac and Az.Accounts, creates the machine connection file
    Get-DataverseAccessToken.ps1   # Web API sign-in for the scripts pac can't cover
    Merge-CrmDataZip.ps1           # merges config/test data zips into the package's one data file
    CdsConnectionParameters/       # per-environment connection files
    Doctoring/                     # solution XML normalization before commit
    Settings/DefaultSettings.ps1   # resolves paths, dependency ordering and package definition
    Tools/                         # vendored Adoxio.Dynamics.DevOps module; see NOTICE
  Sites/_site-config/
    PortalToolkit.Config.psd1      # per-project Power Pages settings
  JmclImportExtension.cs           # Package Deployer import extension base class
  source.nuspec                    # package manifest
```

## Per-developer setup

Run once per machine:

```powershell
cd DeploymentPackage\DevOps
.\Install_PowerShell_Dependencies.ps1
```

`Install_PowerShell_Dependencies.ps1` installs the Power Platform CLI (`pac`) and the `Az.Accounts`
module, both for the current user only, so it does not need an elevated PowerShell. Both versions
are pinned at the top of the script (pac also in `PipelineTemplate/azure-pipelines.yml`), so every
machine runs what was tested; bump them there on purpose. Every script that connects to an
environment signs in with MSAL through one of those two; nothing uses ADAL or stores a password.

It also creates `C:\CrmConnection\MyCdsSandboxConnection.ps1` from the template if it does not
already exist.
That file holds the developer's own sandbox details and lives outside the repository, so it is
shared by every solution repo on the machine and cannot be committed by accident. Edit it before
running anything else — see the comments in
`DevOps\CdsConnectionParameters\MyCdsSandboxConnection-Template.ps1` for what each field expects,
including how the environment URL's host suffix depends on the target's region and cloud.

Upper environments are not represented in this repository at all. Nothing here names a test or
production environment, and there is no configuration a developer can edit that would point these
scripts at one. Promotion beyond the developer sandbox belongs to the release pipeline, which
supplies its own connection details.

## Round trip

```powershell
# environment -> repo
.\Export.ps1 -ConnectionName MySandbox -Actions All

# repo -> environment
.\Import.ps1 -ConnectionName MySandbox -PackageType Unmanaged -Actions All
```

Both take `-Actions` to run a single step instead of the whole sequence; see the `ValidateSet` on
each script for the current list.

### Solution XML normalization

Dataverse does not export child nodes in a stable order, and it stamps `MissingDependencies` with
keys that are regenerated on every export. Left alone, both produce diff noise that buries real
changes. `Export.ps1` therefore strips the keys and sorts three known-safe node sets before the
files are committed; `Import.ps1` regenerates the keys deterministically before packing, since the
`Required` and `Dependent` nodes cross-reference each other by key and the values have to be
internally consistent even though they are arbitrary.

### Dependency solutions

`DefaultSettings.ps1` reads `CdsSolutionDependencies` from the consuming repo's
`SolutionSettings.ps1`, resolves each name against the `CdsDependencies` folder in declaration
order, and prepends them to the target solution. `Import.ps1` imports that list in order, so a
solution that depends on others can be deployed to a fresh environment in one pass.

### Solution version

`Export.ps1` stamps the solution version as `<major>.<yyyy>.<MMdd>.<HHmm>` (UTC), keeping the
major version the solution already has. A solution at 1.x stays at 1.x instead of dropping to 0.x,
which Package Deployer would skip as older than what's installed. To raise the major, change the
solution's version in the maker portal and export.

### Deployment settings and test data

If `DeploymentPackage\DeploymentSettings\<ConnectionName>.json` exists, `Import.ps1` passes it to
`pac solution import --settings-file` for the project's own solution, which sets its connection
references and environment variables for that environment. Make one with
`pac solution create-settings`.

Test data only imports into environments whose connection file sets
`PacConnectionParameter.AllowTestData = $true`. The sandbox template sets it; leave it out of any
connection file for Prod. Asking for `-Actions TestData` against a connection without it fails
before anything runs.

### Package data

Package Deployer imports a single data file, so `Import.ps1` merges the dependencies' config data
and the project's own into `temp\packed\PackageConfigData.zip` whenever it builds the package.
Records with the same id keep the project's copy. Test data is merged in too when the action asks
for it and the connection allows it.

### Document templates

`Import-DocumentTemplates` (`-Actions Import-DocumentTemplates`, included under `All`) imports every
`.docx` and `.xlsx` in `DeploymentPackage\DocumentTemplates`, creating or updating the
`documenttemplate` record with the same name. `pac` has no equivalent command, so
`DevOps\Import-DocumentTemplates.ps1` does it through the Web API, signing in with `Az.Accounts`
(Microsoft's documented route for the Dataverse Web API from PowerShell) against
`PacConnectionParameter.EnvironmentUrl`. Word templates embed their table's object type
code, which differs between environments for custom tables; the script rewrites it to the target
environment's value before uploading. Set `PacConnectionParameter.TenantId` in the connection file
to pin the sign-in to one tenant.

It replaces the vendored `CCLLC.Cds.DevOps.PowerShell` module, the last path in this template on the
older `Get-CrmConnection` / ADAL authentication chain.

## Power Pages

`Export.ps1` maintains two representations of a site: a human-readable mirror under
`DeploymentPackage/Sites/<site>/` and the solution components under
`DeploymentPackage/CdsSolution/powerpagecomponents/<guid>/`. Staging a readable file in git does
not stage its component counterpart, and nothing in the file names connects them.
`Stage-PortalChange.ps1` closes that gap by reading each staged file's own primary key and staging
the matching component folder. `Upload-StagedPortalChanges.ps1` then pushes those staged changes to
the environment as an overlay on a fresh download, so edits made by other developers to files you
did not touch survive.

Project settings for a site live in `Sites/_site-config/PortalToolkit.Config.psd1`, including the
`Cloud` and `Region` values -- check both before pointing this at a GCC tenant, since the defaults
here are commercial. Only the environment URL is per-developer; it comes from the
`PowerPagesConnectionParameter` section of the connection file.

## Packaging

`source.nuspec` publishes the `DevOps` scripts, tooling and the site config template as
`JMCL.Dataverse.DeploymentTemplate.Sources` on nuget.org. A consuming repo installs it as a NuGet
dependency and receives updates to this template centrally.

## Pipeline

`.github/workflows/ci.yml` restores and builds `CdsDeploymentTemplate.sln`, runs tests (a
placeholder today -- there is no test project yet), then packs and publishes `source.nuspec` to
nuget.org, all on a `v*` tag. Publishing uses trusted publishing (OIDC) -- no stored API key -- the
same approach used by the JMCL code libraries. Named to match JMCL's own `ci.yml`, even though this
one workflow currently only runs on a tag rather than on every push or PR.

`azure-pipelines.yml` and `DeploymentPackage/PipelineTemplate/azure-pipelines.yml` are an earlier
Azure DevOps setup, kept as reference rather than current. They are not wired to any live pipeline
and their organization-specific feed ID and agent pool have been replaced with placeholders; revive
them only if this template's publishing ever needs to move back to an Azure DevOps-hosted feed.

## Provenance

Originally published by Scott Colson as the CDS Deployment Template under the MIT license. See
`LICENSE` and `NOTICE` for the license terms and the attribution of vendored third-party components
under `DevOps/Tools/`.
