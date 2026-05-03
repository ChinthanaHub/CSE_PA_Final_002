Act as a  Cloud Security Architect and DevSecOps Engineer.
Design and generate a complete end-to-end hands-on implementation for a Secure Cloud Infrastructure + DevSecOps pipeline using AWS, Terraform, Kubernetes (EKS), and GitHub.

This solution must be practical, production-like, and demonstrable in a live interview, not just conceptual.

🎯 OBJECTIVE
Build a secure, modular, reusable cloud platform and DevSecOps CI/CD pipeline that demonstrates:
End-to-end pipeline understanding
Security integrated into DevOps workflows
Real implementation (not theory)
Failure handling, alerts, and observability

🧱 INFRASTRUCTURE REQUIREMENTS (TERRAFORM)
Design using modular Terraform architecture:
Required Modules:
VPC (public + private subnets, NAT, routing)
Private EKS cluster (no public endpoint)
IAM module (least privilege roles/policies)
IRSA (IAM Roles for Service Accounts)
KMS module (encryption for EKS, secrets, logs)
Secrets module (AWS Secrets Manager / SSM)
Logging module (CloudTrail, CloudWatch)
Security module:
GuardDuty
Security Hub
IAM Access Analyzer
Expectations:
Separate dev and prod environments
Reusable modules
Remote backend (S3 + DynamoDB locking)
Encryption everywhere (KMS)

🧭 ARCHITECTURE DIAGRAM
Generate:
Low-Level Architecture Diagram (LLD)
Include:
All AWS resources
Network flows
Security layers
CI/CD integration
Output format:
draw.io XML (so I can import directly)

☸️ KUBERNETES (EKS) SECURITY
Implement:
Private EKS cluster
RBAC policies
IAM → Kubernetes mapping (IRSA)
Network Policies (deny-by-default)
Secrets management (K8s + AWS Secrets Manager)
Pod security (Kyverno or OPA)

🔐 POLICY AS CODE
Use:
Kyverno OR OPA (free tools)
Examples:
Block privileged containers
Enforce resource limits
Require signed images
Restrict latest tag usage
Create:
Separate policy module
Apply via pipeline

🔄 CI/CD PIPELINE (GITHUB ACTIONS)
Pipeline Requirements:
Trigger:
Pull Request → validation
Push to main → deploy
Manual approval → production
Pipeline Stages:
Terraform Validate + Plan
Security Scans (shift-left):
SAST → CodeQL or Semgrep
SCA → Dependency-Check or Snyk (free tier)
Terraform Security:
tfsec or Checkov
Build Container Image
Container Scan:
Trivy (critical vulnerabilities fail pipeline)
SBOM Generation:
Syft
Image Signing:
Cosign
Push Image (ECR)
Deploy to EKS

🚨 PIPELINE SECURITY RULES
Fail pipeline on:
Critical vulnerabilities
Misconfigurations
Terraform drift
No hardcoded credentials
Use OIDC for AWS authentication (GitHub → AWS)
Secrets via GitHub + AWS Secrets Manager

📦 IMAGE PIPELINE FLOW
Must clearly demonstrate:
build → scan → SBOM → sign → push (digest-based)

📊 MONITORING & ALERTING
Use free-tier AWS + open-source tools:
Implement:
CloudWatch Logs & Metrics
GuardDuty findings
Security Hub aggregation
Prometheus + Grafana (optional)
Show:
Alerts for:
Security findings
Pipeline failures
Unauthorized access
Notification:
SNS or Slack webhook

🧪 DEMO SCENARIOS (VERY IMPORTANT)
Include real test cases:
Push vulnerable code → pipeline fails
Deploy insecure container → blocked by policy
Misconfigured IAM → flagged by Access Analyzer
Drift in Terraform → detected
Unsigned image → rejected

💰 COST OPTIMIZATION
Before implementation:
List all AWS services used
Identify Free Tier usage
Suggest minimal-cost architecture

📁 OUTPUT EXPECTATIONS
Provide:
Folder structure on GitHub repo [ https://github.com/ChinthanaHub/CSE_PA_Final_002.git ]
Terraform code (modular) 
GitHub Actions pipeline YAML
Kubernetes manifests
Security policies (Kyverno/OPA)
draw.io XML diagram
Step-by-step deployment guide
Demo script (what to say in interview)

TOOLS (FREE ONLY)
Use only free-tier or open-source tools:
Terraform
GitHub Actions
Trivy
Syft
Cosign
Checkov / tfsec
Semgrep / CodeQL
Kyverno / OPA
AWS Free Tier services


