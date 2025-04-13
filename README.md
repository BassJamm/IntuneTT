# IntuneTT

Intune Troubleshooting Toolkit - To help with troubleshooting policy, app and other such deployments.

I did not make all of the scripts within this, the idea of the tool is to collect all the useful stuff for troubleshooting
Intune devices into one space.

Install the module using the ps gallery, `Install-Module -Name IntuneTT`.

## Features

# Ideas

- [ ] Upload to Azure Blob
- [ ] Delete Win32 App from Win32Apps Reg key

## Implemented

- [X] Export all MDMDiagnostic Data for review.[See here](#export-all-mdmd-diags).
- [X] Appliation Assignment Report.
- [X] Attestation Readiness Script.
- [X] Win32 App Report.
- [X] Collect Autopilot Diagnostic Information.
- [X] Install all required MG Graph modules for troubleshooting issues.
- [X] Auth with MG Graph with scopes required to troubleshoot issues.

## Commands

### Connect-ToMGGraph

- Will connect to Microsoft Graph with the correct scopes to run the rest of the scripts and functions in this model.

### Find-StringInFile

- Will take in a folder path and a string to search for. It will return a list of files that contain that string.
- Useful for finding strings in the IME logs rather than searching them manually.

## Get-AttestationReadiness

- Will check for an download the script from the psgallery and run it.
- Bear in mind there are a couple of deprecated commands used in the script but, it does the job still.

## Get-MDMDiagnosticInfo

- This will collect all the mdmdiagnostics from the mdmdiagnostics.exe app. This returns roughtly the
same as what you get from Intune when clicking "collect diagnostics".

## Get-PendingReboot

- Will check for any pending reboots.

## Get-Win32AppReport

- Will grab the current state of play for each application that has a status stored in the local machines registry.

## Get-WinAppAssignments

- Will collect the application assingmnets from intune.
  
## Install-RequiredMGGraphModules

- Will install the required modules for any thing in the scripts\functions in this module.

## ParseIMELogs (WIP)

- Will try to parse the IME logs to be more readable.
- This is a perpetual work in progress as Microsoft seemingly change these occasionally.
