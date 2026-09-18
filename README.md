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
    Install_SDK_Tools.ps1          # populates DevOps/Tools and the machine connection file
    Install_PowerShell_Dependencies.ps1
    CdsConnectionParameters/       # per-environment connection files
    Doctoring/                     # solution XML normalization before commit
    Settings/DefaultSettings.ps1   # resolves paths, dependency ordering and package definition
    Tools/                         # SDK tooling and third-party PowerShell modules; see NOTICE
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
.\Install_SDK_Tools.ps1
```

`Install_SDK_Tools.ps1` downloads the SDK tooling into `DevOps\Tools` and creates
`C:\CrmConnection\MyCdsSandboxConnection.ps1` from the template if it does not already exist.
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

### Document templates

`Import-DocumentTemplates` (`-Actions Import-DocumentTemplates`, included under `All`) is provided
by the vendored `CCLLC.Cds.DevOps.PowerShell` module and is the one path in this template still on
the older `Get-CrmConnection` / ADAL authentication chain -- `pac` has no equivalent command. It
reads `CrmConnectionParameter` from the connection file, which every other action in `Export.ps1`
and `Import.ps1` no longer uses.

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

`.github/workflows/publish.yml` packs and publishes `source.nuspec` to nuget.org on a `v*` tag,
using trusted publishing (OIDC) -- no stored API key -- the same approach used by the JMCL code
libraries.

`azure-pipelines.yml` and `DeploymentPackage/PipelineTemplate/azure-pipelines.yml` are an earlier
Azure DevOps setup, kept as reference rather than current. They are not wired to any live pipeline
and their organization-specific feed ID and agent pool have been replaced with placeholders; revive
them only if this template's publishing ever needs to move back to an Azure DevOps-hosted feed.

## Provenance

Originally published by Scott Colson as the CDS Deployment Template under the MIT license. See
`LICENSE` and `NOTICE` for the license terms and the attribution of vendored third-party components
under `DevOps/Tools/`.
