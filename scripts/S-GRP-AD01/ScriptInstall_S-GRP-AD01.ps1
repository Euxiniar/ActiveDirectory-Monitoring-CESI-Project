# #############################################################################
# 
# Name: ScriptInstall_S-GRP-AD01.ps1
# Comment: Installation Script and AD Insertion Script used in a School Project
# Source: https://github.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project
#
# Author:  Joël DIDIER (Studisys - joeldidier - joel_didier_)
# Website: https://studisys.net
# Date:  2019/11/11
# Email: contact@studisys.net
# GitHub: joeldidier (https://github.com/joeldidier)
#
# #############################################################################

$ServerName = "S-GRP-AD01"
$NewAdminName = "S-GRP-AD01-ADM"
$DomainName = "isec-group.local"
$NetBIOSName = "IGRPDOM1"
$SharesPath = "C:\Shares"
$RoamingProfilesFolderName = "Profiles$"
$RoamingProfilesShareName = "Profiles$"
$RoamingProfilesPath = "$SharesPath\$RoamingProfilesFolderName"
$PersonalFoldersDirectory = "$SharesPath\Personal$"
$ServiceFolderName = "Services"
$PersonalFolderName = "Personal$"

$Gateway = "192.168.31.2"
$Prefix = "24"
$S_GRP_AD01_IP = "192.168.31.3"
$S_GRP_AD02_IP = "192.168.31.4"
$S_TCOM_SMB01_IP = "192.168.31.5"
$ServerName = "S-GRP-AD01"
$DomainName = "isec-group.local"
$NetBIOSName = "IGRPDOM1"
$Hostname_2 = "S-GRP-AD02"
$NetBIOSDOM = "IGRPDOM1"
$Domain = "isec-group.local"
$S_GRP_AD01_IP = "192.168.31.3"
$S_GRP_AD02_IP = "192.168.31.4"
$Gateway = "192.168.31.2"
$Prefix = "24"
$DNS1 = "192.168.31.3"
$DNS2 = "1.1.1.1"
$SubnetMask = "255.255.255.0"
$StartRange = "192.168.31.21"
$EndRange = "192.168.31.253"
$DHCPPoolName = "ISEC User Devices"
$dnsList = $DNS1,$DNS2

function SilenceOutput
{
    $ProgPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
}

# This function renames the hostname and the Administrator account, then reboots the server. 
# It does not reboot the server if they are already set up.
function Set-PreReq # OK ?
{
    $restartflag = 0
    # Rename Server Name
    if ($env:computername -ne "$ServerName")
    {
        Write-Host "[INFO] Changing Hostname to $ServerName..." -ForegroundColor Cyan
        $result = Rename-Computer -NewName "$ServerName" -Force -Passthru -WarningAction SilentlyContinue
        $restartflag = 1
    }
    

    #Rename Default Admin User
    if ($result = Get-LocalUser -WarningAction SilentlyContinue | Where-Object {$_.Name -eq "$NewAdminName"} -WarningAction SilentlyContinue)
    {

    } else {
        Write-Host "[INFO] Changing 'Administrator' to $NewAdminName..." -ForegroundColor Cyan
        $result = Rename-LocalUser -Name "Administrator" -NewName "$NewAdminName" -WarningAction SilentlyContinue
        $restartflag = 1
    }

    if ($restartflag -eq "1")
    {
        Write-Host "[PROMPT] The server need to be restarted. Please restart the script once the server has booted back up." -ForegroundColor Magenta
        pause
        Restart-Computer
        exit
    }

}

function Get-DomAdmCred # OK !
{

    # Set password to the one specified by the user (Example: "ADprincipal4321!")
    Write-Host "[PROMPT] Please enter the new password for the Domain Administrator." -ForegroundColor Magenta
    $Password = Read-Host -AsSecureString
    $UserAccount = Get-LocalUser -Name "S-GRP-AD01-ADM"
    $UserAccount | Set-LocalUser -Password $Password

}

