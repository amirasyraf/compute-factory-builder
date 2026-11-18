source "amazon-ebs" "windows" {
  region        = var.region
  source_ami    = var.source_ami
  instance_type = "t3.large"
  # Packer reads the generated Administrator password with its temporary key pair.
  communicator                = "winrm"
  winrm_username              = "Administrator"
  winrm_use_ssl               = true
  winrm_insecure              = true
  winrm_use_ntlm              = true
  winrm_timeout               = "20m"
  windows_password_timeout    = "20m"
  user_data_file              = "${path.root}/winrm.ps1"
  ami_name                    = local.image_name
  associate_public_ip_address = true

  vpc_filter {
    filters = { "isDefault" = "true" }
  }
  subnet_filter {
    filters   = { "default-for-az" = "true" }
    most_free = true
    random    = false
  }

  tags            = local.image_tags
  snapshot_tags   = local.image_tags
  run_tags        = local.image_tags
  run_volume_tags = local.image_tags
}
