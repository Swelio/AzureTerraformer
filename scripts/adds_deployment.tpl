Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools

#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName "${domain_name}" `
-DomainNetbiosName "${netbios}" `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$true `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true `
-SafeModeAdministratorPassword:(ConvertTo-SecureString -AsPlainText "${safe_mode_admin_password}" -Force)

shutdown /r /t 20 /c \"Post-deployment installation complete.\" /f /d p:2:2