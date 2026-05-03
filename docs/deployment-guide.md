# Step-by-Step Deployment Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5 | `brew install terraform` |
| AWS CLI | >= 2.x | `brew install awscli` |
| kubectl | >= 1.29 | `brew install kubectl` |
| Helm | >= 3.x | `brew install helm` |
| Cosign | latest | `brew install cosign` |
| Syft | latest | `brew install syft` |
| Trivy | latest | `brew install trivy` |

---

## Phase 1: AWS Bootstrap (Run Once)

### 1.1 Configure AWS CLI

```bash
aws configure
# Enter Access Key, Secret Key, region: us-east-1, output: json
```

### 1.2 Bootstrap Remote State (Before Using S3 Backend)

The first apply uses local state to create the S3 bucket and DynamoDB table.
Temporarily comment out `backend.tf` for the initial apply, then re-enable it.

```bash
cd terraform/environments/dev

# 1. Comment out the backend "s3" block in backend.tf
# 2. Run init with local backend
terraform init

# 3. Create only the state infrastructure first
terraform apply -target=aws_s3_bucket.terraform_state \
                -target=aws_s3_bucket_versioning.terraform_state \
                -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state \
                -target=aws_s3_bucket_public_access_block.terraform_state \
                -target=aws_dynamodb_table.terraform_state_lock \
                -target=module.kms

# 4. Uncomment backend.tf and migrate state
terraform init -migrate-state
```

---

## Phase 2: Deploy Dev Environment

### 2.1 Copy and fill in variables

```bash
cp terraform/environments/dev/terraform.tfvars.example \
   terraform/environments/dev/terraform.tfvars

# Edit terraform.tfvars with your values
```

### 2.2 Apply full dev infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan -out=tfplan.bin
terraform apply tfplan.bin
```

This creates:
- VPC with 1 public subnet + 3 private subnets (single NAT Gateway)
- KMS keys for EKS, CloudWatch, S3, Secrets Manager
- IAM roles (EKS cluster, node groups, GitHub OIDC, IRSA)
- Private EKS cluster (no public endpoint)
- GuardDuty, Security Hub, IAM Access Analyzer
- CloudTrail, CloudWatch log groups
- SNS topic for alerts

### 2.3 Configure kubectl

```bash
aws eks update-kubeconfig \
  --name cse-pa-final-dev-cluster \
  --region us-east-1
```

### 2.4 Verify cluster access

```bash
kubectl get nodes
kubectl get namespaces
```

---

## Phase 3: Install Kubernetes Add-ons

### 3.1 Install Kyverno

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  -n kyverno --create-namespace \
  --set replicaCount=1
```

### 3.2 Apply Kyverno Policies

```bash
kubectl apply -f policies/kyverno/
kubectl get clusterpolicy
```

### 3.3 Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Apply SecretStore and ExternalSecrets (update ACCOUNT_ID first)
sed -i 's/ACCOUNT_ID/YOUR_AWS_ACCOUNT_ID/g' kubernetes/secrets/secret-store.yaml
kubectl apply -f kubernetes/secrets/
```

### 3.4 Apply RBAC and Network Policies

```bash
kubectl apply -f kubernetes/rbac/
kubectl apply -f kubernetes/network-policies/
```

### 3.5 Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/prometheus/prometheus-values.yaml
```

---

## Phase 4: Set Up GitHub Actions CI/CD

### 4.1 Configure GitHub Repository Secrets

Navigate to **GitHub → Repository → Settings → Secrets and variables → Actions**

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN_DEV` | Output from `terraform output github_actions_role_arn` |
| `ALERT_EMAIL` | Your alert email |
| `SEMGREP_APP_TOKEN` | (Optional) Semgrep token for enhanced rules |

### 4.2 Configure GitHub Environments

1. Go to **Settings → Environments**
2. Create `dev` environment (no reviewers required)

### 4.3 Configure GitHub OIDC Trust

The IAM role trust policy allows `repo:ChinthanaHub/CSE_PA_Final_002:*`.
This is set automatically by Terraform.

### 4.4 Trigger the Pipeline

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

---

## Phase 5: Deploy Application

### 5.1 Build and push (done automatically by CI/CD)

The deploy pipeline handles:
1. Build Docker image from `app/Dockerfile`
2. Trivy scan (fails on CRITICAL)
3. Syft SBOM generation
4. Cosign keyless signing
5. Push to ECR with digest
6. Deploy to EKS with digest-pinned image

### 5.2 Manual deploy (for testing)

```bash
# Update deployment image
kubectl set image deployment/app \
  app=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cse-pa-app@sha256:DIGEST \
  -n app

kubectl rollout status deployment/app -n app
```

---

## Verification Checklist

```bash
# 1. Cluster is private (no public endpoint)
aws eks describe-cluster --name cse-pa-final-dev-cluster \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'
# Expected: false

# 2. GuardDuty enabled
aws guardduty list-detectors

# 3. Security Hub enabled with CIS benchmark
aws securityhub get-enabled-standards

# 4. CloudTrail active and multi-region
aws cloudtrail get-trail-status --name cse-pa-final-dev-trail

# 5. Kyverno policies enforced
kubectl get clusterpolicy -o wide

# 6. Network policies applied
kubectl get networkpolicy -n app

# 7. RBAC in place
kubectl auth can-i create pods --as=system:serviceaccount:app:app-sa -n app
```

---

## Cleanup (One-Click Destroy)

Run the destroy script from the repo root after the demo:

**Linux / macOS:**
```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh --auto-approve
```

**Windows (PowerShell):**
```powershell
.\scripts\destroy.ps1 -AutoApprove
```

The script:
1. Drains all Kubernetes workloads (RBAC, network policies, Helm releases)
2. Runs `terraform destroy` to remove all AWS resources
3. Releases the NAT Gateway EIP (stops hourly charges immediately)
