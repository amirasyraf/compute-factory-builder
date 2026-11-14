packer {
  required_version = ">= 1.16.0, < 2.0.0"
  required_plugins {
    amazon = {
      version = ">= 1.3.0, < 2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0, < 2.0.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "source_ami" {
  type        = string
  description = "Official Canonical AMI, resolved from the Ubuntu 26.04 public SSM parameter."
}

variable "git_sha" {
  type = string
}

variable "ssh_ca_public_key" {
  type      = string
  sensitive = true
}

locals {
  build_date = timestamp()
  image_name = "cf-ubuntu-26.04-${formatdate("YYYYMMDDhhmmss", local.build_date)}"
  image_tags = {
    "cf:os"         = "ubuntu"
    "cf:os-family"  = "linux"
    "cf:os-version" = "26.04"
    "cf:managed"    = "true"
    "cf:poc"        = "true"
    "cf:git-sha"    = var.git_sha
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = ["sudo cloud-init status --wait"]
  }

  provisioner "ansible" {
    playbook_file = "${path.root}/../../ansible/bake.yml"
    user          = "ubuntu"
    use_proxy     = false
    extra_arguments = ["--extra-vars", jsonencode({
      cf_image_name        = local.image_name
      cf_build_date        = local.build_date
      cf_git_sha           = var.git_sha
      cf_ssh_ca_public_key = var.ssh_ca_public_key
    })]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
