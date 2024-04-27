#This PowerShell script checks for the presence of the "Microsoft365DSC" module and ensures that it is up-to-date. 
#It also checks for any required dependencies and installs them if necessary.


#Requires -Version 7.4.2
[CmdletBinding()]
param ()

#region Supporting functions
function Write-Log
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter()]
        [System.Int32]
        $Level = 0
    )
    # Gets the current date and time in the format 'yyyy-MM-dd HH:mm:ss'
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Adds indentation to the log message based on the level
    $indentation = '  ' * $Level
    $output = "[{0}] - {1}{2}" -f $timestamp, $indentation, $Message
    
    # Writes the log message to the console
    Write-Host $output
}

##### GENERIC VARIABLES #####
$workingDirectory = $PSScriptRoot
$encounteredError = $false


##### START SCRIPT #####

# Checks if the PowerShell version is 5.1 or higher
if ($PSVersionTable.PSVersion.Major -ne 7)
{
    Write-Log -Message 'You are not using PowerShell v7. Please make sure you are using that version!'
    return
}

try
{
    # Writes a separator to the console
    Write-Log -Message '******************************************************************************'
    Write-Log -Message '*        Checking for Microsoft365Dsc module and all required modules        *'
    Write-Log -Message '******************************************************************************'
    Write-Log -Message ' '

    # Imports the PowerShell data file located in the same directory as the script
    $modules = Import-PowerShellDataFile -Path (Join-Path -Path $workingDirectory -ChildPath 'DscResources.psd1')

    # Checks if the Microsoft365Dsc module is present in the imported data
    if ($modules.ContainsKey("Microsoft365Dsc"))
    {
        Write-Log -Message 'Checking Microsoft365Dsc version' -Level 1
        $psGalleryVersion = $modules.Microsoft365Dsc
        
        # Gets the locally installed version of the module
        $localModule = Get-Module 'Microsoft365Dsc' -ListAvailable

        Write-Log -Message "Required version: $psGalleryVersion" -Level 2
        Write-Log -Message "Installed version: $($localModule.Version)" -Level 2
        
        # Checks if the locally installed version matches the required version
        if ($localModule.Version -ne $psGalleryVersion)
        {
            if ($null -ne $localModule)
            {
                Write-Log -Message 'Incorrect version installed. Removing current module.' -Level 3
                Write-Log -Message 'Removing Microsoft365DSC' -Level 4
                
                # Removes the locally installed module
                $m365ModulePath = Join-Path -Path 'C:\Program Files\WindowsPowerShell\Modules' -ChildPath 'Microsoft365DSC'
                Remove-Item -Path $m365ModulePath -Force -Recurse -ErrorAction 'SilentlyContinue'
            }

            # Configures the PowerShell Gallery and sets the TLS version to 1.2
            Write-Log -Message 'Configuring PowerShell Gallery' -Level 4
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Checks if the PowerShellGet module is installed and, if not, installs it
            $psGetModule = Get-Module -Name PowerShellGet -ListAvailable | Select-Object -First 1
            
            if ($null -eq $psGetModule)
            {
                Write-Log -Message '* Installing PowerShellGet' -Level 5
                Install-Module PowerShellGet -SkipPublisherCheck -Force
                Write-Log -Message 'NOTE: If you receive Package Management errors later in this script, please restart the pipeline.' -Level 6
                Write-Log -Message '      This update is not yet being picked up.' -Level 6
            }
            else
            {
                if ($psGetModule.Version -lt [System.Version]"2.2.4.0")
                {
                    Write-Log -Message '* Installing PowerShellGet' -Level 5
                    Install-Module PowerShellGet -SkipPublisherCheck -Force
                    Write-Log -Message 'NOTE: If you receive Package Management errors later in this script, please restart the pipeline.' -Level 6
                    Write-Log -Message '      This update is not yet being picked up.' -Level 6
                }
            }

            # Installs the Microsoft365Dsc module with the required version
            Write-Log -Message 'Installing Microsoft365Dsc' -Level 4
            $null = Install-Module -Name 'Microsoft365Dsc' -RequiredVersion $psGalleryVersion
        }
        else
        {
            Write-Log -Message 'Correct version installed, continuing.' -Level 3
        }

        # Checks for any required dependencies and updates them if necessary
        Write-Log -Message 'Checking Module Dependencies' -Level 1
        Update-M365DSCDependencies

        # Removes any outdated dependencies
        Write-Log -Message 'Removing Outdated Module Dependencies' -Level 1
        Uninstall-M365DSCOutdatedDependencies

        Write-Log -Message 'Modules installed successfully!'
        Write-Log -Message ' '
    }
    else
    {
        Write-Log -Message "[ERROR] Unable to find Microsoft365Dsc in DscResources.psd1. Cancelling!"
        Write-Host "##vso[task.complete result=Failed;]Failed"
        exit 10
    }
    Write-Log -Message ' '
    Write-Log -Message 'Check complete!'
    Write-Log -Message ' '
    
}
catch
{
    Write-Log -Message ' '
    Write-Log -Message '[ERROR] Error occurred during DSC Compliance check!'
    Write-Log -Message "  Error message: $($_.Exception.Message)"
    $encounteredError = $true
}