function Set-NetworkSettings
{
    $result = (Get-NetIPAddress).IPAddress -Like "192.168.31.3"
    if ($result -eq $NULL)
    {
    Write-Host [INFO] Setting up the Network Interface... -ForegroundColor Cyan
    $AdapterIndex = (Get-NetAdapter -WarningAction SilentlyContinue).ifIndex

    # Set the static IPv4 address
    Write-Host [INFO] Setting IP Address to $S_GRP_AD01_IP/$Prefix and Gateway to $Gateway. -ForegroundColor Cyan
    $result = New-NetIPAddress -InterfaceIndex $AdapterIndex -IPAddress $S_GRP_AD01_IP -DefaultGateway $Gateway -PrefixLength $Prefix -WarningAction SilentlyContinue

    # Set the DNS Servers
    Write-Host [INFO] Setting DNS Servers to $DNS1 [Primary] and $DNS2 [Secondary]. -ForegroundColor Cyan
    $result = Set-DnsClientServerAddress -InterfaceIndex $AdapterIndex -ServerAddresses ("$DNS1","$DNS2") -WarningAction SilentlyContinue
    
    # Enable Ping from IPv4/IPv6 addresses
    Write-Host "[INFO] Allowing Ping requests to this server." -ForegroundColor Cyan
    $result = New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow -WarningAction SilentlyContinue
    $result = New-NetFirewallRule -DisplayName "Allow inbound ICMPv6" -Direction Inbound -Protocol ICMPv6 -IcmpType 8 -Action Allow -WarningAction SilentlyContinue
    }
}

function Install-DHCPServer # OK !
{

    if((($result = Get-WindowsFeature -Name "DHCP" -WarningAction SilentlyContinue).InstallState) -eq "Installed") {
        Write-Host "[WARNING] The DHCP Server is already installed." -ForegroundColor yellow

    } else {

    # Install the DHCP Service
    Write-Host "[INFO] Installing the DHCP Server." -ForegroundColor Cyan
    $result = Install-WindowsFeature DHCP -IncludeManagementTools -WarningAction SilentlyContinue
    }


    # Set the IPv4 range
    $result = Get-DhcpServerV4Scope
    if ($result -eq $NULL){
    Write-Host "[INFO] Setting up the DHCP Pool $DHCPPoolName ($StartRange to $EndRange, Mask $SubnetMask)" -ForegroundColor Cyan
        $result = Add-DhcpServerV4Scope -Name "$DHCPPoolName" -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -WarningAction SilentlyContinue
    }
    

    # Set the DNS Server & Router Address
    $result = Get-DhcpServerV4OptionValue
    if ($result -eq $NULL)
    {
     Write-Host "[INFO] Setting up the DNS $DNS1 and $DNS2 for DHCP Clients (Gateway: $Gateway)" -ForegroundColor Cyan
    $result = Set-DhcpServerV4OptionValue -DnsServer $dnsList -Router $Gateway -Force -PassThru -WarningAction SilentlyContinue
    }
   

}

function Install-PDFCreator
{
$SharesPath = "C:\Shares"
    $PDFCreatorUri = "https://download.pdfforge.org/download/pdfcreator/PDFCreator-stable?download"
    $PDFCreatorDownloadPath = "$SharesPath\InitialServerDeploy$\Printer"
    $PDFCreatorIniUri = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/Software/PDFCreator/PDFCreator.inf"

    # [1/2] Check if the download path exists. If not, create it.
        if ((Test-Path -Path "$PDFCreatorDownloadPath") -eq $False)
        {
            $result = New-Item -ItemType Directory -Force -Path "$PDFCreatorDownloadPath" -WarningAction SilentlyContinue
        }

    if ((Test-Path "$PDFCreatorDownloadPath\PDFCreator.exe") -eq $False)
    {
     # Download PDF Creator with BITS
    Start-BitsTransfer -Source "$PDFCreatorUri" -Destination "$PDFCreatorDownloadPath\PDFCreator.exe"

    # Download the configuration file
    Start-BitsTransfer -Source "$PDFCreatorIniUri" -Destination "$PDFCreatorDownloadPath\PDFCreator.inf"

    # Install PDF Creator 'silently' (No popup, no restart)
    cd $PDFCreatorDownloadPath
    ./PDFCreator.exe /LOADINF="PDFCreator.inf" /VERYSILENT /NORESTART

    Write-Host "[PROMPT] The server need to be restarted. Please restart the script once the server has booted back up." -ForegroundColor Magenta
    pause
    Restart-Computer
    exit
    }
}

