#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-apply}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory.ini"

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/kijanikiosk-key-aws.pem}"
ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"

cd "$TERRAFORM_DIR"

echo "=== Terraform init ==="
terraform init

if [[ "$MODE" == "verify" ]]; then
  echo "=== Terraform plan verification ==="

  set +e
  terraform plan -detailed-exitcode
  PLAN_EXIT=$?
  set -e

  if [[ "$PLAN_EXIT" -eq 1 ]]; then
    echo "Terraform plan failed"
    exit 1
  elif [[ "$PLAN_EXIT" -eq 2 ]]; then
    echo "Terraform detected changes during verify mode"
    exit 2
  fi
else
  echo "=== Terraform apply ==="
  terraform apply -auto-approve
fi

echo "=== Extracting Terraform outputs ==="
API_IP="$(terraform output -json public_ips | jq -r '.api')"
PAYMENTS_IP="$(terraform output -json public_ips | jq -r '.payments')"
LOGS_IP="$(terraform output -json public_ips | jq -r '.logs')"

if [[ -z "$API_IP" || -z "$PAYMENTS_IP" || -z "$LOGS_IP" ]]; then
  echo "Failed to extract one or more Terraform IP outputs"
  exit 1
fi

echo "=== Writing Ansible inventory ==="
cat > "$INVENTORY_FILE" <<EOF
[kijanikiosk]
api-staging ansible_host=${API_IP}
payments-staging ansible_host=${PAYMENTS_IP}
logs-staging ansible_host=${LOGS_IP}

[kijanikiosk:vars]
ansible_user=${ANSIBLE_USER}
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_ssh_common_args=-o StrictHostKeyChecking=accept-new
EOF

cat "$INVENTORY_FILE"

cd "$ANSIBLE_DIR"

echo "=== Testing Ansible connectivity ==="
ansible all -i inventory.ini -m ping

echo "=== Running Ansible playbook ==="
ansible-playbook -i inventory.ini kijanikiosk.yml