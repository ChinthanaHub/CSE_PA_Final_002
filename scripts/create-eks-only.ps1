param()

# PowerShell wrapper for creating EKS cluster only.
# References existing VPC, IAM, and KMS resources.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir 'create-eks-only.sh'

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