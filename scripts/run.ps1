[CmdletBinding()]
param(
  [string]$ConfigPath = "ci.project.json",
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$rootPrefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

function Resolve-ProjectPath([string]$RelativePath, [string]$Purpose) {
  if ([string]::IsNullOrWhiteSpace($RelativePath)) { throw "$Purpose path cannot be empty." }
  if ([System.IO.Path]::IsPathRooted($RelativePath)) { throw "$Purpose path must be relative to the project root." }
  $resolved = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
  if ($resolved -ne $repoRoot -and -not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Purpose path escapes the project root: $RelativePath"
  }

  # Reject existing symlinks, junctions and other reparse points in every
  # path component. Lexical normalization alone does not stop a path inside
  # the workspace from resolving to a location outside it.
  $relativeResolved = [System.IO.Path]::GetRelativePath($repoRoot, $resolved)
  $segments = $relativeResolved -split "[\\/]" | Where-Object { $_ -and $_ -ne "." }
  $cursor = $repoRoot
  foreach ($segment in $segments) {
    $cursor = Join-Path $cursor $segment
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Purpose path contains a symbolic link or reparse point: $cursor"
      }
    }
  }
  return $resolved
}

$configFullPath = Resolve-ProjectPath $ConfigPath "Config"
if (-not (Test-Path -LiteralPath $configFullPath -PathType Leaf)) {
  throw "CI config not found: $configFullPath. Copy tooling/shared-ci/ci.project.example.json to ci.project.json first."
}

$config = Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json
if ($config.schemaVersion -ne 1) { throw "Unsupported CI config schemaVersion: $($config.schemaVersion)" }
if ($null -eq $config.project -or [string]::IsNullOrWhiteSpace([string]$config.project.name)) {
  throw "Config must define a non-empty project.name."
}
if ($null -eq $config.steps -or @($config.steps).Count -eq 0) {
  throw "Config must define at least one step."
}
if ($null -ne $config.project.reportDirectory -and $config.project.reportDirectory -isnot [string]) {
  throw "project.reportDirectory must be a string."
}
foreach ($candidate in @($config.steps)) {
  if ([string]::IsNullOrWhiteSpace([string]$candidate.name) -or [string]::IsNullOrWhiteSpace([string]$candidate.command)) {
    throw "Every step must define non-empty name and command strings."
  }
  if ($null -ne $candidate.args) {
    if ($candidate.args -isnot [array]) { throw "Step '$($candidate.name)' args must be an array of strings." }
    foreach ($argument in $candidate.args) {
      if ($argument -isnot [string]) { throw "Step '$($candidate.name)' args must contain only strings." }
    }
  }
  if ($null -ne $candidate.workingDirectory -and $candidate.workingDirectory -isnot [string]) {
    throw "Step '$($candidate.name)' workingDirectory must be a string."
  }
  if ($null -ne $candidate.continueOnError -and $candidate.continueOnError -isnot [bool]) {
    throw "Step '$($candidate.name)' continueOnError must be a boolean."
  }
}

if (-not $OutputDirectory) {
  $OutputDirectory = $config.project.reportDirectory
  if (-not $OutputDirectory) { $OutputDirectory = "artifacts/ci" }
}
$outDir = Resolve-ProjectPath $OutputDirectory "Report output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $outDir "$runId.log"
$jsonPath = Join-Path $outDir "$runId.json"
$mdPath = Join-Path $outDir "$runId.md"
$results = [System.Collections.Generic.List[object]]::new()
$runStarted = Get-Date
$overallFailed = $false

foreach ($step in $config.steps) {
  if (-not $step.name -or -not $step.command) { throw "Each step requires name and command." }
  $stepDir = if ($step.workingDirectory) { Resolve-ProjectPath ([string]$step.workingDirectory) "Step working directory" } else { $repoRoot }
  if (-not (Test-Path -LiteralPath $stepDir -PathType Container)) {
    throw "Working directory for '$($step.name)' does not exist: $stepDir"
  }

  $argsList = @()
  if ($null -ne $step.args) { $argsList = @($step.args | ForEach-Object { [string]$_ }) }
  $started = Get-Date
  $stdoutFile = Join-Path $outDir "$runId-step-$($results.Count + 1).out"
  $stderrFile = Join-Path $outDir "$runId-step-$($results.Count + 1).err"
  # Arguments may contain credentials or other sensitive values. Never copy them
  # into logs or reports; they are still passed unchanged to the child process.
  Add-Content -LiteralPath $logPath -Value "[$($started.ToString('o'))] START $($step.name): $($step.command) (argumentCount=$($argsList.Count))"

  try {
    # ProcessStartInfo.ArgumentList preserves argument boundaries (including spaces)
    # and avoids shell parsing or command-string interpolation.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = [string]$step.command
    $startInfo.WorkingDirectory = $stepDir
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $argsList) { [void]$startInfo.ArgumentList.Add($argument) }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Process could not be started." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [System.IO.File]::WriteAllText($stdoutFile, $stdoutTask.GetAwaiter().GetResult())
    [System.IO.File]::WriteAllText($stderrFile, $stderrTask.GetAwaiter().GetResult())
    $exitCode = $process.ExitCode
    $process.Dispose()
  } catch {
    $_ | Out-String | Add-Content -LiteralPath $stderrFile
    $exitCode = 9009
  }

  $ended = Get-Date
  $success = ($exitCode -eq 0)
  if (-not $success -and -not $step.continueOnError) { $overallFailed = $true }
  Add-Content -LiteralPath $logPath -Value "[$($ended.ToString('o'))] END $($step.name): exit=$exitCode"
  $results.Add([pscustomobject]@{
    name = [string]$step.name
    command = [string]$step.command
    argumentCount = [int]$argsList.Count
    workingDirectory = [string]$stepDir
    exitCode = [int]$exitCode
    status = if ($success) { "passed" } else { "failed" }
    continueOnError = [bool]$step.continueOnError
    startedAt = $started.ToString("o")
    finishedAt = $ended.ToString("o")
    durationSeconds = [math]::Round(($ended - $started).TotalSeconds, 3)
    stdout = [System.IO.Path]::GetFileName($stdoutFile)
    stderr = [System.IO.Path]::GetFileName($stderrFile)
  })
}

$runEnded = Get-Date
$report = [pscustomobject]@{
  schemaVersion = 1
  project = [string]$config.project.name
  runId = $runId
  status = if ($overallFailed) { "failed" } else { "passed" }
  startedAt = $runStarted.ToString("o")
  finishedAt = $runEnded.ToString("o")
  durationSeconds = [math]::Round(($runEnded - $runStarted).TotalSeconds, 3)
  steps = @($results)
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$lines = @(
  "# CI report: $($report.project)",
  "",
  "- **Status:** $($report.status)",
  "- **Run:** $runId",
  "- **Duration:** $($report.durationSeconds)s",
  "",
  "| Step | Status | Exit | Duration |",
  "|---|---:|---:|---:|"
)
foreach ($item in $results) {
  $lines += "| $($item.name -replace '\|','\\|') | $($item.status) | $($item.exitCode) | $($item.durationSeconds)s |"
}
$lines | Set-Content -LiteralPath $mdPath -Encoding utf8
Write-Host "CI status: $($report.status)"
Write-Host "Report: $mdPath"
Write-Host "JSON: $jsonPath"
Write-Host "Log: $logPath"
if ($overallFailed) { exit 1 }
exit 0
