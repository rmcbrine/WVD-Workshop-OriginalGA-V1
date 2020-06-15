#_____________________Update PowerShell Simple Steps____________________________________________

#If you are not running PowerShell as Administrator, none of this works... If you did NOT run as Admin, quit now and re-start ISE as Administrator

    Set-ExecutionPolicy Unrestricted

# Install / Update core Azure RM Modules regularly:
    #Install the full modules:
    Install-Module -AllowClobber -Force AzureRM
    Install-Module -AllowClobber -Force -Name Microsoft.RDInfra.RDPowerShell
    
    #Update commands
    Update-Module -Name AzureRM
    Update-Module -Name Microsoft.RDInfra.RDPowerShell

#_____________________Variable Definition Section#_____________________
# Choose these names first - some you have to copy/paste (anything labeled Insert)
# Some you have to invent today (anything labeled "Replace with Desired...")
# No spaces, caps matter, no special characters
# EVERY time you re-open PowerShell ISE, you have to select these lines & run them to refresh variables for the session
# EVERY ADMIN MUST HAVE THE SAME INFO HERE - EVERYONE ON THE TEAM NEEDS TO GET THIS RIGHT BEFORE MOVING ON
$SubGUID = "InsertYourSubscriptionGUIDHere"
$SubGUID
$AADGUID = "INSERTYOURAADGUIDHERE"
$AADGUID 
$WVDTenantName = "ReplaceWithDesiredNameofWVDTenant"
$WVDTenantName
$HostPoolNameDesktops = "ReplaceWithDesiredNameofDesktopHostpool"
$HostPoolNameDesktops
$HostPoolNameApps = "ReplaceWithDesiredNameofAppsHostpool"
$HostPoolNameApps
$AppGroupName = "ReplaceWithDesiredNameofAppGroup"
$AppGroupName

#_____________________Login to both AAD and WVD, then get AAD GUID#_____________________

# Login to Azure so you can deploy VMs to your Azure Subscription - you must have Contributor or Owner rights
    Login-AzureRmAccount -Subscription $SubGUID
    # IMPORTANT - output of this command will show you which Azure Subscription your VMs will be built in
    # If it's the "wrong" subscription showing, correct the $SubGUID variable, above and re-run the variable definition, then re-do

# Login to WVD: This doesn't "look" like a login command, but it is :-) 
    Add-RdsAccount –DeploymentUrl “https://rdbroker.wvd.microsoft.com” #You must login with a UPN that has been assigned Tenant Creator role in AAD
    # IMPORTANT - if this fails, then we need to re-visit AAD and add you to WVD as a Tenant Admin
    # Instructions: https://docs.microsoft.com/en-us/azure/virtual-desktop/tenant-setup-azure-active-directory#assign-the-tenantcreator-application-role

# To find out your AAD Tenant ID, go to the website shown & copy/paste this GUID into Notepad for later use:
    https://www.whatismytenantid.com/

#_____________________Create a New WVD Tenant#_____________________

#Create WVD Tenant command (WE ONLY NEED ONE TENANT - DO NOT CREATE MORE THAN ONE):
New-RdsTenant -Name $WVDTenantName -AadTenantId $AADGUID -AzureSubscriptionId $SubGUID

#Validate WVD Tenant created: 
    Get-RdsTenant $WVDTenantName

#Add the rest of your team as RDS Owners of your Tenant:
    New-RdsRoleAssignment -TenantName $WVDTenantName -RoleDefinitionName "RDS Owner" -SignInName team1userb@customdomain.net
        # Add the other UPN’s from your Team to the Tenant using the above command / Change the UPN for –SignInName for each user

# After being added, have each newly-added Tenant Admin run the following cmdlet to list the WVD tenant(s) for which they have access: 
    Get-RdsTenant

#_____________________DEPLOY REMOTEDESKTOPS_____________________

# 1. Reference to deploy a HostPool https://docs.microsoft.com/en-us/learn/modules/m365-deploy-wvd/provision-host-pool

# 1a. Once HostPool is deployed, run this command to see it's details:
    Get-RDSHostPool $WVDTenantName

