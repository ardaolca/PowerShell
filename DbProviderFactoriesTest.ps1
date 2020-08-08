write-host -BackgroundColor Red "List of installed providers:"
[System.Data.Common.DbProviderFactories]::GetFactoryClasses()|ft|out-string -w 4444
 
write-host -BackgroundColor Red "Get Factory"
$f = [System.Data.Common.DbProviderFactories]::GetFactory("ODP.NET, Managed Driver")
 
write-host -BackgroundColor Red "Factory available methods"
$f|gm
 
write-host -BackgroundColor Red "Creating connection"
$c = $f.CreateConnection()
$c.ConnectionString = "Server=127.0.0.1;Port=5432;Database=*****;User Id=report_viewer;Password=******;"
$cmd = $c.CreateCommand()
$cmd.CommandText = "select 2"
 
 
$c.Open()
write-host -BackgroundColor Red "Connected"
 
write-host -BackgroundColor Red "Running query 'select 2'"
$v = $cmd.ExecuteScalar()
write-host -BackgroundColor red "Query is completed"
 
write-host -BackgroundColor Green -ForegroundColor Black "Result is: $v"
 
$c.Close()
write-host -BackgroundColor red "Connection Closed" 
