# Runner host safety test suite

Run on a disposable or otherwise approved Windows test host with PowerShell 7. No Pester package is required.

    pwsh -NoProfile -File tests/Invoke-RunnerHostSafetyTests.ps1

The harness is non-provisioning. It performs:

1. PowerShell parser validation for both host scripts.
2. Preflight fixture tests for matching repository metadata (exit 0), mismatched repository (exit 3), missing metadata (exit 2), and credential marker existence reporting. Sentinel contents placed in fake credential files must not appear in console output or the JSON report.
3. Provisioning plan-only test with a unique account name and unique path. It verifies that no target directory is created.
4. Invalid account/path rejection tests, with a second no-mutation assertion.
5. Static safety-guard checks for SecureString password input, exact confirmation, administrator check, protected ACL inheritance, and absence of runner registration/service installation commands.

The test harness uses only a temporary fixture under the system temp directory for preflight. Provisioning tests do not create local accounts, change passwords, create the target runner directory, modify ACLs, register runners, or install services.

## Boundaries

- These tests do not validate the actual Windows ACL result or behavior of New-LocalUser on a production host.
- Static source checks are regression tripwires, not a substitute for code review.
- The plan-only test requires the Windows LocalAccounts PowerShell module (Get-LocalUser) and an unused unique account name.
- Run full provisioning/ACL integration tests only on a disposable Windows VM after a separate explicit approval. Never use the existing nti-national-traffic-intelligence runner installation as a test fixture.
- Do not publish raw test output if it contains machine-specific paths or identities.
