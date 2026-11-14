# Read-only runner isolation audit

After a separately approved provisioning run on a disposable Windows VM, run this audit from elevated or appropriately authorized 64-bit PowerShell 7:

    pwsh -NoProfile -File scripts/Test-SharedCiRunnerIsolation.ps1 -AccountName svc-shared-ci -RunnerRoot C:\GitHubRunners\shared-ci

The script imports the built-in Microsoft.PowerShell.LocalAccounts module and verifies:

- the named local account exists and is enabled;
- the account is not a member of the local Administrators group;
- the runner root is not a junction or symbolic link (reparse point);
- ACL inheritance is disabled on the runner root;
- the root contains exactly three explicit, non-inherited Allow/FullControl rules for SYSTEM, local Administrators, and the dedicated account, with container/object inheritance.

Exit code 0 means the listed checks passed; exit code 4 means one or more checks failed. Environmental errors (missing account, path, or module) terminate with an error.

This is a read-only verifier. It does not create or modify accounts, group membership, ACLs, runner registration, or services. Review output locally before sharing because it includes the account SID and filesystem path. Run only against the dedicated Shared CI runner directory, never the unrelated existing runner installation.

The verifier is newly authored and has not yet been runtime-validated. The host safety harness now parser-checks this script and statically asserts the reparse-point guard; those checks still require a fresh Windows execution. Its first execution belongs on the disposable Windows VM after provisioning and before runner registration.
