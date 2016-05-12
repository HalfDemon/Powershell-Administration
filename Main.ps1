<#
Much of this code is still from what I consider my 'legacy scripts'.
I am working on converting it to as pure powershell as possible and
then importing everything into my powershell profile. Everything in
here comes from some sort of need at work to at least partially
automate a, seriously, repetitive task such as installing java, or 
removing and rebuilding someones profile on a host. Some 'commandlets'
will accept further input beyond just a system name such as a 
filename to read multiple hostsnames out of to execute commands on.
#>


$app=$args[0]
$system=$args[1]
$type=$args[2]
function Check
{
	[CmdletBinding()]
	param ()
	$system = Read-Host -Prompt 'Destination System:'
	Write-Host If Output is null or empty please check hostname and try again
	Get-ADComputer -filter { name -like $system } | select DistinguishedName, Enabled, DNSHostName | Format-List
	$contest = Test-Connection -ComputerName $system -Count 2
	If ($contest -eq $null)
	{
		Write-Host Cannot reach $system
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
	param ()
	$system = Read-Host -Prompt 'Destination System:'
	set-location 'c:\staging\'
	write-host ("Copying Baseline to $system ")
	xcopy Baseline ("\\$system\C$\staged\Baseline\") /e /c /h /y /z
	set-location 'c:\scripts'
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