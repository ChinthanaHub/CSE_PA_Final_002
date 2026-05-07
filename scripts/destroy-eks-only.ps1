param()

# PowerShell wrapper for destroying EKS cluster only.
# Leaves VPC, IAM, and KMS resources intact.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir 'destroy-eks-only.sh'

if (-not (Test-Path $bashScript)) {
    Write-Error "Shell script not found: $bashScript"
    exit 1
}

if (Get-Command bash -ErrorAction SilentlyContinue) {
    bash $bashScript
} else {
    Write-Error 'bash is not available. Install Git Bash or WSL, then run this command again.'
    exit 1
}