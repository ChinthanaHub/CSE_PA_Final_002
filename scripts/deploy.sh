#!/usr/bin/env bash
# Bootstrap and deploy script
# Usage: ./scripts/deploy.sh [dev|prod] [plan|apply|destroy]

set -euo pipefail

ENVIRONMENT="${1:-dev}"
ACTION="${2:-plan}"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[OK] $*"; }
fail() { echo "[ERROR] $*"; exit 1; }

[ "${ENVIRONMENT}" = "dev" ] || [ "${ENVIRONMENT}" = "prod" ] || \
  fail "Environment must be 'dev' or 'prod'"

TF_DIR="terraform/environments/${ENVIRONMENT}"

check_tools() {
  for tool in terraform aws kubectl helm; do
    command -v "${tool}" >/dev/null 2>&1 || fail "${tool} is not installed"
  done
  ok "All required tools present"
}

terraform_action() {
  log "Running terraform ${ACTION} for ${ENVIRONMENT}..."
  cd "${TF_DIR}"
  terraform init -input=false
  terraform validate

  case "${ACTION}" in
    plan)
      terraform plan -out=tfplan.bin -no-color
      ;;
    apply)
      terraform plan -out=tfplan.bin -no-color
      terraform apply -auto-approve -input=false tfplan.bin
      ;;
    destroy)
      echo "WARNING: This will destroy all ${ENVIRONMENT} resources."
      read -rp "Type '${ENVIRONMENT}' to confirm: " confirm
      [ "${confirm}" = "${ENVIRONMENT}" ] || fail "Aborted"
      terraform destroy -auto-approve
      ;;
  esac
}

configure_kubectl() {
  CLUSTER_NAME=$(terraform -chdir="${TF_DIR}" output -raw eks_cluster_name 2>/dev/null || echo "")
  [ -n "${CLUSTER_NAME}" ] || fail "Cannot get cluster name from Terraform output"
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region us-east-1
  ok "kubectl configured for ${CLUSTER_NAME}"
}

install_addons() {
  log "Installing Kubernetes add-ons..."

  helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
  helm repo add external-secrets https://charts.external-secrets.io --force-update
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  helm repo update

  helm upgrade --install kyverno kyverno/kyverno \
    -n kyverno --create-namespace --wait

  helm upgrade --install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace --wait

  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    -f monitoring/prometheus/prometheus-values.yaml \
    --wait --timeout=600s

  ok "Add-ons installed"
}

apply_manifests() {
  log "Applying Kubernetes manifests..."
  kubectl apply -f kubernetes/app/namespace.yaml
  kubectl apply -f kubernetes/rbac/
  kubectl apply -f kubernetes/network-policies/
  kubectl apply -f policies/kyverno/
  ok "Manifests applied"
}

check_tools

case "${ACTION}" in
  plan|apply|destroy)
    terraform_action
    if [ "${ACTION}" = "apply" ]; then
      configure_kubectl
      install_addons
      apply_manifests
    fi
    ;;
  *)
    fail "ACTION must be plan, apply, or destroy"
    ;;
esac

log "Done! Environment: ${ENVIRONMENT}, Action: ${ACTION}"
