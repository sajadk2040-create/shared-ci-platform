[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$MotionDeckRoot,
  [string]$SharedCiRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$Repository = "sajadk2040-create/shared-ci-platform",
  [ValidateSet("main", "feature/local-command-agent-v1")]
  [string]$Ref = "feature/local-command-agent-v1",
  [ValidateRange(5, 300)]
  [int]$PollSeconds = 15,
  [switch]$Once
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Gh {
  param([string[]]$Arguments)
  $output = & gh @Arguments 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) { throw "GitHub CLI request failed (exit $code): $($output | Out-String)" }
  return ($output | Out-String).Trim()
}

function Assert-TrustedCheckout {
  param([string]$Path, [string]$ExpectedRemote, [string]$ExpectedBranch)
  if (-not (Test-Path -LiteralPath (Join-Path $Path ".git"))) { throw "Expected a Git checkout at: $Path" }
  $remote = (& git -C $Path remote get-url origin 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $remote -ne $ExpectedRemote) { throw "Unexpected origin remote at $Path" }
  $branch = (& git -C $Path branch --show-current 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $branch -ne $ExpectedBranch) { throw "Checkout must be on branch '$ExpectedBranch': $Path" }
  $status = & git -C $Path status --porcelain
  if ($LASTEXITCODE -ne 0 -or $status) { throw "Checkout must have a clean working tree: $Path" }
}

function Invoke-FixedProcess {
  param([string]$FileName,[string[]]$Arguments,[string]$WorkingDirectory,[int]$TimeoutSeconds)
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FileName
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
  $process = [System.Diagnostics.Process]::new()
  $started = Get-Date
  $timedOut = $false
  $processStarted = $false
  try {
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Process failed to start: $FileName" }
    $processStarted = $true
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $timedOut = $true
      try { $process.Kill($true) } catch { if (-not $process.HasExited) { throw } }
      $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    return [pscustomobject]@{
      exitCode = [int]$exitCode
      timedOut = [bool]$timedOut
      durationSeconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 3)
      stdout = $stdout
      stderr = $stderr
    }
  }
  finally {
    if ($processStarted -and -not $process.HasExited) { try { $process.Kill($true); $process.WaitForExit() } catch {} }
    $process.Dispose()
  }
}

function Invoke-AllowedTask {
  param([string]$Task)
  $motiondeckRemote = "https://github.com/sajadk2040-create/motiondeck-studio.git"
  $sharedCiRemote = "https://github.com/sajadk2040-create/shared-ci-platform.git"
  switch ($Task) {
    "motiondeck.repository-validation" {
      Assert-TrustedCheckout -Path $MotionDeckRoot -ExpectedRemote $motiondeckRemote -ExpectedBranch "main"
      $scriptPath = Join-Path $MotionDeckRoot "scripts/Test-MotionDeckRepository.ps1"
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "MotionDeck validation script not found." }
      return Invoke-FixedProcess -FileName "pwsh" -Arguments @("-NoProfile","-File",$scriptPath) -WorkingDirectory $MotionDeckRoot -TimeoutSeconds 300
    }
    "motiondeck.git-status" {
      Assert-TrustedCheckout -Path $MotionDeckRoot -ExpectedRemote $motiondeckRemote -ExpectedBranch "main"
      return Invoke-FixedProcess -FileName "git" -Arguments @("status","--short","--branch") -WorkingDirectory $MotionDeckRoot -TimeoutSeconds 30
    }
    "motiondeck.current-commit" {
      Assert-TrustedCheckout -Path $MotionDeckRoot -ExpectedRemote $motiondeckRemote -ExpectedBranch "main"
      return Invoke-FixedProcess -FileName "git" -Arguments @("rev-parse","HEAD") -WorkingDirectory $MotionDeckRoot -TimeoutSeconds 30
    }
    "shared-ci.core-smoke" {
      Assert-TrustedCheckout -Path $SharedCiRoot -ExpectedRemote $sharedCiRemote -ExpectedBranch $Ref
      $scriptPath = Join-Path $SharedCiRoot "tests/Invoke-RunnerSmokeTests.ps1"
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Shared CI core smoke script not found." }
      return Invoke-FixedProcess -FileName "pwsh" -Arguments @("-NoProfile","-File",$scriptPath) -WorkingDirectory $SharedCiRoot -TimeoutSeconds 900
    }
    "shared-ci.local-agent-static" {
      Assert-TrustedCheckout -Path $SharedCiRoot -ExpectedRemote $sharedCiRemote -ExpectedBranch $Ref
      $scriptPath = Join-Path $SharedCiRoot "tests/Invoke-LocalAgentStaticTests.ps1"
      if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Local agent static test script not found." }
      return Invoke-FixedProcess -FileName "pwsh" -Arguments @("-NoProfile","-File",$scriptPath) -WorkingDirectory $SharedCiRoot -TimeoutSeconds 60
    }
    default { throw "Task is not allowlisted: $Task" }
  }
}

