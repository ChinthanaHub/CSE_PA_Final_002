# Interview Demo Script

## Opening Statement (30 seconds)

> "I've built a production-grade, secure cloud infrastructure and DevSecOps pipeline on AWS.
> The platform uses Terraform for infrastructure-as-code, EKS for container orchestration,
> GitHub Actions for CI/CD — with security integrated at every stage. Let me walk you through
> the architecture and then run a few live scenarios."

---

## Section 1: Architecture Overview (3 minutes)

**Open the draw.io diagram**

> "Here's the low-level architecture. Starting from the left:
>
> GitHub Actions is our CI/CD engine. It authenticates to AWS using **OIDC** — no stored
> credentials anywhere. When a developer pushes to main, the pipeline runs.
>
> Moving right into AWS:
> - A **VPC** with 1 public subnet and 3 private subnets across AZs (demo-optimised: single NAT Gateway)
> - The public subnet contains the single NAT Gateway and Internal ALB
> - Private subnets contain the EKS worker nodes — **no direct internet access**
> - The EKS control plane has **no public endpoint** — only reachable from within the VPC
>
> Around the edges, we have security services: GuardDuty monitors for threats, Security Hub
> aggregates compliance findings, IAM Access Analyzer flags overly permissive policies,
> CloudTrail logs every API call. All findings route to SNS for alerting.
>
> Every secret is managed through AWS Secrets Manager, encrypted with KMS, and surfaced to
> pods via the External Secrets Operator using IRSA — IAM Roles for Service Accounts.
> The pod never holds long-lived credentials."

---

## Section 2: The CI/CD Pipeline (4 minutes)

**Open GitHub Actions in browser or show the YAML**

> "The pipeline has two workflows:
>
> **PR Validation** — runs on every pull request:
> - Semgrep for SAST, finding code vulnerabilities before they merge
> - Checkov and tfsec scan our Terraform for misconfigurations
> - OWASP Dependency-Check for vulnerable libraries
> - Gitleaks scans for hardcoded secrets — if a dev accidentally commits a key, it's caught here
> - Terraform plan runs and posts the output directly to the PR comment
>
> **Deploy pipeline** — runs on merge to main:
> - Builds the Docker image
> - **Trivy** scans it — CRITICAL vulnerabilities fail the pipeline hard
> - **Syft** generates an SBOM attached to the image
> - **Cosign** signs the image using keyless OIDC signing — no private key to manage
> - Pushes to ECR using the **digest** (sha256 hash), not a mutable tag
> - Deploys to dev automatically, then requires **manual approval** for production"

---

## Section 3: Kubernetes Security (3 minutes)

**Run kubectl commands live**

```bash
# Show namespaces
kubectl get namespaces

# Show Kyverno policies
kubectl get clusterpolicy

# Show network policies
kubectl get networkpolicy -n app

# Show RBAC
kubectl get clusterrole | grep -E "read-only|deployer|pipeline"
```

> "Inside Kubernetes:
> - **Kyverno** enforces policies as a webhook. No privileged containers, no root users,
>   no 'latest' tags, resource limits required, and images must be Cosign-signed.
>   A deployment that violates any of these is rejected at the API level — before it even schedules.
>
> - **Network Policies** implement deny-by-default. Pods can't talk to each other unless
>   explicitly allowed. The app namespace only allows ingress from the ingress controller
>   and DNS egress.
>
> - **RBAC** follows least privilege. The pipeline service account can only deploy to specific
>   namespaces. Regular developers get read-only access."

---

## Section 4: Live Demo Scenarios (5 minutes)

### Demo 1: Push Vulnerable Code → Pipeline Fails

```bash
# Show a file with a known vulnerability (e.g., old library version)
cat app/go.mod

# Make a fake commit
echo 'require golang.org/x/net v0.0.0-20210316092652-d523dce5a7f4' >> app/go.mod
git add . && git commit -m "add vulnerable dependency"
git push origin feature/demo-vuln-dep
```

> "Watch the PR validation workflow — OWASP Dependency-Check will flag the CVE-2021-33197
> vulnerability and fail the pipeline. The PR cannot be merged until it's fixed."

