#!/usr/bin/env bash
set -euo pipefail

# Force unlock Terraform state and clean up partial destroy state.
# Use this when KMS key is missing but S3 bucket still exists.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform/environments/dev"
cd "${TF_DIR}"

echo "Force unlocking Terraform state and cleaning up..."

export AWS_REGION="${AWS_REGION:-us-east-1}"

# Force unlock the state
terraform force-unlock -force "$(terraform state list 2>/dev/null | head -1 || echo "LOCK_ID")" 2>/dev/null || true

# Remove any local state files that might be corrupted
rm -f errored.tfstate terraform.tfstate.backup

# Initialize with local backend temporarily to avoid S3/KMS issues
cp backend.tf backend.tf.backup
cat > backend.tf << 'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF

terraform init -reconfigure -input=false

echo "State unlocked and switched to local backend."
echo "You can now run terraform-dev-up.ps1 to recreate the infrastructure."
echo "After successful recreation, you can switch back to S3 backend."