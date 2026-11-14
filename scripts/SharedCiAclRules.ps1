function Get-SharedCiAclRuleAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$Rules,
        [Parameter(Mandatory=$true)][string[]]$ExpectedIdentities
    )
    $expected = @($ExpectedIdentities | Sort-Object -Unique)
    $unexpected = @($Rules | Where-Object {
        $_.AccessControlType -ne 'Allow' -or
        $_.Identity -notin $expected -or
        $_.Rights -ne 'FullControl' -or
        $_.InheritanceFlags -ne 'ContainerInherit, ObjectInherit' -or
        $_.PropagationFlags -ne 'None' -or
        [bool]$_.IsInherited
    })
    $seen = @($Rules | ForEach-Object { [string]$_.Identity } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $_ -notin $seen })
    [pscustomobject]@{
        IsValid = ($Rules.Count -eq 3 -and $unexpected.Count -eq 0 -and $missing.Count -eq 0)
        RuleCount = $Rules.Count
        UnexpectedRuleCount = $unexpected.Count
        MissingPrincipalCount = $missing.Count
        UnexpectedRules = $unexpected
        MissingPrincipals = $missing
    }
}

function Test-SharedCiReparsePointAttributes {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][IO.FileAttributes]$Attributes)
    return (($Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Get-SharedCiParentAclAssessment {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Path)

    $broadSids = @('S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-4','S-1-5-2')
    $writeMask = [int64](
        [Security.AccessControl.FileSystemRights]::WriteData -bor
        [Security.AccessControl.FileSystemRights]::AppendData -bor
        [Security.AccessControl.FileSystemRights]::CreateDirectories -bor
        [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership -bor
        [Security.AccessControl.FileSystemRights]::Modify -bor
        [Security.AccessControl.FileSystemRights]::FullControl
    )

    $candidate = [IO.Path]::GetFullPath($Path)
    while (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $parent = [IO.Directory]::GetParent($candidate)
        if ($null -eq $parent) { throw 'No existing ancestor directory could be found for the runner parent path.' }
        $candidate = $parent.FullName
    }

    $checked = @()
    $broadWrite = @()
    $reparse = @()
    $inspectionErrors = @()
    $current = [IO.DirectoryInfo]::new($candidate).FullName
    while ($current) {
        try {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            $checked += $current
            if (Test-SharedCiReparsePointAttributes -Attributes $item.Attributes) {
                $reparse += $current
            }
            $acl = Get-Acl -LiteralPath $current -ErrorAction Stop
            $rules = $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
            foreach ($rule in $rules) {
                $sid = $rule.IdentityReference.Value
                $rights = [int64]$rule.FileSystemRights
                if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
                    $sid -in $broadSids -and
                    (($rights -band $writeMask) -ne 0)) {
                    $broadWrite += [pscustomobject]@{
                        Ancestor = $current
                        PrincipalSid = $sid
                        Rights = $rule.FileSystemRights.ToString()
                        Inherited = [bool]$rule.IsInherited
                    }
                }
            }
        }
        catch {
            $inspectionErrors += [pscustomobject]@{
                Ancestor = $current
                ErrorType = $_.Exception.GetType().Name
            }
        }
        $parentInfo = [IO.Directory]::GetParent($current)
        if ($null -eq $parentInfo) { break }
        $next = $parentInfo.FullName
        if ([string]::Equals($next, $current, [StringComparison]::OrdinalIgnoreCase)) { break }
        $current = $next
    }

    [pscustomobject]@{
        IsSafe = ($reparse.Count -eq 0 -and $broadWrite.Count -eq 0 -and $inspectionErrors.Count -eq 0)
        RequestedPath = [IO.Path]::GetFullPath($Path)
        ExistingAncestorChecked = $candidate
        CheckedAncestors = $checked
        ReparsePointAncestors = $reparse
        BroadPrincipalWriteEntries = $broadWrite
        InspectionErrors = $inspectionErrors
        BroadPrincipalSidsChecked = $broadSids
        Notes = 'Read-only conservative check. It detects write-capable Allow ACEs for Everyone, Authenticated Users, BUILTIN Users, Interactive, and Network; it does not calculate effective access through nested group membership.'
    }
}
