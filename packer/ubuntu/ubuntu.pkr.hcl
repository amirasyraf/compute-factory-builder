packer {
  required_version = ">= 1.16.0, < 2.0.0"
  required_plugins {
    amazon = {
      version = ">= 1.3.0, < 2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      version = ">= 2.6.0, < 3.0.0"
      source  = "github.com/hashicorp/azure"
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
  default     = ""
  description = "AWS only: official Canonical AMI, resolved from the Ubuntu 26.04 public SSM parameter."
}

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_location" {
  type    = string
  default = "australiaeast"
}

variable "git_sha" {
  type = string
}

variable "ssh_ca_public_key" {
  type      = string
  sensitive = true
}

variable "ssh_ca_fingerprint" {
  type        = string
  description = "OpenSSH SHA256 fingerprint of ssh_ca_public_key; tagged so ./poc can match images to the current CA."
  validation {
    condition     = can(regex("^SHA256:[A-Za-z0-9+/]{43}$", var.ssh_ca_fingerprint))
    error_message = "Pass the SHA256 fingerprint printed by ssh-keygen -lf for the CA public key."
  }
}

locals {
  build_date = timestamp()
  image_name = "cf-ubuntu-26.04-${formatdate("YYYYMMDDhhmmss", local.build_date)}"
  # Azure gallery versions are three integers; leading zeros are not allowed.
  gallery_version = "1.${formatdate("YYYYMMDD", local.build_date)}.${regex_replace(formatdate("hhmmss", local.build_date), "^0+(.)", "$1")}"
  # The OS login user created at launch on every platform.
  ssh_user = "ubuntu"
  image_tags = {
    "cf:os"         = "ubuntu"
    "cf:os-family"  = "linux"
    "cf:os-version" = "26.04"
    "cf:managed"    = "true"
    "cf:poc"        = "true"
    "cf:git-sha"    = var.git_sha
    # The baked CA trust; an image is reusable only while this CA exists.
    "cf:ssh-ca-fingerprint" = var.ssh_ca_fingerprint
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu", "source.azure-arm.ubuntu"]

  provisioner "shell" {
    inline = ["sudo cloud-init status --wait"]
  }

  provisioner "ansible" {
    playbook_file = "${path.root}/../../ansible/bake.yml"
    use_proxy     = false
    extra_arguments = ["--extra-vars", jsonencode({
      cf_image_name        = local.image_name
      cf_build_date        = local.build_date
      cf_git_sha           = var.git_sha
      cf_ssh_ca_public_key = var.ssh_ca_public_key
      cf_ssh_user          = local.ssh_user
    })]
  }

  # Azure images must be generalized; this also removes the temporary Packer build user.
  provisioner "shell" {
    only            = ["azure-arm.ubuntu"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline          = ["/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
    skip_clean      = true
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
