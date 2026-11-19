# Azure: generalize the image. Every wait has a deadline; failures print sysprep's error log.
$ErrorActionPreference = 'Stop'
foreach ($service in 'RdAgent', 'WindowsAzureGuestAgent') {
  $deadline = (Get-Date).AddMinutes(10)
  while ((Get-Service $service).Status -ne 'Running') {
    if ((Get-Date) -gt $deadline) { throw "$service did not start" }
    Start-Sleep -Seconds 5
  }
}
# Sysprep refuses app packages installed for a user but not provisioned for all users (0x80073cf2):
# such as the WinGet source the bake's check downloads. Remove those apps (sysprep does not check
# frameworks, which App Installer depends on). App Installer itself is provisioned by the bake.
$provisioned = (Get-AppxProvisionedPackage -Online).PackageName
Get-AppxPackage -AllUsers |
  Where-Object { $_.SignatureKind -ne 'System' -and -not $_.IsFramework -and -not $_.NonRemovable -and $provisioned -notcontains $_.PackageFullName } |
  ForEach-Object {
    Write-Output "Removing unprovisioned package $($_.PackageFullName)"
    Remove-AppxPackage -Package $_.PackageFullName -AllUsers
  }
Start-Process -Wait -FilePath "$env:SystemRoot\System32\Sysprep\Sysprep.exe" -ArgumentList '/oobe', '/generalize', '/quiet', '/quit', '/mode:vm'
$state = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State'
$deadline = (Get-Date).AddMinutes(2)
while ((Get-ItemProperty $state).ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
  if ((Get-Date) -gt $deadline) {
    Get-Content "$env:SystemRoot\System32\Sysprep\Panther\setuperr.log" -Tail 20
    throw "sysprep did not generalize the image: $((Get-ItemProperty $state).ImageState)"
  }
  Start-Sleep -Seconds 10
}
Write-Output (Get-ItemProperty $state).ImageState
