param (
	[switch] $Help=$false,
	[switch] $ShowInGridView = $true,
	[string] $WebPortalUrl="",
	[string] $Username="",
	[string] $Password="",
	[string] $CsvOutput=""
)

if($Help){
	write-host 'Example usages:'
	write-host '.\ExtractDataSources.ps1 -ShowInGridView:$true -CsvOutput:"c:\logs\DataSources.csv" -WebPortalUrl:"http://localhost/PBIReports" -Username:"Administrator" -Password:"P@ssw0rd!"'
	write-host '	  Uses username and password to connect Web Portal REST API'
	write-host '	  Traverse all items and finds all the data sources'
	write-host '	  Shows them inside a GridView'
	write-host '	  Export them into a CSV file: c:\logs\DataSources.csv'
	write-host ''
	write-host '.\ExtractDataSources.ps1 -ShowInGridView:$true -CsvOutput:"c:\logs\DataSources.csv" -WebPortalUrl:"http://localhost/PBIReports"'
	write-host '	  Uses current credentials/identity to connect Web Portal REST API'
	write-host '	  Traverse all items and finds all the data sources'
	write-host '	  Shows them inside a GridView'
	write-host '	  Export them into a CSV file: c:\logs\DataSources.csv'
	write-host ''
	write-host '.\ExtractDataSources.ps1 -ShowInGridView:$true -WebPortalUrl:"http://localhost/PBIReports"'
	write-host '	  Uses current credentials/identity to connect Web Portal REST API'
	write-host '	  Traverse all items and finds all the data sources'
	write-host '	  Shows them inside a GridView'	
	write-host ''
	exit
}


function Log($log){
	write-host -BackgroundColor red $log
}

$apiUrl = "$($WebPortalUrl)/api/v2.0"

if($Password.length -eq 0){
	$credOject = $null
}else{
	# Convert to SecureString
	[securestring]$secStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
	[pscredential]$credOject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
}

$catalogItemsUrl = "$($apiUrl)/CatalogItems"
if($credOject -eq $null){
	$ci = Invoke-WebRequest -Uri $catalogItemsUrl -UseDefaultCredentials
}else{
	$ci = Invoke-WebRequest -Uri $catalogItemsUrl -Credential $credOject
}