# 2. Give Test User accounts and/or the rest of your team access per the code below
    # format to add users: Add-RdsAppGroupUser <tenantname> <hostpoolname> “Desktop Application Group” -UserPrincipalName <userupn>
    Add-RdsAppGroupUser $WVDTenantName $HostPoolNameDesktops “Desktop Application Group” -UserPrincipalName willy@customdomain.net

    # Command to remove a user (just so you have them/not really part of the lab)
        #Remove-RdsAppGroupUser $WVDTenantName $HostPoolNameDesktops “Desktop Application Group” -UserPrincipalName team1usera@customdomain.net

    # URL to acccess your published VMs:
        https://rdweb.wvd.microsoft.com/webclient/
        # Or, if you can't remember that (I never can) just go to:
        https://aka.ms/wvdweb

    # If you LATER (not now) want to create a custom URL, check this out in future:
        # http://xenithit.blogspot.com/2020/02/create-corporate-url-for-windows.html

# 3. Enumerate all users who can access these desktops:
        Get-RdsAppGroupUser -TenantName $WVDTenantName -HostPoolName $HostPoolNameDesktops -AppGroupName "Desktop Application Group"

# 4. This command sets the host pool to be a validation host pool - it will receive service updates at a faster cadence, allowing you to test any service changes before they are deployed broadly in production.
        Set-RdsHostPool -TenantName $WVDTenantName -HostPoolName $HostPoolNameDesktops -ValidationEnv $true

#_____________________DEPLOY REMOTEAPPS_____________________

# 1. Deploy a HostPool and do not add any Default Users during creation (users can't access both desktop and apps same hostpool)

# 2. Create a new RemoteApp app group
    # Format: New-RdsAppGroup <tenantname> <hostpoolname> <appgroupname> -ResourceType "RemoteApp"
    New-RdsAppGroup $WVDTenantName $HostPoolNameApps $AppGroupName -ResourceType "RemoteApp"
    # Verify AppGroup was created
    Get-RdsAppGroup $WVDTenantName $HostPoolNameApps

# 3. Get a list of start menu apps on the host pool's virtual machine image & output to a text file for searching
    # Format: Get-RdsStartMenuApp <tenantname> <hostpoolname> <appgroupname>
    # IMPORTANT: First create a folder at root of your local C: drive called c:\scratch
    Get-RdsStartMenuApp $WVDTenantName $HostPoolNameApps $AppGroupName | Out-File -FilePath c:\scratch\applist.txt


# 4. Run the following cmdlet to install the application based on its appalias
    # Format: New-RdsRemoteApp <tenantname> <hostpoolname> <appgroupname> -Name <remoteappname> -AppAlias <appalias>
    # Examples of Commonly-published Apps:
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "Word" -AppAlias word
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "Excel" -AppAlias excel
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "PowerPoint" -AppAlias powerpoint
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "Outlook" -AppAlias outlook
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "MSPaint" -AppAlias paint
        # This one is just cool: opens a browser to a specific URL and uses "FriendlyName argument to put a custom name on the Chrome icon
        New-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName -Name "Chrome" -AppAlias googlechrome -FriendlyName "MSN" -CommandLineSetting Require -RequiredCommandLine "--allow-no-sandbox-job --disable-gpu https://www.msn.com"
    
    # Example code to remove a published app    
        #Remove-RdsRemoteApp <Tenant Name> <Host Pool Name> <Application Group Name> -Name <Friendly Name>

# 4.a. Verify RemoteApps show up in the AppGroup:
    Get-RdsRemoteApp $WVDTenantName $HostPoolNameApps $AppGroupName

# 7. Run the following cmdlet to grant users access to the RemoteApps in the app group:
    # Example:
    Add-RdsAppGroupUser $WVDTenantName $HostPoolNameApps $AppGroupName -UserPrincipalName willy@customdomain.net
    # Example to remove: Remove-RdsAppGroupUser <Tenant Name> <Host Pool Name> <Application Group Name> -UserPrincipalName <user@domain.com>

# 8. Enumerate access to App Groups
    Get-RdsAppGroupUser -TenantName $WVDTenantName -HostPoolName $HostPoolNameApps -AppGroupName $AppGroupName

#_____________________AUDITING AND ADMINISTRATIVE COMMANDS_____________________

#Administration and Troubleshooting Commands:

# Enumerate HostPools
    Get-RdsHostPool -TenantName $WVDTenantName

# Enumerate VMs that constitute each HostPool - tells you a lot about status of VMs, how many sessions, etc.
    Get-RdsSessionHost -TenantName $WVDTenantName -HostPoolName $HostPoolNameDesktops
    Get-RdsSessionHost -TenantName $WVDTenantName -HostPoolName $HostPoolNameApps

# Enumerate who has which role
    Get-RdsRoleAssignment -TenantName $WVDTenantName -HostPoolName $HostPoolNameDesktops -AppGroupName "Desktop Application Group"

