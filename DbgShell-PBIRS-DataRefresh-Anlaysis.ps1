$startTime = get-date

#DbgShell - Active Data Refreshes
$epsMT = !dumpheap -type EventProcessingService -stat | sls "EventProcessingService$" | %{$_.line.split(" ")[0] }
$epsAddress = !DumpHeap /d -mt $epsMT -short
$executingTasksAddress = !dumpobj /d $epsAddress | sls "_executingTasks$" | %{$_.line.split(" ")[-2]}
$tablesAddress = !dumpobj /d $executingTasksAddress | sls "m_tables$" | %{$_.line.split(" ")[-2]}
$bucketsAddress = !dumpobj /d $tablesAddress | sls "m_buckets$" | %{$_.line.split(" ")[-2]}
$etKvpAddresses = !dumparray /d $bucketsAddress | sls "^\[" | sls -notmatch "null$" | %{$_.line.split(" ")[-1] }
$taskAddresses = $etKvpAddresses | %{ !dumpobj /d $_ } | sls "m_value$" | %{$_.line.split(" ")[-2] }
$taskActionAddresses = $taskAddresses | %{ !dumpobj /d $_ } | sls "m_action$" | %{$_.line.split(" ")[-2] }
$taskActionTargetAddresses = $taskActionAddresses | %{ !dumpobj /d $_ } | sls "_target$" | %{$_.line.split(" ")[-2] }
$eventToProcessAddresses = $taskActionTargetAddresses | %{ !dumpobj /d $_ } | sls "eventToProcess$" | %{$_.line.split(" ")[-2] }
$subscriptionIdAddresses = $eventToProcessAddresses | %{ !dumpobj /d $_ } | sls "EventData" | %{$_.line.split(" ")[-2] }
$subscriptionIds = $subscriptionIdAddresses | %{ !dumpobj /d $_ } | sls "^String:" | %{$_.line.split(":")[1].trim() }


#DbgShell - Active Data refreshes - try to resolve ItemId (if available)
$asdrMT = !dumpheap -type AnalysisServicesDataRefresh | sls "AnalysisServicesDataRefresh$" | %{$_.line.split(" ",2)[0]}
$activeAndRecentDataRefreshes = !dumpheap /d -mt $asdrMT -short
$refreshInfoAddresses = $activeAndRecentDataRefreshes | %{ !dumpobj /d $_ } | sls "_refreshInfo$" | %{$_.line.split(" ")[-2]}
$subIdToItemId = @{}; $refreshInfoAddresses | %{ $cmdRes = !dumpobj /d $_; $iid=$cmdRes|sls CatalogItemId|%{$_.line.split(" ")[-2]}; $sid=$cmdRes|sls SubscriptionId|%{$_.line.split(" ")[-2]}; $sid = dt nt!_guid $sid; $iid = dt nt!_guid $iid;  $iid=$iid.tostring(); $sid=$sid.tostring();  if(!$subIdToItemId.containskey($sid)){ $subIdToItemId.Add($sid, $iid); } }



#DbgShell Report
write-output "Detailed Report:"
write-output "Active Data Refreshes: (Count,Name=SubscriptionId)"
($subscriptionIds|group|select count,name|sort count -descending|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-output "`t$($_)"}
write-output ""

write-output "Resolving report ItemId of active data refreshes:"
write-output "`tResolved? SubscriptionId ItemId"; 
$subscriptionIds | %{ if($subIdToItemId.containskey($_)){ write-output "`tMatch $($_) $($subIdToItemId[$_])"; }else{ write-output "`tNOMatch $($_) "; } }
write-output ""

write-output "Active Data Refreshes: (Count,Name=Report_ItemID"
($subscriptionIds|%{$x=@{}; $x.SubscriptionId = $_; $x.ItemId = $subIdToItemId[$_]; new-object psobject -Property $x}|group ItemId|select count,name|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-output "`t$($_)"}
write-output ""


#DbgShell Summary
Write-output "Summary Report:"
Write-output "Active Data Refresh Count: $($subscriptionIds.length)"
Write-output "There are $(($subscriptionIds|group|where count -gt 1|measure).count) overlapping DataRefresh in terms of individual schedules"
write-output "    These subscriptions have a total of $(($subscriptionIds|group|where count -gt 1|measure -sum count).sum) different data refreshes running at the same time."
Write-output ""

Write-output "There are $(($subscriptionIds|%{$x=@{}; $x.SubscriptionId = $_; $x.ItemId = $subIdToItemId[$_]; new-object psobject -Property $x}|group ItemId|where count -gt 1|measure).count) overlapping Report DataRefresh in terms of individual reports."
write-output "    These reports have a total of $(($subscriptionIds|%{$x=@{}; $x.SubscriptionId = $_; $x.ItemId = $subIdToItemId[$_]; new-object psobject -Property $x}|group ItemId|where count -gt 1|measure -sum count).sum) different data refreshes running at the same time."
Write-output ""

Write-output "Overlapping subscription Ids:"
($subscriptionIds|group|where count -gt 1|sort count -Descending|select count,name|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-output "`t$($_)"}

Write-output ""
Write-output "Overlapping report Ids:"
($subscriptionIds|%{$x=@{}; $x.SubscriptionId = $_; $x.ItemId = $subIdToItemId[$_]; new-object psobject -Property $x}|group ItemId|where count -gt 1|select count,name|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-output "`t$($_)"}

$endTime = get-date

write-output ""
write-output "Script was completed in $(($endTime-$startTime).totalseconds) seconds"