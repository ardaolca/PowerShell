param (
    [string] $ExecutionLogCsv
)

$id = get-random
$code = @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Diagnostics;

namespace PBIRS_DataRefreshAnalyzer$id
{
    public class OverlapDetector
    {
		public static List<string> result = new List<string>();
        public static List<string> Detect()
        {
            var elfile = @"$ExecutionLogCsv";
            var els = File.ReadAllLines(elfile).Skip(1).ToList();
            var reader = new StreamReader(elfile);
            var table = new Dictionary<string, List<Tuple<string, Guid, State>>>();
            string el;
            while((el = reader.ReadLine()) != null){
                var cols = el.Split(';');
                if (cols.Length > 10 && cols[4] == "Refresh Cache")
                {
                    new int[] { 8, 9 }.ToList().ForEach(i =>
                       {
                           if (!table.ContainsKey(cols[i]))
                           {
                               table.Add(cols[i], new List<Tuple<string, Guid, State>>());
                           }
                       });
                    var executionId = Guid.Parse(cols[3]);
                    var itemPath = cols[1];
                    var isError = cols[14] != "rsSuccess";
                    switch (cols[7])
                    {
                        case "ASModelStream":
                            table[cols[8]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.ASModelStreamStart));
                            table[cols[9]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.ASModelStreamEnd));
                            break;
                        case "DataRefresh":
                            table[cols[8]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.DataRefreshStart));
                            table[cols[9]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.DataRefreshEnd));
                            break;
                        case "SaveToCatalog":
                            table[cols[8]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.SaveToCatalogStart));
                            table[cols[9]].Add(new Tuple<string, Guid, State>(itemPath, executionId, isError ? State.Exception : State.SaveToCatalogEnd));
                            break;
                        default:
                            throw new NotImplementedException();
                    }
                }
            }
            reader.Close();

            var reports = els.Select(p => p.Split(new char[] { ';' }, 3)[1]).GroupBy(p => p).Select(p => p.Key).ToList();
            var reportDataRefreshState = new Dictionary<string, Dictionary<Guid,State>>();
            foreach (var r in reports)
            {
                reportDataRefreshState.Add(r, new Dictionary<Guid, State>());
            }

            //WriteLine("Time", "#ConcurrRefreshes", "ItemPath");
            var timeline = table.Keys.OrderBy(p => p).ToList();
            foreach(var time in timeline)
            {
                var events = table[time];
                foreach(var evt in events)
                {
                    var rdrs = reportDataRefreshState[evt.Item1];

                    if (evt.Item3 == State.SaveToCatalogEnd || evt.Item3 == State.Exception)
                    {
                        rdrs.Remove(evt.Item2);
                    }
                    else
                    {
                        if (!rdrs.ContainsKey(evt.Item2))
                        {
                            if (rdrs.Count > 0)
                            {
                                //Overlap
                                WriteLine(time, (rdrs.Count + 1).ToString(), evt.Item1);
                            }
                            rdrs.Add(evt.Item2, evt.Item3);
                        }
                        else
                        {
                            rdrs[evt.Item2] = evt.Item3;
                        }
                    }
                    
                }
            }

            return result;
        }

        public static void WriteLine(string time, string count, string itempath)
        {
			var line = time + "\t" + count + "\t" + itempath;
			result.Add(line);
            //Console.WriteLine(line);
        }
        public enum State
        {
            None = 0,
            ASModelStreamStart,
            ASModelStreamEnd,
            DataRefreshStart,
            DataRefreshEnd,
            SaveToCatalogStart,
            SaveToCatalogEnd,
            Exception
        }
    }


}

"@

$assembilies = ("System.IO","System.Collections","System","System.Linq")
Add-Type -TypeDefinition $code -Language CSharp -ReferencedAssemblies $assembilies
$result = invoke-expression "[PBIRS_DataRefreshAnalyzer$id.OverlapDetector]::Detect()"
$resultObj = $result | %{$cols=$_.split("`t"); $objhash = @{};  $objhash.time = $cols[0]; $objhash.count = $cols[1]; $objhash.itempath = $cols[2];  new-object -type PSCustomObject -Property $objhash}
$resultObj