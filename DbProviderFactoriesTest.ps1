param (
	[switch] $ShowAll = $true,
	[string] $DbProviderFactoryInvariantName,
	[string] $ScalarQuery="",
	[string] $ConnectionString=""
)

if ($ShowAll){
	write-host -BackgroundColor Red "List of installed providers:"
	([System.Data.Common.DbProviderFactories]::GetFactoryClasses()|ft|out-string -w 4444).split("`r`n")|?{$_.length -gt 0}|%{write-host "`t$($_)"}
}

if($DbProviderFactoryInvariantName.length -eq 0){
	write-host ""
	write-host "Example usages:"
	write-host '.\DbProviderFactoriesTest.ps1 -DbProviderFactoryInvariantName:"System.Data.SqlClient" -ConnectionString:"data source=sqlserver2016;user id=sa;password=P@ssw0rd" -ScalarQuery:"select 1 as id"'
	write-host '.\DbProviderFactoriesTest.ps1 -DbProviderFactoryInvariantName:"System.Data.SqlClient" -ConnectionString:"data source=sqlserver2016;user id=sa;password=P@ssw0rd"'
	write-host '.\DbProviderFactoriesTest.ps1 -DbProviderFactoryInvariantName:"System.Data.SqlClient"'
	exit
}

write-host -BackgroundColor Red "Get Factory"
$f = [System.Data.Common.DbProviderFactories]::GetFactory($DbProviderFactoryInvariantName)

if($f -eq $null){
	write-host -BackgroundColor Red "Db Provider factory can not be found: $($DbProviderFactoryInvariantName)"
	exit
}

write-host -BackgroundColor Red "Factory available methods"
($f|gm|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-host "`t$($_)"}

if($ConnectionString.length -eq 0){
	exit
}

write-host -BackgroundColor Red "Connecting..."
$c = $f.CreateConnection()
$c.ConnectionString = $ConnectionString
$c.Open()
write-host -BackgroundColor Red "Connected."

if($ScalarQuery.length -eq 0){
	write-host -BackgroundColor red "Closing connection..." 
	$c.Close()
	write-host -BackgroundColor red "Closed connection." 
	exit
}

write-host -BackgroundColor Red "Running scalar query $ScalarQuery..."
$cmd = $c.CreateCommand()
$cmd.CommandText = $ScalarQuery
$v = $cmd.ExecuteScalar()
write-host -BackgroundColor red "Query is completed."

write-host ""
write-host -BackgroundColor Green -ForegroundColor Black "Result is:"
write-host "$v"
write-host ""

write-host -BackgroundColor red "Closing connection..." 
$c.Close()
write-host -BackgroundColor red "Closed connection." 