$items = ($ci.Content|convertfrom-json)."value"
$result = $items|where type -in @("PowerBIReport","Report","DataSource")|%{
	$dataSourceItem = @{}
	$item = $_;
	Log($item.path)

	$expand = "Properties"
	if($item.type -ne "DataSource"){
		$expand = "DataSources," + $expand
	}
	#Log($expand)

	$dataSourceUrl = "$($apiUrl)/CatalogItems(Path=%27$($item.path)%27)?&`$expand=$($expand)"
	#Log($dataSourceUrl)
	
	if($credOject -eq $null){
		$ds = Invoke-WebRequest -Uri $dataSourceUrl -UseDefaultCredentials
	}else{
		$ds = Invoke-WebRequest -Uri $dataSourceUrl -Credential $credOject
	}
	$dsj = ($ds.Content|ConvertFrom-Json)

	if($item.type -ne "DataSource"){
		$dsj = $dsj.DataSources
	}

	$dsj|%{
		$_dsj = $_
		#Log($($_|measure|out-string))

		#Item related properties
		$dataSourceItem.ItemId = $item.id
		$dataSourceItem.ItemName = $item.name
		$dataSourceItem.ItemPath = $item.path
		$dataSourceItem.ItemType = $item.type

		
		$dataSourceItem.DataSourceId = $_dsj.Id
		$dataSourceItem.DataSourceName = $_dsj.Name
		$dataSourceItem.ConnectionString = $_dsj.ConnectionString
		$dataSourceItem.CredentialRetrieval = $_dsj.CredentialRetrieval
		$dataSourceItem.IsEnabled = $_dsj.IsEnabled
		$dataSourceItem.IsOriginalConnectionStringExpressionBased = $_dsj.IsOriginalConnectionStringExpressionBased
		$dataSourceItem.CredentialsByUser = $_dsj.CredentialsByUser
		$dataSourceItem.CredentialsInServer = $_dsj.CredentialsInServer
		$dataSourceItem.ReferenceToSharedDataSource = $false

		if($item.type -eq "PowerBIReport"){
			$dataSourceItem.DataSourceType = "PowerBIReport-" + $_dsj.DataModelDataSource.Type
			$dataSourceItem.AuthType = $_dsj.DataModelDataSource.AuthType
			$dataSourceItem.TargetDatabaseType = $_dsj.DataModelDataSource.Kind
			$dataSourceItem.DataSourceName = "PowerBIReport-DataSource"
			$dataSourceItem.CredentialRetrieval = "N/A"

			#Log($($_dsj|fl|out-string))
		}else{
			$dataSourceItem.AuthType = $_dsj.CredentialRetrieval
			$dataSourceItem.TargetDatabaseType = $_dsj.DataSourceType

			if ($item.type -eq "Report"){
				if($_dsj.IsReference -eq "True"){
					$dataSourceItem.ReferenceToSharedDataSource = $true
				}
				$dataSourceItem.DataSourceType = "PaginatedReportEmbeddedDataSource"
			}elseif ($item.type -eq "DataSource"){
				$dataSourceItem.DataSourceType = "SharedDataSource"
			}

			
			if($_dsj.CredentialsInServer -ne $null){
				#Log($_dsj.CredentialsInServer.UseAsWindowsCredentials)
				if ($_dsj.CredentialsInServer.UseAsWindowsCredentials -eq $true){
					$dataSourceItem.AuthType = "Windows"
				}else{
					$dataSourceItem.AuthType = "SQL"
				}
			}elseif($_dsj.CredentialsByUser -ne $null){
				#write-host $_dsj.CredentialsByUser.UseAsWindowsCredentials
				if ($_dsj.CredentialsByUser.UseAsWindowsCredentials -eq $true){
					$dataSourceItem.AuthType = "Windows"
				}else{
					$dataSourceItem.AuthType = "SQL"
				}
			}

			if($_dsj.CredentialRetrieval -eq "integrated"){
				$dataSourceItem.AuthType = "Integrated"
			}
		}
		
		
		new-object psobject -Property $dataSourceItem

		
	}
	#Log($($dsj.datasources|out-string))
}

$removeUnnecessaryColumns = @("ReferenceToSharedDataSource","IsOriginalConnectionStringExpressionBased", "CredentialsByUser", "CredentialsInServer")
$result = $result|where ReferenceToSharedDataSource -eq $false|%{
	foreach($unnecessaryColumn in $removeUnnecessaryColumns){
		$_.psobject.properties.remove($unnecessaryColumn)
	}
	$_
}

#Add new column, TargetDatabaseServer
#Try to parse connection string for each Data Source type
#Different databases can have different syntax
$result = $result|%{
	$_|add-member -MemberType NoteProperty -Name "TargetDatabaseServer" -value ""
	$_
}
$result|%{
	if($_.DataSourceType -eq "PowerBIReport-Import"){
		if($_.targetdatabasetype -in @("SQL","OLEDB-MD")){
			$cstokens = $_.connectionstring.split(";")
			$_.targetdatabaseserver = $cstokens[0]
		}elseif($_.targetdatabasetype -in @("SQL","OLEDB-MD")){
			#More code for impala connection string manipulation
		}
		
	}else{
		if($_.targetdatabasetype -in @("SQL","OLEDB-MD")){
			$_.targetdatabaseserver = ($_.connectionstring.split(";")|?{$_.split("=")[0].trim().tolower() -eq "data source"}).split("=")[1]
		}elseif($_.targetdatabasetype -in @("SQL","OLEDB-MD")){
			#More code for impala connection string manipulation
		}
	}

}

if($ShowInGridView){
	$result|Out-GridView
}

if($CsvOutput.length -gt 0){
	$result|ConvertTo-Csv -Delimiter ","|select -skip 1 > "$($CsvOutput)"
}