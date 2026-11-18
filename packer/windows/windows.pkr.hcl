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

variable "os_version" {
  type        = string
  default     = "2025"
  description = "Windows Server release (images.yaml version); selects the base image and gallery definition."
  validation {
    condition     = can(regex("^20[0-9]{2}$", var.os_version))
    error_message = "Use a Windows Server release such as 2025."
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "source_ami" {
  type        = string
  default     = ""
  description = "AWS only: Amazon's Windows Server <os_version> English Full Base AMI, from its public SSM parameter."
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
  image_name = "cf-windows-${var.os_version}-${formatdate("YYYYMMDDhhmmss", local.build_date)}"
  # Azure gallery versions are three integers; leading zeros are not allowed.
  gallery_version = "1.${formatdate("YYYYMMDD", local.build_date)}.${regex_replace(formatdate("hhmmss", local.build_date), "^0+(.)", "$1")}"
  # The OS login user each platform creates at launch: the built-in Administrator on AWS; Azure
  # forbids that name, so its VMs are launched with cfadmin (platform.json os.windows.sshUser).
  ssh_user = {
    "amazon-ebs" = "Administrator"
    "azure-arm"  = "cfadmin"
  }
  image_tags = {
    "cf:os"         = "windows"
    "cf:os-family"  = "windows"
    "cf:os-version" = var.os_version
    "cf:managed"    = "true"
    "cf:poc"        = "true"
    "cf:git-sha"    = var.git_sha
    # The baked CA trust; an image is reusable only while this CA exists.
    "cf:ssh-ca-fingerprint" = var.ssh_ca_fingerprint
  }
}

build {
  sources = ["source.amazon-ebs.windows", "source.azure-arm.windows"]

  # Over WinRM (pywinrm on the runner). Packer's inventory supplies the host and port (and asks for
  # Basic auth, which the connection file overrides with NTLM). Its ansible_user is the runner's
  # local user over WinRM, so the communicator's user and password are passed here.
  provisioner "ansible" {
    playbook_file = "${path.root}/../../ansible/bake.yml"
    use_proxy     = false
    extra_arguments = [
      "--extra-vars", "@${path.root}/../../ansible/connection/windows.yml",
      "--extra-vars", jsonencode({ ansible_user = build.User, ansible_password = build.Password }),
      "--extra-vars", jsonencode({
        cf_image_name        = local.image_name
        cf_build_date        = local.build_date
        cf_git_sha           = var.git_sha
        cf_ssh_ca_public_key = var.ssh_ca_public_key
        cf_ssh_user          = local.ssh_user[source.type]
      }),
    ]
  }

  # EC2Launch v2 runs again at the next boot (new Administrator password, disk extension). Current
  # EC2Launch v2 blocks until done (its --block flag is deprecated). No sysprep: the VMs are not
  # domain-joined, so the shared machine SID is acceptable for this POC.
  provisioner "powershell" {
    only   = ["amazon-ebs.windows"]
    inline = ["& \"$env:ProgramFiles\\Amazon\\EC2Launch\\ec2launch.exe\" reset"]
  }

  # Azure images must be generalized; Azure creates the login user at the next boot.
  provisioner "powershell" {
    only = ["azure-arm.windows"]
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while ($true) { $state = (Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State).ImageState; if ($state -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $state; Start-Sleep -s 10 } else { break } }",
    ]
  }

  post-processor "manifest" {
    output = "packer-manifest.json"
  }
}
