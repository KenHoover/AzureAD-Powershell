# AzureAD-Powershell
Powershell stuff related to Azure AD (and probably some O365 mixed in)

Run-AzureADReport.ps1 : Uses GRAPH API to retrieve audit data from target AzureAD environment.

by Ken Hoover <ken.hoover@yale.edu> for Yale University

Parameters:

[ Required ] ReportName [String] - the name of the report you want.  These are case sensitive!

[ Required ] LookbackInterval [Integer 1-30 ]- how many days back in time you want to look for results (not all reports use this)

[ Optional ] ApplicationID [String] - required for some reports.  Ignored if the selected report doesn't need it.

Output: A list of objects, one object per entry in the returned list of event records.  This can be captured into a variable or piped to downstream cmdlets like convertto-CSV for further processing.

 Example: 

 Run the "auditEvents" report, looking for records within 10 days of right now.

 .\get-AzureADAuditeventsReport.ps1 -ReportName auditEvents -LookbackInterval 10
  
 Dependency:  Uses "AzureADReports.xml" to pull information on the available reports and their requirements for parameter checking.
