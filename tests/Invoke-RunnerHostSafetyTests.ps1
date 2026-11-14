[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$preflight = Join-Path $RepositoryRoot 'scripts/Test-RunnerHostReadiness.ps1'
$provision = Join-Path $RepositoryRoot 'scripts/Prepare-SharedCiRunnerHost.ps1'
foreach ($path in @($preflight, $provision)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required script missing: $path" }
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $details = ($errors | ForEach-Object { $_.Message }) -join [Environment]::NewLine
        throw ("Parser failure in " + $path + [Environment]::NewLine + $details)
    }
}
Write-Host 'PASS: runner host scripts parse'
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "ASSERTION FAILED: $Message" } }
function Invoke-PwshCapture {
    param([string[]]$Arguments)
    $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive @Arguments 2>&1 | ForEach-Object { "$_" })
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join [Environment]::NewLine) }
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("shared-ci-host-tests-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$passed = $false
try {
    $fixture = Join-Path $testRoot 'runner'
    $null = New-Item -ItemType Directory -Path $fixture
    @{ agentName='fixture-runner'; gitHubUrl='https://github.com/example-org/example-repo'; workFolder='_work' } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixture '.runner') -Encoding utf8
    $null = New-Item -ItemType Directory -Path (Join-Path $fixture '_work')
    $sentinel = 'DO-NOT-LEAK-CREDENTIAL-CONTENT-7F19A2'
    Set-Content -LiteralPath (Join-Path $fixture '.credentials') -Value $sentinel -NoNewline
    Set-Content -LiteralPath (Join-Path $fixture '.credentials_rsaparams') -Value $sentinel -NoNewline
    $reportPath = Join-Path $testRoot 'preflight-report.json'
    $good = Invoke-PwshCapture -Arguments @('-File',$preflight,'-RunnerRoot',$fixture,'-ExpectedRepository','example-org/example-repo','-ReportPath',$reportPath)
    Assert-True ($good.ExitCode -eq 0) 'matching repository metadata should return exit code 0'
    $reportText = Get-Content -LiteralPath $reportPath -Raw
    $report = $reportText | ConvertFrom-Json
    Assert-True ($report.RepositoryMatchesExpectation -eq $true) 'report should mark repository match'
    Assert-True ($report.CredentialMarkerFilesPresent.'.credentials' -eq $true) 'credential marker presence should be reported'
    Assert-True ($report.CredentialFileContentsRead -eq $false) 'report must state credential contents were not read'
    Assert-True (-not $reportText.Contains($sentinel)) 'credential file contents must not appear in report'
    Assert-True (-not $good.Output.Contains($sentinel)) 'credential file contents must not appear in console output'
    $wrong = Invoke-PwshCapture -Arguments @('-File',$preflight,'-RunnerRoot',$fixture,'-ExpectedRepository','another-org/another-repo')
    Assert-True ($wrong.ExitCode -eq 3) 'repository mismatch must return exit code 3'
    $missing = Join-Path $testRoot 'missing-metadata'
    $null = New-Item -ItemType Directory -Path $missing
    $absent = Invoke-PwshCapture -Arguments @('-File',$preflight,'-RunnerRoot',$missing,'-ExpectedRepository','example-org/example-repo')
    Assert-True ($absent.ExitCode -eq 2) 'missing runner metadata must return exit code 2'
    Write-Host 'PASS: preflight match/mismatch, missing metadata, and credential non-disclosure'

    $drive = $env:SystemDrive
    if (-not $drive) { $drive = [IO.Path]::GetPathRoot($env:WINDIR).TrimEnd('\') }
    $safeName = 'host-test-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $target = Join-Path (Join-Path $drive 'GitHubRunners') $safeName
    $account = 'svc-test-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $plan = Invoke-PwshCapture -Arguments @('-File',$provision,'-AccountName',$account,'-RunnerRoot',$target)
    Assert-True ($plan.ExitCode -eq 0) ("plan-only invocation should succeed. Output: " + $plan.Output)
    Assert-True (-not (Test-Path -LiteralPath $target)) 'plan-only must not create runner directory'
    Assert-True ($plan.Output.Contains('"Mode": "Plan only"')) 'plan output must identify Plan only mode'
    $badName = Invoke-PwshCapture -Arguments @('-File',$provision,'-AccountName','invalid account','-RunnerRoot',$target)
    Assert-True ($badName.ExitCode -ne 0) 'invalid account name must be rejected'
    $badPath = Invoke-PwshCapture -Arguments @('-File',$provision,'-AccountName',$account,'-RunnerRoot',(Join-Path $testRoot 'inside-profile'))
    Assert-True ($badPath.ExitCode -ne 0) 'non-approved path layout must be rejected'
    Assert-True (-not (Test-Path -LiteralPath $target)) 'rejected inputs must not create runner directory'
    Write-Host 'PASS: provisioning plan-only non-mutation and invalid-input rejection'

    $source = Get-Content -LiteralPath $provision -Raw
    Assert-True ($source.Contains('Read-Host') -and $source.Contains('-AsSecureString')) 'password must be requested as SecureString'
    Assert-True ($source.Contains('$ConfirmationText -cne $requiredConfirmation')) 'exact confirmation gate must exist'
    Assert-True ($source.Contains('Test-IsAdministrator')) 'administrator gate must exist'
    Assert-True ($source.Contains('SetAccessRuleProtection($true, $false)')) 'directory ACL inheritance must be protected'
    Assert-True (-not $source.Contains('ConvertFrom-SecureString')) 'password must not be serialized by the script'
    Assert-True (-not $source.Contains('ConvertTo-SecureString')) 'password must not be reconstructed from persisted text'
    Assert-True (-not $source.Contains('config.cmd')) 'provisioning must not register a runner'
    Assert-True (-not $source.Contains('svc install')) 'provisioning must not install runner service'
    Write-Host 'PASS: provisioning source safety guards'
    Write-Host 'NOTE: no account creation, password setting, ACL mutation, runner registration, or service installation was exercised.'
    $passed = $true
    Write-Host 'PASS: runner host safety tests (3 groups)'
}
catch {
    Write-Host ("FAILED: runner host safety tests — " + $_)
    Write-Host ("Temporary test workspace retained: " + $testRoot)
    throw
}
finally { if ($passed) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue } }
