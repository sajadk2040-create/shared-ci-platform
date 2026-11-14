# Local validation guide

This repository can be validated on a developer-controlled Windows machine without GitHub Actions and without a registered GitHub runner.

## Requirements

- Windows 10/11 or Windows Server supported by PowerShell 7.
- PowerShell 7 (`pwsh`) installed and available on `PATH`.
- A clean checkout of this repository.
- No GitHub token, repository secret, or production credential is needed.

## Consumer starter template validation

```powershell
pwsh -NoProfile -File tests/Invoke-ConsumerTemplateTests.ps1
```

This local, non-provisioning test checks the consumer starter config structure, parses its PowerShell smoke script, and verifies the workflow's matching immutable-SHA placeholders, manual-only trigger and read-only permission. It is a focused structural test, not a full JSON Schema validator or a GitHub Actions execution. See [Consumer template validation](CONSUMER-TEMPLATE-TESTS.md).

## Core runner validation

From the repository root:

```powershell
$PSVersionTable.PSVersion
pwsh -NoProfile -File tests/Invoke-RunnerSmokeTests.ps1
```

The core harness exercises child-process execution, report generation, stdout/stderr capture, exact argument boundaries, exit-code handling, lexical path confinement, invalid-config rejection, Windows junction traversal, timeout process-tree termination, and concurrent report isolation. It exits non-zero on the first failed assertion.

## Runner host safety tests

```powershell
pwsh -NoProfile -File tests/Invoke-RunnerHostSafetyTests.ps1
```

This non-provisioning harness validates parser syntax for the host scripts and opt-in link integration script, runner metadata handling, credential-content non-disclosure, provisioning plan-only behavior, ACL assessment cases, isolation-audit source guards and static provisioning safety checks. It does not create accounts, set passwords, mutate ACLs, register runners or install services.

## Real Windows filesystem-link integration

This opt-in test creates a real junction in a unique temporary directory and verifies the actual filesystem attributes. It also attempts a symbolic link, reporting SKIP if the environment does not permit creating one.

```powershell
pwsh -NoProfile -File tests/Invoke-RunnerFilesystemLinkIntegrationTests.ps1 -EnableFilesystemLinkTests
```

Run only on a disposable or approved Windows test host. The script does not touch runner installation paths and cleans up only its unique temporary fixture. Junction creation is required; symbolic-link creation is environment-dependent.

## Read-only post-provisioning isolation audit

Only after a separately approved provisioning run on a disposable Windows VM:

```powershell
pwsh -NoProfile -File scripts/Test-SharedCiRunnerIsolation.ps1 -AccountName svc-shared-ci -RunnerRoot C:\GitHubRunners\shared-ci
```

The verifier is read-only. It checks the dedicated account, local Administrators membership, protected ACL entries and reparse points along the runner-root ancestor chain. Its current revision still requires Windows runtime validation. See [Runner host isolation audit](RUNNER-HOST-ISOLATION-AUDIT.md).

## Evidence to record

For each validation run, record the Windows edition/build, PowerShell version, exact command, complete console output, whether junction and symbolic-link tests ran or were skipped, and the tested commit SHA. Redact machine-specific paths and identities before publishing. Use [the validation evidence template](VALIDATION-RESULTS-TEMPLATE.md).

## Boundaries

Local validation does not dispatch GitHub Actions, register a runner, publish a release tag, or prove the reusable workflow succeeds on a self-hosted runner. The reparse-point check is defense-in-depth and does not eliminate concurrent time-of-check/time-of-use races. Run only trusted configuration in an isolated, least-privilege workspace.
