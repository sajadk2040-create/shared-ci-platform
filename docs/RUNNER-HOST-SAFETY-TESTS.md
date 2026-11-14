# Runner host safety test suite

Run on a disposable or otherwise approved Windows test host with PowerShell 7. No Pester package is required.

    pwsh -NoProfile -File tests/Invoke-RunnerHostSafetyTests.ps1

The harness is non-provisioning. It performs:

1. PowerShell parser validation for the preflight, provisioning, isolation-audit, shared ACL helper, and opt-in filesystem-link integration scripts.
2. Preflight fixture tests for matching repository metadata (exit 0), mismatched repository (exit 3), missing metadata (exit 2), and credential marker existence reporting. Sentinel contents placed in fake credential files must not appear in console output or the JSON report.
3. Provisioning plan-only test with a unique account name and unique path. It verifies that no target directory is created.
4. Isolation-audit source checks for root and ancestor reparse-point rejection, including volume-root-safe path traversal; synthetic ordinary-directory versus reparse-point attribute cases.
5. Synthetic ACL rule assessment: a valid exact-three-principal ACL passes; an extra principal, Deny ACE, missing principal, wrong rights, or inherited ACE fails.
6. Static provisioning safety-guard checks for SecureString password input, exact confirmation, administrator check, protected ACL inheritance, and absence of runner registration/service installation commands.

The harness does not create local accounts, change passwords, create the target runner directory, modify ACLs, register runners, or install services.

## Real filesystem-link integration test (opt-in)

On a disposable or approved Windows test host with PowerShell 7, run:

```powershell
pwsh -NoProfile -File tests/Invoke-RunnerFilesystemLinkIntegrationTests.ps1 -EnableFilesystemLinkTests
```

This creates a uniquely named fixture under the system temporary directory, creates a real directory junction, and checks the actual filesystem attributes with the shared reparse-point predicate. It also attempts a real symbolic link. If Windows policy or privilege prevents symbolic-link creation, that subtest is reported as SKIP; junction creation is mandatory for this opt-in run. Cleanup is limited to the generated fixture and the links created by this script. Do not run against the existing runner installation or production paths.

## Boundaries

- Synthetic ACL tests validate pure rule-assessment logic, not the Windows ACL provider or behavior of New-LocalUser on a production host.
- Static source checks are regression tripwires, not a substitute for code review.
- Plan-only account-existence checks use the Windows CIM provider and do not require the LocalAccounts module. Apply mode explicitly requires 64-bit PowerShell 7 and imports Microsoft.PowerShell.LocalAccounts before account creation.
- Run provisioning/ACL integration tests only on a disposable Windows VM after separate explicit approval.
- Do not publish raw test output if it contains machine-specific paths or identities.

## Execution evidence — 2026-11-14

An earlier revision of the host safety harness passed three groups on the authorized Windows 11 host. That evidence does not cover the current five-group harness or the new real-filesystem-link integration script.

## Current validation status

The five-group host safety harness, the real junction integration test, the optional symbolic-link test, and the read-only isolation audit remain **pending execution on Windows**. No account creation, password setting, ACL mutation, runner registration, or service installation has been performed.
