@{
    # Identity — where this project lives
    # Find your TenantId at: https://portal.azure.com → Microsoft Entra ID → Overview
    TenantId               = "00000000-0000-0000-0000-000000000000"
    
    # Cloud: "UsGov" for GCC, "Public" for commercial Azure
    Cloud                  = "Public"

    # Region: typically "NorthAmerica2" for GCC, "NorthAmerica" or "UnitedStates" for commercial
    Region                 = "NorthAmerica"

    # ProfileName: the pac CLI auth profile name used for this project (see `pac auth list`).
    # Just a local label — the same value works for every developer on this project.
    ProfileName            = "[projectname]-PowerPages"
    
    # Site — what to download/upload
    # SiteFriendlyName: the Power Pages site name with the env-specific suffix stripped
    # Example: site is named "Acme Customer Portal - dev01portal" → SiteFriendlyName is "Acme Customer Portal"
    SiteFriendlyName       = "REPLACE WITH YOUR SITE FRIENDLY NAME"
    
    # SiteFriendlyNameSuffix: the env-specific portion of the friendly name (including leading " - ")
    # Example: " - dev01portal", " - testportal", " - prodportal"
    SiteFriendlyNameSuffix = " - REPLACE WITH ENV SUFFIX"
    
    # SiteWebsiteId: the GUID of the Power Pages site in the env you're targeting
    # Find via: pac pages list (after authenticating to the env)
    SiteWebsiteId          = "00000000-0000-0000-0000-000000000000"
    
    # Auth — Microsoft public client used for delegated MSAL flows.
    # This is constant across tenants; do not change unless you know why.
    MsalPublicClientId     = "51f81489-12ee-4a9e-aaae-a2591f45987d"
    
    # Patcher config — folder types Phase 2 of Upload-StagedPortalChanges
    # should patch via Web API to work around pac field-drop bugs.
    # Each entry maps a pac-download folder type to its Dataverse table info.
    TableMap = @{
        'basic-forms' = @{
            EntitySet           = 'mspp_entityforms'
            LogicalName         = 'mspp_entityform'
            PrimaryKeyYamlField = 'adx_entityformid'
        }
        'advanced-forms' = @{
            EntitySet           = 'mspp_webforms'
            LogicalName         = 'mspp_webform'
            PrimaryKeyYamlField = 'adx_webformid'
        }
        'web-pages' = @{
            EntitySet           = 'mspp_webpages'
            LogicalName         = 'mspp_webpage'
            PrimaryKeyYamlField = 'adx_webpageid'
        }
        'table-permissions' = @{
            EntitySet           = 'mspp_entitypermissions'
            LogicalName         = 'mspp_entitypermission'
            PrimaryKeyYamlField = 'adx_entitypermissionid'
        }
    }

    # Advanced form steps live nested under advanced-forms/<form>/advanced-form-steps/.
    AdvancedFormStepsTable = @{
        EntitySet           = 'mspp_webformsteps'
        LogicalName         = 'mspp_webformstep'
        PrimaryKeyYamlField = 'adx_webformstepid'
    }
}