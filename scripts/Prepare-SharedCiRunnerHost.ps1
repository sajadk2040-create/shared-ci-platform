[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [string]$AccountName = 'svc-shared-ci',
    [string]$RunnerRoot = 'C:\GitHubRunners\shared-ci',
    [switch]$Apply,
    [string]$ConfirmationText
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$requiredConfirmation = 'CREATE SHARED-CI SERVICE ACCOUNT AND ISOLATED DIRECTORY'
. (Join-Path $PSScriptRoot 'SharedCiAclRules.ps1')
function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if ($env:OS -ne 'Windows_NT') { throw 'This provisioning script is Windows-only.' }
if ($AccountName -notmatch '^[A-Za-z][A-Za-z0-9_-]{2,19}$') { throw 'AccountName must be 3-20 safe characters.' }
$targetRoot = [IO.Path]::GetFullPath($RunnerRoot).TrimEnd('\')
$profileRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
if ($targetRoot.StartsWith($profileRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or $targetRoot.Equals($profileRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'RunnerRoot must be outside the current user profile.' }
if ($targetRoot -notmatch '^[A-Za-z]:\\GitHubRunners\\[A-Za-z0-9_-]+$') { throw 'RunnerRoot must be directly under <drive>:\GitHubRunners\.' }
if (Test-Path -LiteralPath $targetRoot) { throw "Target directory already exists; refusing to reuse or modify it: $targetRoot" }
$parentPath = Split-Path -Parent $targetRoot
$parentAclAssessment = Get-SharedCiParentAclAssessment -Path $parentPath
$existing = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount=True AND Name='$AccountName'" -ErrorAction Stop |
    Where-Object { $_.LocalAccount -and $_.Name -eq $AccountName }
if ($null -ne $existing) { throw "Local account '$AccountName' already exists; refusing to modify an existing account." }
[pscustomobject]@{
    AccountName = $AccountName
    RunnerRoot = $targetRoot
    ParentAclAssessment = $parentAclAssessment
    ExistingAccountWillBeModified = $false
    ExistingRunnerWillBeModified = $false
    RunnerRegistration = 'Not performed'
    WindowsServiceInstallation = 'Not performed'
    GitHubCredentialsReadOrStored = $false
    Mode = if ($Apply) { 'Apply requested' } else { 'Plan only' }
} | ConvertTo-Json -Depth 4
if (-not $Apply) {
    Write-Host 'Plan only. No account or directory was created. Re-run with -Apply and the exact confirmation text to authorize local changes.'
    return
}
if (-not [Environment]::Is64BitProcess) { throw 'Apply mode requires 64-bit PowerShell 7 because the Windows LocalAccounts module is not supported in 32-bit PowerShell.' }
if (-not (Test-IsAdministrator)) { throw 'Run this script from an elevated 64-bit PowerShell 7 session.' }
if (-not $parentAclAssessment.IsSafe) { throw 'Runner parent path failed the read-only ACL/reparse-point preflight. Review ParentAclAssessment before provisioning.' }
Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction Stop
if ($ConfirmationText -cne $requiredConfirmation) { throw "Explicit confirmation required. Supply -ConfirmationText exactly: $requiredConfirmation" }
if (-not $PSCmdlet.ShouldProcess("$AccountName and $targetRoot", 'Create standard local account and isolated directory')) { throw 'Provisioning was not approved by ShouldProcess.' }
$password = $null
$createdAccount = $false
$createdDirectory = $false
try {
    $password = Read-Host "Enter a strong password for local account $AccountName" -AsSecureString
    if ($null -eq $password -or $password.Length -lt 16) { throw 'Password must contain at least 16 characters.' }
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) { throw 'The dedicated parent directory must exist before Apply. Create and secure it manually as an administrator, then rerun the read-only preflight.' }
    New-Item -Path $targetRoot -ItemType Directory -ErrorAction Stop | Out-Null
    $createdDirectory = $true
    $user = New-LocalUser -Name $AccountName -Password $password -Description 'Dedicated least-privilege account for Shared CI Platform runner; not yet registered.'
    $createdAccount = $true
    $administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $userSid = if ($user.SID -is [Security.Principal.SecurityIdentifier]) { $user.SID } else { [Security.Principal.SecurityIdentifier]::new([string]$user.SID) }
    $security = [Security.AccessControl.DirectorySecurity]::new()
    $security.SetAccessRuleProtection($true, $false)
    $inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    foreach ($sid in @($administratorsSid, $systemSid, $userSid)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, [Security.AccessControl.FileSystemRights]::FullControl, $inheritance, $propagation, $allow)
        [void]$security.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $targetRoot -AclObject $security
    [pscustomobject]@{
        Result = 'Prepared'
        AccountName = $user.Name
        AccountSid = $userSid.Value
        RunnerRoot = $targetRoot
        DirectoryAcl = 'Protected: SYSTEM, local Administrators, and dedicated account only'
        ExistingAccountsModified = $false
        ExistingRunnerModified = $false
        RunnerRegistered = $false
        WindowsServiceInstalled = $false
        CredentialMaterialPersistedByScript = $false
        FollowUp = 'Review account and ACL locally. Runner registration and service installation require a separate reviewed step.'
    } | ConvertTo-Json -Depth 4
}
catch {
    Write-Error $_
    if ($createdAccount -or $createdDirectory) {
        Write-Warning 'Provisioning partially changed the host. No automatic rollback was attempted. Inspect locally before retrying.'
        Write-Warning ("Account created by this run: " + $createdAccount)
        Write-Warning ("Directory created by this run: " + $createdDirectory)
    }
    throw
}
finally { if ($null -ne $password) { $password.Dispose() } }
