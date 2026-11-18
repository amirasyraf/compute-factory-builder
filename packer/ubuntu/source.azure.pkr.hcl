source "azure-arm" "ubuntu" {
  # The workflow logs the CLI in with GitHub OIDC (azure/login); no secret.
  use_azure_cli_auth = true
  subscription_id    = var.azure_subscription_id
  location           = var.azure_location
  os_type            = "Linux"
  image_publisher    = "Canonical"
  image_offer        = "ubuntu-26_04-lts"
  image_sku          = "server"
  image_version      = "latest"
  # A size with vCPU quota in the subscription; it supports only NVMe disks.
  vm_size              = "Standard_D2ls_v6"
  disk_controller_type = "NVMe"
  ssh_timeout          = "10m"

  shared_image_gallery_destination {
    subscription            = var.azure_subscription_id
    resource_group          = "cf-images"
    gallery_name            = "cfimages"
    image_name              = "ubuntu"
    image_version           = local.gallery_version
    use_shallow_replication = true
  }

  # Tags the temporary build resource group and everything in it, plus the image version.
  azure_tags = local.image_tags
}
