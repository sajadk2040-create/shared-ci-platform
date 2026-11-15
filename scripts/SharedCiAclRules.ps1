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
        IsValid = ($Rules.Count -eq $expected.Count -and $unexpected.Count -eq 0 -and $missing.Count -eq 0)
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

function Test-SharedCiBroadPrincipalWriteRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PrincipalSid,
        [Parameter(Mandatory=$true)][Security.AccessControl.FileSystemRights]$Rights,
        [Parameter(Mandatory=$true)][Security.AccessControl.AccessControlType]$AccessControlType
    )
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
        [Security.AccessControl.FileSystemRights]::TakeOwnership
    )
    return (
        $AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        $PrincipalSid -in $broadSids -and
        (([int64]$Rights -band $writeMask) -ne 0)
    )
}

function Test-SharedCiBroadPrincipalDeleteChildRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PrincipalSid,
        [Parameter(Mandatory=$true)][Security.AccessControl.FileSystemRights]$Rights,
        [Parameter(Mandatory=$true)][Security.AccessControl.AccessControlType]$AccessControlType
    )
    $broadSids = @('S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-4','S-1-5-2')
    return ($AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and $PrincipalSid -in $broadSids -and (([int64]$Rights -band [int64][Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles) -ne 0))
}

function Test-SharedCiParentAclState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][bool]$ParentExists,
        [Parameter(Mandatory=$true)][bool]$ParentAclValid,
        [Parameter(Mandatory=$true)][bool]$ParentAclProtected,
        [Parameter(Mandatory=$true)][int]$ReparsePointCount,
        [Parameter(Mandatory=$true)][int]$InspectionErrorCount,
        [Parameter(Mandatory=$true)][int]$AncestorDeleteChildCount
    )
    return ($ParentExists -and $ParentAclValid -and $ParentAclProtected -and $ReparsePointCount -eq 0 -and $InspectionErrorCount -eq 0 -and $AncestorDeleteChildCount -eq 0)
}

