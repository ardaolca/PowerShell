$lastNdays = 21
$logs = "c:\logs\ms\" + (get-date).tostring("yyyyMMddhhmmss") + "-$(hostname)\"
New-item -type directory -force $logs -ErrorAction SilentlyContinue | out-null
get-service "powerbireportserver"|%{
	$instance=$_.name
	$displayname=$_.displayname
	$pathname = (get-wmiobject win32_service | ?{$_.displayname -eq $displayname}).pathname
	$pathname = $pathname.substring(1,$pathname.length-2)
	$loginstance = "$($logs)$instance`\";
	new-item -type directory -Force $loginstance -ErrorAction SilentlyContinue | out-null
	$rsfoldertokens = $pathname.split("`\");
	 
	$rsfoldertokens = $rsfoldertokens[0..$($rsfoldertokens.length-3)];
	$rspath = $rsfoldertokens -join "`\"
	$rspath += "\";
	Get-ChildItem -Path $rspath -include "*.ini","*.config","*.json" -exclude "__AssemblyInfo__.ini" -recurse | 
	%{ 
		$targetFileName = $loginstance + $_.FullName.replace($rspath,'').replace("`\",'_')
		copy-item $($_.FullName) $targetFileName 
	}
	New-item -type directory -force "$($loginstance)LogFiles" -ErrorAction SilentlyContinue | out-null
	get-childitem "$($rspath)LogFiles"|
			?{$_.CreationTime -gt (get-date).adddays(-1 * $lastNdays) -or $_.LastWriteTime -gt (get-date).adddays(-1 * $lastNdays)}|
			select -ExpandProperty FullName|
			copy-item -Destination "$($loginstance)LogFiles"
	get-childitem "$($rspath)LogFiles" > "$($logs)ListOfFilesUnderLogsFolder.txt"
	get-childitem "$($rspath)LogFiles\SQL*log"|select -ExpandProperty FullName|copy-item -Destination "$($loginstance)LogFiles" -Force -ea SilentlyContinue
	write-output "Done: $($rspath)"
}
write-output "Collecting Data..."


write-output "Collecting: PBIRS WMI Information..."
$computer = $env:COMPUTERNAME
$namespace = "ROOT\Microsoft\SqlServer\ReportServer\RS_PBIRS\V15"
$classname = "MSReportServer_Instance"
$wmi = Get-WmiObject -Class $classname -ComputerName $computer -Namespace $namespace
$wmi|fl > "$($logs)wmi-pbirs-instance.txt"

$namespace = "ROOT\Microsoft\SqlServer\ReportServer\RS_PBIRS\V15\Admin"
$classname = "MSReportServer_ConfigurationSetting"
$wmi = Get-WmiObject -Class $classname -ComputerName $computer -Namespace $namespace
$wmi|fl > "$($logs)wmi-pbirs-configurationsettings.txt"
write-output "Collected: PBIRS WMI Information."


write-output "Collecting: ALL RS related WMI Information..."
$wmiAllrsLog = "$($logs)wmi-all-rs-information.txt"
$rswmiNamespace = "ROOT\Microsoft\SqlServer\ReportServer"
$traverseList = new-object system.collections.stack
$traverseList.Push($rswmiNamespace)

while($traverseList.Count -gt 0){
	$ns = $traverseList.pop()
	write-output $ns  >> $wmiAllrsLog
	Get-WmiObject -Namespace $ns -list|?{
		$_.name -notlike "__*" -and $_.name -notlike "CIM_*" -and $_.name -notlike "MSFT_*"
	}|select -ExpandProperty Name|%{
		write-output "`tInstance: $_"  >> $wmiAllrsLog
		$wmi = Get-WmiObject -Class $_ -Namespace $ns
		($wmi|fl|out-string -w 4444).split("`r`n")|?{$_.length -gt 0 -and !$_.StartsWith("__")}|%{write-output "`t`t$_"  >> $wmiAllrsLog}
	}
	$sns = Get-WmiObject -Namespace $ns -class __namespace |select -ExpandProperty name
	$sns|%{$traverseList.push($ns + "\" + $_)}
}
write-output "Collected: ALL RS related WMI Information..."


ipconfig /all > "$($logs)ipconfig.txt"
gc c:\windows\system32\drivers\etc\hosts > "$($logs)hosts.txt"
hostname > "$($logs)hostname.txt"
ping $(hostname) /4 -n 1 > "$($logs)ping.txt"

write-output "Collecting: System event logs"
get-eventlog -logname system -After (get-date).adddays(-1 * $lastNdays)|fl > "$($logs)system-eventlogs-$(hostname).txt"
write-output "Collecting: Application event logs"
get-eventlog -logname application -After (get-date).adddays(-1 * $lastNdays)|fl > "$($logs)application-eventlogs-$(hostname).txt"
write-output "Collecting: Security event logs"
get-eventlog -logname security -After (get-date).adddays(-1 * $lastNdays)|fl > "$($logs)security-eventlogs-$(hostname).txt"
write-output "Collecting: Setupystem event logs"
Get-WinEvent -FilterHashtable @{logname = 'setup'}|fl > "$($logs)setup-eventlogs-$(hostname).txt"
	
write-host "Collecting: hotfix and application lists..."
#installed programs applications
$x = $null
$x = Get-WmiObject -Class Win32_Product
$x|convertto-html|out-string -Width 9999 > "$($logs)applications.html"
$x|convertto-json > "$($logs)applications.json"
	
#installed hotfix list
$x = $null
$x = get-wmiobject -class win32_quickfixengineering
$x|convertto-html|out-string -Width 9999 > "$($logs)hotfix.html"
$x|convertto-json > "$($logs)hotfix.json"	
write-output "Collected: hotfix and application lists."

$loadInfo = [Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices")
$server = New-Object Microsoft.AnalysisServices.Server
$server.connect("localhost:5132")
$Server.Databases|%{
	    $_|fl >> "$($logs)pbirs-as-databases.txt"
}

write-output "Compressing into an archive..."
$compressedFile = "$($logs.Substring(0,$logs.Length-1)).zip"
Compress-Archive -Path "$($logs)" -DestinationPath $compressedFile -CompressionLevel Optimal
write-host -backgroundcolor red "Upload this file   >>>   " -nonewline; 
write-host -foregroundcolor red "	$($compressedFile)"
explorer "$($logs)..\"