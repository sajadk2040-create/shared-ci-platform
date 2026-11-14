# Runner host safety test suite

Run on a disposable or otherwise approved Windows test host with PowerShell 7. No Pester package is required.

    pwsh -NoProfile -File tests/Invoke-RunnerHostSafetyTests.ps1

The harness is non-provisioning. It performs:

1. PowerShell parser validation for the preflight, provisioning, isolation-audit, and shared ACL helper scripts.
2. Preflight fixture tests for matching repository metadata (exit 0), mismatched repository (exit 3), missing metadata (exit 2), and credential marker existence reporting. Sentinel contents placed in fake credential files must not appear in console output or the JSON report.
3. Provisioning plan-only test with a unique account name and unique path. It verifies that no target directory is created.
4. Isolation-audit source checks for root and ancestor reparse-point rejection, including volume-root-safe path traversal; synthetic ordinary-directory versus reparse-point attribute cases model both symbolic links and junctions without creating filesystem links.
5. Synthetic ACL rule assessment: a valid exact-three-principal ACL passes; an extra principal, Deny ACE, missing principal, wrong rights, or inherited ACE fails.
6. Static provisioning safety-guard checks for SecureString password input, exact confirmation, administrator check, protected ACL inheritance, and absence of runner registration/service installation commands.

The test harness uses only a temporary fixture under the system temp directory for preflight. Provisioning tests do not create local accounts, change passwords, create the target runner directory, modify ACLs, register runners, or install services.

## Boundaries

- Synthetic ACL tests validate the pure rule-assessment logic, not the Windows ACL provider or behavior of New-LocalUser on a production host.
- Static source checks are regression tripwires, not a substitute for code review.
- Plan-only account-existence checks use the Windows CIM provider and do not require the LocalAccounts module. Apply mode explicitly requires 64-bit PowerShell 7 and imports Microsoft.PowerShell.LocalAccounts before any account creation.
- Run full provisioning/ACL integration tests only on a disposable Windows VM after a separate explicit approval. Never use the existing nti-national-traffic-intelligence runner installation as a test fixture.
- Do not publish raw test output if it contains machine-specific paths or identities.


## Execution evidence — 2026-11-14

Executed on the authorized Windows 11 host using PowerShell 7 after pulling the remediation commit. Observed output:

- PASS: runner host scripts parse
- PASS: preflight match/mismatch, missing metadata, and credential non-disclosure
- PASS: provisioning plan-only non-mutation and invalid-input rejection
- PASS: provisioning source safety guards
- PASS: runner host safety tests (3 groups)

The plan-only compatibility issue was resolved by replacing the plan-stage Get-LocalUser dependency with a read-only Windows CIM account lookup. Apply mode separately requires elevated 64-bit PowerShell 7 and imports Microsoft.PowerShell.LocalAccounts. No account creation, password setting, ACL mutation, runner registration, or service installation was exercised. This evidence is limited to the tests listed above and is not an approval to provision the production host.


## Latest additions — not yet executed on Windows

The current harness contains five logical groups and includes parser validation for `scripts/SharedCiAclRules.ps1`, volume-root-safe ancestor checks, and synthetic positive/negative ACL cases. These additions are committed but are not considered passed until the latest `main` revision is pulled and the command above completes successfully on Windows PowerShell 7. The link tests exercise the shared attribute predicate with synthetic metadata; they do not create real junctions or symbolic links and do not replace a dedicated Windows integration test. The historical execution evidence below applies only to the earlier three-group harness revision.
