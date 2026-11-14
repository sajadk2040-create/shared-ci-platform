# Local validation guide

This repository can be validated on a developer-controlled Windows machine without GitHub Actions and without a registered GitHub runner.

## Requirements

- Windows 10/11 or Windows Server supported by PowerShell 7.
- PowerShell 7 (`pwsh`) installed and available on `PATH`.
- A clean checkout of this repository.
- No GitHub token, repository secret, or production credential is needed.

## Run validation

Open PowerShell 7 in the repository root and run:

```powershell
$PSVersionTable.PSVersion
pwsh -NoProfile -File tests/Invoke-RunnerSmokeTests.ps1
```

The harness parses `scripts/run.ps1` with the PowerShell language parser, provisions a temporary project, and exercises:

1. successful child-process execution and JSON/Markdown/log report generation;
2. stdout and stderr capture;
3. exact argument boundaries for values containing spaces and quotes, while confirming raw argument values are absent from persisted reports/logs;
4. preservation of a child process exit code of 23 and runner exit code 1;
5. rejection of lexical project-root traversal;
6. rejection of absolute config paths and unsupported schema versions before a configured command runs;
7. on Windows, rejection of a directory junction that points outside the temporary project;
8. timeout reporting and termination of a timed-out process with its spawned child;
9. two simultaneous runs in one output directory, verifying unique run IDs and preservation of both sets of reports and stream files.

The harness prints a PASS line for parser validation and a final PASS line when all applicable checks finish. It exits non-zero on the first failed assertion. On failure, it retains the temporary workspace and prints its path for diagnosis; on success, it removes the temporary workspace.

## Evidence to record

For a release candidate, record the following in the project handoff:

- Windows edition/build;
- `$PSVersionTable.PSVersion`;
- exact harness command;
- complete console output;
- confirmation that the junction test ran (Windows only);
- commit SHA tested.

Do not include machine-specific secrets, environment variables containing credentials, or private paths in public logs.

Use [the validation evidence template](VALIDATION-RESULTS-TEMPLATE.md) to capture the runtime version, tested commit and results. Keep the filled-in copy local until machine-specific details have been reviewed and redacted.

## Boundaries

This is a local validation path. It does not dispatch GitHub Actions, register a runner, publish a release tag, or prove that the reusable workflow succeeds on a self-hosted runner. Those remain separate release gates. The path reparse-point check is defense-in-depth and does not eliminate concurrent time-of-check/time-of-use races; run only trusted configuration in an isolated, least-privilege workspace.
