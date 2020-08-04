<#Param(
    [Parameter(Mandatory=$True)]
	[string]$svcAcct,
	
	[Parameter(Mandatory=$True)]
	[string]$pass
    )
#>
	
[string]$webroot = "D:\application"
[string]$OnesourceTaxPOOL = "application"
[string]$OnesourceTaxSite = "application"
rmdir $webroot -Recurse
mkdir $webroot
Copy-Item "C:\TeamCity\buildAgent\work\application\.build\temp\_PublishedWebsites\WebApplication\*" $webroot -Recurse
function Start-Throttle {
    Write-Host
    Write-Host
    Write-Host 'Start-Sleep'
    Write-Host (Get-Date)
    Start-Sleep -Seconds 2
    Write-Host (Get-Date)
    Write-Host
    Write-Host
    }

Function Start-ExecuteWithRetry {
    Param(
    [Parameter(Mandatory=$True)]
    $Command
    )

    $Command

    if ($LastExitCode -ne 0) { 
        Write-Host
        Write-Host "Failed with exit code:  $LastExitCode"
	    Start-Throttle 
        Write-Host "Retrying last command.  Attempt 1"
        $Command
	    } 

    if ($LastExitCode -ne 0) { 
        Write-Host
        Write-Host "Failed with exit code:  $LastExitCode"
	    Start-Throttle 
        Write-Host "Retrying last command.  Attempt 2"
        $Command
	    } 
    if ($LastExitCode -ne 0) { 
        Write-Host
        Write-Host "Failed with exit code:  $LastExitCode"
        }
    Write-Host
    Write-Host
    Remove-Variable Command
    }

function DeleteSite {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Site
        )
    Write-Host
    Write-Host "Deleting Site:  `"$Site`""
    $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe delete site "$Site"
    Start-ExecuteWithRetry -Command $TheCommand
	Remove-Variable TheCommand
	Write-Host
    }

function DeletePool {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Pool
        )
    Write-Host
    Write-Host "Deleting App Pool:  `"$Pool`""
    $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe delete apppool "$Pool"
    Start-ExecuteWithRetry -Command $TheCommand
	Remove-Variable TheCommand
	Write-Host
    }

function CreateDir {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$NewPath
        )
    if ( ! (test-path -pathtype container -Path "$NewPath")) {
        Write-Host "Creating Directory:  `"$NewPath`""
        New-Item -ItemType Directory -Path "$NewPath"
        }

        Write-Host
        Write-Host

    if ( ! (test-path -pathtype container -Path "$NewPath")) {
        Write-Host "FAIL - The following path is missing"
        Write-Host "$NewPath"
        }
        else {
        Write-Host "SUCCESS - FOUND - `"$NewPath`""
        }
    
        Write-Host
        Write-Host

    }

# Removing undesired Web Sites
foreach ($SiteName in (& $env:SystemRoot\system32\inetsrv\APPCMD.exe list sites /text:name)) {
    if ("$SiteName" -eq "$OnesourceTaxSite"){DeleteSite -Site "$SiteName"}
    }
#    if ("$SiteName" -eq "OneSourceFileService"){DeleteSite -Site "$SiteName"}


# Removing Undesired Pools
foreach ($AppPoolName in (& $env:SystemRoot\system32\inetsrv\APPCMD.exe list apppools /text:name)) {
    if ("$AppPoolName" -eq "$OnesourceTaxPOOL") {DeletePool -Pool "$AppPoolName"}
    }
#    if ("$AppPoolName" -eq "OneSourceFileService") {DeletePool -Pool "$AppPoolName"}


Write-Host
<#
Write-Host
& cmd /c pause.exe

#>
<#
**********************************************************************************************************************
Create Directory Structure and Populate with Code
**********************************************************************************************************************


Write-Host "Creating Directory Structure"

    CreateDir -NewPath "$webroot\$OnesourceTaxSite"
    CreateDir -NewPath "D:\Data\IIS\LogFiles\FailedReqLogFiles"

    Write-Host
    Write-Host



#>
<#
**********************************************************************************************************************
Set Directory Permissions
**********************************************************************************************************************
#>
<#

#Read and Execute
cmd.exe /c 'icacls.exe "D:\CWT" /grant:r "BUILTIN\IIS_IUSRS:(OI)(CI)(RX)"'
#cmd.exe /c 'icacls.exe "D:\CWT" /grant:r "$svcAcct:(OI)(CI)(RX)"'

#Print Permissions to the session
cmd.exe /c 'icacls.exe "D:\CWT"'


#Modify
cmd.exe /c 'icacls.exe "D:\CWT" /grant:r "BUILTIN\IIS_IUSRS:(OI)(CI)(M)"'
#>

<#
**********************************************************************************************************************
Create App Pools below
**********************************************************************************************************************
#>



Write-Host "Creating App Pool:  `"$OnesourceTaxPOOL`""
    $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe add apppool `
            /name:"$OnesourceTaxPOOL" `
            /enable32BitAppOnWin64:"true" `
            /managedRuntimeVersion:"v4.0" `
            /managedPipelineMode:"Integrated" `
            /processModel.identityType:ApplicationPoolIdentity
	Start-ExecuteWithRetry -Command $TheCommand
	Remove-Variable TheCommand
    Write-Host
    Write-Host



<#
**********************************************************************************************************************
Create Site below
**********************************************************************************************************************
#>



#Creating Site OneSourceTax
    Write-Host "Creating Site:  `"$OneSourceTaxSite`""
        $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe add site `
                /name:"$OneSourceTaxSite" `
                /bindings:"http/*:9411:" `
                /physicalPath:"$webroot" `
                /logfile.logExtFileFlags:"Date, Time, ClientIP, UserName, SiteName, ComputerName, ServerIP, Method, UriStem, UriQuery, HttpStatus, Win32Status, BytesSent, BytesRecv, TimeTaken, ServerPort, UserAgent, Cookie, Referer, ProtocolVersion, Host" `
                /logFile.directory:"D:\Data\IIS\LogFiles" `
                /traceFailedRequestsLogging.directory:"D:\Data\IIS\LogFiles\FailedReqLogFiles"
		Start-ExecuteWithRetry -Command $TheCommand
		Remove-Variable TheCommand
        Write-Host
        Write-Host

    #Assigning to app pool
    Write-Host "Assigning site to app pool"
        $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe set app `
            "$OneSourceTaxSite/" `
            /applicationPool:"$OneSourceTaxPOOL"
		Start-ExecuteWithRetry -Command $TheCommand
		Remove-Variable TheCommand
        Write-Host
        Write-Host
		
	#Set Anonymous Authentication to Application Pool Identity:  required for 2012 servers
   
    Write-Host "Set Anonymous Authentication Specific User"
        $TheCommand = & $env:SystemRoot\system32\inetsrv\APPCMD.exe set config `
        "$OneSourceTaxSite" `
        /section:anonymousAuthentication `
		/userName: `
        /commit:apphost
		Start-ExecuteWithRetry -Command $TheCommand
		Remove-Variable TheCommand
        Write-Host
        Write-Host
