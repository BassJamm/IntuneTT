# IntuneTT

Intune Troubleshooting Toolkit - To help with troubleshooting policy, app and other such deployments.

I did not make all of the scripts within this, the idea of the tool is to collect all the useful stuff for troubleshooting
Intune devices into one space.

Install the module using the ps gallery, `Install-Module -Name IntuneTT`.

## Features To Add

- [ ] Export all MDMDiagnostic Data for review.[See here](#export-all-mdmd-diags).
- [X] Appliation Assignment Report.
- [X] Attestation Readiness Script.
- [X] Win32 App Report.
- [X] Collect Autopilot Diagnostic Information.
- [X] Install all required MG Graph modules for troubleshooting issues.
- [X] Auth with MG Graph with scopes required to troubleshoot issues.

### Export All MDMD Diags

This command, `mdmdiagnosticstool.exe -area "DeviceEnrollment;DeviceProvisioning;ManagementService;PushNotification;WnsProvider;Autopilot" -zip 'C:\Temp\MDMDiag.zip'
