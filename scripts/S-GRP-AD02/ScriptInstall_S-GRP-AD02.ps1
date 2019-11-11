# #############################################################################
# 
# Name: ScriptInstall_S-GRP-AD02.ps1
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
$DNS2 = "192.168.31.4"
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

function Get-DomAdmCred
{
    Write-Host "[PROMPT] Please enter the password of the $Domain Domain Administrator." -ForegroundColor Magenta
    $Password = Read-Host -AsSecureString

    Write-Host "[PROMPT] Please enter the credentials of the $Domain Domain Administrator." -ForegroundColor Magenta
    $Credentials = (Get-Credential IGRPDOM1\S-GRP-AD01-ADM)
}

function Set-NetworkSettings
{
    Write-Host [INFO] Setting up the Network Interface... -ForegroundColor Cyan
    $AdapterIndex = (Get-NetAdapter -WarningAction SilentlyContinue).ifIndex

    # Set the static IPv4 address
    Write-Host [INFO] Setting IP Address to $S_GRP_AD02_IP/$Prefix and Gateway to $Gateway. -ForegroundColor Cyan
    $result = New-NetIPAddress -InterfaceIndex $AdapterIndex -IPAddress $S_GRP_AD02_IP -DefaultGateway $Gateway -PrefixLength $Prefix -WarningAction SilentlyContinue

    # Set the DNS Servers
    Write-Host [INFO] Setting DNS Servers to $DNS1 [Primary] and $DNS2 [Secondary]. -ForegroundColor Cyan
    $result = Set-DnsClientServerAddress -InterfaceIndex $AdapterIndex -ServerAddresses ("$DNS1","$DNS2") -WarningAction SilentlyContinue

    # Enable Ping from IPv4/IPv6 addresses
    Write-Host "[INFO] Allowing Ping requests to this server." -ForegroundColor Cyan
    New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow
    New-NetFirewallRule -DisplayName "Allow inbound ICMPv6" -Direction Inbound -Protocol ICMPv6 -IcmpType 8 -Action Allow
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
    Write-Host "[INFO] Setting up the DHCP Pool $DHCPPoolName ($StartRange to $EndRange, Mask $SubnetMask)" -ForegroundColor Cyan
    $result = Add-DhcpServerV4Scope -Name "$DHCPPoolName" -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -WarningAction SilentlyContinue

    # Set the DNS Server & Router Address
    Write-Host "[INFO] Setting up the DNS $DNS1 and $DNS2 for DHCP Clients (Gateway: $Gateway)" -ForegroundColor Cyan
    $result = Set-DhcpServerV4OptionValue -DnsServer $dnsList -Router $Gateway -Force -PassThru -WarningAction SilentlyContinue

}

function Install-ADDSRole
{
    if((($result = Get-WindowsFeature -Name "AD-Domain-Services" -WarningAction SilentlyContinue).InstallState) -eq "Installed") {
        Write-Host "[WARNING] The AD DS Role is already installed." -ForegroundColor yellow

    } else {

    Write-Host "[INFO] Installing the AD DS Role." -ForegroundColor Cyan

    # Install the ADDS Services
    $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue
    }

    Write-Host "[INFO] Joining $Hostname_2 to $DomainName domain as a Secondary DC." -ForegroundColor Cyan
    $result = Install-ADDSDomainController -CreateDnsDelegation:$false -DatabasePath 'C:\Windows\NTDS' -DomainName "$DomainName" -InstallDns:$true -LogPath 'C:\Windows\NTDS' -NoGlobalCatalog:$false -SiteName 'Default-First-Site-Name' -SysvolPath 'C:\Windows\SYSVOL' -NoRebootOnCompletion:$true -Force:$true -Credential (Get-Credential) -WarningAction SilentlyContinue
   
}





SilenceOutput

Get-DomAdmCred

Set-NetworkSettings

Install-DHCPServer

Install-ADDSRole


Write-Host "[SUCCESS] Successfully installed all the required roles ! The server will now restart."  -ForegroundColor Cyan
pause
Restart-Server

# And here it ends. 
# "Is that all ? Is it over ? I'm sure something is missing !"
#
# No. It's all done. You've witnessed how PowerShell commands can be so powerful.
# Learn PowerShell, just drop that GUI away (✿◡‿◡)