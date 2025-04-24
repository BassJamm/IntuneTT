###########################################
#   Get Uninstall Strings from Registry   #
###########################################
function Get-UninstallStrings {
    <#
    .SYNOPSIS
    Will try to collect all uninstall strings from registry.
    .NOTES
    This will not output any applications that do not have a displayname.
    #>

    Begin {

        $applications = @()

        $registryKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
        )
    }
    Process {
        foreach ($key in $registryKeys) {

            $subKeys = Get-ChildItem $key
            $count = 0

            foreach ($subkey in $subKeys) {
                $count++

                Write-Progress -PercentComplete ($count / $subKeys.count * 100) `
                    -Status "Processing subkeys of $key" `
                    -Activity "Processing subkey $count of $($subKeys.Count)"

                $appInformation = Get-ItemProperty ( $subkey -replace "HKEY_LOCAL_MACHINE", "HKLM:" )

                if($appInformation.displayname){

                    $applications += [PSCustomObject]@{
                        Name            = $appInformation.displayname
                        Version         = $appInformation.DisplayVersion
                        InstallDate     = if ($appInformation.InstallDate) { [datetime]::ParseExact($appInformation.InstallDate, "yyyyMMdd", $null) } else { $appInformation.InstallDate }
                        UninstallString = $appInformation.UninstallString
                        MSIExecCommand  = if ($appInformation.UninstallString -match "MsiExec.exe") { "MSIExec.exe " + ($appInformation.UninstallString -replace '/I|/X', '/x ' -replace "MsiExec.exe", "") + " /NORESTART" } else { "N\A" }
                        Path            = $appInformation.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", ""
                    }
                }

            }

            Write-Progress -Activity "Processing subkeys" -Completed
        }
    }

    End {
        return $applications
    }
}
#endRegion

#######################################
#   Get Running Process information   #
#######################################
function Get-RunningProcessInfo {
    <#
    .SYNOPSIS
    Will search the running processes and return the ones matching the searched for string.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$searchString,
        [Parameter()]
        [switch]$outDefault
    )

    $gatheredProcesses = Get-CimInstance -ClassName Win32_Process | Where-Object {
        $_.name -match $searchString -or
        $_.CommandLine -match $searchString
    }

    $propertySplat = @(
        "ParentProcessId",
        "ProcessId",
        "ProcessName",
        "CreationDate",
        "CommandLine",
        @{n='WorkingSetSize(MB)'; e={($_.WorkingSetSize / 1MB)}}
    )
    if ($outDefault) {
        $gatheredProcesses | Select-Object -Property $propertySplat | Format-List
    }
}
#endRegion

######################################
#   Install-RequiredMGGraphModules   #
######################################
function Install-RequiredModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$InputValues
    )
    Begin {
        $requiredModules = @(
            "Microsoft.Graph.Authentication",
            "Microsoft.Graph.DeviceManagement",
            "Microsoft.Graph.Beta.Devices.CorporateManagement",
            "Microsoft.Graph.Beta.DeviceManagement",
            "Microsoft.Graph.Compliance",
            "Microsoft.Graph.Users",
            "Microsoft.Graph.Groups"
        )
    }
    Process {
        foreach ($module in $requiredModules) {
            if ( -not (Get-Module -Name $module -ErrorAction SilentlyContinue) ) {
                try {
                    Write-Host "Installing Module $module"
                    Install-Module -Name $module -Confirm:$false
                }
                catch {
                    $_
                }
            }
        }
    }
    End {
        return
    }
}
#endRegion

