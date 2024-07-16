##############################################
# EnableDisableVersioning.ps1
# Alex Clark - aleclar@microsoft.com
#
#
##############################################
# Dependencies
##############################################

## Requires the following modules:
try {
    Import-Module Microsoft.Graph.Authentication
    Import-Module Microsoft.Graph.Sites
    Import-Module PnP.PowerShell
}
catch {
    Write-Error "Error importing modules required modules - $($Error[0].Exception.Message))"
    Exit
}


# Graph Permissions
# Sites.Read.All
# Sites.Manage.All

# SPO Permissions
# Sites.Read.All

##############################################
# Variables
##############################################

# Auth
$clientId = ""
$tenantId = ""
$thumbprint = ""

# Process all sites or only sites in the input file
$allSites = $false

# List of Sites to check (ignore if $allSites = $true)
$inputSitesCSV = "./SiteCollectionsList.txt"

# Enable or disable versioning
$enableVersioning = $true

# Version type (Major, MajorMinor)
$versionType = "MajorMinor"

# Major version limit
$majorVersionLimit = 10

# Minor version limit - only used if $versionType = "MajorMinor"
$minorVersionLimit = 10

# Log file location (timestamped with script start time)
$timeStamp = Get-Date -Format "yyyyMMddHHmmss"
$successLogFileLocation = "C:\EnableDisableVersioningSuccessLog-$timeStamp.csv"
$errorLogFileLocation = "C:\EnableDisableVersioningErrorLog-$timeStamp.csv"

##############################################
# Functions
##############################################

function ConnectToMSGraph {  
    try {
        Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateThumbprint $thumbprint
    }
    catch {
        Write-Host "Error connecting to MS Graph - $($Error[0].Exception.Message)" -ForegroundColor Red
        Exit
    }
}

function ConnectToPnP ($siteUrl) {
    try {
        Connect-PnPOnline -Url $siteUrl -ClientId $clientId -Tenant $tenantId -Thumbprint $thumbprint
    }
    catch {
        Write-Host "Error connecting to PnP" -ForegroundColor Red
    }
}

function ReadSitesFromTxtFile($siteListCSVFile) {
    $siteList = Get-Content $siteListCSVFile
    return $siteList
}

function Get-Sites {
    try {
        
        if (!$allSites) {
            $siteList = ReadSitesFromTxtFile($inputSitesCSV)
            $sites = Get-MgSite -Property "siteCollection,webUrl,id" -All | where { $siteList -contains $_.WebUrl } -ErrorAction Stop
            return $sites 
        }

        # Get all sites, filter out OneDrive sites
        $sites = Get-MgSite -Property "siteCollection,webUrl,id" -All | Where-Object { !($_.WebUrl.Contains("my.sharepoint.com")) } -ErrorAction Stop
        return $sites #| where {$_.WebUrl.Contains("/home")}
    }
    catch {
        Write-Host " Error getting sites" -ForegroundColor Red
    }   
}

function Get-AllSubsites ($site, $subsites) {
    Write-Host " Getting Subsites for: $($site.webUrl)..."

    # Add the site to the subsites array
    $subsites.Add($site) | Out-Null

    try {
        # Get the site's children
        $children = Get-MgSubSite -Property "siteCollection,webUrl,id" -SiteId $site.Id -All -ErrorAction Stop

        # Recursively get all subsites and their descendants
        foreach ($child in $children) {

            # Recursively get the subsite's descendants
            Get-AllSubsites -site $child -subsites $subsites
        }
    }
    catch {
        if ($Error[0].Exception.Message.Contains("Access to this site has been blocked")) {
            # Swallow the error - will be caught in next function
            return
        }
    } 
}

