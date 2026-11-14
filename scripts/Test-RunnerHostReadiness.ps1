[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$RunnerRoot,
    [Parameter(Mandatory=$true)][ValidatePattern('^[^/]+/[^/]+$')][string]$ExpectedRepository,
    [string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProcessOwner {
    param([int]$ProcessId)
    try {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction Stop
        if ($null -eq $p) { return $null }
        $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction Stop
        if ($owner.ReturnValue -eq 0) { return "$($owner.Domain)\$($owner.User)" }
    } catch { }
    return $null
}

$resolvedRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RunnerRoot).Path)
$runnerFile = Join-Path $resolvedRoot '.runner'
$markerState = @{}
foreach ($name in @('.credentials', '.credentials_rsaparams')) {
    $markerState[$name] = Test-Path -LiteralPath (Join-Path $resolvedRoot $name) -PathType Leaf
}
$metadata = $null
$metadataError = $null
if (Test-Path -LiteralPath $runnerFile -PathType Leaf) {
    try { $metadata = Get-Content -LiteralPath $runnerFile -Raw | ConvertFrom-Json }
    catch { $metadataError = 'Runner metadata exists but could not be parsed as JSON.' }
}

$registeredRepository = $null
if ($null -ne $metadata) {
    foreach ($property in @('gitHubUrl', 'serverUrl', 'url')) {
        $value = $metadata.$property
        if ($value -and "$value" -match 'github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$') {
            $registeredRepository = $Matches[1]
            break
        }
    }
}

$processes = @()
try {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'Runner.Listener.exe'" |
        ForEach-Object {
            $exe = $_.ExecutablePath
            $matchesRoot = $false
            if ($exe) {
                $matchesRoot = [IO.Path]::GetFullPath($exe).StartsWith(
                    $resolvedRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
            }
            [pscustomobject]@{
                ProcessId = [int]$_.ProcessId
                ExecutablePath = $exe
                Owner = Get-ProcessOwner -ProcessId ([int]$_.ProcessId)
                PathMatchesTarget = $matchesRoot
            }
        })
} catch { $processes = @() }

$services = @()
try {
    $services = @(Get-CimInstance Win32_Service |
        Where-Object { $_.Name -like 'actions.runner*' -or $_.PathName -like '*Runner.Listener.exe*' } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                State = $_.State
                StartMode = $_.StartMode
                StartName = $_.StartName
                PathReferencesTarget = ($_.PathName -and $_.PathName.IndexOf(
                    $resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0)
            }
        })
} catch { $services = @() }

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
$currentIsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$aclEntries = @()
try {
    $acl = Get-Acl -LiteralPath $resolvedRoot
    $aclEntries = @($acl.Access | ForEach-Object {
        [pscustomobject]@{
            Identity = $_.IdentityReference.Value
            Rights = $_.FileSystemRights.ToString()
            Type = $_.AccessControlType.ToString()
            Inherited = [bool]$_.IsInherited
        }
    })
} catch { }

$repoMatches = ($registeredRepository -and
    $registeredRepository.Equals($ExpectedRepository, [StringComparison]::OrdinalIgnoreCase))
$metadataPresent = ($null -ne $metadata)
$report = [pscustomobject]@{
    SchemaVersion = 1
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
    RunnerRoot = $resolvedRoot
    ExpectedRepository = $ExpectedRepository
    MetadataPresent = $metadataPresent
    MetadataParseError = $metadataError
    RunnerName = if ($metadata) { $metadata.agentName } else { $null }
    RegisteredRepository = $registeredRepository
    RepositoryMatchesExpectation = [bool]$repoMatches
    WorkFolder = if ($metadata) { $metadata.workFolder } else { $null }
    CredentialMarkerFilesPresent = $markerState
    CredentialFileContentsRead = $false
    ListenerProcesses = $processes
    RunnerServices = $services
    AuditProcessIdentity = $currentIdentity.Name
    AuditProcessIsAdministrator = $currentIsAdmin
    RootAcl = $aclEntries
    Notes = @(
        'Read-only inventory; no runner credential file contents were opened.',
        'ACL output is descriptive and is not a complete security assessment.',
        'This script does not register, configure, stop, start, or modify a runner.',
        'A persistent self-hosted runner is not a security sandbox.'
    )
}
if ($ReportPath) {
    $reportFullPath = [IO.Path]::GetFullPath($ReportPath)
    $parent = Split-Path -Parent $reportFullPath
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Report parent directory does not exist: $parent"
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportFullPath -Encoding utf8
}
$report | ConvertTo-Json -Depth 8
if (-not $metadataPresent) { exit 2 }
if (-not $repoMatches) { exit 3 }
exit 0
