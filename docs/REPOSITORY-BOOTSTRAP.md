# Standalone repository bootstrap

Target repository: `sajadk2040-create/shared-ci-platform`.

The standalone repository has been created and populated. Its root contains the PowerShell runner, schema, presets, examples, documentation, reusable workflow and MIT license.

## Consumer contract

1. Commit a root-level `ci.project.json` conforming to `schemas/ci-project.schema.json`.
2. Add a caller workflow that invokes the reusable workflow from a reviewed versioned tag or commit SHA.
3. Register a dedicated runner with the `shared-ci` label before enabling dispatch.
4. Use protected branches and trusted code only on this runner.
5. Keep the report output under `artifacts/ci` for the reusable workflow artifact upload.

## Local runtime validation

See [Local validation guide](LOCAL-VALIDATION.md). The expanded eight-group smoke harness passed on Windows / PowerShell 7.6.9 at commit `068a78027c74d023f13abf00122de14bb1d55461`. It covers parser validation, success/failure behavior, stream/report capture, argument preservation/redaction, lexical and junction path rejection, invalid config, timeout with spawned-child termination, and parallel report isolation.

The harness is a local runner test. It does not validate the GitHub reusable workflow, runner service configuration, permissions on a long-lived runner or deployment behavior.

## Reusable workflow design

- The workflow checks out the caller project and platform source into separate directories.
- Both checkouts disable persisted Git credentials.
- Workflow permissions are limited to `contents: read`.
- The job runs only on a dedicated self-hosted Windows/X64 runner with the `shared-ci` label.
- The runner's output directory is explicitly set to `artifacts/ci`, matching the artifact upload path.
- Do not run untrusted fork pull-request code on a privileged self-hosted runner.

## Release gates

`v0.1.0` was published on 2026-11-16 only after the following were complete:

| # | Gate | Status | Evidence |
|---|---|---|---|
| 1 | The expanded local PowerShell 7 smoke harness passes on the release candidate. | met | `tests/Invoke-RunnerSmokeTests.ps1`, eight groups, green on every self-hosted run |
| 2 | The reusable workflow YAML is parsed and reviewed. | met | `tests/Invoke-RunnerHostSafetyTests.ps1`, five groups |
| 3 | A dedicated least-privilege self-hosted runner is provisioned, isolated and security-reviewed. | partially met | both runners are Windows services on a dedicated host, but they run as `SYSTEM` / `NETWORK SERVICE`; the dedicated `svc-shared-ci` account is still pending |
| 4 | A manual workflow run succeeds on that runner using a reviewed platform commit. | met | run `43766141459` (manual dispatch, `main` @ `7e1c8bc`) |
| 5 | Artifact upload is verified and reviewed for secret leakage. | met | run `43766608260`, 10 files, 0 token-like matches |
| 6 | The release artifact contains no secrets or machine-specific paths. | met | PR #10 redaction; re-inspection found 0 `C:\`, `GitHubRunners` or `_work` fragments |
| 7 | MotionDeck's consumer config/workflow is reviewed and uses the versioned platform reference. | met | tag `v0.1.0` at `62a28e7`, consumer run `43832199370` green at `reusable.yml@v0.1.0` |

Gate 3 stays open as post-release hardening: reducing the runner services to a dedicated machine account
changes host ACLs and service identities, so it is tracked separately and does not block the `0.1.0` release.
