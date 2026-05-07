param()

# PowerShell wrapper for force unlocking Terraform state.
# Use this when KMS key issues prevent normal operations.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir 'terraform-dev-force-unlock.sh'

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