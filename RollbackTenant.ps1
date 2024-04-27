#This PowerShell script is rolling back changes made by previous DSC (Desired State Configuration) scripts by generating new DSC configurations that undo the original changes.
#The key steps: 
#1. Loading the original DSC config scripts and replacing "Present" with "Absent" to reverse the state. Also updating the configuration name and data file references.
#2. Saving these "rollback" configs to new files.
#3. Prompting for credentials to the target tenant.
#4. Renewing the DSC agent certificate.
#5. Running the rollback configs against the target tenant and monitoring progress.
#6. Outputting status and timing information.
<###############################################>
#Update M365DSC Module
Update-M365DSCModule -Scope CurrentUser

# Use delegated access to connect to the Graph API and supply the scopes
Connect-MgGraph -Scopes 'Directory.Read.All', 'Domain.Read.All', 'Policy.Read.All', 'IdentityProvider.Read.All', 'Organization.Read.All', 'User.Read.All', 'EntitlementManagement.Read.All', 'UserAuthenticationMethod.Read.All', 'IdentityUserFlow.Read.All', 'APIConnectors.Read.All', 'AccessReview.Read.All', 'Agreement.Read.All', 'Policy.Read.PermissionGrant', 'PrivilegedAccess.Read.AzureResources', 'PrivilegedAccess.Read.AzureAD', 'Application.Read.All'

#region Banner
#Define refresh icon and green checkmark characters
$Refresh = [char]::ConvertFromUtf32(0x1F504)
$GreenCheckmark = [char]::ConvertFromUtf32(0x2705)
$stringRefresh = ""
#Build refresh icon string
for ($i = 0; $i -lt 25; $i++)
{
    $stringRefresh += $Refresh
}
#endregion

#region Update Rollback Config
#Get existing config file content
$content = Get-Content "C:\M365DSC\AADUser.ps1" | Out-String
#Update content to reverse state
$content = $content.Replace('"Present"', '"Absent"')
$content = $content.Replace("Configuration AADUser", "Configuration Rollback")
$content = $content.Replace("AADUser -ConfigurationData", "Rollback -ConfigurationData")
#Output updated content to new file
$content | Out-File "C:\M365DSC\Rollback\RollbackUsers.ps1" -Force

#Repeat process for second config file
$content = Get-Content "C:\M365DSC\AADDemo.ps1" | Out-String
$content = $content.Replace('"Present"', '"Absent"')
$content = $content.Replace("Configuration AADDemo", "Configuration Rollback")
$content = $content.Replace("AADDemo -ConfigurationData", "Rollback -ConfigurationData")
$content | Out-File "C:\M365DSC\Rollback\RollbackConfig.ps1" -Force
#endregion

#Get target tenant credentials
$Global:Target = Get-Credential -Message "Enter Target Tenant Credentials"

#Renew agent certificate
Set-M365DSCAgentCertificateConfiguration -GeneratePFX -Password "..." -ForceRenew

#region Apply Rollback
#Output refresh icon header
Write-Host "`r`n$stringRefresh"
Write-Host "            Rolling Back Configuration"
Write-Host $stringRefresh

#Apply user rollback
& "C:\M365DSC\Rollback\RollbackUsers.ps1" $Global:Target | Out-Null
Start-DscConfiguration -Path "C:\M365DSC\Rollback" -Wait -Verbose -Force

#Monitor progress
Write-Host "Rolling back Users on target tenant" -NoNewline
Start-Sleep -Seconds 2
$i = 2
while ((Get-DSCLocalConfigurationManager).LCMState -eq "Busy")
{
    Write-Host "." -NoNewline
    $i = $i + 2
    Start-Sleep -Seconds 2
}
#Output completion icon
Write-Host $GreenCheckMark

#Apply configuration rollback
& "C:\M365DSC\Rollback\RollbackConfig.ps1" $Global:Target | Out-Null
Start-DscConfiguration -Path "C:\M365DSC\Rollback" -Wait -Verbose -Force

#Monitor progress
Write-Host "Rolling back configuration on target tenant" -NoNewline
Start-Sleep -Seconds 2
$i = $i + 2
while ((Get-DSCLocalConfigurationManager).LCMState -eq "Busy")
{
    Write-Host "." -NoNewline
    $i = $i + 2
    Start-Sleep -Seconds 2
}
#Output completion icon
Write-Host $GreenCheckMark
#Output elapsed time
Write-Host "Rollback took {" -NoNewline
Write-Host "$i Seconds" -ForegroundColor Cyan -NoNewline
Write-Host "}"
#endregion