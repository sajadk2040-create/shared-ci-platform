[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

$templateRoot = Join-Path $RepositoryRoot 'examples/consumer-template'
$configPath = Join-Path $templateRoot 'ci.project.example.json'
$smokePath = Join-Path $templateRoot 'scripts/ci-smoke.ps1'
$workflowPath = Join-Path $templateRoot '.github/workflows/shared-ci.yml.example'
$reusableWorkflowPath = Join-Path $RepositoryRoot '.github/workflows/reusable.yml'
foreach ($path in @($configPath, $smokePath, $workflowPath, $reusableWorkflowPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required consumer template file missing: $path" }
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
Assert-True ($config.schemaVersion -eq 1) 'template config must use schemaVersion 1'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$config.project.name)) 'template project name is required'
Assert-True ($config.project.reportDirectory -eq 'artifacts/ci') 'template report directory must be artifacts/ci'
Assert-True (@($config.steps).Count -eq 1) 'starter config must contain exactly one smoke step'
$step = @($config.steps)[0]
Assert-True ($step.command -eq 'pwsh') 'starter step must invoke PowerShell explicitly'
Assert-True ($step.args -is [array]) 'starter step arguments must be an array'
Assert-True (($step.args -join '|') -eq '-NoProfile|-File|scripts/ci-smoke.ps1') 'starter step must call the checked-in smoke script'
Assert-True ($step.timeoutSeconds -eq 60) 'starter smoke step must have a bounded timeout'
Write-Host 'PASS: consumer template config structure'

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($smokePath, [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-True ($parseErrors.Count -eq 0) ('consumer smoke script must parse: ' + (($parseErrors | ForEach-Object Message) -join '; '))
$smokeSource = Get-Content -LiteralPath $smokePath -Raw
Assert-True ($smokeSource.Contains("README.md")) 'starter smoke script must check the root README'
Write-Host 'PASS: consumer smoke script parses and checks repository presence'

$workflow = Get-Content -LiteralPath $workflowPath -Raw
$placeholder = '<REVIEWED_40_CHARACTER_COMMIT_SHA>'
$usePattern = 'sajadk2040-create/shared-ci-platform/\.github/workflows/reusable\.yml@' + [regex]::Escape($placeholder)
$refPattern = '(?m)^\s*platform-ref:\s*' + [regex]::Escape($placeholder) + '\s*$'
Assert-True ([regex]::Matches($workflow, $usePattern).Count -eq 1) 'workflow must pin reusable workflow using the documented SHA placeholder'
Assert-True ([regex]::Matches($workflow, $refPattern).Count -eq 1) 'workflow platform-ref must use the same documented SHA placeholder'
Assert-True ([regex]::Matches($workflow, [regex]::Escape($placeholder)).Count -eq 2) 'workflow must contain exactly two matching SHA placeholders'
Assert-True ($workflow -match '(?m)^\s*workflow_dispatch:\s*$') 'workflow must be manual-only'
Assert-True ($workflow -notmatch '(?m)^\s*(pull_request|push):') 'workflow must not enable push or pull_request triggers by default'
Assert-True ($workflow -match '(?m)^\s*contents:\s*read\s*$') 'workflow must use read-only contents permission'
Write-Host 'PASS: consumer workflow pin and trigger safety'

$reusable = Get-Content -LiteralPath $reusableWorkflowPath -Raw
Assert-True ($reusable -match "github\.event_name\s*==\s*'workflow_dispatch'") 'reusable workflow must reject non-manual caller events'
Assert-True ($reusable -match 'github\.ref_protected\s*==\s*true') 'reusable workflow must require a protected caller ref'
Assert-True ($reusable -match "PLATFORM_REF\s+-notmatch\s+'\^\[0-9a-fA-F\]\{40\}\$'") 'reusable workflow must validate a full 40-character SHA before checkout'
Assert-True ([regex]::Matches($reusable, '(?m)^\s*uses:\s*actions/checkout@[0-9a-f]{40}\s+# v[0-9.]+\s*$').Count -eq 2) 'both checkout actions must be pinned to full commit SHAs'
Assert-True ($reusable -match '(?m)^\s*uses:\s*actions/upload-artifact@[0-9a-f]{40}\s+# v[0-9.]+\s*$') 'artifact action must be pinned to a full commit SHA'
Assert-True ($reusable -match '(?m)^\s*retention-days:\s*3\s*$') 'report artifact retention must be limited to three days'
Write-Host 'PASS: reusable workflow event, branch, SHA, action-pin and artifact-retention gates'
Write-Host 'PASS: consumer template tests (4 groups)'
