#!/usr/bin/env bash
# One-click teardown for demo environment.
# Usage: ./scripts/destroy.sh [--auto-approve]
set -euo pipefail

AUTO_APPROVE=""
[[ "${1:-}" == "--auto-approve" ]] && AUTO_APPROVE="-auto-approve"

CLUSTER_NAME="cse-pa-final-dev-cluster"
TF_DIR="$(cd "$(dirname "$0")/../terraform/environments/dev" && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "==> Destroying CSE-PA-Final demo environment"
echo "    Cluster : $CLUSTER_NAME"
echo "    Region  : $AWS_REGION"
echo "    TF dir  : $TF_DIR"
[[ -z "$AUTO_APPROVE" ]] && echo "    (run with --auto-approve to skip confirmation prompts)"
echo ""

# ── Step 1: Remove Kubernetes workloads ─────────────────────────────────────
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
     --query 'cluster.status' --output text 2>/dev/null | grep -q ACTIVE; then

  echo "==> Updating kubeconfig for $CLUSTER_NAME"
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

  echo "==> Removing application workloads"
  kubectl delete -f kubernetes/rbac/              --ignore-not-found=true || true
  kubectl delete -f kubernetes/network-policies/  --ignore-not-found=true || true
  kubectl delete -f kubernetes/secrets/           --ignore-not-found=true || true
  kubectl delete -f policies/kyverno/             --ignore-not-found=true || true

  echo "==> Uninstalling Helm releases"
  helm uninstall kyverno          -n kyverno          --ignore-not-found 2>/dev/null || true
  helm uninstall external-secrets -n external-secrets --ignore-not-found 2>/dev/null || true
  helm uninstall monitoring       -n monitoring        --ignore-not-found 2>/dev/null || true
else
  echo "==> Cluster not found or not ACTIVE — skipping Kubernetes cleanup"
fi

# ── Step 2: Terraform destroy ────────────────────────────────────────────────
echo ""
echo "==> Running terraform destroy in $TF_DIR"
cd "$TF_DIR"
terraform init -input=false -reconfigure

# S3 bucket has force_destroy=false; flip it before destroy so Terraform can empty it
terraform apply $AUTO_APPROVE -input=false \
  -target=aws_s3_bucket.terraform_state \
  -var='force_destroy_state_bucket=true' 2>/dev/null || true

terraform destroy $AUTO_APPROVE -input=false

echo ""
echo "==> Demo environment fully destroyed."