function Install-ADDomain
{

  if((($result = Get-WindowsFeature -Name "AD-Domain-Services" -WarningAction SilentlyContinue).InstallState) -eq "Installed") {
        Write-Host "[WARNING] The AD DS Role is already installed." -ForegroundColor yellow

    } else {

    Write-Host "[INFO] Installing the AD DS Role." -ForegroundColor Cyan

    # Install the ADDS Services
    $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue

    $restartflag = "1"
    }

    Write-Host "[PROMPT] Please enter the new password for the Domain Administrator." -ForegroundColor Magenta
    $Password = Read-Host -AsSecureString

    

    # Install the ADDS role on S-GRP-AD01, create a new forest with the domain as "isec-group.local", set NETBIOS name and install DNS
    try { 
        $result = Get-ADDomain
    } catch {
    Write-Host "[INFO] Creating a new AD Forest (Domain Name: $DomainName - NetBIOS Name: $NetBIOSName)" -ForegroundColor Cyan
     $result = Install-ADDSForest -DomainName "$DomainName" -DomainNetbiosName "$NetBIOSName" -InstallDns:$true -NoRebootOnCompletion:$true -SafeModeAdministratorPassword $Password -Force -WarningAction SilentlyContinue
    $restartflag = "1"
    }

    

    if ($restartflag -eq "1")
    {

        Write-Host "[PROMPT] The server need to be restarted. Please restart the script once the server has booted back up." -ForegroundColor Magenta
        pause
        Restart-Computer
        exit
    }
    # Configure the DNS Conditional Forwarding Zone (redirect all requests for isec-telecom.local to the correct DNS server)
    try
    {
        
        $result = Add-DnsServerConditionalForwarderZone -Name "isec-telecom.local" -ReplicationScope "Forest" -MasterServers "$S_TCOM_SMB01_IP" -WarningAction SilentlyContinue
    Write-Host "[INFO] Creating a DNS entry to redirect all DNS requests for isec-telecom.local domain to $S_TCOM_SMB01_IP" -ForegroundColor Cyan
    } catch
    {

    }
}