# Find out a specific user's role:
    Get-RdsRoleAssignment -SignInName "user@customdomain.net"

# Assign a specific role
    New-RdsRoleAssignment -RoleDefinitionName "RDS Owner" -SignInName "user@customdomain.net" -TenantGroupName "Default Tenant Group" -TenantName $WVDTenantName

#Managing User Sessions

# Show active user sessions - use these to get SessionHostName and SessionID for further commands
    Get-RdsUserSession $WVDTenantName $HostPoolNameDesktops
    Get-RdsUserSession $WVDTenantName $HostPoolNameApps

# Send Users a message
    Send-RdsUserSessionMessage $WVDTenantName $HostPoolNameDesktops -SessionHostName "SessionHostName" -SessionId 1111 -MessageTitle "Test announcement" -MessageBody "Test message."
    Send-RdsUserSessionMessage $WVDTenantName $HostPoolNameApps -SessionHostName "SessionHostName" -SessionId 1111 -MessageTitle "Test announcement" -MessageBody "Test message."

# Disconnect Users
    Disconnect-RdsUserSession $WVDTenantName $HostPoolNameDesktops -SessionHostName "SessionHostName" -SessionId 1111 #you must replace SessionID with correct number
    Disconnect-RdsUserSession $WVDTenantName $HostPoolNameApps -SessionHostName "SessionHostName" -SessionId 1111 #you must replace SessionID with correct number

# Logoff Users
    Invoke-RdsUserSessionLogoff $WVDTenantName $HostPoolNameDesktops -SessionHostName "SessionHostName" -SessionId 1111 #you must replace SessionID with correct number
    Invoke-RdsUserSessionLogoff $WVDTenantName $HostPoolNameApps -SessionHostName "SessionHostName" -SessionId 1111 #you must replace SessionID with correct number


#_____________________DIAGNOSTICS OUTPUT FOR TROUBLESHOOTING_____________________

# When you get an error and need more info for troubleshooting: https://docs.microsoft.com/en-us/azure/virtual-desktop/diagnostics-role-service
 
    # Get all Diagnostics across the WVD Tenant
    Get-RdsDiagnosticActivities -TenantName $WVDTenantName -Detailed

    # Get Diagnostics related to a specific user:
    Get-RdsDiagnosticActivities -UserName "rich@customdomain.net" -TenantName “$WVDTenantName” -StartTime “2/20/2020 8:45:00” | Out-File -FilePath c:\scratch\errors.txt


#_____________________DELETE THINGS_____________________

Get-RdsTenant
#Use output from above to find Tenant name and copy/paste into $DELWVDTenantName variable, below

    $DELWVDTenantName = "Paste in the Tenant containing whatever you want to delete"
    $DELWVDTenantName

Get-RdsHostPool $DELWVDTenantName
#Use output from above to find Host Pool name and copy/paste into $DELHostPoolID variable, below

    $DELHostPoolName = "Paste in the Host Pool containing whatever you want to delete"
    $DELHostPoolName

Get-RdsAppGroup -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolID
#Use output from above to find App Group name(s) and copy/paste into $DELAppGroupName variables, below

    $DELAppGroupName = "Paste in the App Group containing whatever you want to delete"
    $DELAppGroupName

    $DELAppGroupName = "Desktop Application Group"
    $DELAppGroupName

# Walk through next steps with one of these $DELAppGroupName selected/run, then come back later and do the next one; need to be run through once per Host Pool

# FIRST remove RemoteApps published, one by one
    Get-RdsRemoteApp -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName -AppGroupName $DELAppGroupName
    Remove-RdsRemoteApp -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName -AppGroupName $DELAppGroupName -Name "Type in the name of the app you want to un-publish"

# SECOND remove AppGroups
    Get-RdsAppGroup -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName
    Remove-RdsAppGroup -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName -AppGroupName $DELAppGroupName

# THIRD remove each SessionHost
    Get-RdsSessionHost -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName
    # Use output from above to get each SessionHost by name and replace in the following lines, then run each line to drop each host (run command per host)
        Remove-RdsSessionhost -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName -Name "Type in the name of each Host name"

# FOURTH REmove The HostPool
    Remove-RdsHostPool -TenantName $DELWVDTenantName -HostPoolName $DELHostPoolName

# Once all HostPools are deleted, move on to deleting the Tenant
# FIFTH Remove the Tenant
    Remove-RdsTenant -Name $DELWVDTenantName 