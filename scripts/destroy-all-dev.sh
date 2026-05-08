#!/usr/bin/env bash
set -euo pipefail

# Forcefully destroy ALL resources in the dev environment (terraform/environments/dev).
# This includes VPC, EKS, IAM, KMS, logging, secrets, security, and all dependencies.
# WARNING: This is destructive and cannot be undone easily.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev"
cd "${TF_DIR}"

echo "=========================================="
echo "DESTROYING ALL DEV RESOURCES"
echo "=========================================="
echo "This will destroy:"
echo "  - EKS Cluster"
echo "  - VPC and subnets"
echo "  - IAM roles and policies"
echo "  - KMS keys"
echo "  - CloudWatch logs"
echo "  - Secrets Manager"
echo "  - Security resources"
echo "  - S3 buckets"
echo "=========================================="
echo ""
read -p "Are you absolutely sure? Type 'destroy-all' to continue: " confirmation

if [ "$confirmation" != "destroy-all" ]; then
  echo "Aborted. No resources were destroyed."
  exit 0
fi

export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Initializing Terraform..."
terraform init -input=false -upgrade

echo ""
echo "Validating configuration..."
terraform validate

echo ""
echo "Planning destruction of all resources..."
terraform plan -destroy -out=tfdestroy-all.plan -input=false

echo ""
echo "Applying destruction plan..."
terraform apply -auto-approve -input=false tfdestroy-all.plan

rm -f tfdestroy-all.plan

echo ""
echo "=========================================="
echo "ALL DEV RESOURCES DESTROYED"
echo "=========================================="
echo "All infrastructure in terraform/environments/dev has been removed."
echo "S3 state bucket may still exist - delete manually if needed."