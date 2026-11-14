# Local Command Agent (preview)

The Local Command Agent is an opt-in foreground PowerShell process. It polls a structured inbox and writes one response file per command.

## Security model

- Inbox entries contain a task identifier only, never a shell command, executable, script path, or arbitrary arguments.
- A hard-coded local allowlist maps task identifiers to fixed scripts or fixed Git operations.
- The agent never uses Invoke-Expression or downloads code for execution.
- GitHub CLI authentication is used locally; no token is stored in the inbox, script, or response.
- The process runs in the current user's session, not as a Windows service or administrator.
- Project validation requires clean checkouts with expected remotes and branches.
- Response output is capped and common credential patterns are redacted. Do not configure deployment secrets on this workstation.
- This is not a sandbox. An allowlisted task still runs with the current user's permissions. Review agent updates before use.

## Prerequisites

- Windows PowerShell 7, Git, and GitHub CLI (gh).
- gh auth login completed for an account with write access to this repository.
- A clean trusted clone of Shared CI Platform.
- A clean MotionDeck Studio clone on main.

## Start

From the Shared CI Platform checkout:

    pwsh -NoProfile -File .\scripts\Start-SharedCiLocalAgent.ps1 -MotionDeckRoot C:\Users\user\MotionDeckStudio\motiondeck-clean-validation -Ref feature/local-command-agent-v1

The agent polls every 15 seconds. Press Ctrl+C to stop it. It is not installed as a service and does not start automatically with Windows.

Use -Once to perform one poll and exit. Use -PollSeconds 30 to change the interval.

## Protocol

The inbox file is commands/inbox.json. It contains schemaVersion 1 and either a null command or a command with id, task, issuedAt and expiresAt.

Supported task IDs in v1:

- motiondeck.repository-validation: run the fixed MotionDeck repository validation script.
- motiondeck.git-status: report branch and short working-tree status.
- motiondeck.current-commit: report the current MotionDeck commit.
- shared-ci.core-smoke: run the fixed Shared CI core smoke test.

The agent rejects expired commands, timestamps too far in the future, malformed IDs, unknown tasks, dirty or unexpected checkouts, and duplicate command IDs.

Each response is written to responses/<command-id>.json. Responses include task, status, exit code, duration, timestamps and bounded/redacted output. The inbox is not automatically cleared; the response file makes processing idempotent.

## Static safety check

Run the parser and source-guard checks before starting the agent:

    pwsh -NoProfile -File .\tests\Invoke-LocalAgentStaticTests.ps1

This is a static check only; it does not validate live GitHub polling or Windows process execution.

## Limitations

- One outstanding command at a time; replace the inbox only after the previous response exists.
- Keep the agent running only while actively developing.
- Do not use this protocol for arbitrary shell commands, account changes, credential operations, deployments, destructive file operations, or untrusted pull-request code.
- This preview branch is not production-approved. Review and test the implementation before using it on the primary machine.
