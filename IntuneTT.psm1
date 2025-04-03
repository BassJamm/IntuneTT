#################################
#   Auth with Microsoft Graph   #
#################################
function Connect-ToMGGraph {
    Begin {
        ################################
        #   Install Required Modules   #
        ################################
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
        ########################
        #   Connect To Graph   #
        ########################
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
    Begin {
        $runTime = Get-Date -uFormat "%H-%M-%S"
        $outPutFilename = "mdmdiags-$runTime.txt"
        $diagFileName = "mdmdiags-$runTime.zip"
        $mdmDiagTool = "C:\windows\System32\MdmDiagnosticsTool.exe"
        $processArgs = "-area Autopilot -zip C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName"
    }
    Process {
        ###########################
        #	Collect Diagnostics   #
        ###########################

        # Collect diag logs
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

        #################################
        #	Download Community Script   #
        #################################
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

        ######################
        #   Run the Script   #
        ######################
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
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $fileName
    )

    Begin {
        $pattern = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>[\d:.]+)" date="(?<Date>\d{1,2}-\d{1,2}-\d{4})"(?<Misc>.*?)>'
        $rawLogs = (Get-Content -Path $fileName -Raw) -join "`r`n"
        $matchedStrings = [regex]::Matches($rawLogs,$pattern)
        $nonMatchedStrings = [regex]::Matches($rawLogs, '^(?!.*$pattern).*')
        $matchedStringsArray = [System.Collections.Generic.List[PSCustomObject]]::new()
        $count = 0
    }

    Process {
        foreach($string in $matchedStrings){
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
        if($nonMatchedStrings.count -gt 0){
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