function Get-SharedCiParentAclAssessment {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Path)

    $broadSids = @('S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-4','S-1-5-2')
    $expectedParentSids = @('S-1-5-18','S-1-5-32-544')
    $requested = [IO.Path]::GetFullPath($Path)

    if (-not (Test-Path -LiteralPath $requested -PathType Container)) {
        return [pscustomobject]@{
            IsSafe = $false
            ParentExists = $false
            RequestedPath = $requested
            ExistingAncestorChecked = $null
            CheckedAncestors = @()
            ReparsePointAncestors = @()
            BroadPrincipalWriteEntries = @()
            AncestorDeleteChildEntries = @()
            InspectionErrors = @()
            ParentAclAssessment = $null
            ParentAclProtected = $false
            BroadPrincipalSidsChecked = $broadSids
            Notes = 'The dedicated parent directory must be created and secured by an administrator before provisioning. Missing parents are never created automatically.'
        }
    }

    $checked = @()
    $broadWrite = @()
    $ancestorDeleteChild = @()
    $reparse = @()
    $inspectionErrors = @()
    $parentAclAssessment = $null
    $parentAclProtected = $false
    $current = [IO.DirectoryInfo]::new($requested).FullName
    $isFirst = $true

    while ($current) {
        try {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            $checked += $current
            if (Test-SharedCiReparsePointAttributes -Attributes $item.Attributes) { $reparse += $current }

            $acl = Get-Acl -LiteralPath $current -ErrorAction Stop
            $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))

            if ($isFirst) {
                $parentAclProtected = [bool]$acl.AreAccessRulesProtected
                $normalizedRules = @($rules | ForEach-Object {
                    [pscustomobject]@{
                        Identity = $_.IdentityReference.Value
                        AccessControlType = $_.AccessControlType.ToString()
                        Rights = $_.FileSystemRights.ToString()
                        InheritanceFlags = $_.InheritanceFlags.ToString()
                        PropagationFlags = $_.PropagationFlags.ToString()
                        IsInherited = [bool]$_.IsInherited
                    }
                })
                $parentAclAssessment = Get-SharedCiAclRuleAssessment -Rules $normalizedRules -ExpectedIdentities $expectedParentSids

                foreach ($rule in $rules) {
                    $sid = $rule.IdentityReference.Value
                    if (Test-SharedCiBroadPrincipalWriteRule -PrincipalSid $sid -Rights $rule.FileSystemRights -AccessControlType $rule.AccessControlType) {
                        $broadWrite += [pscustomobject]@{ Ancestor = $current; PrincipalSid = $sid; Rights = $rule.FileSystemRights.ToString(); Inherited = [bool]$rule.IsInherited }
                    }
                }
            }
            else {
                foreach ($rule in $rules) {
                    $sid = $rule.IdentityReference.Value
                    if (Test-SharedCiBroadPrincipalDeleteChildRule -PrincipalSid $sid -Rights $rule.FileSystemRights -AccessControlType $rule.AccessControlType) {
                        $ancestorDeleteChild += [pscustomobject]@{ Ancestor = $current; PrincipalSid = $sid; Rights = $rule.FileSystemRights.ToString(); Inherited = [bool]$rule.IsInherited }
                    }
                }
            }
        }
        catch {
            $inspectionErrors += [pscustomobject]@{ Ancestor = $current; ErrorType = $_.Exception.GetType().Name }
        }

        $parentInfo = [IO.Directory]::GetParent($current)
        if ($null -eq $parentInfo) { break }
        $next = $parentInfo.FullName
        if ([string]::Equals($next, $current, [StringComparison]::OrdinalIgnoreCase)) { break }
        $current = $next
        $isFirst = $false
    }

    $safe = Test-SharedCiParentAclState -ParentExists $true -ParentAclValid ([bool]$parentAclAssessment.IsValid -and $broadWrite.Count -eq 0) -ParentAclProtected $parentAclProtected -ReparsePointCount $reparse.Count -InspectionErrorCount $inspectionErrors.Count -AncestorDeleteChildCount $ancestorDeleteChild.Count

    [pscustomobject]@{
        IsSafe = $safe
        ParentExists = $true
        RequestedPath = $requested
        ExistingAncestorChecked = $requested
        CheckedAncestors = $checked
        ReparsePointAncestors = $reparse
        BroadPrincipalWriteEntries = $broadWrite
        AncestorDeleteChildEntries = $ancestorDeleteChild
        InspectionErrors = $inspectionErrors
        ParentAclAssessment = $parentAclAssessment
        ParentAclProtected = $parentAclProtected
        BroadPrincipalSidsChecked = $broadSids
        Notes = 'The existing parent must have protected ACL inheritance and exactly two explicit inheritable FullControl Allow ACEs: SYSTEM and local Administrators. Ancestors are checked for reparse points, inspection failures, and broad-principal DeleteSubdirectoriesAndFiles rights. Broad create-directory rights on an ancestor do not invalidate an already-existing protected parent.'
    }
}

function Test-SharedCiExistingRunnerDirectoryState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][bool]$DirectoryExists,
        [Parameter(Mandatory=$true)][bool]$IsReparsePoint,
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
        -not [bool]$_.IsInherited
    })
    $seen = @($Rules | ForEach-Object { [string]$_.Identity } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $_ -notin $seen })
    [pscustomobject]@{
        IsSafe = ($DirectoryExists -and -not $IsReparsePoint -and $Rules.Count -eq $expected.Count -and $unexpected.Count -eq 0 -and $missing.Count -eq 0)
        DirectoryExists = $DirectoryExists
        IsReparsePoint = $IsReparsePoint
        RuleCount = $Rules.Count
        UnexpectedRuleCount = $unexpected.Count
        MissingPrincipalCount = $missing.Count
    }
}
