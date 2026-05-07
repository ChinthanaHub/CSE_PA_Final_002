#!/usr/bin/env bash
set -euo pipefail

# Destroy EKS cluster only, leaving VPC, IAM, and KMS resources intact.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev-eks-only"
cd "${TF_DIR}"

echo "Destroying EKS cluster only from ${TF_DIR}"

export AWS_REGION="${AWS_REGION:-us-east-1}"

terraform init -input=false

# Optional: validate before destroying
terraform validate

terraform plan -destroy -out=tfdestroy-eks-only.plan -input=false
terraform apply -auto-approve tfdestroy-eks-only.plan

rm -f tfdestroy-eks-only.plan

echo "EKS cluster destroy complete. VPC, IAM, and KMS resources remain intact."