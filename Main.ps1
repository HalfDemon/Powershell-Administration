<#
Much of this code is still from what I consider my 'legacy scripts'.
I am working on converting it to as pure powershell as possible and
then importing everything into my powershell profile. Everything in
here comes from some sort of need at work to at least partially
automate a, seriously, repetitive task such as installing java, or 
removing and rebuilding someones profile on a host. Some 'commandlets'
will accept further input beyond just a system name such as a 
filename to read multiple hostsnames out of to execute commands on.
Please note that this is VERY beta and is far from complete. Bad things
could very easily happen if you have no idea what you're doing.
#>

<#
Notes:
multi dc lookup, 
#>


$app=$args[0]
$system=$args[1]
$type=$args[2]
function Check
{
	[CmdletBinding()]
	param()
	$system = Read-Host -Prompt 'Destination System:'
	Write-Host If Output is null or empty please check hostname and try again
	Get-ADComputer -filter { name -like $system } | select DistinguishedName, Enabled, DNSHostName | Format-List
	$contest = Test-Connection -ComputerName $system -Count 2
	If ($contest -eq $null)
	{
		Write-Host Cannot reach $system
		Write-Host Performing lookup
		Write-Host ''
		nslookup $system
	}
	Else
	{
		gwmi win32_computersystem -comp $system | select Username
	}
}
function Install-Baseline
{
	[CmdletBinding()]
	param()
	$system = Read-Host -Prompt 'Destination System:'
	set-location 'c:\staging\'
	write-host ("Copying Baseline to $system ")
	xcopy Baseline ("\\$system\C$\staged\Baseline\") /e /c /h /y /z
	set-location 'c:\scripts'
	mstsc -v $system -f
}
function Get-AppVersion
{
	[CmdletBinding()]
	param ()
	$system = Read-Host -Prompt 'Destination System:'
	dir ("\\$system\C$\Program Files\Java\") >> C:\Logs\Version-$system.txt
	dir ("\\$system\C$\Program Files (X86)\Java\") >> C:\Logs\Version-$system.txt
	dir ("\\$system\C$\Program Files\") >> C:\Logs\Version-$system.txt
	dir ("\\$system\C$\Program Files (X86)\") >> C:\Logs\Version-$system.txt
	notepad C:\Logs\Version-$system.txt
}
function Get-Installed
{
	[CmdletBinding()]
	param ()
	$system = Read-Host -Prompt 'Destination System:'
	set-location 'c:\scripts\'
	.\psinfo -h -s \\$system > C:\logs\psinfo-$system.txt
	nano C:\logs\psinfo-$system.txt
}
function Get-UserSize
{
	[CmdletBinding()]
	param ()
	$system = Read-Host -Prompt 'Destination System:'
	$colItems = (get-childitem \\$system\C$\users\ -recurse | measure-object -property length -sum)
	"{0:N2}" -f ($colItems.sum / 1MB) + " MB"
}
function Install-Java
{
	[CmdletBinding()]
	param
	(
		$PMulti
	)
	$major = Read-Host -Prompt 'Java Major Revision:'
	$minor = Read-Host -Prompt 'Java Minor Revision'
	
	[int]$xMenuChoiceA = 0
	while ($xMenuChoiceA -lt 1 -or $xMenuChoiceA -gt 2)
	{
		Write-host "1. Single"
		Write-host "2. Multi"
		[Int]$xMenuChoiceA = read-host "Please enter an option 1 or 2"
	}
	Switch ($xMenuChoiceA)
	{
		1{Java-Single}
		2{Java-Multi}
		default {Java-Single}
	}
}
function Java-Single
{
	[CmdletBinding()]
	param ()
	
	$system = Read-Host -Prompt 'Destination System:'
	$major = Read-Host -Prompt 'Java Major Revision:'
	$minor = Read-Host -Prompt 'Java Minor Revision'
	set-location 'c:\staging\'
	write-host Java
	xcopy java ("\\$system\C$\staged\Java\") /e /c /h /y /z
	set-location 'c:\scripts\'
	.\psexec.exe \\$system -h -s c:\staged\java\jre$major-$minor-x86.exe /s
	.\psexec.exe \\$system -h -s c:\staged\java\jre$major-$minor-x64.exe /s
	echo f | .\psexec \\$system -h -s reg import "c:\staged\java\java.reg"
}
function Java-Multi
{
	[CmdletBinding()]
	param ()
	Write-Host 'Multiple Hosts will be targeted'
	$jMultiFile = Read-Host -Prompt 'File with hostnames:'
	foreach ($jHostname in Get-Content $jMultiFile )
	{
		set-location 'c:\staging\'
		write-host Java
		xcopy java ("\\$jHostname\C$\staged\Java\") /e /c /h /y /z
		set-location 'c:\scripts\'
		.\psexec.exe \\$jHostname -h -s c:\staged\java\jre$major-$minor-x86.exe /s
		.\psexec.exe \\$jHostname -h -s c:\staged\java\jre$major-$minor-x64.exe /s
		echo f | .\psexec \\$jHostname -h -s reg import "c:\staged\java\java.reg"
	}
}
function Assist
{
	[CmdletBinding()]
	param
	(
		$pComputer
	)
	#TODO: Place script here
	msra /offerra $pComputer
	
}
function Clean-Temp
{
	[CmdletBinding()]
	param
	()
	#TODO: Place script here
	[int]$xMenuChoiceA = 0
	while ($xMenuChoiceA -lt 1 -or $xMenuChoiceA -gt 2)
	{
		Write-host "1. Single"
		Write-host "2. Multi"
		[Int]$xMenuChoiceA = read-host "Please enter an option 1 or 2"
	}
	Switch ($xMenuChoiceA)
	{
		1{ Clean-Temp-Single }
		2{ Clean-Temp-Multi }
		default { Clean-Temp-Single }
	}
}
function Clean-Temp-Single
{
	[CmdletBinding()]
	param ()
	#TODO: Place script here
	$pComputer = Read-Host -Prompt 'Hostname:'
	.\psexec  -s -h \\$pComputer powershell -InputFormat None Remove-Item -Recurse -Force C:\Windows\Temp\*;
}
function Clean-Temp-Multi
{
	[CmdletBinding()]
	param ()
	#TODO: Place script here
	$pFile = Read-Host -Prompt 'Multi-Host FileName:'
	get-content $file | foreach-object {
		Write-Host ' '
		.\psexec  -s -h \\$_ powershell -InputFormat None Remove-Item -Recurse -Force C:\Windows\Temp\*
		##It's ugly but this section checks the exit code of PSEXEC, if it's anything other than 1 or 0 it sets it to fail.
		if ($LASTEXITCODE -ge '2')
		{
			$status = 'Fail'
		}
		if ($LASTEXITCODE -eq '1264')
		{
			$status = 'Auth Fail'
		}
		if ($LASTEXITCODE -eq '1')
		{
			$status = 'Success'
		}
		if ($LASTEXITCODE -eq '0')
		{
			$status = 'Success'
		}
		if ($LASTEXITCODE -eq '53')
		{
			$status = 'Admin$ Share'
		}
		echo "$_	$status 	$LASTEXITCODE" >> $file-result.csv
	}
}
function Test-RemoteConnectivity
{
	[CmdletBinding()]
	param()
	$pDestination = Read-Host -Prompt 'Destination Machine:'
	$pFile = Read-Host -Prompt 'Hoppping Point File:'
	$pResult = Read-Host -Prompt 'Result File:'
	$reach = 0
	write-host Checking remote networks for connectivity to $pDestination
	get-content $pfile | foreach-object {
		if (ping -n 2 -w 300 $_ | Select-String -pattern 'TTL')
		{
			if (.\psexec -h -s \\$_ ping -n 3 -w 300 $pDestination | select-string -pattern TTL)
			{
				write-host The network that $_ is on can reach $pDestination
				echo ("The network that $_ is on can reach $pDestination ") >> $pResult
				$reach++
			}
		}
	}
	
	write-host $reach networks can reach $pDestination >> $pResult
}
function Config-Service
{
	[CmdletBinding()]
	param ()
	#TODO: Place script here
	$action = Read-Host -Prompt 'Set Service as Automatic, Manual, Disabled:'
	$service = Read-Host -Prompt 'Service:'
	$system = Read-Host -Prompt 'Host:'
	write-host ("Setting StatupType of $service to $action on $system")
	if ($action -eq "Manual")
	{
		Set-Service -computername $system $service -StartupType $action
		(get-service -computername $system -name $service).Start()
	}
	if ($action -eq "Automatic")
	{
		Set-Service -computername $system $service -StartupType $action
		(get-service -computername $system -name $service).Start()
	}
	if ($action -eq "Disabled")
	{
		(get-service -computername $system -name $service).Stop()
		Set-Service -computername $system $service -StartupType $action
	}
	write-host ("Getting startup option of $service on $system")
	gwmi win32_service -computername $system | where { $_.Name -eq ("$service") }
}
