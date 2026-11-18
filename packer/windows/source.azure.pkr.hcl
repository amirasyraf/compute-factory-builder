source "azure-arm" "windows" {
  # The workflow logs the CLI in with GitHub OIDC (azure/login); no secret.
  use_azure_cli_auth = true
  subscription_id    = var.azure_subscription_id
  location           = var.azure_location
  os_type            = "Windows"
  image_publisher    = "MicrosoftWindowsServer"
  image_offer        = "WindowsServer"
  image_sku          = "${var.os_version}-datacenter-g2"
  image_version      = "latest"
  # A size with vCPU quota in the subscription; it supports only NVMe disks.
  vm_size              = "Standard_D2ls_v6"
  disk_controller_type = "NVMe"
  # Packer creates the WinRM certificate in a temporary Key Vault in the build resource group.
  communicator   = "winrm"
  winrm_username = "packer"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_use_ntlm = true
  winrm_timeout  = "20m"

  shared_image_gallery_destination {
    subscription            = var.azure_subscription_id
    resource_group          = "cf-images"
    gallery_name            = "cfimages"
    image_name              = "windows-${var.os_version}"
    image_version           = local.gallery_version
    use_shallow_replication = true
  }

  # Tags the temporary build resource group and everything in it, plus the image version.
  azure_tags = local.image_tags
}