---

### Demo 2: Deploy Insecure Container → Blocked by Kyverno

```bash
# Try to deploy a privileged pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: app
spec:
  containers:
  - name: bad
    image: nginx:latest
    securityContext:
      privileged: true
EOF
```

> "Kyverno immediately rejects this — see the error: *'Privileged containers are not allowed'*
> and *'Using latest tag is not allowed'*. Two policy violations, one rejection. The pod
> never reaches a node."

---

### Demo 3: Detect Terraform Drift

```bash
# Manually change something in AWS (e.g., edit a security group in console)
# Then run:
cd terraform/environments/dev
terraform plan -detailed-exitcode
echo "Exit code: $?"
```

> "Exit code 2 means drift detected. Our pipeline runs this check on every deployment.
> If someone made an out-of-band change in the AWS console, we catch it."

---

### Demo 4: Unsigned Image Rejected by Kyverno

```bash
# Try to deploy an image that wasn't signed by our pipeline
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-pod
  namespace: app
spec:
  containers:
  - name: app
    image: nginx:1.25.3
EOF
```

> "Kyverno verifies the Cosign signature against our GitHub Actions OIDC identity.
> This image wasn't signed by our pipeline, so it's rejected. This is supply chain
> security in action — only our pipeline can produce deployable images."

---

### Demo 5: Misconfigured IAM → Flagged by Access Analyzer

```bash
# Show Access Analyzer findings
aws accessanalyzer list-findings \
  --analyzer-arn $(aws accessanalyzer list-analyzers --query 'analyzers[0].arn' --output text) \
  --query 'findings[*].{Type:findingType,Resource:resource,Status:status}' \
  --output table
```

> "IAM Access Analyzer continuously checks all resource policies. If an S3 bucket or
> KMS key is made publicly accessible or shared outside the account, it appears here
> within minutes. We have EventBridge routing these findings to SNS for immediate alerting."

---

## Section 5: Security Posture Summary (1 minute)

> "Let me summarize what's in place:
>
> | Layer | Control |
> |-------|---------|
> | Code | Semgrep SAST, Dependency-Check SCA, Gitleaks |
> | IaC | Checkov + tfsec, TF Plan on PRs |
> | Container | Trivy scan, Cosign signing, SBOM, ECR immutable tags |
> | Kubernetes | Kyverno policies, RBAC, Network Policies, IRSA |
> | AWS | GuardDuty, Security Hub (CIS + AWS + PCI), CloudTrail, Access Analyzer |
> | Secrets | Secrets Manager + KMS + External Secrets Operator |
> | Auth | OIDC everywhere — no long-lived credentials |
>
> This is security shifted left — vulnerabilities caught in code review, not in production."

---

## Closing Statement

> "The architecture is fully modular — adding a new environment is copying a tfvars file.
> The pipeline is reusable across any application. Everything is auditable through CloudTrail,
> and every security event triggers an alert. I'm happy to go deeper on any component."

---

## Common Interview Questions

**Q: Why OIDC over stored credentials?**
> Stored credentials don't expire automatically and are hard to rotate. OIDC tokens are
> short-lived (15 minutes), scoped to specific repos/branches, and require no secret management.

**Q: Why Kyverno over OPA/Gatekeeper?**
> Kyverno uses Kubernetes-native YAML rather than Rego. Easier to read, review, and maintain.
> Gatekeeper is more powerful for complex rules but has a steeper learning curve.

**Q: How do you handle secret rotation?**
> Secrets Manager supports automatic rotation via Lambda. The External Secrets Operator
> refreshes the Kubernetes secret every hour, so app pods pick up rotated secrets on restart
> without any pipeline involvement.

**Q: Why private EKS endpoint?**
> The control plane API is the highest-value attack target. Exposing it publicly creates
> brute-force and credential-stuffing risk. With a private endpoint, you'd need VPN or
> bastion access to reach the API server at all.

**Q: How does the SBOM help?**
> An SBOM is a bill of materials — every library and dependency in the image. When a new
> CVE drops (like log4shell), we can instantly query SBOMs across all running images to
> identify which deployments are affected, without guessing.
