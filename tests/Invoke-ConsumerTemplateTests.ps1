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
foreach ($path in @($configPath, $smokePath, $workflowPath)) {
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
Write-Host 'PASS: consumer template tests (3 groups)'
