# Shared CI smoke project

This fixture exercises the generic process-runner contract without installing dependencies.

Run the success case from this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File ../../scripts/run.ps1 -ConfigPath ci.project.json
```

Expected behavior after execution is validated on a PowerShell 7 host:
- process exit code 0;
- report status `passed`;
- one step with exit code 0;
- Markdown, JSON, stdout, stderr and log files under `artifacts/ci/`.

Run the intentional failure case:

```powershell
pwsh -NoProfile -File ../../scripts/run.ps1 -ConfigPath ci.project.expected-failure.json
```

Expected behavior:
- runner process exits non-zero;
- report status `failed`;
- step exit code is 23;
- report files are written under `artifacts/ci-failure/`.

These are test fixtures only. The expected results are specifications, not observed test outcomes. Do not mark the platform validated until both commands and the path/config negative tests have actually run on PowerShell 7.
