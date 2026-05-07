#!/usr/bin/env bash
set -euo pipefail

# Create EKS cluster only, referencing existing VPC, IAM, and KMS resources.
# This assumes VPC, IAM roles, and KMS keys already exist from previous deployments.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev-eks-only"
cd "${TF_DIR}"

echo "Creating EKS cluster only from ${TF_DIR}"

export AWS_REGION="${AWS_REGION:-us-east-1}"

terraform init -input=false

# Optional: validate configuration before applying
terraform validate

terraform plan -out=tfplan-eks-only.bin -input=false
terraform apply -auto-approve tfplan-eks-only.bin

rm -f tfplan-eks-only.bin

echo "EKS cluster creation complete."
echo "Cluster name: $(terraform output -raw cluster_name)"
echo "Cluster endpoint: $(terraform output -raw cluster_endpoint)"