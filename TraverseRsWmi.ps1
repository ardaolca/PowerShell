$rswmiNamespace = "ROOT\Microsoft\SqlServer\ReportServer"
$traverseList = new-object system.collections.stack
$traverseList.Push($rswmiNamespace)

while($traverseList.Count -gt 0){
	$ns = $traverseList.pop()
	write-output $ns
	Get-WmiObject -Namespace $ns -list|?{
		$_.name -notlike "__*" -and $_.name -notlike "CIM_*" -and $_.name -notlike "MSFT_*"
	}|select -ExpandProperty Name|%{
		write-output "`tInstance: $_";
		$wmi = Get-WmiObject -Class $_ -Namespace $ns
		($wmi|fl|out-string -w 4444).split("`r`n")|?{$_.length -gt 0 -and !$_.StartsWith("__")}|%{write-output "`t`t$_"}
	}
	$sns = Get-WmiObject -Namespace $ns -class __namespace |select -ExpandProperty name
	$sns|%{$traverseList.push($ns + "\" + $_)}
}
