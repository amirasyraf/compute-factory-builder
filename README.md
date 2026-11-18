# Compute Factory — Bake

Builds golden images with Packer and Ansible for every `images.yaml` row: Ubuntu 26.04
(`packer/ubuntu`) and Windows Server 2025 (`packer/windows`), each on AWS and Azure. Ubuntu is built
from the official Canonical amd64 image: an AMI in the default AWS VPC, and an Azure
Compute Gallery version of `cf-images/cfimages/ubuntu` (from Canonical's
Marketplace image `ubuntu-26_04-lts/server`, Gen2; version `1.<YYYYMMDD>.<hhmmss>`,
generalized with `waagent -deprovision+user`). Pushes to `main` and manual
dispatch run the matrix unless repository variable `CF_POC_MAINTENANCE=1` is set
by teardown. Authentication is OIDC only: AWS (`AWS_ROLE_ARN`,
`AWS_REGION`) for every row, because the CA public key is read from SSM at build
time and is never committed; Azure (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`, `AZURE_LOCATION`, `azure/login`) for Azure rows. The
CA, gallery and image definition are created by the orchestrator's `infra/images`
root. Private CA material is not used during bake.

Every AMI, snapshot and gallery version is tagged `cf:ssh-ca-fingerprint` with the
OpenSSH SHA256 fingerprint of the baked CA public key (`ssh-keygen -lf`). The
orchestrator reuses an image only while that CA exists, and `./poc up
--images-only` dispatches this workflow, verifies every `images.yaml` row and
removes superseded images.

The image includes base utilities, UTC, provenance in
`/etc/compute-factory/image-info.json`, and SSH CA trust (principals file for the
OS login user, `cf_ssh_user`, which may differ from the Packer build user). Software selections are
installed later by the platform repo's fry playbooks.

Windows Server 2025 (`packer/windows`, `os_version` from the row): AWS from Amazon's
`Windows_Server-2025-English-Full-Base` AMI (public SSM parameter, owner `801119661308`), Azure from
`MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2` into gallery definition `windows-2025`. Packer
connects over WinRM HTTPS with NTLM (`winrm.ps1` user data on AWS; Packer's temporary Key Vault
certificate on Azure) and runs the same `bake.yml` over WinRM (`pywinrm`, `ansible/connection/windows.yml`,
collections from `ansible/requirements.yml`). The image gets OpenSSH Server with PowerShell as its shell
and a certificates-only `sshd_config` (port forwarding allowed for browser RDP), the principals file for
`Administrator` (AWS) or `cfadmin` (Azure), UTC, Remote Desktop allowed, provenance in
`C:\ProgramData\ComputeFactory\image-info.json`, and the `Microsoft.WinGet.Client` module for all users.
AWS finishes with `ec2launch reset`, Azure with sysprep. No Windows updates are applied at bake time.
A Windows bake takes much longer than Ubuntu; the job timeout is 90 minutes.

## Local checks

Install Packer 1.16.2 and Python 3.12–3.14, then
`pip install -r requirements-ansible.txt` and `ansible-galaxy collection install -r ansible/requirements.yml`.
For each of `packer/ubuntu` and `packer/windows` run `packer init`, `packer fmt -check` and
`packer validate -syntax-only`, then `ansible-playbook --syntax-check -i localhost, ansible/bake.yml`.

For a local build, export `PKR_VAR_ssh_ca_public_key`, its `PKR_VAR_ssh_ca_fingerprint`
(`SHA256:…` from `ssh-keygen -lf`), `PKR_VAR_git_sha` and, for AWS,
`PKR_VAR_source_ami` (Canonical's Ubuntu 26.04 public SSM AMI ID) with AWS credentials, then run
`packer build -only=amazon-ebs.ubuntu packer/ubuntu`; for Azure, `PKR_VAR_azure_subscription_id`
with an `az login`, then `packer build -only=azure-arm.ubuntu packer/ubuntu`.

## Extend

Add an OS directory under `packer/` (named after the `images.yaml` `os`), its role task files, its base
image case in the workflow, and a row in `images.yaml`. Add another platform with
`source.<platform>.pkr.hcl` beside the OS build file (any platform-specific
generalization as an `only` provisioner), then extend the workflow's
authentication/source selector and add a matrix row. Keep common guest setup in
Ansible, not in platform-specific sources. Update both repos together when
changing the exact Ansible pin.
