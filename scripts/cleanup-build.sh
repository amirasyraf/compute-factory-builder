#!/usr/bin/env bash
# Remove what a cancelled, timed-out or failed Packer build left behind: only resources tagged with
# this job's cf:bake-run, and only Packer's temporary ones (images are never touched here).
set -euo pipefail
run=${CF_BAKE_RUN:?}
case "${CF_PLATFORM:?}" in
  aws)
    tag=("Name=tag:cf:bake-run,Values=$run")
    read -r -a instances <<< "$(aws ec2 describe-instances --filters "${tag[@]}" \
      Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId' --output text)"
    if (( ${#instances[@]} )); then
      echo "Terminating build instances: ${instances[*]}"
      aws ec2 terminate-instances --instance-ids "${instances[@]}" >/dev/null
      aws ec2 wait instance-terminated --instance-ids "${instances[@]}"
    fi
    for group in $(aws ec2 describe-security-groups --filters "${tag[@]}" 'Name=group-name,Values=packer_*' \
        --query 'SecurityGroups[].GroupId' --output text); do
      echo "Deleting build security group $group"
      aws ec2 delete-security-group --group-id "$group" >/dev/null
    done
    for key in $(aws ec2 describe-key-pairs --filters "${tag[@]}" 'Name=key-name,Values=packer_*' \
        --query 'KeyPairs[].KeyPairId' --output text); do
      echo "Deleting build key pair $key"
      aws ec2 delete-key-pair --key-pair-id "$key" >/dev/null
    done
    ;;
  azure)
    for group in $(az group list --query "[?tags.\"cf:bake-run\"=='$run' && starts_with(name, 'pkr-')].name" -o tsv); do
      echo "Deleting build resource group $group"
      az group delete --name "$group" --yes
    done
    ;;
  *) echo "Unsupported platform $CF_PLATFORM" >&2; exit 1 ;;
esac
echo "No build resources of $run remain"
