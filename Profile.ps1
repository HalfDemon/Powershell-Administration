#Setup Reusable Functions
Function Cleanup{
    #Script Cleanup
    Write-Host Cleaning Up
    $Multi = $null
    $MultiV = $null
    $MultiReq = $null
    $System = $null
}
Function Copy-RemoteSystem{
    Set-Staging
    Write-Host Copying $cItem to $System 
    xcopy $cItem ("\\$System\C$\Staged\") /e /c /h /y /z
    Set-Home
}
Function Manage-Services{
if ( $act -eq "Restart" ){
    Stop-Service -InputObject $(Get-Service -ComputerName $System -Name $ServiceName)
    Start-Service -InputObject $(Get-Service -ComputerName $System -Name $ServiceName)
    }
if ( $act -eq "Stop" ){
    Stop-Service -InputObject $(Get-Service -ComputerName $System -Name $ServiceName)
    }
if ( $act -eq "Start" ){
    Start-Service -InputObject $(Get-Service -ComputerName $System -Name $ServiceName)
    }
}
Function MultiReq{
    #Set $Multi to null and then request filename for multiple or enter for single
    #if enter is hit without text it is left null and will return null when value is queried
    If ( $args[0] -eq $null ){
        Set-Variable -Name Multi -Value (Read-Host "Please enter multi filename") -Option Constant -Scope Global
    }
    ELSE{
        Set-Variable -name System -Value $args[0] -scope global
    }
    
}
Function PsExecExit{
    #A bit ugly but necessary
    #This function checks the psexec exit codes and writes them to a result file based on multi
    if ($LastPsExecCode -ge '2'){
        $Status = 'Fail'
    }
    if ($LastPsExecCode -eq '1264'){
        $Status = 'Auth Fail'
    }
    if ($LastPsExecCode -eq '1'){
        $Status = 'Success'
    }
    if ($LastPsExecCode -eq '0'){
        $Status = 'Success'
    }
    if ($LastPsExecCode -eq '53'){
        $Status -eq 'Admin$ Share'
    }
    echo "$System	$Status	$LastPsExecCode" >> $Multi-Result.csv
}
Function Set-Home{
Set-Location "C:\Scripts\"
}
Function Set-Staging{
Set-Location "C:\Staging\"
}
Function SysReq{
    #Requests system name from user as a function instead of rewriting each time
    If ( $args[0] -eq $null ){
        Set-Variable -name System -Value  (Read-Host "System Name") -Scope Global
    }
    ELSE{
        Set-Variable -name System -Value $args[0] -scope global
    }
}
Function TestCon{
    $test = Test-Connection -ComputerName $System -Count 2 -ErrorAction SilentlyContinue
    Return $test
}
#End Reusable Function Setup
#Setup Environment Variables
Set-Location "C:\Scripts\"
#End Env Variable Setup
#Begin Work Functions
Function Assist{
    SysReq $args[0]
    msra -offerra $System
}
Function Backup{
    INSERTBACKUPSCRIPTHERE
}
Function Check-Computer{
    SysReq $args[0]
    $System = $System
    Write-Host Destination System: $System
    Write-Host If output is null or empty please check the hostname and try again
    Get-ADComputer -filter { name -like $System } | Select DistinguishedName, Enabled, DNSHostName | Format-List
    If ( $TestCon -eq $null ){
        Write-Host Cannot Reach $System
        Write-Host Performing Lookup
        Write-Host ''
        nslookup $System
    }
    ELSE{
        gwmi win32_computersystem -comp $System | select Username
    }
}
Function Clean-Temp{
    SysReq $args[0]
    .\PsExec.exe -s -h \\$System powershell -InputFormat None Remove-Item -Recurse -Force C:\Windows\Temp\*;
}
Function Clean-TempLocal{
    Remove-Item -Recurse -Force C:\Windows\Temp\*
}
Function Clean-TempMulti{
    MultiReq $args[0]
    Get-Content $Multi | ForEach-Object {
        $System = $_
        .\PsExec.exe -s -h \\$System powershell -InputFormat None Remove-Item -Recurse -Force C:\Windows\Temp\*;
        $LastPsExecCode = $LASTEXITCODE
        PsExecExit
    }
    Cleanup
}
Function Expand-ZipFile{
    MultiReq
    $Destination = Read-Host 'Destination to unzip to'
    $shell = New-Object -com shell.application
    $zip = $shell.NameSpace($Multi)
    foreach($item in $zip.items())
    {
        $shell.Namespace($Destination).copyhere($item)
    }
}
Function Get-BitlockerRecoveryKey{
    SysReq $args[0]
    $computer = Get-ADComputer -Filter {Name -eq $System}
    $BitLockerObjects = Get-ADObject -Filter {objectclass -eq 'msFVE-RecoveryInformation'} -SearchBase $computer.DistinguishedName =Properties 'msFVE-RecoveryPassword'
    $BitLockerObjects | Select-Object @{N='Recovery Key ID';E={($_.DistinguishedName).Substring(29,36)}},msFVE-RecoveryPassword
}
Function Get-InstalledSoftware{
    SysReq $args[0]
    .\PsExec -s -h \\$System > $LogLocation\psinfo-Installed.log
    Nano $LogLocation\psinfo-Installed.log
}
Function Get-SMARTStatus{
    SMARTCOMMANDHERE
}
Function Install-Baseline{
    Set-Staging
    SysReq $args[0]
    $System = $System
    $cItem = "Baseline"
    Write-Host Copying Baseline to $System
    Copy-RemoteSystem
    Set-Home
    RDP $System
    Cleanup
}
Function Install-Java{
    SysReq $args[0]
    $cItem = 'Java'
    $Major = Read-Host 'Java Major Revision'
    $Minor = Read-Host 'Java Minor Revision'
    Copy-RemoteSystem
    .\PsExec.exe -s -h \\$System c:\Staged\jre$Major-$Minor-x86.exe /s
    .\PsExec.exe -s -h \\$System c:\Staged\jre$Major-$Minor-x64.exe /s
    echo f | .\PsExec.exe -s -h \\$System reg import "C:\Staged\Java.reg"
    Cleanup
}
Function Nano($File){
    Notepad $File
}
Function Open-AdminFileDialog{
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.InitialDirectory = 'C:\Scripts\Links\'
    $fd.Multiselect = $true
    $fd.ShowDialog()
    $fd.FileNames
}
Function RDP{
    SysReq $args[0]
    mstsc -v $System
}
Function Reset-Server{

}
Function Set-EventLogRetention{
    SysReq $args[0]
    wevtutil sl Application /rt:false /r:$System
}
Function Start-Server{
    
}
Function Stop-Server{

}
Function Sync-Image{
    Robocopy 'Image Source' C:\Staging\Images\Boot\ /e /z
}
Function Sync-Updates{
    Robocopy "C:\Staging\Image Updates" E:\Updates /mir
}