source "amazon-ebs" "ubuntu" {
  region                      = var.region
  source_ami                  = var.source_ami
  instance_type               = "t3.small"
  ssh_username                = "ubuntu"
  ssh_timeout                 = "10m"
  ssh_clear_authorized_keys   = true
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
