<powershell>
# EC2 user data for the Packer build only: a WinRM HTTPS listener with a self-signed certificate,
# NTLM authentication (Basic stays off). The image's security group never exposes port 5986.
$ErrorActionPreference = 'Stop'
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName 'packer'
Get-ChildItem WSMan:\localhost\Listener | Where-Object { $_.Keys -contains 'Transport=HTTPS' } | Remove-Item -Recurse -Force
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force | Out-Null
Set-Item WSMan:\localhost\MaxTimeoutms 1800000
Set-Item WSMan:\localhost\Service\Auth\Basic $false
New-NetFirewallRule -Name WinRM-HTTPS-Packer -DisplayName 'WinRM HTTPS (Packer build)' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow | Out-Null
Restart-Service WinRM
</powershell>