#############################
#   Collect MDM Diag Logs   #
#############################
function Get-AutopilotDiagnosticInfo {
    <#
    .SYNOPSIS
    Will collect the MDM Diag Logs and then parse them using the
    Get-AutopilotDiagnosticsCommunity script.
    #>
    Begin {
        $runTime = Get-Date -uFormat "%H-%M-%S"
        $outPutFilename = "mdmdiags-$runTime.txt"
        $diagFileName = "mdmdiags-$runTime.zip"
        $mdmDiagTool = "C:\windows\System32\MdmDiagnosticsTool.exe"
        $processArgs = "-area Autopilot -zip C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName"
    }
    Process {
        #	Collect Diagnostics   #
        Write-Output "Collecting Autopilot Diagnostics"
        Start-Process $mdmDiagTool -ArgumentList $processArgs -NoNewWindow -Wait
        Start-Sleep -Seconds 15

        if (Test-Path "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName") {
            Write-Output "Diagnostic Logs collected successfully"
        }
        else {
            Write-Output "Error collecting Diagnostic Logs, please try again."
            Return
        }
        #endRegion

        #	Download Community Script   #
        if (!(Get-InstalledScript Get-AutopilotDiagnosticsCommunity)) {
            try {
                Write-Output "Installing Get-AutopilotDiagnosticsCommunity script..."
                Install-Script -Name Get-AutopilotDiagnosticsCommunity -Force
                # Manually update path to save restarting session.
                $env:PATH += ";C:\Program Files\PowerShell\Scripts"
            }
            catch {
                Write-Output "Error Downloading Script."
                Return
            }
        }
        #endRegion

        #   Run the Script   #
        Write-Output "Exporting all data here, $outPutFilename"
        Get-AutopilotDiagnosticsCommunity.ps1 -ZIPFile "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName" -Online *>&1 | `
            Tee-Object -FilePath "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$outPutFilename"
        #endRegion
    }
    End {
        Write-Output "Completed Get-MDMDiagnostics flow"
        return
    }

}
#endRegion

######################
#   Parse IME Logs   #
######################
function ParseIMELogs {
    <#
    .SYNOPSIS
    Will attempt to parse the IME logs that you pass into it.
    .NOTES
    This does need teaking, MS have added new log files and some new formats.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $fileName
    )

    Begin {
        $pattern = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>[\d:.]+)" date="(?<Date>\d{1,2}-\d{1,2}-\d{4})"(?<Misc>.*?)>'
        $rawLogs = (Get-Content -Path $fileName -Raw) -join "`r`n"
        $matchedStrings = [regex]::Matches($rawLogs, $pattern)
        $nonMatchedStrings = [regex]::Matches($rawLogs, '^(?!.*$pattern).*')
        $matchedStringsArray = [System.Collections.Generic.List[PSCustomObject]]::new()
        $count = 0
    }

    Process {
        foreach ($string in $matchedStrings) {
            $count++
            Write-Progress -PercentComplete ($count / $matchedStrings.count * 100) `
                -Status "Processing Matches" `
                -Activity "Processing match $count of $($matchedStrings.Count)"

            $matchedStringsArray.Add([PSCustomObject]@{
                    Date    = $string.Groups["Date"].Value
                    Time    = $string.Groups["Time"].Value
                    Message = $string.Groups["Message"].Value
                    Misc    = $string.Groups["Misc"].Value
                })
        }
        Write-Progress -Activity "Processing Matches" -Completed
    }

    End {
        if ($nonMatchedStrings.count -gt 0) {
            $nonMatchedStrings | Export-csv -path "$env:temp\IMENonMatchedStrings.csv" -NoTypeInformation
            Write-Output "Non-matching strings exported to $env:temp\IMENonMatchedStrings.csv"
        }

        return $matchedStringsArray.ToArray()
    }
}
#endRegion

###################################
#   Search for Strings in Files   #
###################################
function Find-StringInFile {
    <#
    .SYNOPSIS
    Will find the files that contain the string you parse it.
    #>
    param(
        [string]$searchString,
        [string]$folderpath = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
    )

    (Get-ChildItem -Path $folderpath | Where-Object { -not $_.PSIsContainer }).FullName | ForEach-Object {
        $file = $_
        if ((Get-Content -Path $file | Select-String -SimpleMatch $searchString).Count -gt 0) {
            return $file
        }
    }
}
#endRegion

#############################
#   Get Win32 App Results   #
#############################

function Get-Win32AppReport {
    <#
    .SYNOPSIS
    Will attempt to install Get-Win32AppResults Script from PSGallery and run it.
    #>
    if (Get-InstalledScript -Name Get-Win32AppResult -ErrorAction SilentlyContinue) {
        Get-Win32AppResult.ps1
    }
    else {
        try {
            Write-Output "Installing Get-Win32AppResult.ps1, script from PSGallery, https://www.powershellgallery.com/packages/Get-Win32AppResult/"
            Install-Script -Name Get-Win32AppResult
            Write-Output "Run the command, Get-Win32AppReport, again after this install"
        }
        catch {
            $_
        }
    }

}
#endRegion

#################################
#   Check for pending Reboots   #
#################################
function Get-PendingReboot {
    <#
    .SYNOPSIS
    Will attempt to check for any pending reboots.
    #>
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    )

    $rebootRequired = $false

    foreach ($key in $keys) {
        if (Test-Path $key) {
            $properties = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            if ($properties -match "RebootPending|RebootRequired|PendingFileRenameOperations") {
                Write-Output "Reboot required due to: $key"
                $rebootRequired = $true
            }
        }
    }

    if (-not $rebootRequired) {
        Write-Output "No reboot required."
    }
}
#endregion

#################################
#   Get App Assignment Groups   #
#################################
function Get-AllIntuneAppAssignments {
    <#
    .SYNOPSIS
        Will attempt to install the Get-IntuneAppAssignments and run it.
    #>
    if (Get-InstalledScript -Name Get-IntuneAppAssignments -ErrorAction SilentlyContinue) {
        Get-IntuneAppAssignments
    }
    else {
        try {
            Write-Output "Installing script, Get-IntuneAppAssignments, from PSGallery, https://www.powershellgallery.com/packages/Get-IntuneAppAssignments"
            Install-Script -Name Get-IntuneAppAssignments
            Write-Output "Run the command, Get-IntuneAppAssignments, again after this install"
        }
        catch {
            $_
        }
    }
}
#endRegion

###################################
#   Check Attestation Readiness   #
###################################
function Get-AttestationReadiness {
    <#
    .SYNOPSIS
    Will attempt to run the Autopilottestattestation script created by RudyOoms.
    https://www.powershellgallery.com/packages/Autopilottestattestation/1.0.0.34
    #>

    Begin {
        $outPutFilename = "attestationtest-$(Get-Date -uFormat "%H-%M-%S").txt"

        #   Check and import the module   #
        if (!(Get-Module -ListAvailable -Name Autopilottestattestation -ErrorAction SilentlyContinue)) {
            Write-Host "Requred Module is not installed, installing now..." -ForegroundColor Yellow
            try {
                Install-Module -Name Autopilottestattestation -Scope CurrentUser
            }
            catch {
                $_
                return
            }
        }
    }
    Process {
        Write-Host "Executing attestattion testing command..." -ForegroundColor Yellow
        # No try catch due to deprecated wmic commands, seems to break the try-catch process even with exception handling.
        Test-AutopilotAttestation *>&1 | Tee-Object -FilePath "C:\Temp\Wintune\Reports\$outPutFilename"
    }
    End {
        Write-Host "Exported console output to C:\Temp\Wintune\Reports\$outPutFilename" -ForegroundColor Yellow
    }
}
#endRegion

###############################
#   Collect MDM Diagnostics   #
###############################
function Get-AllMDMDiagnosticInfo {
    <#
        .SYNOPSIS
        Will collect all of the MDM Diag Logs.
        #>
    Begin {
        $outputPath = "C:\Temp\IntuneTroubleshootingTool\MDMDiags\Diagnostics-$(Get-Date -uFormat "%H-%M-%S").zip"
        $mdmDiagTool = "C:\windows\System32\MdmDiagnosticsTool.exe"
        $processArgs = "-area `"DeviceEnrollment;DeviceProvisioning;ManagementService;PushNotification;WnsProvider;Autopilot`" -zip $outputPath"
    }
    Process {
        #	Collect Diagnostics   #
        Write-Output "Collecting Autopilot Diagnostics"
        Start-Process $mdmDiagTool -ArgumentList $processArgs -NoNewWindow -Wait
        Start-Sleep -Seconds 5

        if (Test-Path $outputPath) {
            Write-Output "Diagnostic Logs collected successfully"
        }
        else {
            Write-Output "Error collecting Diagnostic Logs, please try again."
            Return
        }
        #endRegion
    }
    End {
        Write-Output "Completed Get-MDMDiagnostics flow"
        return
    }
}
#endRegion

