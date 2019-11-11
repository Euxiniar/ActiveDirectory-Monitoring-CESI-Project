# Run as ITCOMDOM1 Domain Admin (ITCOMDOM1\administrator) on S-GRP-AD01-ADM
C:\Windows\System32\runas.exe /netonly /user:ITCOMDOM1\administrator powershell.exe

# Import OU
function Create-OrganizationalUnits # OK !
{
    $PathToOUCSV = "$SharesPath\InitialServerDeploy$\OUs\CSV\"
    $OUCSVName = "ISEC-Telecom_OUs.csv"
    $FullOUCSVPath = $PathToOUCSV + $OUCSVName
    $URLtoOUCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/OU/CSV/ISEC-Telecom_OUs.csv"


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

Create-OrganizationalUnits

# Import Groups
function Create-Groups # OK !
{


    $PathToGroupsCSV = "$SharesPath\InitialServerDeploy$\Groups\CSV\"
    $GroupsCSVName = "ISEC-Telecom_Groups.csv"
    $FullGroupsCSVPath = $PathToGroupsCSV + $GroupsCSVName
    $URLtoGroupsCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/Groups/CSV/ISEC-Telecom_Groups.csv"


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

Create-Groups

# Import Users
function Create-Users # OK !
{


    $PathToUsersCSV = "$SharesPath\InitialServerDeploy$\Users\CSV\"
    $UsersCSVName = "ISEC-Telecom_Users.csv"
    $FullUsersCSVPath = $PathToUsersCSV + $UsersCSVName
    $URLtoUsersCSV = "https://raw.githubusercontent.com/joeldidier/ActiveDirectory-Monitoring-CESI-Project/master/assets/Users/CSV/ISEC-Telecom_Users.csv"


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
            Write-Host [INFO] Adding $User.'DisplayNameSurname' $($User.'Login') into $ADGroup. -ForegroundColor Cyan
            Add-ADGroupMember -Identity $ADGroup -Members $User.'Login'
        }
    }
        
    }

    Write-Host "[INFO] Added $UserCount user(s) to Active Directory." -ForegroundColor Cyan

}

Create-Users


Write-Host "Done!"
pause

