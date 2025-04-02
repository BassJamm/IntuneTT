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
                Write-Host "Module $module is already installed."
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
            Write-Host "Connecting to Graph now, a separate window should launch..." -ForegroundColor Yellow
            Connect-MgGraph -NoWelcome
        }
        #endRegion
    }
    End {
        Write-Host "You are connected!"
        Get-MgContext | Select Account, @{ l = 'PermissionScopes'; e = { $_.Scopes -join "`n" } } | fl
        Start-Sleep -Seconds 2 # More pleasent experience for end user.
        return
    }
    
}
#endRegion

#############################
#   Collect MDM Diag Logs   #
#############################
function Get-MDMDiagnostics {
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
        Write-Host "Collecting Autopilot Diagnostics" -ForegroundColor Yellow
        Start-Process $mdmDiagTool -ArgumentList $processArgs -NoNewWindow -Wait
        Start-Sleep -Seconds 15

        if (Test-Path "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName") {
            Write-Host "Diagnostic Logs collected successfully" -ForegroundColor Yellow
        }
        else {
            Write-Host "Error collecting Diagnostic Logs, please try again." -ForegroundColor Red
            Return
        }
        #endRegion

        #################################
        #	Download Community Script   #
        #################################
        if (!(Get-InstalledScript Get-AutopilotDiagnosticsCommunity)) {
            try {
                Write-Host "Installing Get-AutopilotDiagnosticsCommunity script..."
                Install-Script -Name Get-AutopilotDiagnosticsCommunity -Force
                $env:PATH += ";C:\Program Files\PowerShell\Scripts" # Manually update path to save restarting session.
            }
            catch {
                Write-Host "Error Downloading Script."
                Return
            }
        }
        #endRegion

        ######################
        #   Run the Script   #
        ######################
        Write-Host "Exporting all data here, $outPutFilename" -ForegroundColor Yellow
        Get-AutopilotDiagnosticsCommunity.ps1 -ZIPFile "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$diagFileName" -Online *>&1 | `
            Tee-Object -FilePath "C:\Temp\IntuneTroubleshootingTool\AutopilotDiag\$outPutFilename"
        #endRegion
    }
    End {
        Write-Host "Completed Get-MDMDiagnostics flow" -ForegroundColor Green
        return
    }
    
}
#endRegion