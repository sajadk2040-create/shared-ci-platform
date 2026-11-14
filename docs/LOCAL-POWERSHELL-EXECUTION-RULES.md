# Local PowerShell Execution Rules

These instructions apply to all future local PowerShell commands and validation steps for MotionDeck Studio and Shared CI Platform.

## Console presentation

1. Begin every operator-facing PowerShell script with `Clear-Host` so the console is cleared before the task starts.
2. Do not put `Clear-Host` between individual lines of a multi-line script; clear once at the beginning of each new script/task.

## Mandatory output handling

1. Every PowerShell command or script sent to the operator must print a complete, clearly delimited report.
2. At the end of every script, copy the complete report to the Windows Clipboard with `Set-Clipboard`.
3. Capture the native process exit code immediately after the command being tested, before running another native executable or command that could overwrite `$LASTEXITCODE`.
4. Include the exit code in the copied report. Do not report success unless the actual exit code and test output support it.
5. Prefer a single report buffer (for example, a `StringBuilder` or collected output lines) and use `Write-Host` to display it, then `Set-Clipboard -Value $report` to copy exactly the same report.
6. If clipboard access fails, print an explicit warning and preserve the full console output. Never silently claim the report was copied.
7. Do not truncate test output in the operator-facing report. If an underlying tool imposes an output limit, disclose that limitation.
8. Supply multi-line scripts as one complete block. Do not split a PowerShell `if/else`, function, loop, or `try/catch` construct across separate console submissions.

## Safe execution pattern

- Use the intended PowerShell executable explicitly when required. For this project, use 64-bit PowerShell 7 at `C:\Program Files\PowerShell\7\pwsh.exe` when installed.
- Run commands directly in the interactive console when output visibility matters. Avoid wrapping the whole invocation in fragile process-capture helpers.
- Capture `$LASTEXITCODE` immediately after native executables such as `pwsh.exe`, `git.exe`, or `gh.exe`.
- For PowerShell scripts, also capture terminating errors and the script's reported status; do not confuse a wrapper's exit code with the test process result.
- Keep reports free of credentials, tokens, passwords, private keys, and other secrets. Redact sensitive values before copying or publishing output.
- Never ask the operator to paste credentials into chat or include them in reports.

## GitHub local command-agent workflow

- Repository: `sajadk2040-create/shared-ci-platform`.
- Working branch: `feature/local-command-agent-v1`.
- Default authenticated account: `sajadk2040-create`.
- Execute only allowlisted task IDs through `scripts/Start-SharedCiLocalAgent.ps1`; never introduce arbitrary shell-command execution.
- For a one-shot task, invoke the agent with `-Once`, then verify its published response JSON in `responses/<command-id>.json`.
- A task is confirmed only when the response JSON reports `status: passed`, `exitCode: 0`, and the expected test output. A successful agent process alone is not sufficient.
- Keep the reusable workflow and pull request in draft until all required local Windows validation and host-safety gates pass.

## Host and runner safety constraints

- Do not modify, stop, unregister, delete, reconfigure, reuse, or relabel the unrelated runner at `C:\Users\user\MotionDeckStudio\actions-runner\runner` (runner `BR-GHAZANFARI`, belonging to another repository).
- Do not provision or register the dedicated Shared CI runner until all required validation gates pass and the operator explicitly authorizes provisioning.
- Do not run untrusted fork code on a persistent self-hosted runner. Treat the runner as a trusted-code execution environment, not a security sandbox.
- Do not publish a release or dispatch the reusable workflow before the project's stated gates are satisfied.

## Current validation checkpoint (2026-11-14)

The following GitHub response JSON files were independently inspected:

- `shared-ci-host-safety-013`: `status=passed`, `exitCode=0`, `timedOut=false`; five host-safety test groups passed. The harness did not create accounts, set passwords, mutate ACLs, register a runner, or install a service.
- `shared-ci-filesystem-links-015`: `status=passed`, `exitCode=0`; an actual Windows junction was identified as a reparse point. Symbolic-link creation was skipped because Administrator privilege was unavailable.
- `shared-ci-consumer-template-016`: `status=passed`, `exitCode=0`; all three consumer-template groups passed.
- `shared-ci-core-smoke-017`: `status=passed`, `exitCode=0`; all eight core smoke-test groups passed, including timeout tree termination and parallel report isolation.
- `shared-ci-agent-allowlist-012` and `agent-response-decision-tests-010`: passed.

These are local validation results, not proof of a sandbox or successful dedicated-runner provisioning. No Shared CI runner has been registered, no Windows service installed, and no reusable workflow has been dispatched on a dedicated runner. Keep the PR in draft pending remaining review and authorization gates.
