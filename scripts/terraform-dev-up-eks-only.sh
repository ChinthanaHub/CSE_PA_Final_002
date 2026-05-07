#!/usr/bin/env bash
set -euo pipefail

# Recreate only the EKS cluster in the dev Terraform environment.
# This assumes VPC, IAM, logging, secrets, and security resources already exist.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev"
cd "${TF_DIR}"

echo "Bringing up only EKS cluster from ${TF_DIR}"

export AWS_REGION="${AWS_REGION:-us-east-1}"

terraform init -input=false

# Optional: validate configuration before applying
terraform validate

# Target only the EKS module to recreate just the cluster
terraform plan -target=module.eks -out=tfplan-eks.bin -input=false
terraform apply -auto-approve tfplan-eks.bin

rm -f tfplan-eks.bin

echo "EKS cluster apply complete. Cluster is now up."
