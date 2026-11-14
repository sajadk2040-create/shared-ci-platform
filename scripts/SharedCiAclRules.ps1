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
