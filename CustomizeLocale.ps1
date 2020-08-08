param (
    [switch] $Help = $false,
    [switch] $Details = $false,
	[string] $TargetLocale,
    [string] $Property="",
    [string] $PropertyNewValue="",
	[parameter(DontShow)] [switch] $SpawnNewProcess=$true  #For internal use, do not change
)

$scriptPath = $MyInvocation.MyCommand.Source
$scriptName = $MyInvocation.MyCommand.Name


if($Help -or ($TargetLocale.length -eq 0)){
	write-host 'Overrides specific culture setting for a given language. '
	write-host 'This creates an NLP file under c:\windows\globalization\ folder with the following pattern: {locale}.nlp'
	write-host 'Example for pl-pl, it creates pl-pl.nlp'
	write-host ''
	write-host 'After this change, existing process should be restarted, otherwise it continues to read old value'
	write-host ''
	write-host 'This change is machine wide!!!'
	write-host ''
	
	write-host ".\$($scriptName) -Help:$false -Details:$true -TargetLocale:en-US  -Property:NumberFormat.NumberDecimalSeparator -PropertyNewValue:,"
	write-host '-Help:  $true or $false, default value is $false'
	write-host '-Details:  $true or $false, default value is $false'
	write-host '-TargetLocale:  Name of a Locale (CultureInfo), pl-PL, en-US etc'
	write-host '-Property:  The property that will be overridden'
	write-host '            Examples:'
	write-host '            GregorianDateTimeFormat.ShortDatePattern'
	write-host '            GregorianDateTimeFormat.FullDateTimePattern'
	write-host '            NumberFormat.NumberDecimalSeparator'
	write-host ''
	write-host "     Know that some of the values are ready only and can't be overridden."
	write-host ''
	
	write-host '-PropertyNewValue:   When this parameter has a value, given property is set to this value'
	write-host '                     When this parameter is not specified, script shows current value of the given property'
	write-host '                     Examples:'
	write-host '                     For ShortDatePattern, this value can be yyyy-MM-dd'
	write-host '                     For NumberDecimalSeparator, this value can be comma or dot'
	write-host ''
	
	write-host ".\$($scriptName) -Help:`$true"
	write-host "   Shows this menu"
	write-host ''
	
	write-host ".\$($scriptName) -TargetLocale:`"pl-pl`""
	write-host "   Loads pl-pl locale and show all of its properties"
	write-host ''
	
	write-host ".\$($scriptName) -TargetLocale:`"pl-pl`" -Details:`$true"
	write-host "   Loads pl-pl locale and show all of its properties"
	write-host ''
	
	write-host ".\$($scriptName) -TargetLocale:`"pl-pl`" -Property:`"GregorianDateTimeFormat.ShortDatePattern`""
	write-host '   Loads pl-pl locale and show current value of the given property: GregorianDateTimeFormat.ShortDatePattern'
	write-host ''
	
	write-host ".\$($scriptName) -TargetLocale:`"pl-pl`" -Property:`"GregorianDateTimeFormat.ShortDatePattern`" -PropertyNewValue:`"yyyy-MM-dd`""
	write-host '   Loads pl-pl locale, and sets the pattern of the given property to the desired value'
	write-host '   Sets GregorianDateTimeFormat.ShortDatePattern to yyyy-MM-dd'
	write-host ''
	
	write-host ".\$($scriptName) -TargetLocale:`"pl-pl`" -Property:`"NumberFormat.NumberDecimalSeparator`" -PropertyNewValue:`".`""
	write-host '   Loads pl-pl locale, and sets the pattern of the given property to the desired value'
	write-host '   Sets NumberFormat.NumberDecimalSeparator to DOT (.)'
	write-host ''

	exit
}

if($SpawnNewProcess){
	powershell.exe -noprofile $($scriptPath) -TargetLocale:$TargetLocale -Details:`$$Details -Property:$Property -SpawnNewProcess:`$false -PropertyNewValue:$PropertyNewValue
	exit
}

if($TargetLocale.length -gt 0){
	Add-Type -AssemblyName sysglobl
	$cribClass = [System.Globalization.CultureAndRegionInfoBuilder]
	$crmReplacement = [System.Globalization.CultureAndRegionModifiers]::Replacement
	$crib = $cribClass::new($TargetLocale, $crmReplacement)
	
	write-host ''
	write-host -foregroundcolor green "TargetLocale is $($TargetLocale)"
	([system.globalization.cultureinfo]::new($TargetLocale)|out-string).split("`r`n")|?{$_.length -gt 0}|%{write-host -nonewline -foregroundcolor green "`t$($_)"}
	write-host ''
}

if($Details){
	write-host "Current Settings:" -backgroundcolor red
	write-host "General" -backgroundcolor blue
	($crib|out-string).split("`r`n")|?{$_.length -gt 0}|%{"`t$($_)"}

	write-host "`tAvailableCalendars" -backgroundcolor blue
	($crib.AvailableCalendars|out-string).split("`r`n")|?{$_.length -gt 0}|%{"`t`t$($_)"}

	write-host "`tNumberFormat" -backgroundcolor blue
	($crib.NumberFormat|out-string).split("`r`n")|?{$_.length -gt 0}|%{"`t`t$($_)"}

	write-host "`tGregorianDateTimeFormat" -backgroundcolor blue
	($crib.GregorianDateTimeFormat|out-string).split("`r`n")|?{$_.length -gt 0}|%{"`t`t$($_)"}
	
	write-host "`tTextInfo" -backgroundcolor blue
	($crib.TextInfo|out-string).split("`r`n")|?{$_.length -gt 0}|%{"`t`t$($_)"}
}

if($property.length -gt 0){
	$cribProperty = $crib;
	$propertyTokens = $property.split(".")
	for($i=0;$i -lt $propertyTokens.Length ; $i++){
		$cribProperty = $cribProperty."$($propertyTokens[$i])"
	}

	write-host -backgroundcolor red "Current value of $($property) is $($cribProperty)"
}

if($propertyNewValue.length -gt 0){
	write-host -backgroundcolor cyan -foregroundcolor black "New value of $($property) is $($propertyNewValue)"
	if(test-path "c:\windows\globalization\$($TargetLocale).nlp"){
		write-host -foregroundcolor green "`tUnregistered: There is already an NLP file, it is unregistered automatically"
		$cribClass::Unregister($TargetLocale)
	}
	
	$cribPropertyParent = $crib;
	$propertyTokens = $property.split(".")
	for($i=0;$i -lt $propertyTokens.Length-1 ; $i++){
		$cribPropertyParent = $cribPropertyParent."$($propertyTokens[$i])"
	}
	$cribPropertyParent."$($propertyTokens[$propertyTokens.length-1])" = $propertyNewValue
	$crib.Register()
	
	write-host -foregroundcolor green "`tRegistered"
	
	powershell.exe -noprofile $($scriptPath) -TargetLocale:$TargetLocale -Property:$Property -SpawnNewProcess:`$false
}



