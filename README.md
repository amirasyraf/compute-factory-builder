# Compute Factory — Bake

Builds an official Canonical Ubuntu 26.04 amd64 image in the default AWS VPC
with Packer and Ansible. Pushes to `main` and manual dispatch run the image
matrix in `images.yaml`. AWS authentication uses OIDC (`AWS_ROLE_ARN` and
`AWS_REGION` repository variables); the CA public key is read from SSM at build
time and is never committed. Private CA material is not used during bake.

The image includes base utilities, UTC, provenance in
`/etc/compute-factory/image-info.json`, and SSH CA trust. Software selections are
installed later by the platform repo's fry playbooks.

## Local checks

Install Packer 1.16.2 and Python 3.12–3.14, then
`pip install -r requirements-ansible.txt`. Run `packer init packer/ubuntu`,
`packer fmt -check packer/ubuntu`, `packer validate -syntax-only packer/ubuntu`,
and `ansible-playbook --syntax-check -i localhost, ansible/bake.yml`.

For a local build, export `PKR_VAR_source_ami` (Canonical's Ubuntu 26.04 public
SSM AMI ID), `PKR_VAR_ssh_ca_public_key`, `PKR_VAR_git_sha`, and AWS credentials,
then run `packer build -only=amazon-ebs.ubuntu packer/ubuntu`.

## Extend

Add an OS directory under `packer/`, its role task files (Windows stubs currently
fail explicitly), and a row in `images.yaml`. Add another platform with
`source.<platform>.pkr.hcl` beside the OS build file, then extend the workflow's
authentication/source selector and add a matrix row. Keep common guest setup in
Ansible, not in platform-specific sources. Update both repos together when
changing the exact Ansible pin.
