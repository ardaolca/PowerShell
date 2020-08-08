#Sharepoint Management Shell

New-item -itemType Directory -Force -Path C:\Logs
cd c:\logs
Get-SPLogLevel | ? {$_.defaulttraceseverity -ne $_.TraceSeverity -or $_.defaulteventseverity -ne $_.EventSeverity} | Export-Clixml nondefault-sploglevels.xml
Get-SPLogLevel | Export-Clixml all-sploglevels.xml
Set-sploglevel -traceseverity verboseex
$starttime = get-date

write-host -foregroundcolor green "Reproduce the issue and press any key to stop verbose logging"
pause "Press any key to disable verbose logging and collect ULS"

write-host -foregroundcolor green "Restore SP Log Levels to their earlier state"
Clear-sploglevel
import-Clixml .\nondefault-sploglevels.xml | % { $dll = $_; $ll = ($dll | get-sploglevel | ? { $_.Area.Name -eq $dll.Area.Name; }); $ll | set-sploglevel -traceseverity $dll.traceseverity.value -EventSeverity $dll.eventseverity.value; write-output "SPLogLevel Restored To ::: Trace:$($dll.traceseverity.value), Event:$($dll.eventseverity.value), Area:$($dll.area.name), Name:$($dll.name)" } > restore-sploglevels.log
write-host -foregroundcolor green "SP Log Levels were restored"

write-host -foregroundcolor green "Merging ULS between $($starttime) and $(get-date)"
Merge-SPLogFile -Path "C:\Logs\FarmMergedLog.log" -Overwrite -StartTime $starttime -EndTime (get-date)
write-host -foregroundcolor green "Completed check c:\Logs\FarmMergedLog.log"
