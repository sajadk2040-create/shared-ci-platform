[CmdletBinding()]
param(
  [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$pwshCommand = Get-Command pwsh -ErrorAction Stop
$pwshPath = $pwshCommand.Source
$runnerSource = Join-Path $RepositoryRoot "scripts/run.ps1"
if (-not (Test-Path -LiteralPath $runnerSource -PathType Leaf)) {
  throw "Runner not found: $runnerSource"
}

$parseTokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($runnerSource, [ref]$parseTokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
  $details = ($parseErrors | ForEach-Object { $_.Message }) -join [Environment]::NewLine
  throw "PowerShell parser validation failed:`n$details"
}
Write-Host "PASS: PowerShell parser validation"

$testPassed = $false
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("shared-ci-smoke-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $testRoot "project"
$platformRoot = Join-Path $testRoot "platform"
$null = New-Item -ItemType Directory -Path $projectRoot, (Join-Path $platformRoot "scripts") -Force
Copy-Item -LiteralPath $runnerSource -Destination (Join-Path $platformRoot "scripts/run.ps1")

$helperPath = Join-Path $projectRoot "probe.ps1"
@'
param(
  [Parameter(Position = 0)]
  [string]$CapturePath,
  [Parameter(Position = 1)]
  [int]$ExitCode = 0,
  [Parameter()]
  [int]$SleepSeconds = 0,
  [Parameter()]
  [string]$ChildPidPath,
  [Parameter()]
  [string]$ChildExecutable,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ProbeArguments
)
[pscustomobject]@{ arguments = @($ProbeArguments) } |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath $CapturePath -Encoding utf8
if ($ChildPidPath) {
  $child = Start-Process -FilePath $ChildExecutable -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Seconds 60") -PassThru -WindowStyle Hidden
  Set-Content -LiteralPath $ChildPidPath -Value $child.Id
}
if ($SleepSeconds -gt 0) { Start-Sleep -Seconds $SleepSeconds }
Write-Output "probe-stdout"
[Console]::Error.WriteLine("probe-stderr")
exit $ExitCode
'@ | Set-Content -LiteralPath $helperPath -Encoding utf8

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Write-Config([string]$Path, [object]$Config) {
  $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

try {
  # Test 1: successful process, argument boundaries, stdout/stderr and reports.
  $capturePath = Join-Path $projectRoot "captured-args.json"
  $successConfig = Join-Path $projectRoot "success.json"
  Write-Config $successConfig ([pscustomobject]@{
    schemaVersion = 1
    project = @{ name = "shared-ci-smoke-pass"; reportDirectory = "artifacts/pass" }
    steps = @(@{
      name = "argument-boundary-probe"
      command = $pwshPath
      args = @("-NoProfile", "-File", $helperPath, "-CapturePath", $capturePath, "-ExitCode", "0", "value with spaces", 'quote"value', "tail")
    })
  })
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "success.json"
    $successRunnerExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($successRunnerExit -eq 0) "success fixture should return runner exit code 0"
  $captured = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
  Assert-True ($captured.arguments.Count -eq 3) "probe should receive exactly three user arguments"
  Assert-True ($captured.arguments[0] -eq "value with spaces") "argument containing spaces must remain one argument"
  Assert-True ($captured.arguments[1] -eq 'quote"value') "embedded quote must be preserved"
  Assert-True ($captured.arguments[2] -eq "tail") "trailing argument must be preserved"

  $passReports = Join-Path $projectRoot "artifacts/pass"
  $jsonReport = Get-ChildItem -LiteralPath $passReports -Filter "*.json" | Select-Object -First 1
  Assert-True ($null -ne $jsonReport) "JSON report should exist"
  $passReport = Get-Content -LiteralPath $jsonReport.FullName -Raw | ConvertFrom-Json
  Assert-True ($passReport.status -eq "passed") "success report status should be passed"
  Assert-True ($passReport.steps[0].exitCode -eq 0) "success step exit code should be 0"
  Assert-True ($passReport.steps[0].argumentCount -eq 10) "report should record argument count without raw argument values"
  $serializedReport = Get-Content -LiteralPath $jsonReport.FullName -Raw
  Assert-True (-not $serializedReport.Contains("value with spaces")) "report must not expose raw process arguments"
  $runLog = Get-ChildItem -LiteralPath $passReports -Filter "*.log" | Select-Object -First 1
  $logContent = Get-Content -LiteralPath $runLog.FullName -Raw
  Assert-True (-not $logContent.Contains("value with spaces")) "execution log must not expose raw process arguments"
  Assert-True ((Get-ChildItem -LiteralPath $passReports -Filter "*.md").Count -eq 1) "Markdown report should exist"
  Assert-True ((Get-ChildItem -LiteralPath $passReports -Filter "*.log").Count -eq 1) "execution log should exist"
  $stdoutFile = Join-Path $passReports $passReport.steps[0].stdout
  $stderrFile = Join-Path $passReports $passReport.steps[0].stderr
  Assert-True ((Get-Content -LiteralPath $stdoutFile -Raw) -match "probe-stdout") "stdout should be captured"
  Assert-True ((Get-Content -LiteralPath $stderrFile -Raw) -match "probe-stderr") "stderr should be captured"

  # Test 2: child exit code 23 is retained in the report; runner returns 1.
  $failureConfig = Join-Path $projectRoot "failure.json"
  Write-Config $failureConfig ([pscustomobject]@{
    schemaVersion = 1
    project = @{ name = "shared-ci-smoke-fail"; reportDirectory = "artifacts/fail" }
    steps = @(@{
      name = "intentional-exit-23"
      command = $pwshPath
      args = @("-NoProfile", "-File", $helperPath, "-CapturePath", (Join-Path $projectRoot "failed-args.json"), "-ExitCode", "23")
    })
  })
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "failure.json"
    $failureRunnerExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($failureRunnerExit -eq 1) "failed step should produce runner exit code 1"
  $failureJson = Get-ChildItem -LiteralPath (Join-Path $projectRoot "artifacts/fail") -Filter "*.json" | Select-Object -First 1
  $failureReport = Get-Content -LiteralPath $failureJson.FullName -Raw | ConvertFrom-Json
  Assert-True ($failureReport.status -eq "failed") "failure report status should be failed"
  Assert-True ($failureReport.steps[0].exitCode -eq 23) "report must preserve child exit code 23"

  # Test 3: lexical traversal in a workingDirectory is rejected.
  $escapeConfig = Join-Path $projectRoot "escape.json"
  Write-Config $escapeConfig ([pscustomobject]@{
    schemaVersion = 1
    project = @{ name = "shared-ci-smoke-escape" }
    steps = @(@{ name = "escape"; command = $pwshPath; workingDirectory = "../outside"; args = @("-NoProfile", "-Version") })
  })
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "escape.json" 2>&1 | Out-Null
    $escapeRunnerExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($escapeRunnerExit -ne 0) "workingDirectory traversal must be rejected"

  # Test 4: a junction inside the project must not redirect a step outside it.
  if ($IsWindows) {
    $outsideRoot = Join-Path $testRoot "outside"
    $junctionPath = Join-Path $projectRoot "linked-outside"
    $null = New-Item -ItemType Directory -Path $outsideRoot -Force
    $null = New-Item -ItemType Junction -Path $junctionPath -Target $outsideRoot
    try {
      $junctionConfig = Join-Path $projectRoot "junction.json"
      Write-Config $junctionConfig ([pscustomobject]@{
        schemaVersion = 1
        project = @{ name = "shared-ci-smoke-junction" }
        steps = @(@{ name = "junction-escape"; command = $pwshPath; workingDirectory = "linked-outside"; args = @("-NoProfile", "-Version") })
      })
      Push-Location $projectRoot
      try {
        & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "junction.json" 2>&1 | Out-Null
        $junctionRunnerExit = $LASTEXITCODE
      } finally { Pop-Location }
      Assert-True ($junctionRunnerExit -ne 0) "junction path escaping project root must be rejected"
    } finally {
      if (Test-Path -LiteralPath $junctionPath) { Remove-Item -LiteralPath $junctionPath -Force }
    }
  }

  # Test 5: absolute config paths are rejected.
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath $successConfig 2>&1 | Out-Null
    $absoluteConfigExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($absoluteConfigExit -ne 0) "absolute config path must be rejected"

  # Test 6: invalid schema version is rejected before any configured command runs.
  $invalidMarker = Join-Path $projectRoot "invalid-config-command-ran.txt"
  $invalidConfig = Join-Path $projectRoot "invalid.json"
  Write-Config $invalidConfig ([pscustomobject]@{
    schemaVersion = 99
    project = @{ name = "shared-ci-smoke-invalid" }
    steps = @(@{ name = "must-not-run"; command = $pwshPath; args = @("-NoProfile", "-Command", "Set-Content -LiteralPath '$invalidMarker' -Value ran") })
  })
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "invalid.json" 2>&1 | Out-Null
    $invalidConfigExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($invalidConfigExit -ne 0) "unsupported schema version must be rejected"
  Assert-True (-not (Test-Path -LiteralPath $invalidMarker)) "invalid config must be rejected before executing steps"

  # Test 7: timeout terminates the child process and its descendant tree.
  $timeoutConfig = Join-Path $projectRoot "timeout.json"
  $childPidPath = Join-Path $projectRoot "timeout-child.pid"
  Write-Config $timeoutConfig ([pscustomobject]@{
    schemaVersion = 1
    project = @{ name = "shared-ci-smoke-timeout"; reportDirectory = "artifacts/timeout" }
    steps = @(@{
      name = "timeout-with-descendant"
      command = $pwshPath
      timeoutSeconds = 2
      args = @("-NoProfile", "-File", $helperPath, "-CapturePath", (Join-Path $projectRoot "timeout-capture.json"), "-ChildPidPath", $childPidPath, "-ChildExecutable", $pwshPath, "-SleepSeconds", "30")
    })
  })
  Push-Location $projectRoot
  try {
    & $pwshPath -NoProfile -File (Join-Path $platformRoot "scripts/run.ps1") -ConfigPath "timeout.json"
    $timeoutRunnerExit = $LASTEXITCODE
  } finally { Pop-Location }
  Assert-True ($timeoutRunnerExit -eq 1) "timed-out step should fail the runner"
  $timeoutJson = Get-ChildItem -LiteralPath (Join-Path $projectRoot "artifacts/timeout") -Filter "*.json" | Select-Object -First 1
  $timeoutReport = Get-Content -LiteralPath $timeoutJson.FullName -Raw | ConvertFrom-Json
  Assert-True ($timeoutReport.steps[0].timedOut -eq $true) "timeout must be recorded in JSON report"
  Assert-True ($timeoutReport.steps[0].exitCode -eq 124) "timeout should use exit code 124"
  Assert-True ($timeoutReport.steps[0].timeoutSeconds -eq 2) "configured timeout should be reported"
  $childPid = [int](Get-Content -LiteralPath $childPidPath -Raw)
  Start-Sleep -Milliseconds 500
  Assert-True ($null -eq (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) "timed-out process tree must not leave its child running"

  # Test 8: parallel runs in one report directory must not overwrite each other.
  $parallelConfig = Join-Path $projectRoot "parallel.json"
  Write-Config $parallelConfig ([pscustomobject]@{
    schemaVersion = 1
    project = @{ name = "shared-ci-smoke-parallel"; reportDirectory = "artifacts/parallel" }
    steps = @(@{
      name = "parallel-probe"
      command = $pwshPath
      args = @("-NoProfile", "-File", $helperPath, "-CapturePath", (Join-Path $projectRoot "parallel-capture.json"), "-SleepSeconds", "2")
    })
  })
  $runnerPath = Join-Path $platformRoot "scripts/run.ps1"
  $parallelOne = Start-Process -FilePath $pwshPath -ArgumentList @("-NoProfile", "-File", $runnerPath, "-ConfigPath", "parallel.json") -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden
  $parallelTwo = Start-Process -FilePath $pwshPath -ArgumentList @("-NoProfile", "-File", $runnerPath, "-ConfigPath", "parallel.json") -WorkingDirectory $projectRoot -PassThru -WindowStyle Hidden
  $parallelOne.WaitForExit()
  $parallelTwo.WaitForExit()
  Assert-True ($parallelOne.ExitCode -eq 0 -and $parallelTwo.ExitCode -eq 0) "both parallel runner processes should pass"
  $parallelReports = Join-Path $projectRoot "artifacts/parallel"
  $parallelJson = @(Get-ChildItem -LiteralPath $parallelReports -Filter "*.json")
  Assert-True ($parallelJson.Count -eq 2) "parallel runs must produce two JSON reports"
  $parallelIds = @($parallelJson | ForEach-Object { (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json).runId } | Select-Object -Unique)
  Assert-True ($parallelIds.Count -eq 2) "parallel run identifiers must be unique"
  foreach ($extension in @("md", "log", "out", "err")) {
    Assert-True (@(Get-ChildItem -LiteralPath $parallelReports -Filter "*.$extension").Count -eq 2) "parallel runs must preserve both .$extension artifacts"
  }

  Write-Host "PASS: runner smoke tests (8 groups; includes timeout tree termination and parallel report isolation)"
  Write-Host "Temporary test workspace: $testRoot"
  $testPassed = $true
}
catch {
  Write-Host "ERROR: $_"
  Write-Host "FAILED: runner smoke tests"
  Write-Host "Temporary test workspace retained for inspection: $testRoot"
  throw
}
finally {
  if ($testPassed) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
