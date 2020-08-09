param (
	[string] $webPortalUrl="",
	[string] $username="",
	[string] $password="",
	[switch] $deleteReports=$false,
	[switch] $downloadReports=$false,
	[string] $deletedReportArchiveLocation
)

<#
  
  R E A D   M E

#DO NOT run this script too frequently
#This script might cause performance issues
#You should first test it in your non-prod environment
#Scheduling a Windows Job and running this script as Local Administrator on PBIRS instance might cause you to create a security vulnerability. You need to satify security on your own. So that an attacker can change this script and mess up with your environment.
#>


#When this value is $false, import mode reports are identified and written to the disk, but they are not deleted
#When this value is $true, same happens but reports are also deleted. And if something goes wrong you will not be able to revert changes unless you have a database backup
# $deleteReports = $true

#When it is $true, import mode reports are downloaded to the file system
#>>>When $deleteReports is $true but $downloadReports is $false, script runs in Read Only Mode<<<
# $downloadReports = $true


#The Web portal URL
# $webPortalUrl = "http://localhost/PBIReports"

#It would be best to specify a shorter path.
#This path should NOT end with a back slash
# $deletedReportArchiveLocation = "c:\logs\importmode-reports"


#When $userName is null script uses default (current) user identity.
#Keeping the user name here as plain text is not recommended, please keep $username = $null
# [string]$userName = $null
# [string]$userPassword = $null
<# #Example:
[string]$userName = 'serverName\Administrator'
[string]$userPassword = 'P@ssword1!'
#>



#Not to reach MaxRequestPerUser limit in rsreportserver.config
#When this script is run in administrator on PBIRS server this value can be close to ZERO
#However making this value close to ZERO will also have a performance impact!
$operationDelayMs = 50




$apiUrl = "$($webPortalUrl)/api/v2.0"

$timestampStr = (get-date).tostring("HHmmss")
$deletedReportArchiveLocation += "\$((get-date).Year)\$((get-date).Month.ToString().PadLeft(2,"0"))\$((get-date).Day.ToString().PadLeft(2,"0"))\$($timestampStr)"
new-item -ItemType Directory -Path $deletedReportArchiveLocation -force -ea Stop | out-null
$logFile = "$($deletedReportArchiveLocation)\+operationlog.txt"


function OperationDelay{
    [System.Threading.Thread]::Sleep($operationDelayMs)
}
function LogInternal($log, $color, $intend){
    write-host -nonewline ("`t" * $intend)
    write-host -BackgroundColor $color $log -ForegroundColor Black
    (("`t" * $intend) + $log) >> $logFile
}
function Log($log = "", $i=0){
    LogInternal $log "Green" $i
}
function LogError($log, $i=0){
    LogInternal ">>>>ERROR: $($log)" "Red" $i
}
function LogWarning($log, $i=0){
    LogInternal ">>>>WARNING: $($log)" "Yellow" $i
}



Log "Run Time: $((get-date).tostring("yyyyMMdd HHmmss"))"
Log "Configuration:"
Log "Delete reports?"
if ($deleteReports -eq $true){
    Log "YES" 1 
}else{
    Log "NO" 1
}
Log "WEB PORTAL URL: $($webPortalUrl)"
Log "API URL: $($apiUrl)"
Log "Username is null?"
if ($username -eq $null){
    Log "YES" 1 
}else{
    Log "NO" 1
}
Log "OperationDelayMs: $($operationDelayMs)"
Log ""
Log ""



