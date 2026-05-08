param()

# PowerShell wrapper for destroying ALL dev resources (VPC, EKS, IAM, KMS, etc).
# WARNING: This is destructive and cannot be easily undone.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir 'destroy-all-dev.sh'

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