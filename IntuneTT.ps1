
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
    Write-Host $Wintune -ForegroundColor Cyan
    Write-Host "================ $Title ================"
    Write-Host " "
    Write-Host "Press the corresponding number for each option below."
    Write-Host " "
    Write-Host "[e] Open Explorer to the WIntune File Location"
    Write-Host "[0] Authenticate with Microsoft Graph, Exchange Online and EntraId."
    Write-Host "[1] Get Autopilot (MDMDiagnostics) Report"
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
            Invoke-Item 'C:\Temp\IntuneTroubleshootingTool'
        }"0"{
            Connect-ToMGGraph
        }
        "1" { 
            Get-MDMDiagnostics
        }"2" { 
            "Option 2"
        }"q" { 
            return
        }
        Default {}
    }
    Read-Host -Prompt "Press Enter to continue"
} until (
    $input -eq "q"
)
#endRegion