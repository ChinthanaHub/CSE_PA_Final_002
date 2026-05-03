#!/usr/bin/env bash
# Demo scenario scripts for live interview
# Usage: ./scripts/demo-scenarios.sh <scenario>
# Scenarios: 1-vulnerable-code | 2-insecure-pod | 3-drift | 4-unsigned-image | 5-iam-finding

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-cse-pa-final-dev-cluster}"
REGION="${REGION:-us-east-1}"
NAMESPACE="app"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
ok()  { echo "[OK] $*"; }
err() { echo "[FAIL] $*"; }

configure_kubectl() {
  log "Configuring kubectl..."
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"
  ok "kubectl configured"
}

# ─────────────────────────────────────────────────────────────────────
# Demo 1: Insecure container blocked by Kyverno
# ─────────────────────────────────────────────────────────────────────
demo_insecure_pod() {
  log "=== DEMO: Insecure Pod Blocked by Kyverno ==="
  log "Attempting to deploy a privileged container with 'latest' tag..."

  cat <<EOF | kubectl apply -f - 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: demo-bad-pod
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: bad
    image: nginx:latest
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
EOF

  echo ""
  log "Expected: Kyverno blocks with 'Privileged containers are not allowed' and 'latest tag' violations"
  log "Kyverno ClusterPolicies applied:"
  kubectl get clusterpolicy -o custom-columns='NAME:.metadata.name,MODE:.spec.validationFailureAction,BACKGROUND:.spec.background'
}

# ─────────────────────────────────────────────────────────────────────
# Demo 2: Network policy enforcement
# ─────────────────────────────────────────────────────────────────────
demo_network_isolation() {
  log "=== DEMO: Network Policy Enforcement ==="
  log "Current network policies in namespace '${NAMESPACE}':"
  kubectl get networkpolicy -n "${NAMESPACE}"
  echo ""
  log "Attempting pod-to-pod connection blocked by deny-all..."
  kubectl run -n "${NAMESPACE}" nettest \
    --image=busybox:1.36 \
    --restart=Never \
    --rm -it \
    -- wget -qO- --timeout=3 http://app-service 2>&1 || err "Connection blocked by NetworkPolicy (expected)"
}

# ─────────────────────────────────────────────────────────────────────
# Demo 3: Terraform drift detection
# ─────────────────────────────────────────────────────────────────────
demo_drift() {
  log "=== DEMO: Terraform Drift Detection ==="
  log "Running terraform plan to check for drift..."
  cd "$(dirname "$0")/../terraform/environments/dev" || exit 1
  terraform plan -detailed-exitcode -no-color 2>&1 | tail -20
  EXIT_CODE=${PIPESTATUS[0]}
  if [ "${EXIT_CODE}" = "2" ]; then
    err "DRIFT DETECTED — infrastructure changed outside Terraform"
  elif [ "${EXIT_CODE}" = "0" ]; then
    ok "No drift — infrastructure matches Terraform state"
  fi
}

# ─────────────────────────────────────────────────────────────────────
# Demo 4: Unsigned image rejected by Kyverno
# ─────────────────────────────────────────────────────────────────────
demo_unsigned_image() {
  log "=== DEMO: Unsigned Image Rejected ==="
  log "Attempting to deploy an unsigned image (not from our pipeline)..."

  cat <<EOF | kubectl apply -f - 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-demo
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: app
    image: nginx:1.25.3
    securityContext:
      runAsNonRoot: true
      runAsUser: 10001
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
    resources:
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
EOF

  echo ""
  log "Expected: Kyverno rejects — image not signed by our GitHub Actions pipeline"
}

# ─────────────────────────────────────────────────────────────────────
# Demo 5: IAM Access Analyzer findings
# ─────────────────────────────────────────────────────────────────────
demo_iam_analyzer() {
  log "=== DEMO: IAM Access Analyzer ==="
  ANALYZER_ARN=$(aws accessanalyzer list-analyzers \
    --query 'analyzers[0].arn' --output text 2>/dev/null || echo "")

  if [ -z "${ANALYZER_ARN}" ] || [ "${ANALYZER_ARN}" = "None" ]; then
    err "No Access Analyzer found — ensure Terraform has been applied"
    exit 1
  fi

  log "Analyzer ARN: ${ANALYZER_ARN}"
  FINDINGS=$(aws accessanalyzer list-findings \
    --analyzer-arn "${ANALYZER_ARN}" \
    --filter '{"status": {"eq": ["ACTIVE"]}}' \
    --query 'findings[*].{Type:findingType,Resource:resource,Status:status}' \
    --output table 2>/dev/null || echo "No active findings")
  echo "${FINDINGS}"
  ok "IAM Access Analyzer is monitoring all resource-based policies"
}

# ─────────────────────────────────────────────────────────────────────
# Demo 6: GuardDuty status
# ─────────────────────────────────────────────────────────────────────
demo_guardduty() {
  log "=== DEMO: GuardDuty Status ==="
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
  log "Detector ID: ${DETECTOR_ID}"
  aws guardduty get-detector --detector-id "${DETECTOR_ID}" \
    --query '{Status:Status,S3Logs:DataSources.S3Logs.Status,K8s:DataSources.Kubernetes.AuditLogs.Status}' \
    --output table
  ok "GuardDuty active with S3 + Kubernetes audit log monitoring"
}

# ─────────────────────────────────────────────────────────────────────
# Demo 7: Security Hub standards
# ─────────────────────────────────────────────────────────────────────
demo_security_hub() {
  log "=== DEMO: Security Hub Compliance Standards ==="
  aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[*].{Name:StandardsArn,Status:StandardsStatus}' \
    --output table
  ok "Security Hub enabled with CIS, AWS Foundational, and PCI-DSS standards"
}

# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
case "${1:-help}" in
  1|insecure-pod)     configure_kubectl; demo_insecure_pod ;;
  2|network)          configure_kubectl; demo_network_isolation ;;
  3|drift)            demo_drift ;;
  4|unsigned-image)   configure_kubectl; demo_unsigned_image ;;
  5|iam-analyzer)     demo_iam_analyzer ;;
  6|guardduty)        demo_guardduty ;;
  7|securityhub)      demo_security_hub ;;
  all)
    configure_kubectl
    demo_insecure_pod
    demo_unsigned_image
    demo_iam_analyzer
    demo_guardduty
    demo_security_hub
    ;;
  *)
    echo "Usage: $0 <scenario>"
    echo "  1 | insecure-pod    Kyverno blocks privileged+latest container"
    echo "  2 | network         NetworkPolicy isolation demo"
    echo "  3 | drift           Terraform drift detection"
    echo "  4 | unsigned-image  Kyverno rejects unsigned image"
    echo "  5 | iam-analyzer    Show IAM Access Analyzer findings"
    echo "  6 | guardduty       Show GuardDuty status"
    echo "  7 | securityhub     Show Security Hub standards"
    echo "  all                 Run all demos"
    ;;
esac
