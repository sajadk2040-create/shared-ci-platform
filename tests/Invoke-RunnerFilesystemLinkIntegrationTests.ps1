[CmdletBinding()]
param(
    [switch]$EnableFilesystemLinkTests
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $EnableFilesystemLinkTests) {
    Write-Host 'SKIP: pass -EnableFilesystemLinkTests to create disposable filesystem links.'
    exit 0
}
if ($env:OS -ne 'Windows_NT') { throw 'Filesystem link integration tests are Windows-only.' }
if (-not [Environment]::Is64BitProcess) { throw 'Run with 64-bit PowerShell 7.' }

. (Join-Path $PSScriptRoot '..\scripts\SharedCiAclRules.ps1')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('shared-ci-link-integration-' + [guid]::NewGuid().ToString('N'))
$target = Join-Path $testRoot 'target'
$junction = Join-Path $testRoot 'junction'
$symbolicLink = Join-Path $testRoot 'symbolic-link'
$junctionCreated = $false
$symbolicLinkCreated = $false
$passed = $false

try {
    $null = New-Item -ItemType Directory -Path $target -Force
    Set-Content -LiteralPath (Join-Path $target 'marker.txt') -Value 'fixture'
    $mklinkOutput = & cmd.exe /d /c "mklink /J `"$junction`" `"$target`"" 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $junction -PathType Container)) {
        throw ("Junction creation failed; integration test cannot continue. " + ($mklinkOutput -join ' '))
    }
    $junctionCreated = $true
    $junctionItem = Get-Item -LiteralPath $junction -Force
    if (-not (Test-SharedCiReparsePointAttributes -Attributes $junctionItem.Attributes)) {
        throw 'Actual junction was not identified as a reparse point.'
    }
    Write-Host 'PASS: actual Windows junction is identified as a reparse point'

    try {
        $null = New-Item -ItemType SymbolicLink -Path $symbolicLink -Target $target -ErrorAction Stop
        $symbolicLinkCreated = $true
        $linkItem = Get-Item -LiteralPath $symbolicLink -Force
        if (-not (Test-SharedCiReparsePointAttributes -Attributes $linkItem.Attributes)) {
            throw 'Actual symbolic link was not identified as a reparse point.'
        }
        Write-Host 'PASS: actual Windows symbolic link is identified as a reparse point'
    }
    catch {
        if ($symbolicLinkCreated) { throw }
        Write-Host ('SKIP: symbolic-link creation is unavailable in this environment: ' + $_.Exception.Message)
    }

    $passed = $true
    Write-Host 'PASS: filesystem link integration tests'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        # Remove only the unique test-owned links and fixture root; never follow link targets.
        if ($symbolicLinkCreated) { Remove-Item -LiteralPath $symbolicLink -Force -ErrorAction SilentlyContinue }
        if ($junctionCreated) { & cmd.exe /d /c "rmdir `"$junction`"" | Out-Null }
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $passed) { Write-Host ("FAILED: temporary fixture may require manual review: " + $testRoot) }
}
