[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z][A-Za-z0-9_-]{2,19}$')][string]$AccountName,
    [Parameter(Mandatory=$true)][string]$RunnerRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This audit is Windows-only.' }
if (-not [Environment]::Is64BitProcess) { throw 'Run with 64-bit PowerShell 7.' }
Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction Stop
$root = [IO.Path]::GetFullPath($RunnerRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "RunnerRoot does not exist: $root" }
$current = $root
while ($current) {
    $currentItem = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    if (($currentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "RunnerRoot path or one of its ancestors is a reparse point: $current"
    }
    $parent = [IO.Directory]::GetParent($current)
    if ($null -eq $parent) { break }
    $next = $parent.FullName
    if ([string]::Equals($next, $current, [StringComparison]::OrdinalIgnoreCase)) { break }
    $current = $next
}
$user = Get-LocalUser -Name $AccountName -ErrorAction Stop
$adminSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$userSid = if ($user.SID -is [Security.Principal.SecurityIdentifier]) { $user.SID } else { [Security.Principal.SecurityIdentifier]::new([string]$user.SID) }
$adminGroup = Get-LocalGroup -SID $adminSid -ErrorAction Stop
$adminMembers = @(Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction Stop)
$isAdministrator = @($adminMembers | Where-Object {
    $memberSid = if ($_.SID -is [Security.Principal.SecurityIdentifier]) { $_.SID } else { [Security.Principal.SecurityIdentifier]::new([string]$_.SID) }
    $memberSid -eq $userSid
}).Count -gt 0
$acl = Get-Acl -LiteralPath $root
$rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
$expected = @($adminSid.Value, $systemSid.Value, $userSid.Value)
$unexpected = @($rules | Where-Object {
    $_.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
    $_.IdentityReference.Value -notin $expected -or
    $_.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or
    $_.InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit) -or
    $_.PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None -or
    $_.IsInherited
})
$seen = @($rules | ForEach-Object { $_.IdentityReference.Value } | Sort-Object -Unique)
$missing = @($expected | Where-Object { $_ -notin $seen })
$checks = [ordered]@{
    AccountExists = ($null -ne $user)
    AccountEnabled = [bool]$user.Enabled
    AccountIsNotAdministrator = (-not $isAdministrator)
    AclInheritanceDisabled = [bool]$acl.AreAccessRulesProtected
    AclContainsExactlyThreeExpectedRules = ($rules.Count -eq 3 -and $unexpected.Count -eq 0 -and $missing.Count -eq 0)
    UnexpectedAclRuleCount = $unexpected.Count
    MissingAclPrincipalCount = $missing.Count
}
$failed = @($checks.GetEnumerator() | Where-Object { $_.Key -in @('AccountExists','AccountEnabled','AccountIsNotAdministrator','AclInheritanceDisabled','AclContainsExactlyThreeExpectedRules') -and -not [bool]$_.Value })
$result = [ordered]@{
    Result = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    AccountName = $AccountName
    AccountSid = $userSid.Value
    RunnerRoot = $root
    Checks = $checks
    Notes = 'Read-only audit. No account, group, ACL, runner registration, or service changes were made.'
}
$result | ConvertTo-Json -Depth 5
if ($failed.Count -gt 0) { exit 4 }
exit 0