function Protect-Output {
  param([string]$Value)
  $safe = $Value
  $safe = [regex]::Replace($safe,'(?i)(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})','[REDACTED_GITHUB_TOKEN]')
  $safe = [regex]::Replace($safe,'(?i)\bBearer\s+[A-Za-z0-9._~+/-]+=*','Bearer [REDACTED]')
  $safe = [regex]::Replace($safe,'(?i)\b(password|passwd|token|secret|api[_-]?key)\b(\s*[:=]\s*)\S+','$1$2[REDACTED]')
  if ($safe.Length -gt 12000) { $safe = $safe.Substring(0,12000) + [Environment]::NewLine + "[OUTPUT TRUNCATED]" }
  return $safe
}

function Get-ResponseLookupDecision {
  param([int]$ExitCode,[string]$Diagnostic)
  if ($ExitCode -eq 0) { return "exists" }
  if ($Diagnostic -match '(?i)Not Found\s*\(HTTP 404\)|HTTP(?:/\d(?:\.\d)?)?\s+404') {
    return "missing"
  }
  $safeDiagnostic = Protect-Output $Diagnostic
  throw "Could not verify whether response lookup succeeded (gh exit $ExitCode): $safeDiagnostic"
}

function Test-ResponseExists {
  param([string]$Path)
  # Only an explicit GitHub 404 means the response is absent. Authentication,
  # rate-limit, network, and server failures must stop processing (fail closed).
  $output = & gh api "repos/$Repository/contents/${Path}?ref=$Ref" --jq ".sha" 2>&1
  $code = $LASTEXITCODE
  $diagnostic = ($output | Out-String).Trim()
  $decision = Get-ResponseLookupDecision -ExitCode $code -Diagnostic $diagnostic
  return ($decision -eq "exists")
}

function Publish-Response {
  param([string]$Path,[string]$Json)
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Json))
  $message = "agent: record response $([IO.Path]::GetFileNameWithoutExtension($Path))"
  $null = Invoke-Gh -Arguments @("api","--method","PUT","repos/$Repository/contents/$Path","-f","message=$message","-f","content=$encoded","-f","branch=$Ref")
}