function Create-OrganizationalUnits # OK !
{
    $PathToOUCSV = "$SharesPath\InitialServerDeploy\OUs\CSV\"
    $OUCSVName = "ISEC-Group_OUs.csv"
    $FullOUCSVPath = $PathToOUCSV + $OUCSVName
    $URLtoOUCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/OU/CSV/ISEC-Group_OUs.csv"


    if (($result = Test-Path -Path "$FullOUCSVPath" -WarningAction SilentlyContinue) -eq $False)
    {
        if (($result = Test-Path -Path "$PathToOUCSV" -WarningAction SilentlyContinue) -eq $False)
        {
            $result = New-Item -ItemType Directory -Force -Path "$PathToOUCSV" -WarningAction SilentlyContinue
        }

        $result = Invoke-WebRequest -OutFile "$FullOUCSVPath" "$URLtoOUCSV" -WarningAction SilentlyContinue
    }

    $OUCount = 0
    $OUsCSV = Import-Csv "$FullOUCSVPath" -Delimiter ";"

    foreach ($OU in $OUsCSV)
    {
    $OUName = $OU.'Name'
    $OUPath = $OU.'Path'
    $OUFullPath = $OU.'FullPath'

    # If the Organizational Unit already exists...
    if ($result = Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$OUFullPath'" -WarningAction SilentlyContinue)
    {
        # ... Display Warning and do not add Organizational Unit
        Write-Host "[WARNING] Organizational Unit [$OUName] already exists." -ForegroundColor Yellow
    } else { # If it doesn't exist
        # ... Create the Organizational Unit
        Write-Host "[INFO] Adding $OUName into Active Directory (Full Path: $OUFullPath)." -ForegroundColor Cyan
        $result = New-ADOrganizationalUnit -Name $OUName -Path $OUPath -WarningAction SilentlyContinue
        $OUCount++
    }

    }

    Write-Host "[INFO] Added $OUCount Organizational Unit(s) into Active Directory." -ForegroundColor Cyan
}


function Create-Groups # OK !
{


    $PathToGroupsCSV = "$SharesPath\InitialServerDeploy\Groups\CSV\"
    $GroupsCSVName = "ISEC-Group_Groups.csv"
    $FullGroupsCSVPath = $PathToGroupsCSV + $GroupsCSVName
    $URLtoGroupsCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/Groups/CSV/ISEC-Group_Groups.csv"


    if ((Test-Path -Path "$FullGroupsCSVPath") -eq $False)
    {
        if ((Test-Path -Path "$PathToGroupsCSV") -eq $False)
        {
            $result = New-Item -ItemType Directory -Force -Path "$PathToGroupsCSV" -WarningAction SilentlyContinue
        }

        $result = Invoke-WebRequest -OutFile "$FullGroupsCSVPath" "$URLtoGroupsCSV" -WarningAction SilentlyContinue
    }

    $GroupCount = 0
    $GroupsCSV = Import-Csv "$FullGroupsCSVPath" -Delimiter ";"
    
    # For each Groups (1 group per line)
    foreach ($Group in $GroupsCSV)
    {

    try
    {
        $TestGroup = Get-ADGroup -Identity $Group.'Name' -ErrorAction Stop

        Write-Host [WARNING] Group $Group.'Name' already exists in Active Directory. -ForegroundColor Yellow

    } catch {

        # [1/X] We create the Group in Active Directory
        Write-Host [INFO] Adding Group $Group.'Name' into Active Directory at $($Group.'Path'). -ForegroundColor Cyan
        
        try {
            New-ADGroup -Name $Group.'Name' -GroupCategory $Group.'GroupCategory' -GroupScope $Group.'GroupScope' -Path $Group.'Path' -ErrorAction Stop
            $GroupCount++
        } catch {

        Write-Host "[ERROR] Tried to add the following group: ["$Group.'Name'"] despite verifications put in place, since it already exists in Active Directory." -ForegroundColor Red

        }

    # If the "Group" field is empty
    if ([string]::IsNullOrEmpty($Group.'Group'))
    {
      # Do nothing.
    } else {
        # We put the content of the field in a $Groups object, and we set the delimiter to ","
        $Groups = $Group.'Group' -split ","

        # For each group in the field
        foreach ($ADGroup in $Groups)
        {
            # We add the user to this group
            Write-Host [INFO] Adding $ADGroup into  $Group.'Name'. -ForegroundColor Cyan
            Add-ADGroupMember -Identity $Group.'Name' -Members $ADGroup

        }
    }
        
    }

    }
         
   
}



function Create-Users # OK !
{


    $PathToUsersCSV = "$SharesPath\InitialServerDeploy$\Users\CSV\"
    $UsersCSVName = "ISEC-Group_Users.csv"
    $FullUsersCSVPath = $PathToUsersCSV + $UsersCSVName
    $URLtoUsersCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/Users/CSV/ISEC-Group_Users.csv"


    if ((Test-Path -Path "$FullUsersCSVPath") -eq $False)
    {
        if ((Test-Path -Path "$PathToUsersCSV") -eq $False)
        {
            New-Item -ItemType Directory -Force -Path "$PathToUsersCSV" > $NULL
        }

        Invoke-WebRequest -OutFile "$FullUsersCSVPath" "$URLtoUsersCSV"
    }

    # This is the default we'll use for the newly created users. DO NOT DO THIS IN PRODUCTION ! THIS ONLY SERVES AS A PURPOSE OF DEMONSTRATION !
    $DefaultPassword = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force # Password is "P@ssw0rd!"

    $UserCount = 0

    $UsersCSV = Import-Csv "$FullUsersCSVPath" -Delimiter ";"
    foreach ($User in $UsersCSV)
    {        

        if (!(Get-ADUser -Filter "sAMAccountName -eq '$($User.'Login')'")) {
            Write-Host [INFO] Creating account for $User.'DisplayNameSurname' "("$User.'Full-Login'")" -ForegroundColor Cyan
            New-ADUser -Name $User.'DisplayNameSurname' -GivenName $User.'DisplayName' -Surname $User.'DisplaySurname' -SamAccountName $User.'Login' -UserPrincipalName $User.'Full-Login' -AccountPassword $DefaultPassword -Enabled $true -ProfilePath "\\S-GRP-AD01.isec-group.local\RoamingProfiles\%username%" -EmailAddress $User.'Full-Login' -Path $User.'Path' -ErrorAction Stop
            $UserCount++
        }
        else {
            Write-Host [WARNING] User $User.'DisplayNameSurname' "("$User.'Full-Login'")" already exists. -ForegroundColor Yellow
        }
        
    # If the "Group" field is empty
    if ([string]::IsNullOrEmpty($User.'Group'))
    {
      # Do nothing.
    } else {
        # We put the content of the field in a $Groups object, and we set the delimiter to ","
        $Groups = $User.'Group' -split ","
        # For each group in the field
        foreach ($ADGroup in $Groups)
        {
            # We add the user to this group
            Write-Host [INFO] Adding $User.'DisplayNameSurname' $($Group.'Login') into $ADGroup. -ForegroundColor Cyan
            Add-ADGroupMember -Identity $ADGroup -Members $Group.'Login'
        }
    }
        
    }

    Write-Host "[INFO] Added $UserCount user(s) to Active Directory." -ForegroundColor Cyan

}





# Create-BaseFolders : Create the folder structure that will be used for Personal User folders, Roaming Profiles Share
function Create-BaseFolders
{
    # Check if the Users Roaming Profiles folder exists, and create it if it doesn't.
    if ((Test-Path -Path "$RoamingProfilesPath") -eq $False)
    {
            $result = New-Item -ItemType Directory -Force -Path "$RoamingProfilesPath" -WarningAction SilentlyContinue
            Write-Host "[SUCCESS] Created the Roaming Profiles folder ($RoamingProfilesPath)" -ForegroundColor Green
    }
    
    # Create Services Common Folders
    if ((Test-Path -Path "$SharesPath\$ServiceFolderName") -eq $False)
    {
       $result = New-Item -ItemType Directory -Force -Path "$SharesPath\$ServiceFolderName" -WarningAction SilentlyContinue
       Write-Host "[SUCCESS] Created the Services Common folder ($SharesPath\$ServiceFolderName)" -ForegroundColor Green
    }


    # Create Users' Personal Folders
    if ((Test-Path -Path "$SharesPath\$PersonalFolderName") -eq $False)
    {
       $result = New-Item -ItemType Directory -Force -Path "$SharesPath\$PersonalFolderName" -WarningAction SilentlyContinue
       Write-Host "[SUCCESS] Created the Folder Redirection folder ($SharesPath\$PersonalFolderName)" -ForegroundColor Green
    }


    # Create Programs Deployment Folder
    if ((Test-Path -Path "$SharesPath\SoftDeploy$") -eq $False)
    {
       $result = New-Item -ItemType Directory -Force -Path "$SharesPath\SoftDeploy$" -WarningAction SilentlyContinue
       Write-Host "[SUCCESS] Created the Software Deployment folder ($SharesPath\SoftDeploy$)" -ForegroundColor Green
    }

    # Create Initial Server Deploy Folder
    if ((Test-Path -Path "$SharesPath\InitialServerDeploy$") -eq $False)
    {
       $result = New-Item -ItemType Directory -Force -Path "$SharesPath\InitialServerDeploy$" -WarningAction SilentlyContinue
       Write-Host "[SUCCESS] Created the Initial Server Deployment folder ($SharesPath\InitialServerDeploy$)" -ForegroundColor Green
    }

        # Create Wallpapers Folder
    if ((Test-Path -Path "$SharesPath\Wallpapers$") -eq $False)
    {
       $result = New-Item -ItemType Directory -Force -Path "$SharesPath\Wallpapers$" -WarningAction SilentlyContinue
       Write-Host "[SUCCESS] Created the Wallpapers folder ($SharesPath\Wallpapers$)" -ForegroundColor Green
    }

}

function Create-SMBShare
{
    # Create a SMB Share for the Roaming Profiles folder
    New-SmbShare -Path "$RoamingProfilesPath" -Name "$RoamingProfilesShareName"

    # Assign Permissions for Roaming Profiles folder
    Grant-SmbShareAccess -Name "$RoamingProfilesShareName" -AccountName Everyone -AccessRight Full -Force


    

    Set-Printer -Name "PDFCreator" -Shared $True -Published $True -ShareName "PDFCreator" -PortName "pdfcmon"
    printui /Xs /n "PDFCreator" ClientSideRender enabled

}









function Download-7Zip
{
    $7ZipUri = "https://www.7-zip.org/a/7z1900-x64.msi" # PLEASE USE 7-ZIP MSI INSTALLER !
    $7ZipDownloadPath = "$SharesPath\SoftDeploy\7-Zip"

        # [1/2] Check if the download path exists. If not, create it.
        if ((Test-Path -Path "$7ZipDownloadPath") -eq $False)
        {
            New-Item -ItemType Directory -Force -Path "$7ZipDownloadPath" > $NULL
        }

    # [2/2] Download 7-Zip with BITS
    Start-BitsTransfer -Source "$7ZipUri" -Destination "$7ZipDownloadPath\7zip.msi"
        
    # Done !

}

function Configure-GPO
{
    # TODO
}







# OK - Silence all Output
SilenceOutput

# OK - Create the Specific Folders (without rights/shares)
Create-BaseFolders

# OK - Rename what has to be renamed
Set-PreReq

# OK - Get the new password for the Domain Administrator
Get-DomAdmCred

# OK - Configure Network Settings (Static IP Address + DNS)
Set-NetworkSettings

# OK - Install & Setup the DHCP service
Install-DHCPServer

# OK - Install ADDS role and create the new AD domain
Install-ADDomain

# OK - Download, Install the PDFCreator Printer. This will make our DC Server a "Printer" Server.
Install-PDFCreator

# OK - Download 7-Zip... so we can deploy it later ;-)
Download-7Zip

# OK - Create Organizational Units
Create-OrganizationalUnits

# OK? - Create Groups
Create-Groups

# OK - Create Users
Create-Users

# Change default OU for Computers Object
redircmp OU=Computers,OU=ISEC-Group,OU=Global,DC=isec-group,DC=local


# NOK - Create SMB Shares for Folders & Printers
#Create-SMBShares


# NOK - Configure and Deploy all GPO.
#Configure-GPO


Write-Host "Finished. You can now try the brand new User accounts !"
pause
exit

# And here it ends. 
# "Is that all ? Is it over ? I'm sure something is missing !"
#
# No. It's all done. You've witnessed how PowerShell commands can be so powerful.
# Learn PowerShell, just drop that GUI away (✿◡‿◡)