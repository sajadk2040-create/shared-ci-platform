# Runner host read-only preflight

The script scripts/Test-RunnerHostReadiness.ps1 inventories one explicitly selected runner installation. It is intended for review before provisioning a separate runner host.

## Safety properties

- Requires an explicit RunnerRoot and expected owner/repository; it never searches for or chooses a runner automatically.
- Reads only the non-secret .runner metadata file. It checks whether credential marker files exist but never opens their contents.
- Reports matching listener processes, matching Windows services, the audit process identity, and the root directory ACL entries.
- Does not create accounts, change ACLs, register/unregister runners, install services, or start/stop processes.
- Exits 2 when .runner metadata is missing/unreadable and 3 when the registered repository does not match the expected repository. Exit 0 means only that metadata matches; it is not a security approval.

## Example

Run from PowerShell 7. Elevation may be required to inspect all process and service metadata:

    pwsh -NoProfile -File scripts/Test-RunnerHostReadiness.ps1 -RunnerRoot 'C:\GitHubRunners\shared-ci' -ExpectedRepository 'sajadk2040-create/shared-ci-platform' -ReportPath '.\runner-host-preflight.json'

Treat the report as sensitive infrastructure inventory. Review paths and ACL identities before sharing it. Do not include credential contents, registration tokens, passwords, or environment variables in reports or support requests.

## Important interpretation

The script reports the selected root only. It does not establish that the machine is isolated, that inherited permissions are safe, that the runner service is least-privileged, or that the host is suitable for untrusted code. Path and service matching are inventory hints, not proof of ownership. A persistent runner executes repository code with the rights of its service account.

Never point this audit at the unrelated active runner under a developer profile unless there is a separate operational reason and authorization to inventory that installation. This preflight is deliberately non-mutating and does not provision or register the Shared CI runner.
