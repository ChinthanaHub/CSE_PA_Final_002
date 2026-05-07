#!/usr/bin/env bash
set -euo pipefail

# Destroy only the EKS cluster from the dev Terraform environment.
# This keeps VPC, IAM, logging, secrets, and security resources intact,
# destroying only the EKS cluster and related resources.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev"
cd "${TF_DIR}"

echo "Destroying only EKS cluster from ${TF_DIR}"

export AWS_REGION="${AWS_REGION:-us-east-1}"

terraform init -input=false

# Optional: validate before destroying
terraform validate

# Target only the EKS module to destroy just the cluster
terraform plan -destroy -target=module.eks -out=tfdestroy-eks.plan -input=false
terraform apply -auto-approve tfdestroy-eks.plan

rm -f tfdestroy-eks.plan

echo "EKS cluster destroy complete. VPC, IAM, logging, secrets, and security resources remain intact."
