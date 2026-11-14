$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$agentPath = Join-Path $repoRoot "scripts/Start-SharedCiLocalAgent.ps1"
$inboxPath = Join-Path $repoRoot "commands/inbox.json"
$testPath = $PSCommandPath

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAIL: $Message" }
}

# Parse both the agent and this test file before running assertions.
foreach ($path in @($agentPath, $testPath)) {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
  Assert-True ($parseErrors.Count -eq 0) "PowerShell syntax parses: $([IO.Path]::GetFileName($path))"
}

$source = Get-Content -LiteralPath $agentPath -Raw
Assert-True ($source -notmatch '(?i)\bInvoke-Expression\b') "No Invoke-Expression"
Assert-True ($source -notmatch '(?i)ScriptBlock\s*::\s*Create') "No dynamic ScriptBlock creation"
Assert-True ($source -match 'motiondeck\.repository-validation') "MotionDeck validation task is allowlisted"
Assert-True ($source -match 'motiondeck\.git-status') "Git status task is allowlisted"
Assert-True ($source -match 'motiondeck\.current-commit') "Current commit task is allowlisted"
Assert-True ($source -match 'shared-ci\.core-smoke') "Shared CI smoke task is allowlisted"
Assert-True ($source -match 'shared-ci\.local-agent-static') "Local agent static test task is allowlisted"
Assert-True ($source -match '\$taskInvalid = \(\$task\.Length -gt 64 -or \$task -notin \$allowedTasks\)') "Task identifiers are strictly allowlisted and length-bounded"
Assert-True ($source -match 'task = \$responseTask') "Response task metadata is bounded"
Assert-True ($source -match 'ValidateSet\("main", "feature/local-command-agent-v1"\)') "Git ref is constrained"
Assert-True ($source -match 'ExpectedRemote') "Checkout origin is verified"
Assert-True ($source -match 'ExpectedBranch') "Checkout branch is verified"
Assert-True ($source -match 'status --porcelain') "Dirty worktrees are rejected"
Assert-True ($source -match 'expiresAt') "Command expiry is checked"
Assert-True ($source -match 'ConvertFrom-Json -DateKind String') "Inbox timestamps remain ISO strings during JSON parsing"
Assert-True ($source -match 'CultureInfo\]::InvariantCulture') "Timestamp parsing is culture-invariant"
Assert-True ($source -match 'Test-ResponseExists') "Duplicate command responses are checked"
Assert-True ($source -match '\$\{Path\}\?ref=\$Ref') "Response lookup URL delimits the path variable"
Assert-True ($source -match 'OUTPUT TRUNCATED') "Output is bounded"
Assert-True (Test-Path -LiteralPath $inboxPath) "Inbox file exists"

$inbox = Get-Content -LiteralPath $inboxPath -Raw | ConvertFrom-Json
Assert-True ($inbox.schemaVersion -eq 1) "Inbox schema version is 1"
if ($null -ne $inbox.command) {
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$inbox.command.id)) "Inbox command has an ID"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$inbox.command.task)) "Inbox command has a task"
  Assert-True ($inbox.command.task -match '^(motiondeck\.(repository-validation|git-status|current-commit)|shared-ci\.(core-smoke|local-agent-static))$') "Inbox task is allowlisted"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$inbox.command.issuedAt)) "Inbox command has issuedAt"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$inbox.command.expiresAt)) "Inbox command has expiresAt"
}

Write-Host "PASS: local agent static safety tests"