function Configure-Versioning($site, $library, $enableVersioning, $versionType) {
    try {
        if ($versionType -eq "MajorMinor") {
            Set-PnPList -Identity $library.Title -EnableVersioning $enableVersioning -EnableMinorVersions:$true -MajorVersions $majorVersionLimit -MinorVersions $minorVersionLimit -ErrorAction Stop
        }
        else {
            Set-PnPList -Identity $library.Title -EnableVersioning $enableVersioning -EnableMinorVersions:$false -ErrorAction Stop
        }

        if ($enableVersioning) {
            Write-Host "$($versionType) versioning " -NoNewline -ForegroundColor Yellow

            Write-Host "Enabled" -ForegroundColor Green -NoNewline
            
            Write-Host " for library $($library.Title)" -ForegroundColor Yellow
        }
        else {

            Write-Host "$($versionType) versioning " -NoNewline -ForegroundColor Yellow

            Write-Host "Disabled" -ForegroundColor DarkRed -NoNewline
            
            Write-Host " for library $($library.Title)" -ForegroundColor Yellow
        }

        Write-LogEntry -siteUrl $site.WebUrl -libraryTitle $library.Title -versioningEnabled $enableVersioning -versionType $versionType -minorVersionLimit $minorVersionLimit -majorVersionLimit $majorVersionLimit -type "Success"
    }
    catch {
        Write-Host "Error configuring versioning for library $($library.Title) - $($Error[0].Exception.Message)" -ForegroundColor Red
        Write-LogEntry -siteUrl $site.WebUrl -libraryTitle "" -versioningEnabled "" -versionType "" -minorVersionLimit "" -majorVersionLimit "" -type "Error"
    }
}

function Process-DocumentLibraries($site, $enableVersioning) {
    Write-Host "Getting document libraries for site $($site.WebUrl)" -ForegroundColor White

    try {

        ConnectToPnP($site.webUrl)

        $libraries = Get-PnPList | Where-Object { $_.BaseTemplate -eq 101 -and $_.Hidden -eq $false -and $_.Title -ne "Form Templates" -and $_.Title -ne "Site Assets" -and $_.Title -ne "Style Library" }

        foreach ($library in $libraries) {
            Write-Host "Found document library: $($library.Title)" -ForegroundColor Green

            Configure-Versioning -site $site -library $library -enableVersioning $enableVersioning -versionType $versionType
        }
    }
    catch {
        Write-Host "Error getting document libraries for site $($site.WebUrl)" -ForegroundColor Red
        Write-LogEntry -siteUrl $site.WebUrl -libraryTitle "" -versioningEnabled "" -versionType "" -minorVersionLimit "" -majorVersionLimit "" -type "Error"
    }
}


function Write-LogEntry($siteUrl, $libraryTitle, $versioningEnabled, $versionType, $type, $minorVersionLimit, $majorVersionLimit) {
    $logLine = New-Object -TypeName PSObject -Property @{
        Type              = $type
        LogTime           = Get-Date
        SiteUrl           = $siteUrl
        LibraryTitle      = $libraryTitle
        VersioningEnabled = $versioningEnabled
        VersionType       = $versionType
        MinorVersionLimit = $minorVersionLimit
        MajorVersionLimit = $majorVersionLimit
    }

    $orderedLogLine = $logLine | Select-Object -Property Type, LogTime, SiteUrl, LibraryTitle, VersioningEnabled, VersionType, MinorVersionLimit, MajorVersionLimit

    if ($type -eq "Success") {
        $orderedLogLine | Export-Csv -Path $successLogFileLocation -NoTypeInformation -Append
        return
    }

    $orderedLogLine | Export-Csv -Path $errorLogFileLocation -NoTypeInformation -Append
}

function Validate-Variables {
    if ($versionType -ne "Major" -and $versionType -ne "MajorMinor") {
        Write-Host "Invalid version type specified. Please specify either 'Major' or 'MajorMinor'" -ForegroundColor Red
        Exit
    }
    if($minorVersionLimit -lt 0 -or $majorVersionLimit -lt 0) {
        Write-Host "Invalid version limit specified. Please specify a positive integer" -ForegroundColor Red
        Exit
    }
    if (-not ($minorVersionLimit -is [int]) -or -not ($majorVersionLimit -is [int])) {
        Write-Host "Invalid version limit specified. Please specify the version limits as integers." -ForegroundColor Red
        Exit
    }
}

##############################################
# Main
##############################################

## Validate variables
Validate-Variables

## Connect to Mdestinationraph
ConnectToMSGraph

## Get all sites
$sites = Get-Sites 

## hold the log entries
$outputObjs = @()

## Clear the CSVs
$outputObjs | Export-Csv -Path $errorLogFileLocation -NoTypeInformation -Force
$outputObjs | Export-Csv -Path $successLogFileLocation -NoTypeInformation -Force

## Loop through sites
foreach ($site in $sites) {
    # Get all subsites and their descendants
    # Root site is added to the array of sites
    $subsites = New-Object System.Collections.ArrayList
    Get-AllSubsites -site $site -subsites $subsites

    foreach ($subsite in $subsites) {
        ## Process libraries
        Process-DocumentLibraries -site $subsite -enableVersioning $enableVersioning
    }
}

