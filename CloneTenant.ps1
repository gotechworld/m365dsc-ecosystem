# Exports the M365DSC configuration for the specified components from the source tenant to the specified path and file. 
# Then imports the configuration to the target tenant to clone those components.
# Tracks the time taken to clone the components and provides status indicators.
<###############################################>
#Install PowerShellGet
Install-Module -Name PowerShellGet -Force -AllowClobber -Repository PSGallery -Scope CurrentUser

#Install Microsoft365DSC
Install-Module Microsoft365DSC -Force -AllowClobber -Repository PSGallery -Scope CurrentUser

#Install Dependencies
Update-M365DSCDependencies -Scope CurrentUser

#Update M365DSC Module
Update-M365DSCModule -Scope CurrentUser

# Use delegated access to connect to the Graph API and supply the scopes
Connect-MgGraph -Scopes 'Directory.Read.All', 'Domain.Read.All', 'Policy.Read.All', 'IdentityProvider.Read.All', 'Organization.Read.All', 'User.Read.All', 'EntitlementManagement.Read.All', 'UserAuthenticationMethod.Read.All', 'IdentityUserFlow.Read.All', 'APIConnectors.Read.All', 'AccessReview.Read.All', 'Agreement.Read.All', 'Policy.Read.PermissionGrant', 'PrivilegedAccess.Read.AzureResources', 'PrivilegedAccess.Read.AzureAD', 'Application.Read.All'

$WarningPreference = "SilentlyContinue"

#region Banners
#Creates banner variables for visual status indicators
$Package = [Char]::ConvertFromUtf32(0x1F4E6)
$Rocket = [Char]::ConvertFromUtf32(0x1F680)
$GreenCheckmark = [char]::ConvertFromUtf32(0x2705)

$stringPackage = ""; $stringRocket = ""
for ($i = 0; $i -lt 25; $i++) {
    $stringPackage += $Package
    $stringRocket += $Rocket
}
#endregion

#Create directory for rollback files
New-Item -Path "C:\M365DSC\Rollback" -ItemType Directory -Force

#Get source tenant credentials
$Global:Source = Get-Credential -Message "Enter Source Tenant Credentials"

#Generate certificate for DSC agent
Set-M365DSCAgentCertificateConfiguration -GeneratePFX -Password "..." -ForceRenew

#region Export
Write-Host "`r`n$stringPackage"
Write-Host "            Exporting Source Tenant"
Write-Host $stringPackage
Write-Host "Loading Depencencies. This may take a few seconds..."

#Exports M365 DSC configuration from source tenant
#Export AADUser component
Export-M365DSCConfiguration -Credential $Global:Source `
    -Components @("AADUser") `
    -Path "C:\M365DSC" `
    -FileName "AADUser.ps1" 

#Export other AAD components
Export-M365DSCConfiguration -Credential $Global:Source `
    -Components @("AADApplication", "AADGroup") `
    -Path "C:\M365DSC" `
    -FileName "AADDemo.ps1" 
                            
#endregion

#Get target tenant credentials
$Global:Target = Get-Credential -Message "Enter Target Tenant Credentials"

#region Clone
#Applies exported DSC configurations to target tenant
Write-Host "`r`n"
Write-Host $stringRocket
Write-Host "              Cloning Source Tenant"
Write-Host $stringRocket

#Apply AADUser configuration
& "C:\M365DSC\AADUser.ps1" $Global:Target | Out-Null
Start-DscConfiguration -Path "C:\M365DSC\AADUser" -Wait -Verbose -Force

Write-Host "Restoring Users on target tenant" -NoNewline
Start-Sleep -Seconds 2
$i = 2
while ((Get-DSCLocalConfigurationManager).LCMState -eq "Busy") {
    Write-Host "." -NoNewline
    $i = $i + 2
    Start-Sleep -Seconds 2
}

Write-Host $GreenCheckMark

#Apply other AAD configurations
& "C:\M365DSC\AADDemo.ps1" $Global:Target | Out-Null
Start-DscConfiguration -Path "C:\M365DSC\AADDemo" -Wait -Verbose -Force

Write-Host "Restoring Users on target tenant" -NoNewline
Start-Sleep -Seconds 2
$i = 2
while ((Get-DSCLocalConfigurationManager).LCMState -eq "Busy") {
    Write-Host "." -NoNewline
    $i = $i + 2
    Start-Sleep -Seconds 2
}
Write-Host $GreenCheckMark

#Track time to clone and display completion  
Write-Host "Cloning took {" -NoNewline
Write-Host "$i Seconds" -ForegroundColor Cyan -NoNewline
Write-Host "}"
#endregion