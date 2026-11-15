# Local Command Agent (preview)

The Local Command Agent is an opt-in foreground PowerShell process. It polls a structured inbox and writes one metadata-only response file per command.

## Security model

- Inbox entries contain a task identifier only, never a shell command, executable, script path, or arbitrary arguments.
- A hard-coded local allowlist maps task identifiers to fixed scripts or fixed Git operations.
- The agent never uses Invoke-Expression or downloads code for execution.
- GitHub CLI authentication is used locally; no token is stored in the inbox, script, or response.
- The process runs in the current user's session, not as a Windows service or administrator.
- Project validation requires clean checkouts with expected remotes and branches.
- **Public GitHub responses contain metadata only**: command ID, allowlisted task ID, status, exit code, timeout flag, timestamps and duration.
- Detailed stdout, stderr and rejection diagnostics are written separately under the current user's local application data directory: `%LOCALAPPDATA%\MotionDeckStudio\SharedCiAgent\responses` (or `~/.motiondeck-studio/shared-ci-agent/responses` when LOCALAPPDATA is unavailable).
- Local logs can still contain sensitive information. Keep the workstation account protected and inspect logs before sharing them. Common credential patterns are redacted, but redaction is not a guarantee.
- This is not a sandbox. An allowlisted task still runs with the current user's permissions. Review agent updates before use.

## Prerequisites

- 64-bit PowerShell 7, Git, and GitHub CLI (gh).
- gh auth login completed for an account with write access to this repository.
- A clean trusted clone of Shared CI Platform.
- A clean MotionDeck Studio clone on main.

## Start

From the Shared CI Platform checkout:

    pwsh -NoProfile -File .\scripts\Start-SharedCiLocalAgent.ps1 -MotionDeckRoot <path-to-motiondeck-clone> -Ref security/workflow-gates-acl-v2

The agent polls every 15 seconds. Press Ctrl+C to stop it. It is not installed as a service and does not start automatically with Windows.

Use -Once to perform one poll and exit. Use -PollSeconds 30 to change the interval. The agent explicitly resolves and verifies a 64-bit PowerShell 7 executable rather than trusting PATH order.

## Protocol

The inbox file is `commands/inbox.json`. It contains schemaVersion 1 and either a null command or a command with id, task, issuedAt and expiresAt.

Supported task IDs in v1:

- motiondeck.repository-validation: run the fixed MotionDeck repository validation script.
- motiondeck.git-status: report branch and short working-tree status.
- motiondeck.current-commit: report the current MotionDeck commit.
- shared-ci.core-smoke: run the fixed Shared CI core smoke test.
- shared-ci.local-agent-static: run the fixed local agent parser and source-guard tests.
- shared-ci.host-safety: run the read-only host safety harness.
- shared-ci.filesystem-links: run the actual Windows junction/reparse-point integration test; symbolic-link creation is attempted when the host permits it.
- shared-ci.consumer-template: validate the consumer configuration, smoke script, immutable workflow pin and trigger safety.

The agent rejects expired commands, timestamps too far in the future, malformed IDs, unknown tasks, dirty or unexpected checkouts, and duplicate command IDs. Response lookup is fail-closed: only an explicit GitHub 404 is treated as an absent response; authentication, rate-limit, network and server errors stop processing.

Each public response is written to `responses/<command-id>.json` and contains only the metadata fields listed above. Detailed execution output is saved locally, not committed or uploaded. The inbox is not automatically cleared; the response file makes processing idempotent. After a task is verified, the operator should clear or replace the inbox before starting another task.

## Static safety check

Run the parser and source-guard checks before starting the agent:

    pwsh -NoProfile -File .\tests\Invoke-LocalAgentStaticTests.ps1

The static test validates parser safety, task allowlisting, 64-bit PowerShell resolution, fail-closed response lookup behavior, and separation between public metadata and local detailed logs.

## Security migration note

This implementation is being developed on a clean branch based on `main` so the prior preview branch's historical response artifacts are not inherited. The old draft PR and its historical commits remain unchanged. Because the repository is public, previously committed response artifacts may remain accessible through old commit history; deleting a file from a later commit does not erase that history. Do not merge the old PR or publish those historical artifacts as a release. If full historical removal is ever required, it needs a separately reviewed repository-history rewrite and GitHub cache/reference assessment.

## Limitations

- One outstanding command at a time; replace the inbox only after the previous response exists.
- Keep the agent running only while actively developing.
- Do not use this protocol for arbitrary shell commands, account changes, credential operations, deployments, destructive file operations, or untrusted pull-request code.
- This preview branch is not production-approved. Review and test the implementation before using it on the primary machine.
