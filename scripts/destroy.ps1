#Requires -Version 5.1
# One-click teardown for demo environment (Windows PowerShell).
# Usage: .\scripts\destroy.ps1 [-AutoApprove]
param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

$ClusterName  = "cse-pa-final-dev-cluster"
$TFDir        = Join-Path $PSScriptRoot "..\terraform\environments\dev"
$AwsRegion    = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$ApproveFlag  = if ($AutoApprove) { "-auto-approve" } else { "" }

Write-Host "==> Destroying CSE-PA-Final demo environment"
Write-Host "    Cluster : $ClusterName"
Write-Host "    Region  : $AwsRegion"
Write-Host "    TF dir  : $TFDir"
if (-not $AutoApprove) {
    Write-Host "    (run with -AutoApprove to skip confirmation prompts)"
}
Write-Host ""

# ── Step 1: Remove Kubernetes workloads ─────────────────────────────────────
$clusterStatus = aws eks describe-cluster --name $ClusterName --region $AwsRegion `
    --query "cluster.status" --output text 2>$null

if ($clusterStatus -eq "ACTIVE") {
    Write-Host "==> Updating kubeconfig for $ClusterName"
    aws eks update-kubeconfig --name $ClusterName --region $AwsRegion

    Write-Host "==> Removing application workloads"
    kubectl delete -f kubernetes/rbac/             --ignore-not-found=true 2>$null
    kubectl delete -f kubernetes/network-policies/ --ignore-not-found=true 2>$null
    kubectl delete -f kubernetes/secrets/          --ignore-not-found=true 2>$null
    kubectl delete -f policies/kyverno/            --ignore-not-found=true 2>$null

    Write-Host "==> Uninstalling Helm releases"
    helm uninstall kyverno          -n kyverno          2>$null
    helm uninstall external-secrets -n external-secrets 2>$null
    helm uninstall monitoring       -n monitoring        2>$null
} else {
    Write-Host "==> Cluster not found or not ACTIVE -- skipping Kubernetes cleanup"
}

# ── Step 2: Terraform destroy ────────────────────────────────────────────────
Write-Host ""
Write-Host "==> Running terraform destroy in $TFDir"
Set-Location $TFDir
terraform init -input=false -reconfigure

if ($ApproveFlag) {
    terraform destroy -auto-approve -input=false
} else {
    terraform destroy -input=false
}

Write-Host ""
Write-Host "==> Demo environment fully destroyed."
