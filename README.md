# Compute Factory — Bake

Builds an official Canonical Ubuntu 26.04 amd64 image with Packer and Ansible on
every platform in `images.yaml`: an AMI in the default AWS VPC, and an Azure
Compute Gallery version of `cf-images/cfimages/ubuntu` (from Canonical's
Marketplace image `ubuntu-26_04-lts/server`, Gen2; version `1.<YYYYMMDD>.<hhmmss>`,
generalized with `waagent -deprovision+user`). Pushes to `main` and manual
dispatch run the matrix. Authentication is OIDC only: AWS (`AWS_ROLE_ARN`,
`AWS_REGION`) for every row, because the CA public key is read from SSM at build
time and is never committed; Azure (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`, `AZURE_LOCATION`, `azure/login`) for Azure rows. The
gallery and image definition are created by the orchestrator's `infra/`. Private
CA material is not used during bake.

The image includes base utilities, UTC, provenance in
`/etc/compute-factory/image-info.json`, and SSH CA trust (principals file for the
OS login user, `cf_ssh_user`, which may differ from the Packer build user). Software selections are
installed later by the platform repo's fry playbooks.

## Local checks

Install Packer 1.16.2 and Python 3.12–3.14, then
`pip install -r requirements-ansible.txt`. Run `packer init packer/ubuntu`,
`packer fmt -check packer/ubuntu`, `packer validate -syntax-only packer/ubuntu`,
and `ansible-playbook --syntax-check -i localhost, ansible/bake.yml`.

For a local build, export `PKR_VAR_ssh_ca_public_key`, `PKR_VAR_git_sha` and, for AWS,
`PKR_VAR_source_ami` (Canonical's Ubuntu 26.04 public SSM AMI ID) with AWS credentials, then run
`packer build -only=amazon-ebs.ubuntu packer/ubuntu`; for Azure, `PKR_VAR_azure_subscription_id`
with an `az login`, then `packer build -only=azure-arm.ubuntu packer/ubuntu`.

## Extend

Add an OS directory under `packer/`, its role task files (Windows stubs currently
fail explicitly), and a row in `images.yaml`. Add another platform with
`source.<platform>.pkr.hcl` beside the OS build file (any platform-specific
generalization as an `only` provisioner), then extend the workflow's
authentication/source selector and add a matrix row. Keep common guest setup in
Ansible, not in platform-specific sources. Update both repos together when
changing the exact Ansible pin.
