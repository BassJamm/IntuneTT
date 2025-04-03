# IntuneTT

Intune Troubleshooting Toolkit - To help with troubleshooting policy, app and other such deployments.

This is in ALPHA - the full module will be uploaded soon.

I did not make all of the scripts within this, the idea of the tool is to collect all the useful stuff for troubleshooting
Intune devices into one space.

## Publishing Process

### 1. Local Testing

```powershell
# Remove any old version from the session
Remove-Module IntuneTT -ErrorAction SilentlyContinue

# Import the module
Import-Module IntuneTT -Force

# Verify module is loaded
Get-Module IntuneTT

# Check exported functions
Get-Command -Module IntuneTT
```

### 2. Pre-Publish Checks

Review any errors.

```powershell
Invoke-ScriptAnalyzer -Path .\IntuneTT.psm1 | ft -a
```

Update release Information and Version

- Edit the .psd1 file.
  - Release Information and Version

Confirm exported functions and information.

```powershell
Test-ModuleManifest .\IntuneTT.psd1
```

### 3. Publish

WhatIf

`Publish-Module -Path .\ -Repository PSGallery -NuGetApiKey "YOUR_API_KEY" -WhatIf`

`Publish-Module -Path .\ -Repository PSGallery -NuGetApiKey "YOUR_API_KEY"`
