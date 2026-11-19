# Vendy image builder

This repo builds the golden images Vendy uses when it provisions a VM. [`images.yaml`](images.yaml)
lists the four builds: Ubuntu 26.04 and Windows Server 2025, each on AWS and Azure. Ubuntu is built
from the official Canonical amd64 image: an AMI in the default AWS VPC, and an Azure
Compute Gallery version of `cf-images/cfimages/ubuntu` (from Canonical's
Marketplace image `ubuntu-26_04-lts/server`, Gen2; version `1.<YYYYMMDD>.<hhmmss>`,
generalized with `waagent -deprovision+user`). The workflow runs on manual dispatch or on pushes to
`main` that change Packer, Ansible, the matrix, requirements, or the workflow. Teardown disables it
and sets `CF_POC_MAINTENANCE=1`. Workflow authentication uses OIDC: AWS (`AWS_ROLE_ARN`,
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
`C:\ProgramData\ComputeFactory\image-info.json`, PowerShell 7.6 LTS, WinGet (App Installer, pinned release) provisioned for all users, and the
`Microsoft.WinGet.Client` module for all users (as SYSTEM it works only in PowerShell 7).
AWS finishes with `ec2launch reset`, Azure with sysprep. No Windows updates are applied at bake time.
Each matrix job has a 60-minute timeout. Windows is usually slower than Ubuntu. The Ubuntu
`cloud-init status --wait` command has no separate deadline. Before sysprep, Azure removes app
packages installed for a user but not provisioned for all users (such as the WinGet source), which
sysprep otherwise refuses (0x80073cf2).

When a job fails or is cancelled, the workflow attempts cleanup by its `cf:bake-run` tag. The cleanup
step can also be interrupted, so cancellation or timeout does not guarantee that all build resources
are gone. It never deletes published images. Check the failed job's log and use the POC lifecycle
runbook if leftovers remain.

## Local checks

Use Packer 1.16.2 and Python 3.14 to match the runner. In a Python virtual environment, run:

```sh
pip install -r requirements-ansible.txt
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook --syntax-check -i localhost, ansible/bake.yml
```

For each changed matrix row, run `packer init` and `packer fmt -check` on its OS directory. Then run
full `packer validate` with the same source selector and inputs as [the bake
workflow](.github/workflows/bake.yml). For example, `packer validate -only=amazon-ebs.ubuntu packer/ubuntu`
needs the matching `PKR_VAR_source_ami`, the build SHA, and the CA **public** key and its fingerprint.
Azure rows use `azure-arm.<os>`, the subscription and location, and Azure access. Windows uses
`PKR_VAR_os_version` from the matrix row. See the workflow for the exact inputs and their sources.

Before dispatching, exercise new or changed guest commands on a disposable instance of the same
OS and cloud. Syntax checks alone won't catch a stuck guest or broken sysprep. The workflow calls
`packer build`; it does not run a separate preflight. `./poc up --images-only` is a real bake and
can remove superseded images after verification.

## Extend

Add an OS directory under `packer/` (named after the `images.yaml` `os`), its role task files, its base
image case in the workflow, and a row in `images.yaml`. Add another platform with
`source.<platform>.pkr.hcl` beside the OS build file (any platform-specific
generalization as an `only` provisioner), then extend the workflow's
authentication/source selector and add a matrix row. Keep common guest setup in
Ansible, not in platform-specific sources. Update both repos together when
changing the exact Ansible pin.
