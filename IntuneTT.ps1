
<#PSScriptInfo

.VERSION 0.0.1

.GUID b135bd10-596c-43aa-87ce-e75436382ffe

.AUTHOR Will Hornsby

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

<#

.DESCRIPTION
 Entry point for the module

#>
$intunett = @"

    ____      __                 ____________
   /  _/___  / /___  ______  ___/_  __/_  __/
   / // __ \/ __/ / / / __ \/ _ \/ /   / /
 _/ // / / / /_/ /_/ / / / /  __/ /   / /
/___/_/ /_/\__/\__,_/_/ /_/\___/_/   /_/

"@

###################################
#   Create Folder Paths needed    #
###################################
$folders = @('Reports', 'Logs')
try {
    foreach ($folder in $folders) {
        New-Item -Path C:\Temp\IntuneTroubleshootingTool -Name $folder -ItemType Directory -Force
    }
}
catch {
    Write-Error $_.Exception.Message
}
#endRegion

########################
#   Import Functions   #
########################
try {
    Import-Module "$PSScriptRoot\IntuneTT.psm1"
}
catch {
    Write-Host "Failing to Import functions."
}

#####################
#   Menu Function   #
#####################
function Show-Menu {
    param (
        [string]$Title = 'Intune Troubleshooting Tools'
    )
    Clear-Host
    Write-Host $intunett -ForegroundColor Cyan
    Write-Host "================ $Title ================"
    Write-Host " "
    Write-Host "Press the corresponding number for each option below."
    Write-Host " "
    Write-Host "[e] Open Explorer to the WIntune File Location"
    Write-Host "[0] Authenticate with Microsoft Graph, Exchange Online and EntraId."
    Write-Host "[1] Get Autopilot (MDMDiagnostics) Report"
    Write-Host "[2] Search for Strings in the Intune Logs"
    Write-Host "[3] Parse the Intune logs for easier reading"
    Write-Host "[Q] Quit."
}
#endRegion

########################
#   Menu Entry Point   #
########################
do {
    Show-Menu
    Write-Host " "
    $choice = Read-Host "Please make a selection"
    switch ($choice) {
        "e" {
            Clear-Host
            Invoke-Item 'C:\Temp\IntuneTroubleshootingTool'
        }"0" {
            Clear-Host
            Connect-ToMGGraph
        }
        "1" {
            Clear-Host
            Get-MDMDiagnostics
        } "2" {
            Clear-Host
            Write-Host "Searching for Strings in logs, this should return file names which contain the string..." -ForegroundColor Yellow
            Write-Host " "
            $string = Read-host -Prompt "Enter the string you want to find.(add quotes around the string for spaces)"
            if ($string) {
                Write-Host " "
                Find-FileWithReferenceStrings -searchString $string
            }
            else {
                Write-Host "Please enter a valid string or any string" -ForegroundColor Red
            }
            Write-Host " "
            Write-Host "Take note of these, you can pass them into option 3 to parse the log file." -ForegroundColor Yellow
        } "3" {
            Clear-Host
            Write-Host "Maybe best to go make a brew, this can take a while...not found a quicker method yet" -ForegroundColor Cyan
            $fileToParse = Read-Host -Prompt "Enter the file path (include quotes for strigns with spaces)"
            if ($fileToParse) { ParseIMELogs -fileName $fileToParse | Out-GridView }
        }"q" {
            return
        }
        Default {}
    }
    Read-Host -Prompt "Take any notes required and press Enter to continue"
} until (
    $input -eq "q"
)
#endRegion