function Invoke-AgentPoll {
  $rawContent = Invoke-Gh -Arguments @("api","repos/$Repository/contents/commands/inbox.json?ref=$Ref","--jq",".content")
  $jsonText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($rawContent -replace "\s","")))
  $inbox = $jsonText | ConvertFrom-Json -DateKind String
  if ($inbox.schemaVersion -ne 1) { throw "Unsupported inbox schemaVersion." }
  if ($null -eq $inbox.command) { Write-Host "Inbox empty; waiting."; return }
  $command = $inbox.command
  $id = [string]$command.id
  $task = [string]$command.task
  if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw "Invalid command ID." }
  if ([string]::IsNullOrWhiteSpace($task)) { throw "Command task is missing." }
  $allowedTasks = @(
    "motiondeck.repository-validation",
    "motiondeck.git-status",
    "motiondeck.current-commit",
    "shared-ci.core-smoke",
    "shared-ci.local-agent-static"
  )
  $taskInvalid = ($task.Length -gt 64 -or $task -notin $allowedTasks)
  $responseTask = if ($task.Length -gt 64) { $task.Substring(0,64) } else { $task }
  $invariantCulture = [Globalization.CultureInfo]::InvariantCulture
  $roundtripStyle = [Globalization.DateTimeStyles]::RoundtripKind
  $issuedAt = [DateTimeOffset]::Parse([string]$command.issuedAt, $invariantCulture, $roundtripStyle)
  $expiresAt = [DateTimeOffset]::Parse([string]$command.expiresAt, $invariantCulture, $roundtripStyle)
  $now = [DateTimeOffset]::Now
  if ($issuedAt -gt $now.AddMinutes(5)) { throw "Command issue time is too far in the future." }
  if ($expiresAt -le $now -or $expiresAt -le $issuedAt -or $expiresAt -gt $issuedAt.AddHours(1)) { throw "Command is expired or has an invalid lifetime." }
  $responsePath = "responses/$id.json"
  if (Test-ResponseExists -Path $responsePath) { Write-Host "Already processed: $id"; return }
  Write-Host "Executing allowlisted task '$task' ($id)..."
  $startedAt = [DateTimeOffset]::Now
  try {
    if ($taskInvalid) { throw "Command task is not in the local allowlist or exceeds the task ID limit." }
    $result = Invoke-AllowedTask -Task $task
    $status = if ($result.exitCode -eq 0) { "passed" } else { "failed" }
    $exitCode = [int]$result.exitCode
    $timedOut = [bool]$result.timedOut
    $duration = [double]$result.durationSeconds
    $stdout = Protect-Output ([string]$result.stdout)
    $stderr = Protect-Output ([string]$result.stderr)
  }
  catch {
    $status = "rejected"
    $exitCode = 126
    $timedOut = $false
    $duration = [math]::Round(([DateTimeOffset]::Now - $startedAt).TotalSeconds,3)
    $stdout = ""
    $stderr = Protect-Output $_.Exception.Message
  }
  $response = [ordered]@{
    schemaVersion = 1
    commandId = $id
    task = $responseTask
    status = $status
    exitCode = $exitCode
    timedOut = $timedOut
    startedAt = $startedAt.ToString("o")
    finishedAt = [DateTimeOffset]::Now.ToString("o")
    durationSeconds = $duration
    stdout = $stdout
    stderr = $stderr
  }
  $responseJson = $response | ConvertTo-Json -Depth 5
  Publish-Response -Path $responsePath -Json $responseJson
  Write-Host "Response published: $responsePath (status=$status, exit=$exitCode)"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is required." }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required." }
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) { throw "PowerShell 7 (pwsh) is required." }
if (-not (Test-Path -LiteralPath $MotionDeckRoot -PathType Container)) { throw "MotionDeckRoot does not exist." }
if (-not (Test-Path -LiteralPath $SharedCiRoot -PathType Container)) { throw "SharedCiRoot does not exist." }
$null = Invoke-Gh -Arguments @("auth","status")
$login = Invoke-Gh -Arguments @("api","user","--jq",".login")
Write-Host "Authenticated GitHub account: $login"
Write-Host "Repository: $Repository"
Write-Host "Ref: $Ref"
Write-Host "Polling every $PollSeconds seconds. Press Ctrl+C to stop."
do {
  try { Invoke-AgentPoll }
  catch { Write-Warning ("Agent poll failed: " + (Protect-Output $_.Exception.Message)) }
  if ($Once) { break }
  Start-Sleep -Seconds $PollSeconds
} while ($true)
