$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Location).Path
$readmePath = Join-Path $repoRoot 'README.md'

if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    throw "README.md was not found at repository root: $repoRoot"
}

Write-Host "PASS: consumer repository smoke check"
Write-Host "INFO: replace scripts/ci-smoke.ps1 with project-specific checks."