$credOject = $null
if($userName -eq $null){
    # Convert to SecureString
    [securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
    [pscredential]$credOject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
}


$importModeReports = $null
$ci = $null
$items = $null

if($credOject -eq $null){
    $ci = Invoke-WebRequest -Uri "$($apiUrl)/CatalogItems" -UseDefaultCredentials
}else{
    $ci = Invoke-WebRequest -Uri "$($apiUrl)/CatalogItems" -Credential $credOject
}

$items = ($ci.Content|convertfrom-json)."value"
$importModeReports = $items|where type -in @("PowerBIReport")|?{
    $item = $null
    $dataSourceUrl = $null
    $ds = $null
    $dsj = $null

    $item = $_;
    Log($item.id + " => " + $item.path)

    $dataSourceUrl = "$($apiUrl)/CatalogItems($($item.id))?&`$expand=DataSources"
    
    OperationDelay
    if($credOject -eq $null){
        $ds = Invoke-WebRequest -Uri $dataSourceUrl -UseDefaultCredentials
    }else{
        $ds = Invoke-WebRequest -Uri $dataSourceUrl -Credential $credOject
    }
    $dsj = ($ds.Content|ConvertFrom-Json)

    if($dsj.HasDataSources.Count -eq $true -and $dsj.DataSources[0].DataModelDataSource.Type -eq "Import"){
        LogWarning "$($item.path) is in import mode and marked as 'should be deleted'" 1
        $true   
    }else{
        $false
    }
}

Log ""
Log "List of reports to be deleted:"
$importModeReports|%{
    Log "$($_.id) => $($_.path)" 1
    Log "Created By $($_.CreatedBy)" 2
    Log "Modified By $($_.ModifiedBy)" 2
    Log "Report Size: $($_.size) bytes" 2
}

$downloadedImportModeReports = $null
if($downloadReports -eq $true){
    $downloadedImportModeReports = $importModeReports|?{
        $reportName = $null
        $reportFullPathOnDisk = $null
        $reportDownloadUrl = $null
        $response = $null

        $reportName = $_.name
        $reportFullPathOnDisk = $deletedReportArchiveLocation + $_.path.replace("/","\") + ".pbix"
        $reportFullParentPathOnDisk = Split-Path $reportFullPathOnDisk
        Log "Downloading report $($_.path)..."
        Log "Report Parent Folder: $($reportFullParentPathOnDisk)" 1
        Log "Report Full Path: $($reportFullPathOnDisk)" 1
    
    
        $reportDownloadUrl = $apiUrl + "/CatalogItems($($_.id))/Content/`$value"
        Log "Download URL $($reportDownloadUrl)" 1
    
        OperationDelay
        if($credOject -eq $null){
            $response = Invoke-WebRequest -Uri $reportDownloadUrl -Method Get -UseDefaultCredentials
        }else{
            $response = Invoke-WebRequest -Uri $reportDownloadUrl -Method Get -Credential $credOject
        }

    
        if($response -eq $null -or $response.StatusCode -ne 200){
            #$response|convertto-json
            LogError "Unable to download report. HTTP STATUS Code: $($response.StatusCode)" 1
            LogError "This report will not be deleted." 1
            LogError "$($error[0])" 2
            $false
        }else{
            Log "Fetched report $($_.path)." 1
            Log "Writing report to disk $($reportFullPathOnDisk)..." 1

            Log "Creating folder structure on disk $($reportFullParentPathOnDisk)" 1
            if (new-item -ItemType Directory -Force -Path $reportFullParentPathOnDisk -ea SilentlyContinue){
                Log "Folder structure is created." 1
                Log "Report is being written to the disk... ($($_.size) bytes)" 1
                Set-Content $reportFullPathOnDisk -Value $response.Content -Encoding Byte

                $r = test-path $reportFullPathOnDisk
                if ($r){
                    Log "Report was written to disk." 2
                }else{
                    Log "Report couldn't be written to disk." 2
                }
                $r
            }else{
                LogError "Unable to create the folder." 2
                LogError "$($error[0])" 2
                $false
            }
        }
    }
}

$deletedReports = @()
if($downloadReports -eq $true -and $deleteReports -eq $true){
    LogWarning "DeleteReports is true, deletion is starting..."
    
    $deletedReports = $downloadedImportModeReports|?{
        LogWarning "Deleting report: $($_.path)..." 1
        $deleteCatalogItemUrl = $null
        $response = $null

        $deleteCatalogItemUrl = $apiUrl + "/CatalogItems($($_.id))"
        Log "Delete URL: $deleteCatalogItemUrl" 1
        OperationDelay
        if($credOject -eq $null){
            $response = Invoke-WebRequest -Uri $deleteCatalogItemUrl -Method Delete -UseDefaultCredentials
        }else{
            $response = Invoke-WebRequest -Uri $deleteCatalogItemUrl -Method Delete -Credential $credOject
        }

        if($response -ne $null -and $response.StatusCode -eq 204){
            LogWarning "Report was deleted: $($_.path)." 2
            $deletedReportCount += 1
            $true
        }else{
            LogError "Unable to delete the report. HTTP STATUS Code: $($response.StatusCode)" 2
            LogError "$($error[0])" 2
            $false
        }
    }
}

$importModeReports|%{
    write-output "$($_.id) $($_.CreatedBy) $($_.ModifiedBy) $($_.path)"
} > "$($deletedReportArchiveLocation)\+1_ImportModeReportList.txt"

$downloadedImportModeReports|%{
    write-output "$($_.id) $($_.CreatedBy) $($_.ModifiedBy) $($_.path)"
} > "$($deletedReportArchiveLocation)\+2_DownloadedImportModeReportList.txt"

$deletedReports|%{
    write-output "$($_.id) $($_.CreatedBy) $($_.ModifiedBy) $($_.path)"
} > "$($deletedReportArchiveLocation)\+3_DeletedImportModeReportList.txt"


Log ""
Log "Summary"
LogWarning "$(($importModeReports|measure).Count) import mode reports were found."
LogWarning "$(($downloadedImportModeReports|measure).Count) import mode reports were written to disk."
LogWarning "$(($deletedReports|measure).Count) import mode reports were deleted."