##########################################
#   Delete Win32App Keys from Registry   #
##########################################
function Remove-Win32AppKeys {
    <#
    .SYNOPSIS
    Will attempt to remove an app from the Win32App registry key paths, which forces the IME to update its status.
    This is akin to gpupdate for apps, essentially allowing you to force required and available apps to update their status.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$appId
    )

    Begin {
        # Define the base registry key path and initialize variables
        $win32AppKeys = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps
        $removeTheString = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\IntuneManagementExtension\\"
        $keysForDeletion = @()
        $propertiesForDeletion = @()
    }

    Process {
        # Iterate through each of the found registry keys
        foreach ($keyItem in $win32AppKeys) {
            $subkeys = Get-ChildItem -Path ($keyItem.PSPath -replace "Microsoft.PowerShell.Core\\", "") -Recurse

            foreach ($subkeyItem in $subkeys) {
                $currentKey = Split-Path $subkeyItem.Name -Leaf
                $getProperties = Get-ItemProperty ($subkeyItem.PSPath -replace "Microsoft.PowerShell.Core\\", "")
                $excludePSProperties = $getProperties.PSObject.Properties | Where-Object Name -notlike "PS*"

                # Check if the current key matches the appId
                if ($currentKey -like "$appId*") {
                    Write-Output "Found Key: $( $subkeyItem.Name -replace $removeTheString )"
                    $keysForDeletion += $subkeyItem.Name
                }
                # Check if any property names contain the appId
                elseif ($excludePSProperties.Name -contains $appId) {
                    Write-Output "Found property under: $( $subkeyItem.Name -replace $removeTheString )"
                    $propertiesForDeletion += [PSCustomObject]@{
                        Path = $subkeyItem.Name
                        Name = $appId
                    }
                }
            }
        }
    }

    End {
        # Confirm the deletion action with the user
        if ($PSCmdlet.ShouldProcess("Attempting to delete all references of the App ID, $appId, from the registry", $appId, "delete")) {

            $deletePrompt = Read-Host -Prompt "Happy to delete? (Y/N)"
            if ($deletePrompt -eq 'n') {
                Write-Output "Cancelling Delete operation"
                return
            }

            foreach ($keyItem in $keysForDeletion) {
                Remove-Item -Path ($keyItem -replace "HKEY_LOCAL_MACHINE", "HKLM:") -Confirm:$false -Recurse
            }

            foreach ($propItem in $propertiesForDeletion) {
                Remove-ItemProperty -Path ($propItem.Path -replace "HKEY_LOCAL_MACHINE", "HKLM:") -Name $propItem.Name
            }

            Write-Output "All references found have been deleted."
        }
    }
}
#endRegion
