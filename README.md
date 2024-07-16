# SharePoint Versioning Scripts

These scripts have been created to allow you to report on the configuration of SharePoint versioning across document libraries in a tenant and in addition, enable/disable versioning on all libraries. All scripts connect to the Microsoft Graph API and SharePoint Online using the PnP PowerShell module to retrieve site/document library information and update versioning settings. 

They are primarily designed for organizations with a large number of SharePoint sites and document libraries where the versioning status is unknown/inconsistent.

You can use GetLibraryVersioningInfo.ps1 script to first report on versioning settings and then leverage EnableDisableVersioning.ps1 script to configure as per your requirements.

It is worth noting that new SharePoint sites now have versioning turned ON by default with no native ability to disable it. 

Special thanks to [Alex Grover](https://github.com/grovale) for his awesome scripts which have been used as a base for these.

There are two scripts in this repo:

## GetLibraryVersioningInfo.ps1

Creates a report of versioning settings for all document libraries in a given SharePoint tenant or a specific set of SharePoint sites. 

## EnableDisableVersioning.ps1

Enables or disables versioning (Major, Minor or Major & Minor) on all document libraries or libraries within a specific set of sites. Also configures Major & Minor version limits.

## Dependencies
The scripts require the following PowerShell modules:
- Microsoft.Graph.Sites
- Microsoft.Graph.Groups
- PnP.PowerShell

Please make sure these modules are installed before running the scripts. If any of the modules are missing, the script will display an error and exit.

## Graph Permissions

The scripts require the following Microsoft Graph permissions:

### GetLibraryVersioningInfo.ps1

Graph Permissions:

- Sites.Read.All

SPO Permissions

- Sites.Read.All

### EnableDisableVersioning.ps1

Graph Permissions:

- Sites.Read.All
- Sites.Manage.All

SPO Permissions

- Sites.Read.All

## App Registration

The scripts require an app registration in Azure AD to authenticate with Microsoft Graph and SharePoint Online. The app registration allows the scripts to access the required resources and perform the necessary operations. To set up the app registration, follow these steps:

1. Go to the Azure portal (portal.azure.com) and navigate to the Azure Active Directory section.
2. Select "App registrations" and click on "New registration" to create a new app registration.
3. Provide a name for the app registration and choose the appropriate supported account types (e.g., single tenant, multi-tenant).
4. Once the app registration is created, note down the "Client ID" (also known as the Application ID) as it will be used as the `$clientId` in the scripts.

## Creating a Self-Signed Certificate

The script requires a self-signed certificate that is used for authentication. Follow these steps to create a self-signed certificate using the script:

1. Run the following code to create a self-signed certificate (Note. This script needs to be run from the device that will run the script):

   ```powershell
   $certname = "VersionScriptCert"
   $cert = New-SelfSignedCertificate -Subject "CN=$certname" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256
   Export-Certificate -Cert $cert -FilePath "$certname.cer"  ## Specify your preferred location
    ```

After running the code, the certificate will be saved with the .cer extension in the specified location.

The .cer file will need to be uploaded to the App Registration.

## Variables
The scripts include several variables that can be customized according to your needs:

- `$clientId`: The client ID for authenticating with Microsoft Graph.
- `$tenantId`: The ID of your Entra tenant.
- `$thumbprint`: The thumbprint of the certificate used for authentication.
- `$allSites`: Set to `$true` if you want to process all sites or `$false` to process only sites listed in the input file.
- `$inputSitesCSV`: The path to the input file that contains a list of sites to process. This parameter is ignored if `$allSites` is set to `$true`.
- `$successLogFileLocation`: The location and name of the success log file. The log file will be timestamped with the script start time.
- `$errorLogFileLocation`: The location and name of the error log file. The log file will be timestamped with the script start time.
- `$enableVersioning`: Whether to enable or disable versioning. Note - there is no way to disable versioning natively in the UI but it an be disabled using PnP PowerShell via this script.
- `$versionType`: The version type to configure (when enableVersioning is `$true`). Accepted values are 'Major' or 'MajorMinor'.
- `$majorVersionLimit`: The limit of major versions to keep.
- `$minorVersionLimit`: The limit of minor versions to keep (if version type is set to `MajorMinor`).


You can modify these variables to fit your environment and requirements.

## Output

A sample csv showing the output of the scripts can be seen below. The EnableDisableVersioning.ps1 output is the same as the reporting script and is intended to be used to verify that versioning has been configured successfully. 

### GetLibraryVersioningInfo.ps1

| Type    | LogTime            | SiteUrl                   | LibraryTitle     | VersioningEnabled | VersionType | MajorVersionLimit | MinorVersionLimit |
|---------|--------------------|---------------------------|------------------|-------------------|-------------| -------------| -------------|
| Success | 12/07/2024  12:57:15| https://contoso.sharepoint.com/site1 | Documents     | TRUE              | Major       | 500 | 
| Success | 12/07/2024  12:57:15| https://contoso.sharepoint.com/site2 | Project Documents    | FALSE        | MinorMajor        | 500 | 20
| Success | 12/07/2024  12:57:15| https://contoso.sharepoint.com/site3 | Financial Reports| TRUE              | Major       | 500 | 
| Success | 12/07/2024  12:57:15| https://contoso.sharepoint.com/site4 | Policies         | TRUE              | MinorMajor  | 500 | 100
| Success | 12/07/2024  12:57:15| https://contoso.sharepoint.com/site5 | Meeting Slides   | FALSE             | Major        | 500 |

## Running the scripts

1. Set the value of the variables as per your environment (be sure to create the Entra AD App and generate the cert).
2. CD to the directory containing the script.
3. Execute the desired script.
4. Review the output files. 

## Important Notes
 
- EnableDisableVersioning.ps1 is primarily designed to ENABLE versioning, there is no native UI option to disable versioning but the script has been designed to disable versioning if you wish.
- Be sure to test the EnableDisableVersioning.ps1 script on a small number of SharePoint sites before executing across a tenant, especially when disabling versioning.
- Disabling versioning should not delete existing versions of files but some of the versioning settings on the library may be lost therefore it is important to test first.
