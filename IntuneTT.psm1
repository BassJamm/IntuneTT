
#################################
#   Auth with Microsoft Graph   #
#################################
function Connect-ToMGGraph {
    <#
    .SYNOPSIS
    Will check for correct modules and try to connect to graph ready for other commands to execute.
    #>
    Begin {
        #   Install Required Modules   #
        $requiredModules = @(
            "Microsoft.Graph.Authentication",
            "Microsoft.Graph.Beta.Devices.CorporateManagement",
            "Microsoft.Graph.Beta.DeviceManagement"
        )
        foreach ($module in $requiredModules) {
            if (!(Get-Module -ListAvailable -Name $module)) {
                try {
                    Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber
                }
                catch {
                    $_
                }
            }
            else {
                Write-Output "Module $module is already installed."
            }
        }
        #endregion

    }
    Process {
        #   Connect To Graph   #
        Start-Sleep -Seconds 2 # More pleasent experience for end user.
        if ($null -eq (Get-MgContext).Account) {
            Write-Output "Connecting to Graph now, a separate window should launch..."
            Connect-MgGraph -NoWelcome
        }
        #endRegion
    }
    End {
        Write-Output "You are connected!"
        Get-MgContext | Select-Object Account, @{ l = 'PermissionScopes'; e = { $_.Scopes -join "`n" } } | Format-List
        Start-Sleep -Seconds 2 # More pleasent experience for end user.
        return
    }

}
#endRegion

#############################
#   Collect MDM Diag Logs   #
#############################
function Get-MDMDiagnosticInfo {
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
                $env:PATH += ";C:\Program Files\PowerShell\Scripts" # Manually update path to save restarting session.
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
    if (Get-InstalledScript -Name Get-Win32AppResult) {
        Get-Win32AppResult.ps1
    }
    else {
        try {
            Install-Script -Name Get-Win32AppResult
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
function Get-WinAppAssignments {
    <#
    .SYNOPSIS
        Will attempt to install the Get-IntuneAppAssignments and run it.
    #>
    if (Get-InstalledScript -Name Get-IntuneAppAssignments -ErrorAction SilentlyContinue) {
        Get-IntuneAppAssignments
    }
    else {
        try {
            Install-Script -Name Get-IntuneAppAssignments
        }
        catch {
            $_
        }
    }
}
#endRegion

#################################################
#   Install Required Microsoft Graph Modules   #
#################################################
function Install-RequiredMGGraphModules {
    <#
        .SYNOPSIS
        Will attempt to install the modules required to run this module and the most used ones.
    #>

    $moduleList = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.DeviceManagement",
        "Microsoft.Graph.Beta.Devices.CorporateManagement",
        "Microsoft.Graph.Beta.DeviceManagement",
        "Microsoft.Graph.Compliance"
        "Microsoft.Graph.Users",
        "Microsoft.Graph.Groups"
    )

    Read-Host -Prompt "This will check for and install the required modules for the IntuneTT package... Press Enter to continue"
    $isPSGalleryTrusted = Read-Host -Prompt "Are you happy to mark the PSGallery a trusted repository? (Y/N) this removes the confirmation prompt for each install."

    switch ($isPSGalleryTrusted) {
        "Y" { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted }
        "N" { Write-Output "Gallery not trusted, confirm installation for each module" }
        Default {}
    }

    foreach($module in $moduleList){
        if(!(Get-installedModule $module -ErrorAction SilentlyContinue)){
            try {
                Write-Output "Trying to Install module. $module"
                Install-Module $module -Confirm:$false
            }
            catch {
                $_
            }
        }
        Write-Output "$module already installed"
    }
}
#endRegion