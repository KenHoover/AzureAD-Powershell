# Run-AzureADReport.ps1
#
# Uses GRAPH API to retrieve audit data from target AzureAD environment.
#
# by Ken Hoover <ken.hoover@yale.edu> for Yale University
#

# Parameters:
#
#  [ Required ] ReportName - the name of the report you want.  These are case sensitive!
#  [ Required ] LookbackInterval - how many days back in time you want to look for results (not all reports use this)
#  [ Optional ] ApplicationID - required for some reports.  Ignored if the selected report doesn't need it.
#
#
# Output: A list of objects, one object per entry in the returned list of event records
#
# Example: 

# Run the "auditEvents" report, looking for records within 10 days of right now.
#
# .\get-AzureADAuditeventsReport.ps1 -ReportName auditEvents -LookbackInterval 10
  
# Dependency:  Uses "AzureADReports.xml" to pull information on the available reports and their requirements for parameter checking.

#
# CHANGELOG (add notes on new changes above the initial version)
#
# kjh27    07-JUL-2016     Initial version


# IMPORTANT:  Application must be registered with AzureAD before this will work (that's where you get the client ID and secret)


param (
    [Parameter (mandatory=$true)][String]$ReportName,   # name of report to run
    [Parameter (mandatory=$true)][ValidateRange(1, 30)][string]$LookbackInterval, # How many days to look back (range of 1 to 30 accepted) 
    [Parameter (mandatory=$false)][String]$ApplicationID  # Application ID - required for some reports
)

# Verify that the report the user is requesting is one of the ones listed in the xml file (cheap-ass way to validate)
$reportslist = import-clixml .\AzureADReports.xml
$rlist = New-Object System.Collections.Hashtable
$reportslist | % { $rlist.Add($_.name, $_.LicenseRequired) }

if (!($rlist.ContainsKey($ReportName))) {
    write-warning "$ReportName is not one of the available reports.`nNote that report names are case sensitive."
    exit
}

if (((($reportslist| where {$_.name.equals($ReportName) }).ApplicationIDRequired).equals("True")) -and (!($ApplicationID))) 
{
     write-warning "Report $ReportName requires that an application ID be provided."
     exit
}

# Constants
$clientID       = "<PASTE YOUR CLIENT ID HERE>"         # CLIENT ID for application
$clientSecret   = "<PASTE YOUR CLIENT SECRET HERE>"     # KEY for application.
                                                                 # This is essentially a password so it should be moved to a secure store.

$tenantdomain   = "<PASTE YOUR AZUREAD INSTANCE HERE>"           # The target tenant's name (e.g. myschooledu.onmicrosoft.com)
$loginURL       = "https://login.microsoftonline.com"            # AAD Instance login URL, usually https://login.microsoftonline.com
$resource       = "https://graph.windows.net"                    # Azure AD Graph API resource URI

$lookbackcount = 0 - [System.Convert]::ToInt64($LookbackInterval)       # must be negative since we're going backwards in time.
$LookbackDays   = "{0:s}" -f (get-date).AddDays($lookbackcount) + "Z"   # looks like "2016-07-07T12:28:17Z"

Write-Verbose "Searching for events starting $LookbackDays"

# Create HTTP header, get an OAuth2 access token based on client id, secret and tenant domain
$body       = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
$oauth      = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body


# Parse report items, note that we sometimes need to make multiple pulls to get the whole result.
if ($oauth.access_token -ne $null) {   
    
    # build the URL for the request.  Need to generate this due to varying filter parameters among reports.
    if ((( $reportslist | where { $_.name -eq $reportName } ).filterString).equals("NoFilter")) {
        write-verbose "No filter for this report"
        $url = 'https://graph.windows.net/$tenantdomain/reports/' + $reportName + '?api-version=beta'
    } else {
        $filterParameter = ( $reportslist | where { $_.name -eq $reportName } ).filterString
        write-verbose "Using attribute name $filterParameter to filter by date"
        $url = 'https://graph.windows.net/$tenantdomain/reports/' + $reportName + '?api-version=beta&$filter=' + $filterParameter + ' gt ' + $LookbackDays
    }

    $headerParams = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

    # loop through each query page (1 through n)
    Do{
        # Write-Verbose "Fetching data using Uri: $url"
        $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url)
        foreach ($event in ($myReport.Content | ConvertFrom-Json).value) {
            $event  # output each object we got back in this pull
        }

        # Check if there's more data to pull
        $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'

    } while($url -ne $null)
} else {
    Write-Warning "ERROR: No Access Token"
}